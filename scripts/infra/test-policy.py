#!/usr/bin/env python3
"""Validate completed glibc/Binutils/GCC test summaries; never hide new FAILs."""
import argparse
import collections
import json
import re
from pathlib import Path


def evaluate(package, summaries, make_exit, policy):
    failures, fatal = collections.Counter(), collections.Counter()
    passes, evidence, completed_files = 0, [], {}
    for file in summaries:
        if file.is_symlink():
            raise ValueError('Symlink test summary refused')
        text = file.read_text(errors='replace')
        evidence.append(str(file))
        passes += len(re.findall(r'^\s*PASS:', text, re.M))
        completed_files[str(file)] = bool(re.search(r'^\s*===.*Summary\s*===\s*$', text, re.M)) or (
            package == 'glibc' and file.name == 'tests.sum' and make_exit == 0)
        for line in text.splitlines():
            match = re.match(r'^\s*(FAIL|ERROR|UNRESOLVED|XPASS):\s*(.*)', line)
            if match:
                status, identifier = match.groups()
                if status == 'FAIL':
                    failures[identifier] += 1
                else:
                    fatal[status + ': ' + identifier] += 1
    unexpected = dict(failures)
    for identifier, maximum in policy['allowed_failures'].items():
        matched = [(name, count) for name, count in failures.items()
                   if (name == identifier or name.startswith(identifier + ' '))
                   and policy.get('allowed_failure_detail', '') in name]
        if sum(count for _, count in matched) <= maximum:
            for name, _ in matched:
                unexpected.pop(name, None)
    missing = sorted(set(policy['required_summary_names']) - {p.name for p in summaries})
    completed = bool(completed_files) and all(completed_files.values()) and not missing
    minimum = policy['minimum_pass_count']
    exit_accepted = make_exit == 0 or make_exit == 2 and bool(failures) and not unexpected and not fatal
    accepted = completed and passes >= minimum and not unexpected and not fatal and exit_accepted
    return {'package': package, 'accepted': accepted, 'make_exit': make_exit,
            'pass_count': passes, 'minimum_pass_count': minimum, 'completed': completed,
            'completed_files': completed_files, 'missing_summary_names': missing,
            'failures': dict(failures), 'unexpected_failures': unexpected,
            'fatal_results': dict(fatal), 'summaries': evidence}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('package', choices=('glibc', 'binutils', 'gcc'))
    p.add_argument('--build', required=True, type=Path)
    p.add_argument('--make-exit', required=True, type=int)
    p.add_argument('--output', required=True, type=Path)
    args = p.parse_args()
    policy = json.loads((Path(__file__).resolve().parents[2] / 'manifests/infra-test-policy.json').read_text())[args.package]
    summaries = sorted(args.build.rglob('*.sum'))
    if not summaries:
        p.error('No test summaries: timeout/interruption is not a PASS')
    try:
        result = evaluate(args.package, summaries, args.make_exit, policy)
    except ValueError as error:
        p.error(str(error))
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps(result, sort_keys=True))
    return 0 if result['accepted'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
