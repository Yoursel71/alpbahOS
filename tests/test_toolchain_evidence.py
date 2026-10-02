"""Real tar/manifest/raw DB fixtures; no root, compiler or VM execution."""
import hashlib
import io
import json
import os
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'scripts/infra'))
import toolchain_evidence as evidence
import toolchain_plan
import toolchain_sanity
from package_install import fingerprint
from package_stage import sha, source_pin
from filesystem_layout import DIRECTORIES, LINKS
from test_infra_rebuild import handoff_fixture
import test_infra_rebuild as boundary_tests


def write_json(path, value):
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + '\n')


class ToolchainPackageEvidenceTests(unittest.TestCase):
    def fixture(self, root, abi=False):
        root.chmod(0o700)
        sources = json.loads((REPO / 'manifests/infra-sources.json').read_bytes())
        inputs = {'inputs_sha256': '1' * 64, 'sources_sha256': sha(REPO / 'manifests/infra-sources.json')}
        infra = root / 'transport'; infra.mkdir()
        capsule, auth = handoff_fixture(infra, inputs)
        raw = (infra / 'stability-acceptance.json').read_bytes()
        plan = toolchain_plan.load(REPO)
        binding = {**inputs, 'plan_sha256': fingerprint(plan), 'run_id': capsule['run_id'],
                   'guest_boot_id': capsule['guest_boot_id'], 'handoff_sha256': auth['handoff_sha256']}
        write_json(root / 'inputs.json', binding)
        records, actions, observations = {}, [], []
        for recipe in plan:
            name = recipe['name']; directory = root / name; directory.mkdir()
            source = source_pin(sources, recipe['source'], REPO)
            entries = []
            if name == 'filesystem-layout':
                for path, mode in sorted(DIRECTORIES.items()):
                    entries.append({'path': '/' + path, 'type': 'directory', 'mode': mode, 'uid': 0, 'gid': 0})
                for path, target in sorted(LINKS.items()):
                    entries.append({'path': '/' + path, 'type': 'symlink', 'mode': 0o777,
                                    'uid': 0, 'gid': 0, 'target': target})
            else:
                for path in ('usr', 'usr/share'):
                    entries.append({'path': '/' + path, 'type': 'directory', 'mode': 0o755, 'uid': 0, 'gid': 0})
                content = ('Synthetic payload for ' + name).encode()
                entries.append({'path': '/usr/share/' + name, 'type': 'file', 'mode': 0o644, 'uid': 0, 'gid': 0,
                                'size': len(content), 'sha256': hashlib.sha256(content).hexdigest()})
            contents = {e['path']: content for e in entries if e['type'] == 'file'}
            if abi and name != 'filesystem-layout':
                roles = {
                    'binutils-pass1': ['tools/bin/x86_64-lfs-linux-gnu-ld'],
                    'gcc-pass1': ['tools/bin/x86_64-lfs-linux-gnu-gcc', 'tools/bin/x86_64-lfs-linux-gnu-g++',
                                 'tools/lib/gcc/x86_64-lfs-linux-gnu/15.2.0/include/limits.h'],
                    'linux-headers': ['usr/include/linux/kernel.h'],
                    'glibc-cross-m64': ['usr/include/stdio.h', 'usr/include/limits.h',
                        *['usr/lib/' + f for f in ('libc.so.6', 'ld-linux-x86-64.so.2', 'Scrt1.o', 'crti.o', 'crtn.o')]],
                    'glibc-cross-m32': ['usr/lib32/' + f for f in ('libc.so.6', 'ld-linux.so.2', 'Scrt1.o', 'crti.o', 'crtn.o')],
                    'libstdcxx-cross': ['usr/lib/libstdc++.so.6', 'usr/lib32/libstdc++.so.6', 'usr/include/c++/15.2.0/vector']}
                links = {'glibc-cross-m64': {'lib64/ld-linux-x86-64.so.2': '../lib/ld-linux-x86-64.so.2'},
                         'glibc-cross-m32': {'usr/lib/ld-linux.so.2': '../lib32/ld-linux.so.2'},
                         'libstdcxx-cross': {'usr/lib/libstdc++.so': 'libstdc++.so.6', 'usr/lib32/libstdc++.so': 'libstdc++.so.6'}}.get(name, {})
                paths = set(e['path'][1:] for e in entries)
                for role in [*roles[name], *links]:
                    for parent in reversed(Path(role).parents):
                        path = str(parent)
                        if path != '.' and path not in paths:
                            entries.append({'path': '/' + path, 'type': 'directory', 'mode': 0o755, 'uid': 0, 'gid': 0})
                            paths.add(path)
                    if role in links:
                        entries.append({'path': '/' + role, 'type': 'symlink', 'target': links[role],
                                        'mode': 0o777, 'uid': 0, 'gid': 0})
                    else:
                        data = ('Synthetic ABI role ' + role).encode(); contents['/' + role] = data
                        entries.append({'path': '/' + role, 'type': 'file', 'mode': 0o644, 'uid': 0, 'gid': 0,
                                        'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
            archive = directory / ('toolchain-' + name + '.tar.gz')
            with tarfile.open(archive, 'w:gz') as tar:
                for entry in entries:
                    member = tarfile.TarInfo(entry['path'][1:]); member.mode = entry['mode']
                    member.uid = member.gid = 0
                    if entry['type'] == 'directory': member.type = tarfile.DIRTYPE
                    elif entry['type'] == 'symlink': member.type = tarfile.SYMTYPE; member.linkname = entry['target']
                    else: member.size = len(contents[entry['path']])
                    tar.addfile(member, io.BytesIO(contents[entry['path']]) if entry['type'] == 'file' else None)
            manifest = directory / ('toolchain-' + name + '.json')
            write_json(manifest, {'schema': 'alpbahOS.package-files/v1', 'package': {'name': name,
                       'version': recipe['version'], 'source': {'url': source['url'], 'sha256': source['sha256']}},
                       'entries': entries})
            guest = '/srv/lfs/results/toolchain/' + capsule['run_id'] + '/' + name
            built = {'archive': guest + '/' + archive.name, 'manifest': guest + '/' + manifest.name,
                     'archive_sha256': sha(archive), 'manifest_sha256': sha(manifest), 'source': source, 'seconds': 1.0}
            write_json(directory / 'built.json', {'result': 'BUILT', 'binding': binding, 'built': built})
            url = f'file:///srv/lfs/packages/{name}-{recipe["version"]}-{sha(archive)}.tar.gz'
            record = {'status': 'installed', 'version': recipe['version'], 'method': 'core', 'protected': True,
                      'source': {'url': url, 'sha256': sha(archive)},
                      'files': [e['path'] for e in entries],
                      'symlinks': [e['path'] for e in entries if e['type'] == 'symlink']}
            records[name] = record
            db = directory / (name + '.db.json'); write_json(db, {'schema_version': 1, 'packages': records})
            index = directory / (name + '.index.json')
            write_json(index, {'schema_version': 1, 'entries': {name: {'method': 'core', 'name': name,
                       'version': recipe['version'], 'url': url, 'sha256': sha(archive),
                       'depends': list(recipe.get('requires', [])), 'protected': True}}})
            (directory / (name + '.install.log')).write_text('Synthetic install; no Alp executed.\n')
            write_json(directory / (name + '.installed.json'), {'result': 'PASS', 'package': name,
                       'version': recipe['version'], 'root': '/srv/lfs', 'inputs_sha256': inputs['inputs_sha256'],
                       'recipe_sha256': fingerprint(recipe), 'alp_sha256': sources['alp']['sha256'],
                       'source_date_epoch': sources['source_date_epoch'], 'archive_sha256': sha(archive),
                       'manifest_sha256': sha(manifest), 'db_sha256': sha(db), 'package_record_sha256': fingerprint(record),
                       'index': guest + '/' + index.name, 'index_sha256': sha(index), 'log': guest + '/' + name + '.install.log'})
            observed = directory / 'observed.json'
            write_json(observed, {'schema': 'alpbahOS.installed-observation/v1', 'run_id': capsule['run_id'],
                       'package': name, 'root': '/srv/lfs', 'entries': entries})
            actions.append({'package': name, 'action': 'installed verified bundle',
                            'archive_sha256': sha(archive), 'manifest_sha256': sha(manifest)})
            observations.append({'package': name, 'observed': name + '/observed.json', 'observed_sha256': sha(observed)})
        write_json(root / 'db-final.json', {'schema_version': 1, 'packages': records})
        write_json(root / 'summary.json', {**binding, 'schema': 'alpbahOS.toolchain-guest/v1', 'result': 'PASS',
                   'mode': 'multilib-m32', 'alp_sha256': sources['alp']['sha256'],
                   'source_date_epoch': sources['source_date_epoch'], 'packages': actions,
                   'observations': observations, 'final_db_sha256': sha(root / 'db-final.json'), 'sanity': []})
        return inputs, raw, auth, capsule['guest_boot_id']

    def verify(self, root, args):
        return evidence.verify_packages(root, REPO, *args)

    def rebind_records(self, root, records):
        # Update only synthetic fixture pins so semantic ownership checks run.
        write_json(root / 'db-final.json', {'schema_version': 1, 'packages': records})
        summary = json.loads((root / 'summary.json').read_bytes())
        summary['final_db_sha256'] = sha(root / 'db-final.json'); write_json(root / 'summary.json', summary)
        for i, name in enumerate(toolchain_plan.ORDER):
            directory = root / name; db = directory / (name + '.db.json')
            write_json(db, {'schema_version': 1, 'packages': {p: records[p] for p in toolchain_plan.ORDER[:i + 1]}})
            receipt = directory / (name + '.installed.json'); value = json.loads(receipt.read_bytes())
            value.update(db_sha256=sha(db), package_record_sha256=fingerprint(records[name])); write_json(receipt, value)

    def test_actual_seven_bundles_raw_prefixes_and_readonly_result(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); args = self.fixture(root)
            before = evidence.file_hashes(root)
            proof, payload = self.verify(root, args)
            self.assertEqual(proof['result'], 'VERIFIED_PACKAGE_BYTES')
            self.assertEqual(proof['artifact_sha256'], before)
            self.assertEqual(evidence.file_hashes(root), before)
            self.assertEqual(payload.resolve('lib32'), 'usr/lib32')
            self.assertEqual(payload.file('/srv/lfs/bin/../share/gcc-pass1', {'gcc-pass1'}), '/srv/lfs/usr/share/gcc-pass1')

    def test_raw_snapshot_bytes_and_prefix_drift_rejected(self):
        for change in ('whitespace', 'extra-package', 'old-record'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); args = self.fixture(root)
                name = 'gcc-pass1'; db = root / name / (name + '.db.json')
                if change == 'whitespace':
                    db.write_bytes(db.read_bytes() + b' '); cause = 'receipt/raw DB/index'
                else:
                    value = json.loads(db.read_bytes())
                    if change == 'extra-package': value['packages']['foreign'] = {}; cause = 'exact prefix'
                    else: value['packages']['filesystem-layout']['timestamp'] = 'different'; cause = 'record changed after'
                    write_json(db, value)
                with self.assertRaisesRegex(RuntimeError, cause): self.verify(root, args)

    def test_payload_observation_is_compared_to_real_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); args = self.fixture(root); name = 'gcc-pass1'
            observed = root / name / 'observed.json'; value = json.loads(observed.read_bytes())
            value['entries'][-1]['sha256'] = '0' * 64; write_json(observed, value)
            summary = json.loads((root / 'summary.json').read_bytes())
            summary['observations'][2]['observed_sha256'] = sha(observed); write_json(root / 'summary.json', summary)
            with self.assertRaisesRegex(RuntimeError, 'observation differs'): self.verify(root, args)

    def test_rebound_raw_db_missing_extra_conflicting_and_aliased_claims(self):
        for change in ('missing', 'extra', 'conflict', 'alias'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); args = self.fixture(root)
                records = json.loads((root / 'db-final.json').read_bytes())['packages']
                claims = records['gcc-pass1']['files']
                if change == 'missing': claims.remove('/usr/share/gcc-pass1')
                elif change == 'extra': claims.append('/usr/share/unowned')
                elif change == 'conflict': claims.append('/usr/share/binutils-pass1')
                else: claims[claims.index('/usr/share/gcc-pass1')] = '/bin/../share/gcc-pass1'
                self.rebind_records(root, records)
                if change == 'alias':
                    # '..' in DB claims is rejected even when it would remain in LFS.
                    with self.assertRaisesRegex(RuntimeError, 'Unsafe archive path'): self.verify(root, args)
                else:
                    with self.assertRaisesRegex(RuntimeError, 'ownership missing/extra|claims absent'): self.verify(root, args)

    def test_current_handoff_source_and_fixed_bundle_path(self):
        for change in ('guest-boot', 'source-pin', 'bundle-path', 'source-object', 'order'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); args = list(self.fixture(root))
                if change == 'guest-boot': args[3] = '22222222-2222-4222-8222-222222222222'; cause = 'guest boot invalid'
                elif change == 'source-pin': args[0] = {**args[0], 'sources_sha256': '0' * 64}; cause = 'canonical source manifest'
                elif change in ('bundle-path', 'source-object'):
                    path = root / 'gcc-pass1/built.json'; value = json.loads(path.read_bytes())
                    if change == 'bundle-path': value['built']['archive'] = '/tmp/old.tar.gz'; cause = 'fixed guest path'
                    else: value['built']['source']['url'] = 'https://invalid.test/source'; cause = 'canonical source/timing'
                    write_json(path, value)
                else:
                    path = root / 'summary.json'; value = json.loads(path.read_bytes()); value['packages'].reverse()
                    write_json(path, value); cause = 'ordered package'
                with self.assertRaisesRegex(RuntimeError, cause): self.verify(root, args)

    def test_tar_bytes_protected_record_and_index_cannot_be_pass_strings(self):
        for change in ('archive', 'protected', 'index'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); args = self.fixture(root); name = 'gcc-pass1'
                if change == 'archive':
                    path = root / name / ('toolchain-' + name + '.tar.gz'); path.write_bytes(b'PASS'); cause = 'bundle bytes changed'
                elif change == 'protected':
                    records = json.loads((root / 'db-final.json').read_bytes())['packages']; records[name]['protected'] = False
                    self.rebind_records(root, records); cause = 'protected package'
                else:
                    index = root / name / (name + '.index.json'); value = json.loads(index.read_bytes())
                    value['entries'][name]['depends'] = []; write_json(index, value)
                    receipt = root / name / (name + '.installed.json'); value = json.loads(receipt.read_bytes())
                    value['index_sha256'] = sha(index); write_json(receipt, value); cause = 'index scope/source'
                with self.assertRaisesRegex(RuntimeError, cause): self.verify(root, args)

    def test_alias_hardlink_and_writable_collected_evidence_rejected(self):
        for change in ('alias', 'hardlink', 'writable'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); args = self.fixture(root); path = root / 'db-final.json'
                if change == 'alias': path.rename(root / 'original'); path.symlink_to(root / 'original')
                elif change == 'hardlink': os.link(path, root / 'duplicate')
                else: path.chmod(0o666)
                with self.assertRaisesRegex(RuntimeError, 'alias forbidden|hardlink invalid|write permission invalid'):
                    self.verify(root, args)

    def test_recorded_symlinks_escape_cycle_and_wrong_owner_rejected(self):
        for target in ('../../outside', 'loop'):
            payload = object.__new__(evidence.Payload)
            payload.entries = {'loop': {'type': 'symlink', 'target': target}}
            with self.assertRaisesRegex(RuntimeError, 'escapes LFS|cyclic'):
                payload.resolve('loop/file')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); _, payload = self.verify(root, self.fixture(root))
            for path, owners in (('/usr/share/gcc-pass1', {'gcc-pass1'}),
                                 ('/srv/lfs/usr/share/gcc-pass1', {'glibc-cross-m64'}),
                                 ('/srv/lfs/usr/share/missing', {'gcc-pass1'})):
                with self.assertRaisesRegex(RuntimeError, 'outside recorded|file/owner/tree invalid'):
                    payload.file(path, owners)


class ToolchainAbiEvidenceTests(unittest.TestCase):
    def fixture(self, root):
        packages = ToolchainPackageEvidenceTests()
        args = packages.fixture(root, abi=True)
        proof, payload = packages.verify(root, args)
        epoch = json.loads((REPO / 'manifests/infra-sources.json').read_bytes())['source_date_epoch']
        summary = json.loads((root / 'summary.json').read_bytes()); sanity = []
        binding = {k: proof[k] for k in ('inputs_sha256', 'sources_sha256', 'run_id', 'guest_boot_id', 'handoff_sha256')}
        prefix = ['runuser', '-u', 'lfs', '--', 'env', '-i', 'HOME=/home/lfs',
                  'PATH=/srv/lfs/tools/bin:/usr/bin:/bin', 'LC_ALL=C', 'LANG=C', 'TZ=UTC', 'SOURCE_DATE_EPOCH=' + str(epoch)]
        for number, stage in enumerate(('glibc-cross-m64', 'glibc-cross-m32', 'libstdcxx-cross')):
            directory = root / ('abi-' + stage + '-' + str(number + 1)); directory.mkdir()
            guest = '/srv/lfs/results/toolchain/' + proof['run_id'] + '/' + directory.name
            language = 'c++' if stage == 'libstdcxx-cross' else 'c'
            compiler = '/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-' + ('g++' if language == 'c++' else 'gcc')
            commands, artifacts, rows = [], {}, []

            def command(label, argv, stdout='', stderr='', cwd=guest, input=None):
                command_prefix = [*prefix, 'TMPDIR=' + cwd] if label.endswith('-compile') else prefix
                expected = {'argv': command_prefix + argv, 'cwd': cwd, 'input': input}; commands.append(expected)
                (directory / (label + '.stdout')).write_text(stdout)
                (directory / (label + '.stderr')).write_text(stderr)
                started = 1_000_000_000_000 + len(commands) * 1_000_000_000
                record = {**expected, 'schema': 'alpbahOS.abi-command/v1', 'label': label,
                          **{k: proof[k] for k in ('run_id', 'guest_boot_id', 'handoff_sha256')}, 'exit': 0, 'errors': [],
                          'started_at_ns': started, 'ended_at_ns': started + 1000,
                          'started_monotonic_ns': started, 'ended_monotonic_ns': started + 1000}
                write_json(directory / (label + '.command.json'), record)
                volumes = {path: {'total': 1000, 'available': 600, 'device': device, 'inode': 1}
                           for path, device in (('/', 1), ('/srv/lfs', 2))}
                telemetry = [{'event': 'before-command', 'time_ns': started + 1, 'volumes': volumes},
                             {'event': 'command-started', 'pid': 123, 'argv': expected['argv']},
                             {'event': 'after-command', 'time_ns': started + 999, 'volumes': volumes}]
                (directory / (label + '.space.jsonl')).write_text(''.join(json.dumps(s) + '\n' for s in telemetry))
                for suffix in ('.stdout', '.stderr', '.command.json', '.space.jsonl'):
                    artifacts[label + suffix] = sha(directory / (label + suffix))

            command('multilib', [compiler, '-print-multi-lib'], '.;\n32;@m32\n')
            abis = ('m64',) if stage == 'glibc-cross-m64' else ('m64', 'm32')
            for abi in abis:
                flag = '-' + abi; _, _, interpreter, libdir, owner = toolchain_sanity.ABIS[abi]
                command(abi + '-sysroot', [compiler, flag, '-print-sysroot'], '/srv/lfs\n')
                command(abi + '-linker', [compiler, flag, '-print-prog-name=ld'], '/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-ld\n')
                startfiles = {}
                for filename in ('Scrt1.o', 'crti.o', 'crtn.o'):
                    output = '/srv/lfs/' + libdir + '/' + filename
                    command(abi + '-' + filename, [compiler, flag, '-print-file-name=' + filename], output + '\n')
                    startfiles[filename] = payload.file(output, {owner}, libdir)
                libc = payload.file('/srv/lfs/' + libdir + '/libc.so.6', {owner}, libdir)
                loader = payload.file('/srv/lfs' + interpreter, {owner}, libdir)
                stdlib = None
                if language == 'c++':
                    library = '/srv/lfs/' + libdir + '/libstdc++.so'
                    command(abi + '-libstdcxx', [compiler, flag, '-print-file-name=libstdc++.so'], library + '\n')
                    stdlib = payload.file(library, {'libstdcxx-cross'}, libdir)
                selected = [*startfiles.values(), libc, *([stdlib] if stdlib else [])]
                stdout = 'SEARCH_DIR("=/' + libdir + '");\n' + ''.join('attempt to open ' + path + ' succeeded\n' for path in selected)
                stderr = '#include <...> search starts here:\n /srv/lfs/usr/include\nEnd of search list.\n'
                work = '/srv/lfs/build/' + directory.name + '-' + abi
                command(abi + '-compile', [compiler, flag, '-x', language, '-', '-O2', '-g0',
                    '-ffile-prefix-map=' + work + '=/usr/src/alp-abi-probe', '-v', '-Wl,--verbose', '-o', 'probe'],
                    stdout, stderr, cwd=work, input=toolchain_sanity.probe_source(language))
                command(abi + '-dynamic', ['/usr/bin/readelf', '-d', '--wide', work + '/probe'], 'Dynamic section at offset 0x100 contains 1 entry:\n')
                elf = directory / (abi + '.elf'); boundary_tests.AbiSanityTests().elf(elf, abi)
                artifacts[elf.name] = sha(elf)
                rows.append({'abi': abi, 'language': language, 'elf': toolchain_sanity.elf_identity(elf, abi),
                             'startfiles': startfiles, 'libc': libc, 'loader': loader, 'libstdcxx': stdlib,
                             'trace': toolchain_sanity.parse_trace(stdout, stderr)})
            (directory / 'commands.jsonl').write_text(''.join(json.dumps(c) + '\n' for c in commands))
            artifacts['commands.jsonl'] = sha(directory / 'commands.jsonl')
            write_json(directory / 'summary.json', {'result': 'PASS', 'stage': stage, **binding, 'rows': rows, 'artifact_sha256': artifacts})
            sanity.append({'summary': guest + '/summary.json', 'summary_sha256': sha(directory / 'summary.json')})
        summary['sanity'] = sanity; write_json(root / 'summary.json', summary)
        return args, epoch

    def verify(self, root, args, epoch):
        return evidence.verify(root, REPO, *args)

    def rebind_probe(self, root, directory):
        # Rebind synthetic fixture hashes; byte semantics remain authoritative.
        probe = json.loads((directory / 'summary.json').read_bytes())
        for filename in probe['artifact_sha256']:
            probe['artifact_sha256'][filename] = sha(directory / filename)
        write_json(directory / 'summary.json', probe)
        summary = json.loads((root / 'summary.json').read_bytes())
        for row in summary['sanity']:
            if row['summary'].endswith('/' + directory.name + '/summary.json'):
                row['summary_sha256'] = sha(directory / 'summary.json')
        write_json(root / 'summary.json', summary)

    def test_all_raw_probes_and_elf_bytes_verified_readonly(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); args, epoch = self.fixture(root)
            before = evidence.file_hashes(root); proof = self.verify(root, args, epoch)
            self.assertEqual(proof['result'], 'VERIFIED_GUEST_BYTES')
            self.assertEqual([p['abis'] for p in proof['abi']], [['m64'], ['m64', 'm32'], ['m64', 'm32']])
            self.assertEqual(evidence.file_hashes(root), before)

    def test_rebound_x32_interpreter_and_multilib_bytes_rejected(self):
        for change in ('x32', 'interpreter', 'multilib'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); args, epoch = self.fixture(root); probe = root / 'abi-glibc-cross-m32-2'
                if change == 'x32': boundary_tests.AbiSanityTests().elf(probe / 'm32.elf', 'm32', machine=62); cause = 'x32 forbidden'
                elif change == 'interpreter':
                    boundary_tests.AbiSanityTests().elf(probe / 'm32.elf', 'm32', interpreter='/usr/lib/ld-linux.so.2'); cause = 'interpreter differs'
                else: (probe / 'multilib.stdout').write_text('.;\n32;@m32\nx32;@mx32\n'); cause = 'multilib listing'
                self.rebind_probe(root, probe)
                with self.assertRaisesRegex(RuntimeError, cause): self.verify(root, args, epoch)

    def test_failed_wrong_boot_or_changed_compile_input_rejected(self):
        for change in ('exit', 'boot', 'input', 'argv', 'tmpdir'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); args, epoch = self.fixture(root); probe = root / 'abi-glibc-cross-m64-1'
                path = probe / 'm64-compile.command.json'; value = json.loads(path.read_bytes())
                if change == 'exit': value['exit'] = 1
                elif change == 'boot': value['guest_boot_id'] = '22222222-2222-4222-8222-222222222222'
                elif change == 'input': value['input'] = 'int main(){return 0;}'
                elif change == 'argv': value['argv'].append('-march=native')
                else:
                    index = next(i for i, arg in enumerate(value['argv']) if arg.startswith('TMPDIR='))
                    value['argv'][index] = 'TMPDIR=/srv/lfs/build/unrelated'
                write_json(path, value); self.rebind_probe(root, probe)
                with self.assertRaisesRegex(RuntimeError, 'command execution/argv/input/boot'):
                    self.verify(root, args, epoch)

    def test_space_lifecycle_low_space_and_sampling_gap_rejected(self):
        for change in ('missing-start', 'low-space', 'gap', 'clock'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); args, epoch = self.fixture(root); probe = root / 'abi-glibc-cross-m64-1'
                path = probe / 'm64-compile.space.jsonl'; values = [json.loads(s) for s in path.read_text().splitlines()]
                meta = probe / 'm64-compile.command.json'; record = json.loads(meta.read_bytes())
                if change == 'missing-start': values.pop(1); cause = 'lifecycle incomplete'
                elif change == 'low-space': values[-1]['volumes']['/srv/lfs']['available'] = 100; cause = 'below 15%'
                elif change == 'gap':
                    values[-1]['time_ns'] += 11_000_000_000
                    record['ended_at_ns'] += 11_000_000_000; record['ended_monotonic_ns'] += 11_000_000_000
                    cause = 'time/gap invalid'
                else: record['ended_at_ns'] += 3_000_000_000; cause = 'time drift'
                path.write_text(''.join(json.dumps(v) + '\n' for v in values)); write_json(meta, record)
                self.rebind_probe(root, probe)
                with self.assertRaisesRegex(RuntimeError, cause): self.verify(root, args, epoch)

    def test_actual_host_search_missing_cpp_input_and_runtime_path_rejected(self):
        for change in ('headers', 'linker', 'selected', 'cpp', 'rpath', 'sysroot'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); args, epoch = self.fixture(root); probe = root / 'abi-libstdcxx-cross-3'
                if change == 'headers':
                    path = probe / 'm64-compile.stderr'; path.write_text(path.read_text().replace(' /srv/lfs/usr/include', ' /usr/include\n /srv/lfs/usr/include')); cause = 'searched host headers'
                elif change == 'linker':
                    path = probe / 'm64-compile.stdout'; path.write_text(path.read_text().replace('=/usr/lib', '/usr/lib')); cause = 'searched host directories'
                elif change == 'selected':
                    path = probe / 'm64-compile.stdout'; path.write_text(path.read_text().replace('/srv/lfs/usr/lib/libc.so.6', '/usr/lib/libc.so.6')); cause = 'outside recorded'
                elif change == 'cpp':
                    path = probe / 'm64-compile.stdout'; path.write_text(''.join(line for line in path.read_text().splitlines(True) if 'libstdc++' not in line)); cause = 'omitted target'
                elif change == 'rpath': (probe / 'm64-dynamic.stdout').write_text('(RUNPATH) /host/lib\n'); cause = 'runtime search path'
                else: (probe / 'm64-sysroot.stdout').write_text('/\n'); cause = 'sysroot changed'
                value = json.loads((probe / 'summary.json').read_bytes())
                value['rows'][0]['trace'] = toolchain_sanity.parse_trace((probe / 'm64-compile.stdout').read_text(), (probe / 'm64-compile.stderr').read_text())
                write_json(probe / 'summary.json', value); self.rebind_probe(root, probe)
                with self.assertRaisesRegex(RuntimeError, cause): self.verify(root, args, epoch)

    def test_missing_abi_stage_and_command_order_rejected(self):
        for change in ('stage', 'order', 'extra'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); args, epoch = self.fixture(root); probe = root / 'abi-glibc-cross-m64-1'
                if change == 'stage':
                    summary = json.loads((root / 'summary.json').read_bytes()); summary['sanity'].pop(); write_json(root / 'summary.json', summary); cause = 'three probe stages'
                elif change == 'order':
                    path = probe / 'commands.jsonl'; path.write_text(''.join(reversed(path.read_text().splitlines(True)))); self.rebind_probe(root, probe); cause = 'command ordering'
                else: (probe / 'untracked.stdout').write_text('PASS'); cause = 'exact command/artifact coverage'
                with self.assertRaisesRegex(RuntimeError, cause): self.verify(root, args, epoch)

    def test_abi_verifier_rejects_drift_after_package_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); args, epoch = self.fixture(root)
            proof, payload = evidence.verify_packages(root, REPO, *args)
            (root / 'abi-glibc-cross-m64-1/m64-compile.stdout').write_text('PASS')
            with self.assertRaisesRegex(RuntimeError, 'changed after package'):
                evidence.verify_abi(root, proof, payload, epoch)

    def test_package_only_evidence_and_changed_epoch_cannot_be_full_guest_proof(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); args = ToolchainPackageEvidenceTests().fixture(root)
            with self.assertRaisesRegex(RuntimeError, 'three probe stages missing'):
                evidence.verify(root, REPO, *args)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); args, epoch = self.fixture(root)
            proof, payload = evidence.verify_packages(root, REPO, *args)
            with self.assertRaisesRegex(RuntimeError, 'changed after package'):
                evidence.verify_abi(root, proof, payload, epoch + 1)


if __name__ == '__main__':
    unittest.main()
