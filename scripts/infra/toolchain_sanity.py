"""Guest-only cross C/C++ link probes; never executes the target programs."""
import json
import os
import re
import shutil
import struct
import subprocess
import time
from pathlib import Path
from package_stage import heavy_recipe_guard, sha
from package_install import guest_install_guard, packages
from guest_process import monitor_command
from handoff_binding import validate as validate_handoff
from package_stage import BOOT

LFS = Path('/srv/lfs')
REPO = Path('/opt/alp-infra')
INFRA = Path('/srv/infra')
TRIPLET = 'x86_64-lfs-linux-gnu'
ABIS = {'m64': (2, 62, '/lib64/ld-linux-x86-64.so.2', 'usr/lib', 'glibc-cross-m64'),
        'm32': (1, 3, '/lib/ld-linux.so.2', 'usr/lib32', 'glibc-cross-m32')}


def elf_identity(path, abi):
    """Check ELF class/machine and the actual PT_INTERP bytes, including x32."""
    if path.stat().st_size > 16 * 1024 * 1024:
        raise RuntimeError('Unexpectedly large ABI probe')
    raw = path.read_bytes()
    cls, machine, interpreter, _, _ = ABIS[abi]
    if (len(raw) < 64 or raw[:4] != b'\x7fELF' or raw[4:7] != bytes((cls, 1, 1))
            or struct.unpack_from('<HH', raw, 16)[0] not in (2, 3)
            or struct.unpack_from('<H', raw, 18)[0] != machine
            or struct.unpack_from('<I', raw, 20)[0] != 1):
        raise RuntimeError('ABI probe ELF class/machine/type mismatch; x32 forbidden')
    if cls == 2:
        offset = struct.unpack_from('<Q', raw, 32)[0]
        size, count = struct.unpack_from('<HH', raw, 54)
        expected_size, offset_field, bytes_field, fmt = 56, 8, 32, '<Q'
        header_size, header_size_field = 64, 52
    else:
        offset = struct.unpack_from('<I', raw, 28)[0]
        size, count = struct.unpack_from('<HH', raw, 42)
        expected_size, offset_field, bytes_field, fmt = 32, 4, 16, '<I'
        header_size, header_size_field = 52, 40
    if (struct.unpack_from('<H', raw, header_size_field)[0] != header_size
            or size != expected_size or not 0 < count <= 1024
            or offset < header_size or offset + size * count > len(raw)):
        raise RuntimeError('Invalid ABI probe program header table')
    values = []
    for number in range(count):
        header = offset + size * number
        if struct.unpack_from('<I', raw, header)[0] != 3:
            continue
        start = struct.unpack_from(fmt, raw, header + offset_field)[0]
        length = struct.unpack_from(fmt, raw, header + bytes_field)[0]
        if not 1 < length <= 256 or start + length > len(raw):
            raise RuntimeError('Invalid ABI probe interpreter segment')
        values.append(raw[start:start + length])
    if values != [interpreter.encode() + b'\0']:
        raise RuntimeError('ABI probe interpreter differs from the target root path')
    return {'class': cls, 'machine': machine, 'interpreter': interpreter, 'sha256': sha(path)}


def owned_path(root, raw, owners, tree=None):
    path = Path(raw)
    resolved = path.resolve()
    if (not path.is_absolute() or not path.is_file() or root not in resolved.parents
            or (tree is not None and tree not in resolved.parents)):
        raise RuntimeError('Toolchain path is missing or outside target sysroot: ' + str(path))
    claims = set()
    for name, record in packages(root).items():
        if record.get('status') != 'installed':
            continue
        for item in set(record.get('files', [])) | set(record.get('symlinks', [])):
            candidate = root / item.lstrip('/')
            if candidate.resolve() == resolved:
                claims.add(name)
    if len(claims) != 1 or not claims <= set(owners):
        raise RuntimeError('Toolchain path owner missing/conflicting: ' + str(path))
    return resolved


def parse_trace(stdout, stderr):
    match = re.search(r'#include <\.\.\.> search starts here:\n(.*?)\nEnd of search list\.', stderr, re.S)
    if not match:
        raise RuntimeError('Compiler header search evidence missing')
    headers = [line.strip() for line in match[1].splitlines() if line.strip()]
    search = re.findall(r'SEARCH_DIR\("([^"\n]+)"\)', stdout)
    selected = re.findall(r'^attempt to open (.+?) succeeded\s*$', stdout, re.M)
    if not headers or not search or not selected:
        raise RuntimeError('Compiler/linker raw search/selected-file evidence missing')
    return {'header_search': headers, 'linker_search': search, 'selected_inputs': selected}


def validate_trace(root, stdout, stderr):
    trace = parse_trace(stdout, stderr)
    headers, search, selected = (trace[k] for k in ('header_search', 'linker_search', 'selected_inputs'))
    if not headers or str(root / 'usr/include') not in headers:
        raise RuntimeError('Target sysroot headers absent from compiler search')
    for raw in headers:
        path = Path(raw)
        if not path.is_absolute() or root not in path.resolve().parents or not path.is_dir():
            raise RuntimeError('Compiler searched host/invalid headers: ' + raw)
    if not search or any(not value.startswith('=') for value in search):
        raise RuntimeError('Linker search is not consistently sysroot-relative')
    if not selected:
        raise RuntimeError('Linker selected-file evidence missing')
    for raw in selected:
        owned_path(root, raw, {'gcc-pass1', 'glibc-cross-m64', 'glibc-cross-m32', 'libstdcxx-cross'})
    return trace


def probe_source(language):
    if language == 'c':
        return '#include <limits.h>\n#include <stdio.h>\nint main(void){return CHAR_BIT != 8 || EOF != -1;}\n'
    if language == 'c++':
        return '#include <vector>\nint main(){std::vector<int> v{1,2};return v[0]-1;}\n'
    raise RuntimeError('Unsupported ABI probe language')


def probe(stage, root, result):
    """Fresh diagnostic work/evidence for each invocation, not a stamp."""
    if stage not in ('glibc-cross-m64', 'glibc-cross-m32', 'libstdcxx-cross') or root != LFS:
        raise RuntimeError('ABI sanity stage/root not allowlisted')
    guest_install_guard(root, result)
    heavy_recipe_guard({'phase': 'toolchain', 'abi': 'multilib-m32'})
    sources = json.loads((REPO / 'manifests/infra-sources.json').read_text())
    inputs = json.loads((INFRA / 'inputs.json').read_text())
    authorization = json.loads((INFRA / 'phase2-authorization.json').read_bytes())
    capsule = validate_handoff((INFRA / 'stability-acceptance.json').read_bytes(), authorization,
                               inputs, BOOT.read_text().strip())
    mode_list = ('m64',) if stage == 'glibc-cross-m64' else ('m64', 'm32')
    language = 'c++' if stage == 'libstdcxx-cross' else 'c'
    compiler = root / 'tools/bin' / (TRIPLET + ('-g++' if language == 'c++' else '-gcc'))
    owned_path(root, str(compiler), {'gcc-pass1'}, root / 'tools')
    serial = f'abi-{stage}-{time.time_ns()}'
    evidence = result / serial; evidence.mkdir()
    artifacts, rows = {}, []

    def command(argv, cwd, label, input=None):
        args = ['runuser', '-u', 'lfs', '--', 'env', '-i', 'HOME=/home/lfs',
                'PATH=' + str(root / 'tools/bin') + ':/usr/bin:/bin', 'LC_ALL=C', 'LANG=C', 'TZ=UTC',
                f'SOURCE_DATE_EPOCH={sources["source_date_epoch"]}', *map(str, argv)]
        out, err = evidence / (label + '.stdout'), evidence / (label + '.stderr')
        with (evidence / 'commands.jsonl').open('a') as log:
            log.write(json.dumps({'argv': args, 'cwd': str(cwd), 'input': input}, sort_keys=True) + '\n')
        space = evidence / (label + '.space.jsonl')
        record = {'schema': 'alpbahOS.abi-command/v1', 'run_id': capsule['run_id'],
                  'guest_boot_id': capsule['guest_boot_id'], 'handoff_sha256': authorization['handoff_sha256'],
                  'argv': args, 'cwd': str(cwd), 'input': input, 'label': label,
                  'started_at_ns': time.time_ns(), 'started_monotonic_ns': time.monotonic_ns(),
                  'exit': None, 'errors': []}
        try:
            with out.open('xb') as stdout, err.open('xb') as stderr, space.open('x') as telemetry:
                monitor_command(args, stdout, stderr, telemetry, cwd=cwd, input=input, text=True)
            record['exit'] = 0
        except BaseException as error:
            record['exit'] = error.returncode if isinstance(error, subprocess.CalledProcessError) else None
            record['errors'].append(repr(error))
            raise
        finally:
            record.update(ended_at_ns=time.time_ns(), ended_monotonic_ns=time.monotonic_ns())
            terminal = evidence / (label + '.command.json')
            with terminal.open('x') as stream:
                json.dump(record, stream, sort_keys=True, indent=2); stream.write('\n')
            artifacts[terminal.name] = sha(terminal)
        artifacts[out.name], artifacts[err.name] = sha(out), sha(err)
        artifacts[space.name] = sha(space)
        return out.read_text(), err.read_text()

    listing, _ = command([compiler, '-print-multi-lib'], evidence, 'multilib')
    options = [row.partition(';')[2] for row in listing.strip().splitlines()]
    if len(options) != 2 or set(options) != {'', '@m32'}:
        raise RuntimeError('Cross compiler must expose exactly m64+m32; x32 forbidden')
    for abi in mode_list:
        _, _, interpreter, libdir, libc_owner = ABIS[abi]
        flag = '-' + abi
        sysroot, _ = command([compiler, flag, '-print-sysroot'], evidence, abi + '-sysroot')
        if sysroot.strip() != str(root):
            raise RuntimeError('Cross compiler sysroot mismatch')
        linker, _ = command([compiler, flag, '-print-prog-name=ld'], evidence, abi + '-linker')
        owned_path(root, linker.strip(), {'binutils-pass1'}, root / 'tools')
        startfiles = {}
        for filename in ('Scrt1.o', 'crti.o', 'crtn.o'):
            found, _ = command([compiler, flag, '-print-file-name=' + filename], evidence, abi + '-' + filename)
            startfiles[filename] = str(owned_path(root, found.strip(), {libc_owner}, root / libdir))
        libc = owned_path(root, str(root / libdir / 'libc.so.6'), {libc_owner}, root / libdir)
        loader = owned_path(root, str(root / interpreter.lstrip('/')), {libc_owner}, root / libdir)
        stdlib = None
        if language == 'c++':
            library, _ = command([compiler, flag, '-print-file-name=libstdc++.so'], evidence, abi + '-libstdcxx')
            stdlib = owned_path(root, library.strip(), {'libstdcxx-cross'}, root / libdir)
        work = root / 'build' / (serial + '-' + abi)
        if work.exists() or work.is_symlink() or work.resolve() != work:
            raise RuntimeError('Existing/aliased ABI work refused')
        work.mkdir(); shutil.chown(work, user='lfs', group='lfs')
        source = probe_source(language)
        compile_out, compile_err = command([compiler, flag, '-x', language, '-', '-O2', '-g0',
            '-ffile-prefix-map=' + str(work) + '=/usr/src/alp-abi-probe', '-v', '-Wl,--verbose', '-o', 'probe'],
            work, abi + '-compile', input=source)
        identity = elf_identity(work / 'probe', abi)
        trace = validate_trace(root, compile_out, compile_err)
        chosen = {Path(raw).resolve() for raw in trace['selected_inputs']}
        if not set(map(Path, startfiles.values())) <= chosen or libc not in chosen or (stdlib and stdlib not in chosen):
            raise RuntimeError('Verbose link evidence does not select target CRT/libc inputs')
        dynamic, _ = command(['/usr/bin/readelf', '-d', '--wide', work / 'probe'], evidence, abi + '-dynamic')
        if re.search(r'\((?:RPATH|RUNPATH)\)', dynamic):
            raise RuntimeError('ABI probe has an unexpected runtime library search path')
        saved = evidence / (abi + '.elf'); shutil.copyfile(work / 'probe', saved)
        artifacts[saved.name] = sha(saved)
        rows.append({'abi': abi, 'language': language, 'elf': identity, 'startfiles': startfiles,
                     'libc': str(libc), 'loader': str(loader), 'libstdcxx': str(stdlib) if stdlib else None, 'trace': trace})
    artifacts['commands.jsonl'] = sha(evidence / 'commands.jsonl')
    summary = {'result': 'PASS', 'stage': stage, 'scope': 'cross compile/link only; target programs not executed',
               'inputs_sha256': inputs['inputs_sha256'], 'sources_sha256': sha(REPO / 'manifests/infra-sources.json'),
               'run_id': capsule['run_id'], 'guest_boot_id': capsule['guest_boot_id'],
               'handoff_sha256': authorization['handoff_sha256'],
               'rows': rows, 'artifact_sha256': artifacts}
    (evidence / 'summary.json').write_text(json.dumps(summary, indent=2, sort_keys=True) + '\n')
    return {'summary': str(evidence / 'summary.json'), 'summary_sha256': sha(evidence / 'summary.json')}
