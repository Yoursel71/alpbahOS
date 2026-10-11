import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from contextlib import ExitStack, contextmanager
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
def load(name):
    spec = importlib.util.spec_from_file_location(name, REPO / 'scripts' / (name + '.py'))
    value = importlib.util.module_from_spec(spec); spec.loader.exec_module(value)
    return value

session = load('infra-kernel-session')
transport = load('infra-kernel-authorize')
HOST_BOOT = '11111111-2222-4333-8444-555555555555'
GUEST_BOOT = '22222222-3333-4444-8555-666666666666'


class HostKernelSessionTests(unittest.TestCase):
    def test_actual_cli_absent_base_never_grants_authorization_or_launches(self):
        result = subprocess.run(['python3', '-I', str(REPO / 'scripts/infra-kernel-session.py')], capture_output=True)
        self.assertEqual(result.returncode, 1); self.assertEqual(result.stdout, b'')
        self.assertIn(b'base-acceptance.json', result.stderr)

    def test_root_and_bypass_flags_cannot_open_a_session(self):
        with patch.object(session.os, 'geteuid', return_value=0), patch.object(session, 'rules') as rules:
            with self.assertRaisesRegex(RuntimeError, 'unprivileged'):
                session.preflight()
            with self.assertRaisesRegex(RuntimeError, 'host root'):
                with session.session(): pass
            rules.assert_not_called()
        result = subprocess.run(['python3', '-I', str(REPO / 'scripts/infra-kernel-session.py'), '--resume'], capture_output=True)
        self.assertEqual(result.returncode, 1); self.assertIn(b'bypass/launch flags', result.stderr)

    def test_source_pin_drift_fails_before_imported_helper_execution(self):
        self.assertEqual(len(session.rules()), 3)
        with patch.object(session.buildctl, 'sha', return_value='0' * 64):
            with self.assertRaisesRegex(RuntimeError, 'dependency alias/owner/source drift'):
                session.rules()

    def test_real_lock_collision_and_alias_refuse_before_lifecycle(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(session.buildctl, 'STATE', Path(folder)), patch.object(session.buildctl, 'pid', return_value=None):
            with session.controller_lock():
                with self.assertRaises(BlockingIOError):
                    with session.controller_lock(): pass
            path = Path(folder) / 'controller.lock'; path.unlink()
            protected = Path(folder) / 'protected'; protected.write_text('protected')
            path.symlink_to(protected)
            with self.assertRaises(OSError):
                with session.controller_lock(): pass
            self.assertEqual(protected.read_text(), 'protected')

    @contextmanager
    def fixture(self):
        # Real tiny disk checkpoints/file writes + real host/guest payload codec.
        # All root capture, actual VM identity, SSH and launch are explicit mocks.
        with tempfile.TemporaryDirectory() as folder, ExitStack() as stack:
            root = Path(folder)
            for name in ('vm', 'state', 'artifacts', 'runs', 'run-artifacts', 'requests', 'guest'):
                (root / name).mkdir(mode=0o700)
            vm, state, artifacts, guest = [root / name for name in ('vm','state','artifacts','guest')]
            parent, base, kernel = session.rules()
            for disk in ('builder','lfs'):
                subprocess.run(['qemu-img','create','-f','qcow2',str(vm / (disk+'-active.qcow2')),'1M'],check=True,capture_output=True)
            chains = session.checkpoint_store.inspect_disks(vm, lambda:None, lambda:None)
            proof = {'schema':'alpbahOS.base-acceptance/v1','result':'PASS','stage':'base','mode':'multilib-m32',
                'run_id':'a'*32,'inputs_sha256':'1'*64,'sources_sha256':'2'*64,'closed_disk_chains':chains,
                'guest':{'schema':'alpbahOS.base-guest-evidence/v1','result':'VERIFIED_GUEST_BYTES','package_count':79,
                         'run_id':'a'*32,'inputs_sha256':'1'*64,'sources_sha256':'2'*64,'final_db_sha256':'4'*64}}
            saved = session.checkpoint_store.create(vm,'base','1'*64,'2'*64,proof,lambda:None,lambda:None)
            proof = {**proof, 'checkpoint_sha256':session.buildctl.sha(saved/'checkpoint.json'),
                     'transaction_sha256':session.buildctl.sha(saved/'transaction.json')}
            raw = session.encoded(proof); (artifacts/'base-acceptance.json').write_bytes(raw)
            boot = root/'boot-id'; boot.write_text(HOST_BOOT)
            events=[]; live={'pid':None}
            real_sha = session.buildctl.sha
            def checksum(path):
                path = Path(path)
                if path == REPO/'manifests/infra-sources.json': return '2'*64
                if path == artifacts/'phase1-acceptance.json': return '3'*64
                return real_sha(path)
            def restore(name):
                self.assertEqual(name,'base'); events.append('restore')
                old = vm/'preserved'; old.mkdir(mode=0o700)
                for disk in ('builder','lfs'):
                    active = vm/(disk+'-active.qcow2'); active.rename(old/active.name)
                    subprocess.run(['qemu-img','create','-f','qcow2','-F','qcow2','-b',str(saved/(disk+'.qcow2')),str(active)],check=True,capture_output=True)
            def launch(**kwargs):
                self.assertEqual(kwargs,{'offline':True,'vcpus':16}); events.append('launch'); live['pid']=123
            def stop(): events.append('stop'); live['pid']=None
            def capture(*args): events.append('root-before')
            def snapshot(value,phase):
                events.append('repositories-'+phase)
                session.stage_runs.write(session.stage_runs.ARTIFACTS/value['run_id']/('repositories-'+phase+'.json'),{'fixture':phase})
            measured={'guest_boot_id':GUEST_BOOT,'helper_sha256':{name:session.PINS[name] for name in kernel.HELPERS},
                'inputs':{'inputs_sha256':'1'*64,'sources_sha256':'2'*64},'inputs_raw_sha256':'5'*64,'source_sha256':kernel.SOURCE_SHA}
            real_run = subprocess.run
            wire={'response_change':None,'receipt_change':None,'fail_delivery':False}
            def command(argv, **kwargs):
                if argv[0]=='rsync': events.append('transfer'); return subprocess.CompletedProcess(argv,0,b'',b'')
                if argv[0]!='ssh': return real_run(argv,**kwargs)
                remote=argv[-1]
                if remote=='bash /opt/alp-infra/scripts/infra-kernel-authorize.sh':
                    events.append('deliver')
                    if wire['fail_delivery']: return subprocess.CompletedProcess(argv,1,b'',b'interrupted transport')
                    raw_payload=kwargs['input']; base_raw, base_proof, parent_raw, capsule, auth=transport.decode(raw_payload)
                    current=kernel.binding(auth,base_proof,capsule,measured['inputs'],GUEST_BOOT,measured['helper_sha256'],session.digest(base_raw),session.digest(parent_raw))
                    response=transport.deliver(raw_payload,current,base_raw,parent_raw,session.encoded(auth))
                    if wire['response_change']: response.update(wire['response_change'])
                    return subprocess.CompletedProcess(argv,0,session.encoded(response),b'')
                if 'completed.json' in remote:
                    events.append('read-completion')
                    receipts=list((guest/'kernel-handoffs').glob('*.completed.json'))
                    body=receipts[0].read_bytes()
                    if wire['receipt_change']:
                        value=json.loads(body); value.update(wire['receipt_change']); body=session.encoded(value)
                    return subprocess.CompletedProcess(argv,0,body,b'')
                events.append('measure'); return subprocess.CompletedProcess(argv,0,session.encoded(measured),b'')
            for module, attr, value in [(session.buildctl,'VM',vm),(session.buildctl,'STATE',state),
                    (session.buildctl,'ARTIFACTS',artifacts),(session.stage_runs,'RUNS',root/'runs'),
                    (session.stage_runs,'ARTIFACTS',root/'run-artifacts'),(session.audit,'REQUESTS',root/'requests'),
                    (session.audit,'BOOT',boot),(transport,'INFRA',guest)]:
                stack.enter_context(patch.object(module,attr,value))
            stack.enter_context(patch.object(session,'preflight',return_value=(raw,proof,parent,base,kernel)))
            stack.enter_context(patch.object(session.buildctl,'pid',side_effect=lambda:live['pid']))
            stack.enter_context(patch.object(session.buildctl,'restore',side_effect=restore))
            stack.enter_context(patch.object(session.buildctl,'launch',side_effect=launch))
            stack.enter_context(patch.object(session.buildctl,'stop',side_effect=stop))
            stack.enter_context(patch.object(session.buildctl,'space_guard'))
            stack.enter_context(patch.object(session.buildctl,'sync',side_effect=lambda:events.append('sync')))
            stack.enter_context(patch.object(session.buildctl,'sha',side_effect=checksum))
            stack.enter_context(patch.object(session.buildctl,'inputs_digest',return_value='1'*64))
            stack.enter_context(patch.object(base,'root_capture',side_effect=capture))
            stack.enter_context(patch.object(base,'wait_for_builder_memory'))
            stack.enter_context(patch.object(session.audit,'verify',return_value={'fixture_root_capture':True}))
            stack.enter_context(patch.object(session.stage_runs,'repository_snapshot',side_effect=snapshot))
            stack.enter_context(patch.object(session.host_monitor,'sample',return_value={'boot_id':HOST_BOOT}))
            stack.enter_context(patch.object(session.host_monitor,'validate_sample'))
            stack.enter_context(patch.object(session.subprocess,'run',side_effect=command))
            stack.enter_context(patch.object(transport.kernel.package_install,'guest_install_guard'))
            yield {'root':root,'vm':vm,'proof':proof,'raw':raw,'events':events,'live':live,'base':base,
                   'measured':measured,'wire':wire,'boot':boot,'kernel':kernel}

    def outcome(self,f):
        records=list((f['root']/'runs').glob('*/outcome.json')); self.assertEqual(len(records),1)
        return json.loads(records[0].read_bytes())

    def test_real_fixture_codec_delivery_requires_consumer_and_closes_its_vm(self):
        with self.fixture() as f:
            with self.assertRaisesRegex(RuntimeError,'session failed'):
                with session.session() as context:
                    self.assertEqual(context['response']['result'],'HANDOFF_BOUND')
                    self.assertEqual(context['guest_boot_id'],GUEST_BOOT)
            self.assertEqual(self.outcome(f)['result'],'FAIL')
            self.assertIsNone(f['live']['pid'])
            self.assertLess(f['events'].index('root-before'),f['events'].index('launch'))
            self.assertLess(f['events'].index('measure'),f['events'].index('deliver'))
            self.assertIn('read-completion',f['events'])
            self.assertFalse((f['vm']/'checkpoint-kernel').exists())

    def test_consumer_lifecycle_yields_only_pending_post_not_acceptance(self):
        with self.fixture() as f:
            with session.session() as context:
                value=context['value']
                context['guest_artifact_evidence']={'schema':'alpbahOS.kernel-guest-evidence/v1',
                    'result':'VERIFIED_GUEST_BYTES','guest_boot_id':GUEST_BOOT,
                    **{k:value[k] for k in ('run_id','inputs_sha256','sources_sha256')}}
            self.assertEqual(self.outcome(f)['result'],'PENDING_PRIVILEGED_POST')
            self.assertIn('post_request',context)
            self.assertIsNone(f['live']['pid'])
            self.assertLess(f['events'].index('stop'), f['events'].index('repositories-after'))
            self.assertFalse((f['root']/'artifacts/kernel-acceptance.json').exists())
            self.assertFalse((f['vm']/'checkpoint-kernel').exists())

    def test_current_child_change_or_missing_root_before_has_no_launch(self):
        for change in ('child','root-before'):
            with self.subTest(change=change),self.fixture() as f:
                if change=='child':
                    def changed():
                        subprocess.run(['qemu-io','-f','qcow2','-c','write 0 4096',str(f['vm']/'lfs-active.qcow2')],check=True,capture_output=True)
                    guard=patch.object(f['base'],'wait_for_builder_memory',side_effect=changed)
                else: guard=patch.object(session.audit,'verify',side_effect=RuntimeError('root before unavailable'))
                with guard,self.assertRaises(RuntimeError):
                    with session.session(): pass
                self.assertNotIn('launch',f['events']); self.assertIsNone(f['live']['pid'])

    def test_guest_boot_helper_and_source_mismatch_block_delivery(self):
        for field,value in [('guest_boot_id',HOST_BOOT),('helper_sha256',{}),('source_sha256','0'*64)]:
            with self.subTest(field=field),self.fixture() as f:
                f['measured'][field]=value
                with self.assertRaisesRegex(RuntimeError,'session failed'):
                    with session.session(): pass
                self.assertNotIn('deliver',f['events']); self.assertEqual(self.outcome(f)['result'],'FAIL')
                self.assertIsNone(f['live']['pid'])

    def test_returned_or_committed_receipt_must_match_exact_payload(self):
        for key in ('response_change','receipt_change'):
            with self.subTest(key=key),self.fixture() as f:
                f['wire'][key]={'payload_sha256':'0'*64}
                with self.assertRaisesRegex(RuntimeError,'session failed'):
                    with session.session(): pass
                self.assertEqual(self.outcome(f)['result'],'FAIL'); self.assertIsNone(f['live']['pid'])
                self.assertTrue(list((f['root']/'guest/kernel-handoffs').glob('*.attempt.json')))

    def test_interrupted_delivery_and_consumer_exception_retain_fail_outcome(self):
        for fail in ('delivery','consumer'):
            with self.subTest(fail=fail),self.fixture() as f:
                f['wire']['fail_delivery']=fail=='delivery'
                with self.assertRaisesRegex(RuntimeError,'session failed'):
                    with session.session(): raise RuntimeError('consumer error')
                self.assertEqual(self.outcome(f)['result'],'FAIL')
                self.assertTrue((f['vm']/'preserved').exists()); self.assertIsNone(f['live']['pid'])
                self.assertTrue(list((f['root']/'run-artifacts').glob('*/authorization.json')))

    def test_same_parent_nonce_and_live_controller_never_restore(self):
        with self.fixture() as f,patch.object(session.secrets,'token_hex',return_value=f['proof']['run_id']):
            with self.assertRaisesRegex(RuntimeError,'nonce must differ'):
                with session.session(): pass
            self.assertNotIn('restore',f['events'])
        with self.fixture() as f:
            f['live']['pid']=777
            with self.assertRaisesRegex(RuntimeError,'already live'):
                with session.session(): pass
            self.assertNotIn('restore',f['events']); self.assertEqual(f['live']['pid'],777)

    def test_consumer_evidence_from_another_job_or_boot_is_fail(self):
        for field in ('run_id', 'inputs_sha256', 'sources_sha256', 'guest_boot_id'):
            with self.subTest(field=field), self.fixture() as f:
                with self.assertRaisesRegex(RuntimeError, 'session failed'):
                    with session.session() as context:
                        value = context['value']
                        evidence = {'schema': 'alpbahOS.kernel-guest-evidence/v1',
                            'result': 'VERIFIED_GUEST_BYTES', 'guest_boot_id': GUEST_BOOT,
                            **{k: value[k] for k in ('run_id', 'inputs_sha256', 'sources_sha256')}}
                        evidence[field] = HOST_BOOT if field == 'guest_boot_id' else '0' * len(evidence[field])
                        context['guest_artifact_evidence'] = evidence
                self.assertEqual(self.outcome(f)['result'], 'FAIL')
                self.assertIsNone(f['live']['pid'])
                self.assertFalse((f['root'] / 'artifacts/kernel-acceptance.json').exists())

if __name__=='__main__': unittest.main()
