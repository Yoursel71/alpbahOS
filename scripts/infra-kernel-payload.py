#!/usr/bin/env python3
"""Read-only kernel DESTDIR candidate verification, never stage acceptance.

The future producer must bind actual source/build/accepted Base evidence,
normalize numeric ownership, archive through the shared package code and
install through Alp. This verifies candidate bytes, not a booted kernel.
"""
import argparse
import hashlib
import importlib.util
import json
import posixpath
import re
import stat
import struct
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
VERSION = '6.16.1'
SOURCE_URL = 'https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.16.1.tar.xz'
SOURCE_SHA = 'ea43491bc7ace1e414b3b2d957f8cf96e7049155123f0acce798accf8da1acba'
BOOT_FILES = {'vmlinuz-6.16.1-alpbahOS', 'System.map-6.16.1', 'config-6.16.1'}
MODROOT = 'usr/lib/modules/' + VERSION
METADATA = {'modules.order', 'modules.builtin', 'modules.builtin.modinfo',
            'modules.builtin.ranges', 'modules.dep', 'modules.dep.bin',
            'modules.alias', 'modules.alias.bin', 'modules.softdep',
            'modules.symbols', 'modules.symbols.bin', 'modules.devname',
            'modules.builtin.bin', 'modules.builtin.alias.bin', 'modules.weakdep'}


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, REPO / 'scripts' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


config = load('kernel_configuration', 'infra-kernel-config.py')
capture = load('kernel_capture', 'capture-package-manifest.py')


def safe_path(path, directory=False):
    path = Path(path)
    if path.resolve() != path or path.is_symlink() or not (path.is_dir() if directory else path.is_file()):
        raise RuntimeError('Kernel payload path is missing or aliased')
    return path


def bounded(path, limit):
    safe_path(path)
    if not 0 < path.stat().st_size <= limit:
        raise RuntimeError('Kernel payload size invalid: ' + str(path))
    with path.open('rb') as stream:
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise RuntimeError('Kernel payload changed during bounded read')
    return raw


def relative(value):
    if (not isinstance(value, str) or not value or value.startswith('/')
            or '\\' in value or '\x00' in value or posixpath.normpath(value) != value
            or '..' in value.split('/') or any(part in ('', '.') for part in value.split('/'))):
        raise RuntimeError('Unsafe kernel module path')
    return value


def image_header(path):
    safe_path(path)
    size = path.stat().st_size
    with path.open('rb') as stream:
        header = stream.read(32768)
    if len(header) < 1024 or header[0x1fe:0x200] != b'\x55\xaa' or header[0x202:0x206] != b'HdrS':
        raise RuntimeError('Invalid x86 kernel boot header')
    u16 = lambda offset: struct.unpack_from('<H', header, offset)[0]
    u32 = lambda offset: struct.unpack_from('<I', header, offset)[0]
    if u16(0x206) < 0x20c or not u16(0x236) & 1 or not header[0x211] & 1:
        raise RuntimeError('Kernel is not a modern x86_64 bzImage')
    setup = ((header[0x1f1] or 4) + 1) * 512
    payload_offset, payload_length = u32(0x248), u32(0x24c)
    if (setup >= size or not u32(0x1f4) or not payload_length
            or setup + payload_offset + payload_length > size):
        raise RuntimeError('Kernel boot payload bounds invalid')
    offset = 0x200 + u16(0x20e)
    end = header.find(b'\x00', offset)
    if offset < 0x200 or end < offset or end >= setup or not header[offset:end].startswith((VERSION + ' (').encode()):
        raise RuntimeError('Kernel boot release differs from pinned release')
    # CONFIG_EFI_STUB=y requires an actual PE32+ x86_64 header as well.
    pe = u32(0x3c)
    if (header[:2] != b'MZ' or pe + 26 > min(setup, len(header))
            or header[pe:pe + 4] != b'PE\x00\x00' or u16(pe + 4) != 0x8664
            or u16(pe + 24) != 0x20b):
        raise RuntimeError('Kernel EFI stub header is not PE32+ x86_64')
    return {'boot_protocol': u16(0x206), 'xloadflags': u16(0x236),
            'payload_length': payload_length, 'release': VERSION}


def module_abi(path):
    raw = bounded(path, 64 * 1024 * 1024)
    if (len(raw) < 64 or raw[:7] != b'\x7fELF\x02\x01\x01'
            or struct.unpack_from('<HHI', raw, 16) != (1, 62, 1)):
        raise RuntimeError('Kernel module is not ELF64 little-endian x86_64 ET_REL')
    offset = struct.unpack_from('<Q', raw, 40)[0]
    entry_size, count, names_index = struct.unpack_from('<HHH', raw, 58)
    if entry_size != 64 or not count or names_index >= count or offset + count * 64 > len(raw):
        raise RuntimeError('Kernel module section table invalid')
    sections = [struct.unpack_from('<IIQQQQIIQQ', raw, offset + i * 64) for i in range(count)]
    def section_data(section):
        start, size = section[4:6]
        if start + size > len(raw):
            raise RuntimeError('Kernel module section escaped file')
        return raw[start:start + size]
    names = section_data(sections[names_index])
    found = []
    for section in sections:
        start = section[0]
        end = names.find(b'\x00', start)
        if start >= len(names) or end < 0:
            raise RuntimeError('Kernel module section name invalid')
        if names[start:end] == b'.modinfo':
            if section[1] != 1:
                raise RuntimeError('Kernel module modinfo section type invalid')
            found.append(section_data(section))
    if len(found) != 1:
        raise RuntimeError('Kernel module modinfo missing or duplicated')
    magic = [value[len(b'vermagic='):] for value in found[0].split(b'\x00') if value.startswith(b'vermagic=')]
    if len(magic) != 1 or not magic[0].startswith((VERSION + ' ').encode()):
        raise RuntimeError('Kernel module vermagic release differs')
    return magic[0].decode('ascii')


def verify(stage, manifest):
    stage, manifest = safe_path(stage, True), safe_path(manifest)
    if stage == manifest or stage in manifest.parents:
        raise RuntimeError('Kernel manifest must be outside stage')
    manifest_raw = bounded(manifest, 64 * 1024 * 1024)
    declared = json.loads(manifest_raw)
    if (declared.get('schema') != 'alpbahOS.package-files/v1'
            or declared.get('package') != {'name': 'linux-kernel', 'version': VERSION,
                                         'source': {'url': SOURCE_URL, 'sha256': SOURCE_SHA}}):
        raise RuntimeError('Kernel manifest package/source identity invalid')
    before = capture.capture_tree(stage)
    if declared.get('entries') != before:
        raise RuntimeError('Kernel stage and complete manifest coverage differ')
    owner = stage.stat()
    for entry in before:
        path = relative(entry['path'].lstrip('/'))
        if (entry['type'] not in ('directory', 'file', 'symlink')
                or entry['uid'] != owner.st_uid or entry['gid'] != owner.st_gid
                or (entry['type'] != 'symlink'
                    and entry['mode'] & (stat.S_ISUID | stat.S_ISGID | stat.S_IWOTH))):
            raise RuntimeError('Kernel candidate metadata unsafe or ownership nonuniform')
        allowed = (path in ('boot', 'usr', 'usr/lib', 'usr/lib/modules', MODROOT, MODROOT + '/kernel',
                            'usr/share', 'usr/share/doc', 'usr/share/doc/linux-' + VERSION)
                   or path.startswith('usr/share/doc/linux-' + VERSION + '/')
                   or path in {'boot/' + name for name in BOOT_FILES}
                   or path.startswith(MODROOT + '/kernel/')
                   or path in {MODROOT + '/' + name for name in METADATA})
        if not allowed:
            raise RuntimeError('Unexpected kernel candidate path: ' + path)
        if entry['type'] == 'symlink':
            target = entry['target']
            if path.startswith(MODROOT + '/') or target.startswith('/'):
                raise RuntimeError('Kernel build/source/module symlink cannot enter payload')
            resolved = posixpath.normpath(posixpath.join(posixpath.dirname(path), target))
            relative(resolved)
            if resolved not in {e['path'].lstrip('/') for e in before}:
                raise RuntimeError('Kernel documentation symlink leaves candidate or is dangling')
            try:
                resolved_path = (stage / path).resolve(strict=True)
            except (OSError, RuntimeError) as error:
                raise RuntimeError('Kernel documentation symlink is dangling or cyclic') from error
            if stage not in resolved_path.parents:
                raise RuntimeError('Kernel documentation symlink escapes candidate')
    configuration = config.verify(stage / ('boot/config-' + VERSION))
    values = config.parse((stage / ('boot/config-' + VERSION)).read_bytes())
    if values.get('CONFIG_MODULE_COMPRESS') != 'n' or values.get('CONFIG_LOCALVERSION') != '""':
        raise RuntimeError('Kernel candidate compression/localversion differs from initial plan')
    header = image_header(stage / ('boot/vmlinuz-' + VERSION + '-alpbahOS'))
    symbol_map = bounded(stage / ('boot/System.map-' + VERSION), 64 * 1024 * 1024).decode('ascii').splitlines()
    if any(not re.fullmatch(r'[0-9a-fA-F]{16} [A-Za-z?] [^\s]+', line) for line in symbol_map):
        raise RuntimeError('Kernel System.map format invalid')
    if not {'_text', 'start_kernel', 'init_task'} <= {line.split()[2] for line in symbol_map}:
        raise RuntimeError('Kernel System.map required symbols missing')
    modules = {e['path'][len('/' + MODROOT) + 1:] for e in before
               if e['type'] == 'file' and e['path'].startswith('/' + MODROOT + '/kernel/')}
    if not modules or any(not path.endswith('.ko') for path in modules):
        raise RuntimeError('Kernel candidate lacks uncompressed module payload')
    module_root = stage / MODROOT
    order = bounded(module_root / 'modules.order', 16 * 1024 * 1024).decode('ascii').splitlines()
    if len(order) != len(set(order)) or set(map(relative, order)) != modules:
        raise RuntimeError('Kernel modules.order coverage differs from actual modules')
    dependencies = bounded(module_root / 'modules.dep', 16 * 1024 * 1024).decode('ascii').splitlines()
    seen = set()
    for line in dependencies:
        name, separator, tail = line.partition(':')
        if not separator or relative(name) not in modules or name in seen:
            raise RuntimeError('Kernel module dependency index invalid')
        seen.add(name)
        if any(relative(dependency) not in modules for dependency in tail.split()):
            raise RuntimeError('Kernel module dependency refers outside payload')
    if seen != modules:
        raise RuntimeError('Kernel modules.dep coverage incomplete')
    for name in ('modules.builtin', 'modules.builtin.modinfo', 'modules.dep.bin',
                 'modules.alias', 'modules.alias.bin', 'modules.symbols', 'modules.symbols.bin'):
        safe_path(module_root / name)
    vermagic = {name: module_abi(module_root / name) for name in sorted(modules)}
    if capture.capture_tree(stage) != before or manifest.read_bytes() != manifest_raw:
        raise RuntimeError('Kernel candidate bytes changed during verification')
    return {'schema': 'alpbahOS.kernel-payload/v1', 'result': 'VERIFIED_CANDIDATE_BYTES',
            'manifest_sha256': hashlib.sha256(manifest_raw).hexdigest(),
            'effective_config_sha256': configuration['effective_config_sha256'],
            'numeric_owner': {'uid': owner.st_uid, 'gid': owner.st_gid},
            'boot_header': header, 'module_vermagic': vermagic, 'module_count': len(modules),
            'scope': 'candidate metadata/ABI only; no source/build provenance, Alp ownership, loadability, boot or stage acceptance'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.stage.absolute(), args.manifest.absolute()), indent=2, sort_keys=True))


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, UnicodeError, struct.error) as error:
        raise SystemExit('STOP: ' + str(error))
