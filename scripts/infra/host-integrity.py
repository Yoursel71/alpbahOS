#!/usr/bin/env python3
"""Read-only host RPM/Git integrity evidence before and after VM stages.

Unprivileged RPM results cannot assert privileged host cleanliness. Baseline
comparison rejects new genuine missing paths and new /usr integrity changes.
"""
import argparse
import hashlib
import json
import os
import subprocess
import time
from pathlib import Path

DATA = Path('/mnt/alpbahOS-data/alpbahos-infra-rebuild')
REPO = Path(__file__).resolve().parents[2]


def query(argv):
    p = subprocess.run(argv, capture_output=True, text=True, env={**os.environ, 'LC_ALL': 'C'})
    return {'command': argv, 'exit': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr}


def significant(lines):
    result = set()
    for line in lines.splitlines():
        if 'Permission denied' in line:
            continue
        if line.startswith('missing'):
            result.add(line)
        elif ' /usr/' in line and '?' not in line[:9]:
            result.add(line)
    return result


def classify_privileged(rpm_stdout, rpm_exit, kernel_exit, rpm_stderr='', kernel_stderr=''):
    issues = sorted(significant(rpm_stdout))
    denied = 'Permission denied' in rpm_stdout or 'Permission denied' in rpm_stderr
    return {'accepted': rpm_exit in (0, 1) and kernel_exit == 0 and not issues and not denied
                       and not rpm_stderr.strip() and not kernel_stderr.strip(),
            'system_issues': issues, 'permission_denied': denied,
            'pristine_rpm': rpm_exit == 0 and not rpm_stdout.strip() and not rpm_stderr.strip(),
            'config_or_other_differences': sorted(set(rpm_stdout.splitlines()) - set(issues))}


def validate_privileged_audit():
    """Read user-run root evidence; an empty user-owned file is not an audit."""
    metadata = DATA / 'logs/root-host-audit-after.json'
    if not metadata.is_file() or metadata.is_symlink() or metadata.stat().st_uid != 0:
        raise RuntimeError('Verified root audit metadata missing; user must run host audit')
    value = json.loads(metadata.read_text())
    if value.get('uid') != 0 or value.get('boot_id') != Path('/proc/sys/kernel/random/boot_id').read_text().strip():
        raise RuntimeError('Root audit identity/boot mismatch; refresh after OC reboot')
    elapsed = time.time_ns() - value.get('captured_at_ns', 0)
    if not -60_000_000_000 <= elapsed <= 24 * 3600 * 1_000_000_000:
        raise RuntimeError('Root audit stale or from a future clock')
    outputs = {}
    commands = {'rpm': ['rpm', '-Va'], 'kernel': ['journalctl', '-k', '-b', '--no-pager']}
    for role, argv in commands.items():
        record = value.get('commands', {}).get(role, {})
        if record.get('argv') != argv:
            raise RuntimeError('Unexpected root audit command')
        for field in ('stdout', 'stderr'):
            path = Path(record.get(field, ''))
            if (path.parent != DATA / 'logs' or not path.name.startswith('root-cleanup-audit-after-')
                    or not path.is_file() or path.is_symlink() or path.stat().st_uid != 0):
                raise RuntimeError('Unsafe/unprivileged audit log path')
            raw = path.read_bytes()
            expected = record.get('sha256' if field == 'stdout' else 'stderr_sha256')
            if hashlib.sha256(raw).hexdigest() != expected:
                raise RuntimeError('Root audit bytes changed; STOP')
            outputs[role + '_' + field] = raw.decode('utf-8', errors='replace')
    result = classify_privileged(outputs['rpm_stdout'], value['commands']['rpm']['exit'],
                                 value['commands']['kernel']['exit'], outputs['rpm_stderr'], outputs['kernel_stderr'])
    result['metadata_sha256'] = hashlib.sha256(metadata.read_bytes()).hexdigest()
    if not result['accepted']:
        raise RuntimeError('Privileged host audit failed: ' + repr(result))
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('baseline', 'compare', 'privileged'))
    args = p.parse_args()
    if os.geteuid() == 0:
        p.error('Host root forbidden; user supplies privileged audit separately')
    if DATA.is_symlink() or DATA.stat().st_uid != os.getuid():
        p.error('Unsafe state root')
    if args.action == 'privileged':
        result = validate_privileged_audit()
        print(json.dumps(result, sort_keys=True))
        return
    target = DATA / 'state/host-baseline.json'
    record = {'time_ns': time.time_ns(), 'rpm': query(['rpm', '-Va']),
              'kwin': query(['rpm', '-V', 'kwin']),
              'git': {str(root): {'head': query(['git', '-C', str(root), 'rev-parse', 'HEAD']),
                                  'branch': query(['git', '-C', str(root), 'branch', '--show-current']),
                                  'status': query(['git', '-C', str(root), 'status', '--short', '--branch'])}
                      for root in (Path('/home/yrslf/alpbahOS'), REPO)},
              'privileged_cleanliness': 'UNVERIFIED'}
    log = DATA / f'logs/host-{args.action}-{record["time_ns"]}.json'
    log.write_text(json.dumps(record, indent=2, sort_keys=True) + '\n')
    if args.action == 'baseline':
        if target.exists():
            p.error('Existing baseline preserved; refusing overwrite')
        target.write_bytes(log.read_bytes())
    else:
        old = json.loads(target.read_text())
        before = significant(old['rpm']['stdout'])
        after = significant(record['rpm']['stdout'])
        new = sorted(after - before)
        if record['rpm']['exit'] not in (0, 1) or record['kwin']['exit'] != 0 or new:
            raise SystemExit('STOP: host integrity changed; log=' + str(log) + ' new=' + repr(new))
        for root in record['git']:
            if root == str(REPO):
                continue  # this worktree's intentional implementation changes are logged
            for field in ('head', 'branch'):
                if old['git'][root][field]['stdout'] != record['git'][root][field]['stdout']:
                    raise SystemExit('STOP: original repo HEAD/branch changed: ' + root)
        print('No new readable missing/system RPM differences; privileged clean audit still UNVERIFIED.')
    print('log=' + str(log) + ' sha256=' + hashlib.sha256(log.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
