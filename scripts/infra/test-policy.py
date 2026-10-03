#!/usr/bin/env python3
"""Validate completed glibc/Binutils/GCC test summaries; never hide new FAILs."""
import argparse
import collections
import json
import re
from pathlib import Path


def evaluate(package, summaries, make_exit, policy, build_root=None):
    failures, fatal = collections.Counter(), collections.Counter()
    passes, evidence, completed_files, glibc_results = 0, [], {}, 0
    seen_glibc_results = set()
    for file in summaries:
        if file.is_symlink():
            raise ValueError('Symlink test summary refused')
        text = file.read_text(errors='replace')
        evidence.append(str(file))
        result_rows = re.findall(r'^\s*(PASS|FAIL|ERROR|UNRESOLVED|XPASS|XFAIL|UNSUPPORTED):\s*(.*)',
                                 text, re.M)
        if package == 'glibc' and file.name == 'tests.sum':
            glibc_results = len(result_rows)
        for status, identifier in result_rows:
            key = (status, identifier)
            if package == 'glibc' and key in seen_glibc_results:
                continue
            if package == 'glibc':
                seen_glibc_results.add(key)
            if status == 'PASS':
                passes += 1
            elif status == 'FAIL':
                failures[identifier] += 1
            elif status in ('ERROR', 'UNRESOLVED', 'XPASS'):
                fatal[status + ': ' + identifier] += 1
        completed_files[str(file)] = bool(re.search(r'^\s*===.*Summary\s*===\s*$', text, re.M)) or (
            package == 'glibc' and file.name == 'tests.sum'
            and make_exit in (0, 2)
            and bool(re.search(r'^\s*===\s*glibc tests\s*===\s*$', text, re.M))
            and glibc_results >= policy.get('minimum_result_count', 0))
    unexpected = dict(failures)
    for identifier, maximum in policy['allowed_failures'].items():
        matched = [(name, count) for name, count in failures.items()
                   if (name == identifier or name.startswith(identifier + ' '))
                   and policy.get('allowed_failure_detail', '') in name]
        output_fragments = policy.get('allowed_failure_output_contains', {}).get(identifier, [])
        if output_fragments:
            relative = Path(identifier + '.out')
            output = (build_root / relative) if build_root is not None else None
            valid_output = (output is not None and not relative.is_absolute()
                            and '..' not in relative.parts and output.is_file()
                            and not output.is_symlink()
                            and all(fragment in output.read_text(errors='replace')
                                    for fragment in output_fragments))
            if not valid_output:
                matched = []
        if sum(count for _, count in matched) <= maximum:
            for name, _ in matched:
                unexpected.pop(name, None)
    missing = sorted(set(policy['required_summary_names']) - {p.name for p in summaries})
    if package == 'glibc':
        completed = (any(Path(name).name == 'tests.sum' and value
                          for name, value in completed_files.items()) and not missing)
    else:
        completed = bool(completed_files) and all(completed_files.values()) and not missing
    minimum = policy['minimum_pass_count']
    exit_accepted = make_exit == 0 or make_exit == 2 and bool(failures) and not unexpected and not fatal
    accepted = completed and passes >= minimum and not unexpected and not fatal and exit_accepted
    return {'package': package, 'accepted': accepted, 'make_exit': make_exit,
            'pass_count': passes, 'minimum_pass_count': minimum, 'completed': completed,
            'glibc_result_count': glibc_results if package == 'glibc' else None,
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
        result = evaluate(args.package, summaries, args.make_exit, policy, args.build)
    except ValueError as error:
        p.error(str(error))
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps(result, sort_keys=True))
    return 0 if result['accepted'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
