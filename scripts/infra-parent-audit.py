"""Revalidate completed-stage immutable root audit captures across time/boot.

No requests, root commands or launch authorization are issued. Request age is
checked at its recorded root capture, not at later parent inspection. A new
stage still needs its own current-boot before audit through host_stage_audit.
"""
import json
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / 'infra'))
import host_stage_audit as audit

AUDIT_SHA = '6829df1de7eb4b4039d4c089f0bacc2f4c3bf2e68e4ba9c628c719bc5c090b86'


def request(raw):
    value = json.loads(raw)
    keys = {'schema', 'stage', 'phase', 'run_id', 'audit_id', 'boot_id',
            'inputs_sha256', 'sources_sha256', 'requested_at_ns', 'outcome_sha256'}
    if (not isinstance(value, dict) or set(value) != keys or value['schema'] != audit.SCHEMA
            or value['stage'] not in audit.STAGES or value['phase'] not in ('before', 'after')
            or any(not isinstance(value[k], str) or not re.fullmatch('[0-9a-f]{32}', value[k])
                   for k in ('run_id', 'audit_id'))
            or not isinstance(value['boot_id'], str)
            or not re.fullmatch(r'[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}', value['boot_id'])
            or any(not isinstance(value[k], str) or not re.fullmatch('[0-9a-f]{64}', value[k])
                   for k in ('inputs_sha256', 'sources_sha256'))
            or type(value['requested_at_ns']) is not int or value['requested_at_ns'] <= 0
            or (value['phase'] == 'before' and value['outcome_sha256'] is not None)
            or (value['phase'] == 'after' and (not isinstance(value['outcome_sha256'], str)
                or not re.fullmatch('[0-9a-f]{64}', value['outcome_sha256'])))):
        raise RuntimeError('Archived audit request identity/schema invalid')
    return value


def verify(raw, producer_sha, boundary_ns):
    if producer_sha != AUDIT_SHA or audit.digest(Path(audit.__file__).read_bytes()) != AUDIT_SHA:
        raise RuntimeError('Archived audit source rules changed')
    value = request(raw)
    root = audit.STORE / value['run_id'] / value['phase'] / value['audit_id']
    metadata_raw = audit.read_file(root / 'audit.json', 0)
    metadata = json.loads(metadata_raw)
    if (metadata.get('schema') != 'alpbahOS.root-stage-audit/v1'
            or type(metadata.get('uid')) is not int or metadata['uid'] != 0
            or metadata.get('result') != 'CAPTURED' or metadata.get('request') != value
            or metadata.get('request_sha256') != audit.digest(raw)
            or metadata.get('producer_sha256') != producer_sha
            or metadata.get('boot_id') != value['boot_id']
            or metadata.get('boot_id_after') != value['boot_id']):
        raise RuntimeError('Archived root audit producer/request/boot identity mismatch')
    start, end = metadata.get('started_at_ns'), metadata.get('ended_at_ns')
    if (type(start) is not int or type(end) is not int or type(boundary_ns) is not int
            or not value['requested_at_ns'] <= start <= end <= time.time_ns()
            or start - value['requested_at_ns'] > 24 * 3600 * 10**9
            or (value['phase'] == 'before' and end > boundary_ns)
            or (value['phase'] == 'after' and start < boundary_ns)):
        raise RuntimeError('Archived audit was stale at capture or misses stage boundary')
    commands = metadata.get('commands', {})
    if set(commands) != set(audit.COMMANDS):
        raise RuntimeError('Archived root audit command coverage incomplete')
    outputs, hashes = {}, {'audit.json': audit.digest(metadata_raw)}
    previous_end = start
    for role, argv in audit.COMMANDS.items():
        record = commands[role]
        command_start, command_end = record.get('started_at_ns'), record.get('ended_at_ns')
        if (record.get('argv') != argv or type(record.get('exit')) is not int
                or type(command_start) is not int or type(command_end) is not int
                or not previous_end <= command_start <= command_end <= end):
            raise RuntimeError('Archived root audit command/timing mismatch')
        previous_end = command_end
        outputs[role] = {'exit': record['exit']}
        for stream in ('stdout', 'stderr'):
            name = role + '.' + stream
            if record.get(stream) != name:
                raise RuntimeError('Archived root audit output filename mismatch')
            body = audit.read_file(root / name, 0)
            if audit.digest(body) != record.get(stream + '_sha256'):
                raise RuntimeError('Archived root audit raw bytes changed')
            hashes[name] = audit.digest(body)
            outputs[role][stream] = body.decode(errors='replace')
    # Preserve the original output policy and proof shape byte-for-byte.
    return {'scope': 'privileged host inspection only; guest/stage acceptance separate',
            'request_sha256': audit.digest(raw), 'producer_sha256': producer_sha,
            'artifact_sha256': hashes, 'started_at_ns': start, 'ended_at_ns': end,
            **audit.inspect_outputs(outputs)}


def verify_pair(before_raw, after_raw, producer_sha, stage_start_ns, stage_end_ns):
    before, after = request(before_raw), request(after_raw)
    if (before['phase'] != 'before' or after['phase'] != 'after'
            or any(before[k] != after[k] for k in ('stage', 'run_id', 'boot_id', 'inputs_sha256', 'sources_sha256'))
            or type(stage_start_ns) is not int or type(stage_end_ns) is not int
            or stage_start_ns > stage_end_ns):
        raise RuntimeError('Archived audit pair stage/run/input/boundary mismatch')
    return {'scope': 'privileged host endpoints only; runtime/guest/stage acceptance separate',
            'before': verify(before_raw, producer_sha, stage_start_ns),
            'after': verify(after_raw, producer_sha, stage_end_ns)}
