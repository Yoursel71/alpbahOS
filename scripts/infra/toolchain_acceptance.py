"""Read-only acceptance for a collected Chapter 4/5 toolchain stage."""
import json
from pathlib import Path
import checkpoint_store
import host_monitor
import host_stage_audit as audit
import stage_runs
import toolchain_evidence


def verify(value, run_sha256, after_audit_id, sources, recipes, vm, expected_argv,
           stopped, space_guard):
    """Recompute guest bytes, host audit/telemetry and stopped disk evidence."""
    stage_runs.identity(after_audit_id)
    stopped(); space_guard()
    state = stage_runs.RUNS / stage_runs.identity(value['run_id'])
    root = stage_runs.ARTIFACTS / value['run_id']
    run_raw, run = stage_runs.read(state / 'run.json')
    started_raw, started = stage_runs.read(state / 'started.json')
    outcome_raw, outcome = stage_runs.read(state / 'outcome.json')
    if (run != value or audit.digest(run_raw) != run_sha256 or value['stage'] != 'toolchain'
            or value['mode'] != 'multilib-m32' or value['boot_id'] != audit.BOOT.read_text().strip()
            or outcome.get('schema') != 'alpbahOS.stage-outcome/v1'
            or outcome.get('result') != 'PENDING_PRIVILEGED_POST' or outcome.get('errors') != []
            or outcome.get('run_sha256') != run_sha256
            or outcome.get('started_sha256') != audit.digest(started_raw)
            or started.get('run_sha256') != run_sha256
            or outcome.get('started_at_ns') != started.get('started_at_ns')
            or type(outcome.get('ended_at_ns')) is not int
            or not started['started_at_ns'] <= outcome['ended_at_ns'] <= time_now_ns()
            or outcome.get('artifact_sha256') != stage_runs.file_hashes(root)):
        raise RuntimeError('Toolchain run/outcome/evidence boundaries invalid')

    captured = lambda name: json.loads(audit.read_file(root / name, audit.USER_UID))
    hashes = outcome['artifact_sha256']
    required = {'host-baseline.json', 'authorization.json', 'parent.json', 'handoff.json', 'handoff-response.json',
                'repositories-before.json', 'repositories-after.json', 'toolchain-command.json',
                'toolchain.log', 'toolchain.host.jsonl', 'guest-transfer.json',
                'guest-artifact-proof.json', 'guest-toolchain/summary.json'}
    if not required <= set(hashes):
        raise RuntimeError('Toolchain evidence coverage incomplete')

    _, post = stage_runs.read(state / ('after-' + after_audit_id + '.json'))
    if post.get('outcome_sha256') != audit.digest(outcome_raw):
        raise RuntimeError('Toolchain post audit belongs to a different outcome')
    after_path = Path(post['request'])
    if after_path != audit.REQUESTS / (value['run_id'] + '-after-' + after_audit_id + '.json'):
        raise RuntimeError('Toolchain after audit request path invalid')
    after_raw = audit.read_file(after_path, audit.USER_UID, 65536)
    before_raw = audit.read_file(Path(value['before_request']), audit.USER_UID, 65536)
    if (audit.digest(after_raw) != post.get('request_sha256')
            or audit.digest(before_raw) != value.get('before_request_sha256')):
        raise RuntimeError('Toolchain root audit request bytes changed')
    before_req, after_req = audit.checked_request(before_raw), audit.checked_request(after_raw)
    if (any(before_req.get(k) != value.get(k) for k in ('stage','run_id','boot_id','inputs_sha256','sources_sha256'))
            or any(after_req.get(k) != value.get(k) for k in ('stage','run_id','boot_id','inputs_sha256','sources_sha256'))
            or after_req.get('outcome_sha256') != audit.digest(outcome_raw)):
        raise RuntimeError('Toolchain before/after root audit identity mismatch')
    host = audit.verify_pair(before_raw, after_raw, value['producer_sha256'],
                              started['started_at_ns'], outcome['ended_at_ns'])
    if host['before'] != started.get('before_host_evidence'):
        raise RuntimeError('Toolchain root-before audit changed since execution')

    baseline = captured('host-baseline.json')
    host_monitor.validate_sample(baseline)
    if baseline.get('boot_id') != value['boot_id'] or baseline['completed_at_ns'] > started['started_at_ns']:
        raise RuntimeError('Toolchain host baseline does not precede execution')
    command = captured('toolchain-command.json')
    if command.get('argv') != expected_argv or command.get('exit') != 0:
        raise RuntimeError('Toolchain command differs from canonical successful command')
    auth = captured('authorization.json')
    if (auth.get('oc_confirmed') is not True
            or any(auth.get(k) != value.get(k) for k in ('stage','mode','run_id','inputs_sha256','sources_sha256','boot_id'))
            or type(auth.get('authorized_at_ns')) is not int
            or not started['started_at_ns'] <= auth['authorized_at_ns'] <= command['started_at_ns']):
        raise RuntimeError('Toolchain OC/start authorization binding invalid')
    binding = {k: value[k] for k in ('run_id','stage','inputs_sha256','sources_sha256','boot_id')}
    telemetry = host_monitor.verify_recording(audit.read_file(root / 'toolchain.host.jsonl', audit.USER_UID),
        command, binding, started['started_at_ns'], outcome['ended_at_ns'])

    before_repo, after_repo = (captured('repositories-' + phase + '.json') for phase in ('before','after'))
    repo_paths = {str(p) for p in stage_runs.REPOSITORIES}
    for phase, record in (('before', before_repo), ('after', after_repo)):
        if (record.get('run_id') != value['run_id'] or record.get('phase') != phase
                or not started['started_at_ns'] <= record.get('time_ns', 0) <= outcome['ended_at_ns']
                or set(record.get('repositories', {})) != repo_paths):
            raise RuntimeError('Toolchain repository observations have invalid scope/timing')
        for observed in record['repositories'].values():
            for field in ('head','branch','status'):
                raw = observed.get(field)
                if not isinstance(raw, str) or audit.digest(raw.encode()) != observed.get(field + '_sha256'):
                    raise RuntimeError('Toolchain repository observation hash mismatch')
    if before_repo['repositories'] != after_repo['repositories']:
        raise RuntimeError('Repository HEAD/branch/status changed during toolchain build')

    authorization = captured('authorization.json')
    parent_raw = audit.read_file(root / 'parent.json', audit.USER_UID)
    handoff_raw = audit.read_file(root / 'handoff.json', audit.USER_UID)
    guest_proof = toolchain_evidence.verify(root / 'guest-toolchain',
        Path(__file__).resolve().parents[2],
        {'inputs_sha256': value['inputs_sha256'], 'sources_sha256': value['sources_sha256']},
        handoff_raw, authorization, authorization.get('guest_boot_id'))
    expected_guest = captured('guest-artifact-proof.json')
    if (guest_proof != expected_guest or guest_proof != outcome.get('guest_artifact_evidence')
            or guest_proof.get('result') != 'VERIFIED_GUEST_BYTES'):
        raise RuntimeError('Toolchain guest evidence differs from terminal outcome')
    parent = json.loads(parent_raw)
    if (audit.digest(parent_raw) != value.get('parent', {}).get('sha256')
            or parent.get('result') != 'VERIFIED_PARENT' or parent.get('run_id') != value['run_id']
            or parent.get('inputs_sha256') != value['inputs_sha256']
            or parent.get('sources_sha256') != value['sources_sha256']
            or authorization.get('handoff_sha256') != audit.digest(handoff_raw)):
        raise RuntimeError('Toolchain accepted-parent capsule invalid')

    stopped(); space_guard()
    disks = checkpoint_store.inspect_disks(vm, stopped, space_guard)
    if stage_runs.file_hashes(root) != hashes:
        raise RuntimeError('Toolchain evidence bytes changed during acceptance')
    stopped(); space_guard()
    return {'schema':'alpbahOS.toolchain-acceptance/v1','result':'PASS','stage':'toolchain',
            'run_id':value['run_id'],'after_audit_id':after_audit_id,'mode':value['mode'],
            'inputs_sha256':value['inputs_sha256'],'sources_sha256':value['sources_sha256'],
            'run_sha256':run_sha256,'outcome_sha256':audit.digest(outcome_raw),
            'artifact_sha256':hashes,'parent_sha256':value['parent']['sha256'],
            'parent_capsule_sha256':audit.digest(parent_raw),'host':host,'telemetry':telemetry,
            'guest':guest_proof,'closed_disk_chains':disks,
            'scope':'accepted multilib toolchain gate; base/native/kernel/desktop/ISO remain separate'}


def time_now_ns():
    import time
    return time.time_ns()
