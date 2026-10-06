#!/usr/bin/env python3
"""Verify the required kernel configuration and release before packaging."""
import argparse
import re
from pathlib import Path


def parse(path):
    values = {}
    for line in Path(path).read_text().splitlines():
        if not line:
            continue
        disabled = re.fullmatch(r'# (CONFIG_[A-Z0-9_]+) is not set', line)
        if disabled:
            values[disabled.group(1)] = 'n'
            continue
        if line.startswith('#'):
            continue
        match = re.fullmatch(r'(CONFIG_[A-Z0-9_]+)=(.*)', line)
        if match:
            values[match.group(1)] = match.group(2)
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    parser.add_argument('--required', required=True)
    parser.add_argument('--release-file')
    parser.add_argument('--release', default='6.16.1-alpbahOS')
    args = parser.parse_args()
    actual = parse(args.config)
    required = parse(args.required)
    if not required:
        raise SystemExit('Required config is empty')
    mismatches = {key: (value, actual.get(key)) for key, value in required.items()
                  if actual.get(key) != value}
    if mismatches:
        for key, (expected, observed) in sorted(mismatches.items()):
            print(f'CONFIG_MISMATCH {key}: expected={expected} actual={observed}')
        raise SystemExit(1)
    if actual.get('CONFIG_MODULES') != 'y':
        raise SystemExit('CONFIG_MISMATCH CONFIG_MODULES: expected=y actual=' +
                         str(actual.get('CONFIG_MODULES')))
    if args.release_file:
        release = Path(args.release_file).read_text().strip()
        if release != args.release:
            raise SystemExit(f'KERNEL_RELEASE_MISMATCH expected={args.release} actual={release}')
    else:
        if actual.get('CONFIG_LOCALVERSION') != '"-alpbahOS"':
            raise SystemExit('KERNEL_LOCALVERSION_MISMATCH expected="-alpbahOS"')
        if actual.get('CONFIG_LOCALVERSION_AUTO', 'n') != 'n':
            raise SystemExit('KERNEL_LOCALVERSION_AUTO must be disabled for reproducibility')
        release = args.release + ' (pre-build config)'
    print(f'PASS config_options={len(required)} release={release}')


if __name__ == '__main__':
    main()
