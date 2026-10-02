"""Read-only stability acceptance from root, raw host, guest and disk bytes.

Caller holds the controller lock and validates current Phase1/input pins.
No VM, sudo, receipt or checkpoint is created by this verifier.
"""
import json
from pathlib import Path
import checkpoint_store
import host_monitor
import host_stage_audit as audit
import stage_runs
from stability_evidence import verify_stability_artifacts


def verify(value, run_sha256, after_audit_id, sources, recipes, vm, expected_argv, stopped, space_guard, *, checkpointed=False):
    stage_runs.identity(after_audit_id)
    stopped(); space_guard()
    state = stage_runs.RUNS / stage_runs.identity(value['run_id'])
    root = stage_runs.ARTIFACTS / value['run_id']
    run_raw, run = stage_runs.read(state / 'run.json')
    start_raw, start = stage_runs.read(state / 'started.json')
    end_raw, end = stage_runs.read(state / 'outcome.json')
    if (run != value or audit.digest(run_raw) != run_sha256 or value['stage'] != 'stability'
            or value['mode'] != sources['abi_selection']['mode'] or value['mode'] != 'multilib-m32'
            or value['boot_id'] != audit.BOOT.read_text().strip()
            or start.get('run_sha256') != run_sha256 or end.get('run_sha256') != run_sha256
            or end.get('schema') != 'alpbahOS.stage-outcome/v1' or end.get('result') != 'PENDING_PRIVILEGED_POST'
            or end.get('errors') != [] or end.get('started_sha256') != audit.digest(start_raw)
            or type(start.get('started_at_ns')) is not int or type(end.get('ended_at_ns')) is not int
            or end.get('started_at_ns') != start['started_at_ns'] or start['started_at_ns'] > end['ended_at_ns']):
        raise RuntimeError('Stability run/outcome/phase/input boundaries invalid')
    artifacts = stage_runs.file_hashes(root)
    required = {'host-baseline.json', 'authorization.json', 'repositories-before.json', 'repositories-after.json',
                'command.json', 'stability.log', 'stability.host.jsonl', 'disks-closed.json', 'guest/summary.json'}
    if not required <= set(artifacts) or artifacts != end.get('artifact_sha256'):
        raise RuntimeError('Stability collected bytes changed or complete coverage missing')
    _, post = stage_runs.read(state / ('after-' + after_audit_id + '.json'))
    if post.get('outcome_sha256') != audit.digest(end_raw):
        raise RuntimeError('Post audit request belongs to another outcome')
    request_path = Path(post['request'])
    if request_path != audit.REQUESTS / (value['run_id'] + '-after-' + after_audit_id + '.json'):
        raise RuntimeError('Post audit request path/identity invalid')
    after_raw = audit.read_file(request_path, audit.USER_UID, 65536)
    before_raw = audit.read_file(Path(value['before_request']), audit.USER_UID, 65536)
    if audit.digest(after_raw) != post.get('request_sha256') or audit.digest(before_raw) != value['before_request_sha256']:
        raise RuntimeError('Root audit request raw bytes changed')
    before = audit.checked_request(before_raw)
    after = audit.checked_request(after_raw)
    if any(before[k] != value[k] for k in ('stage', 'run_id', 'boot_id', 'inputs_sha256', 'sources_sha256')):
        raise RuntimeError('Root audit pair differs from current stage inputs')
    if after['audit_id'] != after_audit_id or after['outcome_sha256'] != audit.digest(end_raw):
        raise RuntimeError('Root post audit identity changed')
    host = audit.verify_pair(before_raw, after_raw, value['producer_sha256'], start['started_at_ns'], end['ended_at_ns'])
    if host['before'] != start.get('before_host_evidence'):
        raise RuntimeError('Root before certificate changed since execution')

    def captured(name):
        return json.loads(audit.read_file(root / name, audit.USER_UID))

    baseline = captured('host-baseline.json')
    host_monitor.validate_sample(baseline)
    if baseline['boot_id'] != value['boot_id'] or baseline['completed_at_ns'] > start['started_at_ns']:
        raise RuntimeError('Host baseline does not precede current stage')
    command = captured('command.json')
    if command.get('argv') != expected_argv:
        raise RuntimeError('Host command differs from canonical guest stability command')
    authorization = captured('authorization.json')
    if (authorization.get('oc_confirmed') is not True
            or any(authorization.get(k) != value[k] for k in ('stage', 'mode', 'run_id', 'inputs_sha256', 'sources_sha256', 'boot_id'))
            or type(authorization.get('authorized_at_ns')) is not int
            or not start['started_at_ns'] <= authorization['authorized_at_ns'] <= command['started_at_ns']):
        raise RuntimeError('Stability OC/start authorization record missing or different')
    binding = {key: value[key] for key in ('run_id', 'stage', 'inputs_sha256', 'sources_sha256', 'boot_id')}
    raw_telemetry = audit.read_file(root / 'stability.host.jsonl', audit.USER_UID)
    telemetry = host_monitor.verify_recording(raw_telemetry, command, binding, start['started_at_ns'], end['ended_at_ns'])
    summary = captured('guest/summary.json')
    if summary.get('run_id') != value['run_id']:
        raise RuntimeError('Guest artifacts belong to another stability run')
    guest = verify_stability_artifacts(root / 'guest', sources, value['inputs_sha256'], value['sources_sha256'], recipes)
    if guest != end.get('guest_artifact_evidence'):
        raise RuntimeError('Guest acceptance bytes differ from terminal outcome')
    seconds = (command['ended_monotonic_ns'] - command['started_monotonic_ns']) / 10**9
    if not 1200 <= seconds <= 1830 or abs(seconds - summary['seconds']) > 30:
        raise RuntimeError('Host/guest 20–30 minute execution timing differs')
    repository_records = [captured('repositories-' + phase + '.json') for phase in ('before', 'after')]
    for phase, record in zip(('before', 'after'), repository_records):
        if (record.get('run_id') != value['run_id'] or record.get('phase') != phase
                or type(record.get('time_ns')) is not int
                or not start['started_at_ns'] <= record['time_ns'] <= end['ended_at_ns']
                or set(record.get('repositories', {})) != {str(p) for p in stage_runs.REPOSITORIES}):
            raise RuntimeError('Repository observation scope/timing invalid')
        for observed in record['repositories'].values():
            for field in ('head', 'branch', 'status'):
                if not isinstance(observed.get(field), str) or audit.digest(observed[field].encode()) != observed.get(field + '_sha256'):
                    raise RuntimeError('Repository observation raw status hash invalid')
    if repository_records[0]['repositories'] != repository_records[1]['repositories']:
        raise RuntimeError('Repository HEAD/branch/status changed during stability; review required')
    closed = captured('disks-closed.json')
    if (closed.get('run_id') != value['run_id'] or type(closed.get('time_ns')) is not int
            or not command['ended_at_ns'] <= closed['time_ns'] <= end['ended_at_ns']):
        raise RuntimeError('Stopped disk evidence outside current stage')
    snapshot = checkpoint_store.inspect_accepted_checkpoint(vm, stopped, space_guard) if checkpointed else None
    current_disks = snapshot['closed_disk_chains'] if checkpointed else checkpoint_store.inspect_disks(vm, stopped, space_guard)
    if current_disks != closed.get('chains'):
        raise RuntimeError('Current qcow2/backing bytes differ from closed stage; STOP')
    stopped(); space_guard()
    if stage_runs.file_hashes(root) != artifacts:
        raise RuntimeError('Stage evidence changed during acceptance; STOP')
    proof = {'schema': 'alpbahOS.stability-acceptance/v1', 'result': 'PASS',
            'run_id': value['run_id'], 'after_audit_id': after_audit_id, 'mode': value['mode'],
            'inputs_sha256': value['inputs_sha256'], 'sources_sha256': value['sources_sha256'],
            'run_sha256': run_sha256, 'outcome_sha256': audit.digest(end_raw),
            'artifact_sha256': artifacts, 'host': host, 'telemetry': telemetry, 'guest': guest,
            'closed_disk_chains': current_disks,
            'scope': 'accepted stability gate only; production toolchain/base/desktop/ISO remain separate'}
    if snapshot is not None and snapshot['acceptance'] != proof:
        raise RuntimeError('Saved checkpoint acceptance differs from recomputed full proof; STOP')
    return proof
