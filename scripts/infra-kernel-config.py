#!/usr/bin/env python3
"""Pinned kernel configuration preparation; never builds or installs a kernel.

The future guest kernel controller must separately bind this helper's bytes,
accepted Base parent, actual source, compiler, payload, ownership and boot proof.
Configuration verification alone is not kernel or stage acceptance.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
REQUIRED = REPO / 'configs/kernel/infra-required.config'
REQUIRED_SHA256 = '0af395c208845c45149c6b37a68f4dc71d33371797a087ee9367b57991a2d42c'
VERSION = '6.16.1'
SOURCE_SHA256 = 'ea43491bc7ace1e414b3b2d957f8cf96e7049155123f0acce798accf8da1acba'

# LFS 12.4-systemd Chapter 10, plus QEMU serial console and selected ABI.
ADDITIONAL = {
    'CONFIG_X86_64': 'y', 'CONFIG_MODULES': 'y', 'CONFIG_X86_X32_ABI': 'n',
    'CONFIG_SERIAL_8250': 'y', 'CONFIG_SERIAL_8250_CONSOLE': 'y',
    'CONFIG_WERROR': 'n', 'CONFIG_PSI': 'y', 'CONFIG_PSI_DEFAULT_DISABLED': 'n',
    'CONFIG_IKHEADERS': 'n', 'CONFIG_CGROUPS': 'y', 'CONFIG_MEMCG': 'y',
    'CONFIG_CGROUP_SCHED': 'y', 'CONFIG_RT_GROUP_SCHED': 'n', 'CONFIG_EXPERT': 'n',
    'CONFIG_RELOCATABLE': 'y', 'CONFIG_RANDOMIZE_BASE': 'y',
    'CONFIG_STACKPROTECTOR': 'y', 'CONFIG_STACKPROTECTOR_STRONG': 'y',
    'CONFIG_NET': 'y', 'CONFIG_INET': 'y', 'CONFIG_IPV6': 'y',
    'CONFIG_UEVENT_HELPER': 'n', 'CONFIG_FW_LOADER': 'y',
    'CONFIG_FW_LOADER_USER_HELPER': 'n', 'CONFIG_DMIID': 'y',
    'CONFIG_SYSFB_SIMPLEFB': 'y', 'CONFIG_DRM_PANIC': 'y',
    'CONFIG_DRM_PANIC_SCREEN': '"kmsg"', 'CONFIG_DRM_FBDEV_EMULATION': 'y',
    'CONFIG_DRM_SIMPLEDRM': 'y', 'CONFIG_FRAMEBUFFER_CONSOLE': 'y',
    'CONFIG_INOTIFY_USER': 'y', 'CONFIG_PCI': 'y', 'CONFIG_PCI_MSI': 'y',
    'CONFIG_IOMMU_SUPPORT': 'y', 'CONFIG_IRQ_REMAP': 'y', 'CONFIG_X86_X2APIC': 'y',
}
ASSIGNMENT = re.compile(r'(CONFIG_[A-Za-z0-9_]+)=(y|m|n|-?[0-9]+|0x[0-9a-fA-F]+|"(?:[^"\\]|\\.)*")')
DISABLED = re.compile(r'# (CONFIG_[A-Za-z0-9_]+) is not set')


def read(path):
    path = Path(path)
    if path.is_symlink() or path.resolve() != path or not path.is_file():
        raise RuntimeError('Kernel config path is missing or aliased')
    raw = path.read_bytes()
    if not raw or len(raw) > 4 * 1024 * 1024:
        raise RuntimeError('Kernel config size invalid')
    return raw


def parse(raw):
    values = {}
    for line in raw.decode('utf-8').splitlines():
        match = ASSIGNMENT.fullmatch(line)
        disabled = DISABLED.fullmatch(line)
        if match:
            key, value = match.groups()
        elif disabled:
            key, value = disabled.group(1), 'n'
        elif not line.strip() or line.startswith('#'):
            continue
        else:
            raise RuntimeError('Malformed kernel configuration line')
        if key in values:
            raise RuntimeError('Duplicate kernel configuration symbol: ' + key)
        values[key] = value
    return values


def requirements(path=REQUIRED):
    raw = read(path)
    if hashlib.sha256(raw).hexdigest() != REQUIRED_SHA256:
        raise RuntimeError('Pinned kernel requirement fragment changed')
    values = parse(raw)
    for key, value in ADDITIONAL.items():
        if key in values and values[key] != value:
            raise RuntimeError('Conflicting kernel requirement: ' + key)
        values[key] = value
    return values


def fragment(path=REQUIRED):
    return ''.join(key + '=' + value + '\n' for key, value in sorted(requirements(path).items()))


def verify(config, required=REQUIRED):
    raw = read(config)
    if ('# Linux/x86_64 ' + VERSION + ' Kernel Configuration') not in raw.decode('utf-8').splitlines():
        raise RuntimeError('Effective kernel configuration version/architecture mismatch')
    actual, expected = parse(raw), requirements(required)
    drift = {key: {'required': value, 'actual': actual.get(key)}
             for key, value in expected.items() if actual.get(key) != value}
    if drift:
        raise RuntimeError('Kernel configuration requirements unresolved: ' + json.dumps(drift, sort_keys=True))
    return {'schema': 'alpbahOS.kernel-config/v1', 'result': 'CONFIG_VERIFIED',
            'kernel_version': VERSION, 'expected_source_sha256': SOURCE_SHA256,
            'requirements_sha256': REQUIRED_SHA256,
            'effective_config_sha256': hashlib.sha256(raw).hexdigest(),
            'required_options': expected,
            'scope': 'effective configuration only; no kernel build, ownership, boot or stage acceptance'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('fragment', 'verify'))
    parser.add_argument('--config', type=Path)
    args = parser.parse_args()
    if args.action == 'fragment':
        print(fragment(), end='')
    else:
        if args.config is None:
            parser.error('verify requires --config')
        print(json.dumps(verify(args.config.absolute()), indent=2, sort_keys=True))


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, UnicodeError) as error:
        raise SystemExit('STOP: ' + str(error))
