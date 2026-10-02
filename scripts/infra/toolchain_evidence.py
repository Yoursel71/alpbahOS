"""Read-only verification of collected Chapter 4/5 package evidence.

This verifies received bytes and the guarded guest's payload observations.
It does not certify host integrity, compiler execution, reproducibility or
checkpoint acceptance. The controller's acceptance slot remains closed.
"""
import json
import math
import re
from pathlib import Path
from package_install import fingerprint, member_path, validate_bundle
from package_stage import sha, source_pin
from handoff_binding import validate as validate_handoff
from stage_runs import file_hashes
from toolchain_plan import ORDER, load as canonical_plan
from filesystem_layout import DIRECTORIES, LINKS, FORBIDDEN


class Payload:
    """Resolve recorded guest paths without consulting the host's /srv/lfs."""

    def __init__(self, manifests, records):
        self.entries, self.owners = {}, {}
        for name, entries in manifests.items():
            for entry in entries:
                path = member_path(entry['path'][1:])
                previous = self.entries.get(path)
                if previous is not None and (previous != entry or entry['type'] != 'directory'):
                    raise RuntimeError('Conflicting toolchain payload entry: ' + path)
                self.entries[path] = entry
        self.canonical = {}
        required = {name: set() for name in manifests}
        for name, entries in manifests.items():
            for entry in entries:
                key = self.resolve(entry['path'][1:], follow_leaf=False)
                previous = self.canonical.get(key)
                if previous is not None and previous != entry:
                    # Alias paths cannot hide a second file or different metadata.
                    if {k: v for k, v in previous.items() if k != 'path'} != {k: v for k, v in entry.items() if k != 'path'}:
                        raise RuntimeError('Conflicting canonical toolchain payload: ' + key)
                self.canonical[key] = entry
                if entry['type'] != 'directory':
                    if key in self.owners:
                        raise RuntimeError('Multiple toolchain payload owners: ' + key)
                    self.owners[key] = name; required[name].add(key)
        for name, record in records.items():
            claims = set()
            for field in ('files', 'symlinks'):
                values = record.get(field, [])
                if not isinstance(values, list) or any(not isinstance(v, str) for v in values):
                    raise RuntimeError('Invalid toolchain ownership list')
                for raw in values:
                    if raw.startswith('//'):
                        raise RuntimeError('Noncanonical toolchain ownership path')
                    relative = member_path(raw[1:] if raw.startswith('/') else raw)
                    if not relative:
                        raise RuntimeError('Empty toolchain ownership path')
                    key = self.resolve(relative, follow_leaf=False)
                    entry = self.canonical.get(key)
                    if entry is None:
                        raise RuntimeError('Toolchain DB claims absent payload: ' + key)
                    if entry['type'] == 'directory':
                        if field == 'symlinks':
                            raise RuntimeError('Toolchain DB symlink claim is a directory')
                        continue
                    if field == 'symlinks' and entry['type'] != 'symlink':
                        raise RuntimeError('Toolchain DB symlink claim has wrong type')
                    claims.add(key)
            if claims != required[name] or any(self.owners[key] != name for key in claims):
                raise RuntimeError('Toolchain raw DB ownership missing/extra/conflicting: ' + name)
        self.layout()

    def resolve(self, relative, follow_leaf=True):
        if not isinstance(relative, str) or relative.startswith('/') or '\\' in relative or '\x00' in relative:
            raise RuntimeError('Unsafe recorded guest path')
        todo, resolved, links = relative.split('/'), [], 0
        while todo:
            component = todo.pop(0)
            if component in ('', '.'):
                continue
            if component == '..':
                if not resolved:
                    raise RuntimeError('Recorded guest path escapes LFS')
                resolved.pop(); continue
            key = '/'.join([*resolved, component])
            entry = self.entries.get(key)
            if entry and entry['type'] == 'symlink' and (todo or follow_leaf):
                links += 1
                target = entry['target']
                if links > 40 or target.startswith('/') or '\\' in target or '\x00' in target:
                    raise RuntimeError('Unsafe/cyclic recorded guest symlink')
                todo = target.split('/') + todo
            else:
                if todo and entry is None:
                    raise RuntimeError('Recorded guest parent missing from observed payload')
                if todo and entry and entry['type'] != 'directory':
                    raise RuntimeError('Recorded guest parent is not a directory')
                resolved.append(component)
        return '/'.join(resolved)

    def file(self, raw, owners, tree=None):
        if not isinstance(raw, str) or not raw.startswith('/srv/lfs/'):
            raise RuntimeError('ABI path outside recorded target sysroot')
        key = self.resolve(raw[len('/srv/lfs/'):])
        if (key not in self.canonical or self.canonical[key]['type'] != 'file'
                or self.owners.get(key) not in owners
                or (tree is not None and not key.startswith(tree + '/'))):
            raise RuntimeError('ABI recorded file/owner/tree invalid: ' + raw)
        return '/srv/lfs/' + key

    def layout(self):
        for path, mode in DIRECTORIES.items():
            entry = self.entries.get(path, {})
            if entry.get('type') != 'directory' or entry.get('mode') != mode:
                raise RuntimeError('Recorded toolchain layout directory changed: ' + path)
        for path, target in LINKS.items():
            entry = self.entries.get(path, {})
            if entry.get('type') != 'symlink' or entry.get('target') != target or self.owners.get(path) != ORDER[0]:
                raise RuntimeError('Recorded toolchain layout alias changed: ' + path)
        if any(path == bad or path.startswith(bad + '/') for bad in FORBIDDEN for path in self.entries):
            raise RuntimeError('Recorded toolchain forbidden ABI path')


def verify_packages(root, repo, inputs, capsule_raw, authorization, guest_boot_id):
    """All seven real bundles, raw DB prefixes, receipts and observed payload.

    The caller supplies its measured guest boot and pinned transport bytes.
    A VERIFIED_PACKAGE_BYTES result is deliberately not a stage PASS.
    """
    root, repo = Path(root), Path(repo)
    hashes = file_hashes(root)

    def path(name):
        if name not in hashes:
            raise RuntimeError('Toolchain evidence missing: ' + name)
        return root / name

    def read(name):
        item = path(name)
        if item.stat().st_size > 32 * 1024 * 1024:
            raise RuntimeError('Toolchain JSON evidence too large')
        return json.loads(item.read_bytes())

    sources_path = repo / 'manifests/infra-sources.json'
    if sources_path.resolve() != sources_path or sources_path.is_symlink() or sha(sources_path) != inputs.get('sources_sha256'):
        raise RuntimeError('Toolchain canonical source manifest changed')
    sources_raw = sources_path.read_bytes(); sources = json.loads(sources_raw)
    plan = canonical_plan(repo)
    capsule = validate_handoff(capsule_raw, authorization, inputs, guest_boot_id)
    binding = {**{k: inputs[k] for k in ('inputs_sha256', 'sources_sha256')},
               'plan_sha256': fingerprint(plan), 'run_id': capsule['run_id'],
               'guest_boot_id': guest_boot_id, 'handoff_sha256': authorization['handoff_sha256']}
    summary = read('summary.json')
    expected = {**binding, 'schema': 'alpbahOS.toolchain-guest/v1', 'result': 'PASS',
                'mode': 'multilib-m32', 'alp_sha256': sources['alp']['sha256'],
                'source_date_epoch': sources['source_date_epoch']}
    if read('inputs.json') != binding or any(summary.get(k) != v for k, v in expected.items()):
        raise RuntimeError('Toolchain summary/current run/input binding changed')
    actions, observations = summary.get('packages'), summary.get('observations')
    if (not isinstance(actions, list) or not isinstance(observations, list)
            or [a.get('package') for a in actions] != list(ORDER)
            or [a.get('package') for a in observations] != list(ORDER)):
        raise RuntimeError('Toolchain exact ordered package/observation coverage missing')

    def database(name, names):
        data = read(name)
        if data.get('schema_version') != 1 or not isinstance(data.get('packages'), dict) or set(data['packages']) != set(names):
            raise RuntimeError('Toolchain raw DB exact prefix/package coverage changed')
        return data['packages']

    final = database('db-final.json', ORDER)
    if summary.get('final_db_sha256') != hashes['db-final.json']:
        raise RuntimeError('Toolchain final raw DB SHA changed')
    manifests = {}
    for number, (recipe, action, observation) in enumerate(zip(plan, actions, observations)):
        name = recipe['name']; prefix = name + '/'
        guest_directory = '/srv/lfs/results/toolchain/' + capsule['run_id'] + '/' + name
        built_record = read(prefix + 'built.json')
        if built_record.get('result') != 'BUILT' or built_record.get('binding') != binding:
            raise RuntimeError('Toolchain built bundle binding changed')
        built = built_record['built'].copy()
        canonical_source = source_pin(sources, recipe['source'], repo)
        if built.get('source') != canonical_source or not (type(built.get('seconds')) in (int, float) and math.isfinite(built['seconds']) and built['seconds'] > 0):
            raise RuntimeError('Toolchain bundle canonical source/timing changed')
        for field, suffix in (('archive', '.tar.gz'), ('manifest', '.json')):
            filename = 'toolchain-' + name + suffix
            if built.get(field) != guest_directory + '/' + filename:
                raise RuntimeError('Toolchain bundle fixed guest path changed')
            built[field] = path(prefix + filename)
        manifest = validate_bundle(recipe, built)
        if any(type(entry.get(k)) is not int or entry[k] != 0
               for entry in manifest['entries'] for k in ('uid', 'gid')):
            raise RuntimeError('Toolchain product payload ownership metadata must be root')
        manifests[name] = manifest['entries']
        if (action.get('action') not in ('installed verified bundle', 'verified installed; no rebuild/reinstall')
                or any(action.get(k) != built[k] for k in ('archive_sha256', 'manifest_sha256'))):
            raise RuntimeError('Toolchain action bundle hashes changed')
        observed_name = prefix + 'observed.json'; path(observed_name)
        expected_observation = {'schema': 'alpbahOS.installed-observation/v1', 'run_id': capsule['run_id'],
                                'package': name, 'root': '/srv/lfs', 'entries': manifest['entries']}
        if (observation.get('observed') != observed_name
                or observation.get('observed_sha256') != hashes[observed_name]
                or read(observed_name) != expected_observation):
            raise RuntimeError('Toolchain actual payload observation differs from bundle')
        snapshot_name = prefix + name + '.db.json'
        prefix_db = database(snapshot_name, ORDER[:number + 1])
        if any(record != final[owner] for owner, record in prefix_db.items()):
            raise RuntimeError('Toolchain raw DB package record changed after installation')
        record = final[name]
        url = f'file:///srv/lfs/packages/{name}-{recipe["version"]}-{built["archive_sha256"]}.tar.gz'
        if (record.get('status') != 'installed' or record.get('version') != recipe['version']
                or record.get('method') != 'core' or record.get('protected') is not True
                or record.get('source', {}).get('url') != url
                or record.get('source', {}).get('sha256') != built['archive_sha256']):
            raise RuntimeError('Toolchain raw DB protected package/source identity changed')
        receipt = read(prefix + name + '.installed.json')
        index_name = prefix + name + '.index.json'; path(index_name)
        receipt_expected = {'result': 'PASS', 'package': name, 'version': recipe['version'], 'root': '/srv/lfs',
                            'inputs_sha256': inputs['inputs_sha256'], 'recipe_sha256': fingerprint(recipe),
                            'alp_sha256': sources['alp']['sha256'], 'source_date_epoch': sources['source_date_epoch'],
                            'archive_sha256': built['archive_sha256'], 'manifest_sha256': built['manifest_sha256'],
                            'db_sha256': hashes[snapshot_name], 'package_record_sha256': fingerprint(record),
                            'index': guest_directory + '/' + name + '.index.json', 'index_sha256': hashes[index_name],
                            'log': guest_directory + '/' + name + '.install.log'}
        if any(receipt.get(k) != v for k, v in receipt_expected.items()):
            raise RuntimeError('Toolchain installation receipt/raw DB/index binding changed')
        path(prefix + name + '.install.log')
        entry = {'method': 'core', 'name': name, 'version': recipe['version'], 'url': url,
                 'sha256': built['archive_sha256'], 'depends': list(recipe.get('requires', [])), 'protected': True}
        if read(index_name) != {'schema_version': 1, 'entries': {name: entry}}:
            raise RuntimeError('Toolchain installation index scope/source changed')
    payload = Payload(manifests, final)
    if (file_hashes(root) != hashes or sources_path.read_bytes() != sources_raw
            or fingerprint(canonical_plan(repo)) != binding['plan_sha256']):
        raise RuntimeError('Toolchain collected/canonical evidence changed during verification')
    proof = {'schema': 'alpbahOS.toolchain-package-evidence/v1', 'result': 'VERIFIED_PACKAGE_BYTES',
             **binding, 'source_date_epoch': sources['source_date_epoch'], 'alp_sha256': sources['alp']['sha256'],
             'final_db_sha256': hashes['db-final.json'], 'artifact_sha256': hashes,
             'scope': 'received package/DB/payload bytes only; ABI/host/monitor/stage acceptance still required'}
    return proof, payload


def verify_abi(root, proof, payload, source_date_epoch):
    """Reparse saved ELF, compiler/linker streams and per-command telemetry.

    This completes guest byte evidence, not host or whole stage acceptance.
    Must be called immediately after verify_packages on the same collection.
    """
    from toolchain_sanity import ABIS, TRIPLET, elf_identity, parse_trace, probe_source
    from guest_process import check_space
    root = Path(root)
    hashes = file_hashes(root)
    if (hashes != proof.get('artifact_sha256') or proof.get('result') != 'VERIFIED_PACKAGE_BYTES'
            or source_date_epoch != proof.get('source_date_epoch')):
        raise RuntimeError('ABI collection changed after package byte verification')
    binding = {k: proof[k] for k in ('inputs_sha256', 'sources_sha256', 'run_id', 'guest_boot_id', 'handoff_sha256')}
    summary = json.loads((root / 'summary.json').read_bytes())
    sanity = summary.get('sanity')
    stages = ('glibc-cross-m64', 'glibc-cross-m32', 'libstdcxx-cross')
    if not isinstance(sanity, list) or len(sanity) != len(stages):
        raise RuntimeError('ABI exact three probe stages missing')
    results = []
    for stage, row in zip(stages, sanity):
        raw_path = row.get('summary')
        guest_prefix = '/srv/lfs/results/toolchain/' + proof['run_id'] + '/'
        if not isinstance(raw_path, str) or not raw_path.startswith(guest_prefix):
            raise RuntimeError('ABI summary belongs to another guest job')
        relative = raw_path[len(guest_prefix):]
        if not re.fullmatch('abi-' + stage + r'-[0-9]+/summary\.json', relative) or relative not in hashes:
            raise RuntimeError('ABI fixed evidence path missing/invalid')
        if row.get('summary_sha256') != hashes[relative]:
            raise RuntimeError('ABI raw summary SHA changed')
        directory = root / Path(relative).parent
        value = json.loads((root / relative).read_bytes())
        if (value.get('result') != 'PASS' or value.get('stage') != stage
                or any(value.get(k) != v for k, v in binding.items())):
            raise RuntimeError('ABI current input/guest boot/stage binding changed')
        language = 'c++' if stage == 'libstdcxx-cross' else 'c'
        compiler = '/srv/lfs/tools/bin/' + TRIPLET + ('-g++' if language == 'c++' else '-gcc')
        payload.file(compiler, {'gcc-pass1'}, 'tools')
        abis = ('m64',) if stage == 'glibc-cross-m64' else ('m64', 'm32')
        if not isinstance(value.get('rows'), list) or [r.get('abi') for r in value['rows']] != list(abis):
            raise RuntimeError('ABI m64/m32 coverage differs; x32 forbidden')
        artifacts, commands, required = value.get('artifact_sha256'), [], {'commands.jsonl'}
        evidence_guest = guest_prefix + directory.name
        prefix = ['runuser', '-u', 'lfs', '--', 'env', '-i', 'HOME=/home/lfs',
                  'PATH=/srv/lfs/tools/bin:/usr/bin:/bin', 'LC_ALL=C', 'LANG=C', 'TZ=UTC',
                  'SOURCE_DATE_EPOCH=' + str(source_date_epoch)]

        def command(label, argv, cwd=evidence_guest, input=None):
            command_prefix = prefix
            if label.endswith('-compile'):
                if not re.fullmatch(r'/srv/lfs/build/abi-[a-z0-9-]+-(?:m64|m32)', cwd):
                    raise RuntimeError('ABI compile TMPDIR is outside its private work directory')
                command_prefix = [*prefix, 'TMPDIR=' + cwd]
            expected = {'argv': command_prefix + argv, 'cwd': cwd, 'input': input}
            commands.append(expected)
            filenames = [label + suffix for suffix in ('.stdout', '.stderr', '.space.jsonl', '.command.json')]
            required.update(filenames)
            for filename in filenames:
                relative_file = directory.name + '/' + filename
                if (not isinstance(artifacts, dict) or relative_file not in hashes
                        or artifacts.get(filename) != hashes[relative_file]):
                    raise RuntimeError('ABI command raw artifact missing/changed: ' + filename)
            record = json.loads((directory / (label + '.command.json')).read_bytes())
            expected_record = {**expected, 'schema': 'alpbahOS.abi-command/v1', 'label': label,
                               **{k: binding[k] for k in ('run_id', 'guest_boot_id', 'handoff_sha256')},
                               'exit': 0, 'errors': []}
            if any(record.get(k) != v for k, v in expected_record.items()):
                raise RuntimeError('ABI command execution/argv/input/boot evidence changed: ' + label)
            times = ('started_at_ns', 'ended_at_ns', 'started_monotonic_ns', 'ended_monotonic_ns')
            if any(type(record.get(k)) is not int or record[k] <= 0 for k in times):
                raise RuntimeError('ABI command time evidence invalid')
            wall = record['ended_at_ns'] - record['started_at_ns']
            elapsed = record['ended_monotonic_ns'] - record['started_monotonic_ns']
            if wall <= 0 or elapsed <= 0 or abs(wall - elapsed) > 2_000_000_000:
                raise RuntimeError('ABI command wall/monotonic time drift')
            telemetry = [json.loads(line) for line in (directory / (label + '.space.jsonl')).read_text().splitlines()]
            if (len(telemetry) < 3 or telemetry[0].get('event') != 'before-command'
                    or telemetry[1].get('event') != 'command-started'
                    or telemetry[-1].get('event') != 'after-command'
                    or telemetry[1].get('argv') != expected['argv']
                    or type(telemetry[1].get('pid')) is not int or telemetry[1]['pid'] <= 0
                    or any(s.get('event') != 'command-running' for s in telemetry[2:-1])):
                raise RuntimeError('ABI command space telemetry lifecycle incomplete')
            samples = [telemetry[0], *telemetry[2:]]
            previous = None
            for sample in samples:
                check_space(previous, sample)
                timestamp = sample.get('time_ns')
                if (type(timestamp) is not int or not record['started_at_ns'] <= timestamp <= record['ended_at_ns']
                        or (previous and not 0 <= timestamp - previous['time_ns'] <= 10_000_000_000)):
                    raise RuntimeError('ABI command space telemetry time/gap invalid')
                previous = sample
            if (samples[0]['time_ns'] - record['started_at_ns'] > 5_000_000_000
                    or record['ended_at_ns'] - samples[-1]['time_ns'] > 5_000_000_000):
                raise RuntimeError('ABI command space telemetry start/end coverage missing')
            return ((directory / (label + '.stdout')).read_text(), (directory / (label + '.stderr')).read_text())

        listing, _ = command('multilib', [compiler, '-print-multi-lib'])
        lines = listing.strip().splitlines()
        if len(lines) != 2 or any(';' not in s for s in lines) or {s.partition(';')[2] for s in lines} != {'', '@m32'}:
            raise RuntimeError('ABI compiler multilib listing differs; x32 forbidden')
        for abi, measured in zip(abis, value['rows']):
            _, _, interpreter, libdir, owner = ABIS[abi]
            flag = '-' + abi
            if measured.get('language') != language:
                raise RuntimeError('ABI probe language changed')
            saved = abi + '.elf'; required.add(saved)
            if directory.name + '/' + saved not in hashes or artifacts.get(saved) != hashes[directory.name + '/' + saved]:
                raise RuntimeError('ABI actual ELF artifact missing/changed')
            identity = elf_identity(directory / saved, abi)
            if measured.get('elf') != identity:
                raise RuntimeError('ABI actual ELF identity differs from report')
            sysroot, _ = command(abi + '-sysroot', [compiler, flag, '-print-sysroot'])
            if sysroot.strip() != '/srv/lfs':
                raise RuntimeError('ABI raw compiler sysroot changed')
            linker, _ = command(abi + '-linker', [compiler, flag, '-print-prog-name=ld'])
            payload.file(linker.strip(), {'binutils-pass1'}, 'tools')
            startfiles = {}
            for filename in ('Scrt1.o', 'crti.o', 'crtn.o'):
                output, _ = command(abi + '-' + filename, [compiler, flag, '-print-file-name=' + filename])
                startfiles[filename] = payload.file(output.strip(), {owner}, libdir)
            libc = payload.file('/srv/lfs/' + libdir + '/libc.so.6', {owner}, libdir)
            loader = payload.file('/srv/lfs' + interpreter, {owner}, libdir)
            stdlib = None
            if language == 'c++':
                output, _ = command(abi + '-libstdcxx', [compiler, flag, '-print-file-name=libstdc++.so'])
                stdlib = payload.file(output.strip(), {'libstdcxx-cross'}, libdir)
            if any(measured.get(k) != v for k, v in {'startfiles': startfiles, 'libc': libc, 'loader': loader, 'libstdcxx': stdlib}.items()):
                raise RuntimeError('ABI raw CRT/libc/loader/C++ selection differs from report')
            work = '/srv/lfs/build/' + directory.name + '-' + abi
            stdout, stderr = command(abi + '-compile', [compiler, flag, '-x', language, '-', '-O2', '-g0',
                '-ffile-prefix-map=' + work + '=/usr/src/alp-abi-probe', '-v', '-Wl,--verbose', '-o', 'probe'],
                cwd=work, input=probe_source(language))
            trace = parse_trace(stdout, stderr)
            if measured.get('trace') != trace or '/srv/lfs/usr/include' not in trace['header_search']:
                raise RuntimeError('ABI actual compiler/linker trace differs or sysroot headers absent')
            for header in trace['header_search']:
                if not header.startswith('/srv/lfs/'):
                    raise RuntimeError('ABI compiler searched host headers')
                key = payload.resolve(header[len('/srv/lfs/'):])
                if payload.canonical.get(key, {}).get('type') != 'directory':
                    raise RuntimeError('ABI header search directory not in observed payload')
            if any(not raw.startswith('=') for raw in trace['linker_search']):
                raise RuntimeError('ABI linker searched host directories')
            selected = {payload.file(raw, {'gcc-pass1', 'glibc-cross-m64', 'glibc-cross-m32', 'libstdcxx-cross'})
                        for raw in trace['selected_inputs']}
            if not set(startfiles.values()) | {libc} | ({stdlib} if stdlib else set()) <= selected:
                raise RuntimeError('ABI actual linker omitted target CRT/libc/C++ inputs')
            dynamic, _ = command(abi + '-dynamic', ['/usr/bin/readelf', '-d', '--wide', work + '/probe'])
            if re.search(r'\((?:RPATH|RUNPATH)\)', dynamic):
                raise RuntimeError('ABI actual dynamic output has runtime search path')
        if (not isinstance(artifacts, dict) or set(artifacts) != required
                or {Path(k).name for k in hashes if Path(k).parent == Path(directory.name)} != required | {'summary.json'}
                or artifacts.get('commands.jsonl') != hashes.get(directory.name + '/commands.jsonl')):
            raise RuntimeError('ABI exact command/artifact coverage changed')
        actual_commands = [json.loads(line) for line in (directory / 'commands.jsonl').read_text().splitlines()]
        if actual_commands != commands:
            raise RuntimeError('ABI raw command ordering/coverage differs')
        results.append({'stage': stage, 'summary_sha256': row['summary_sha256'], 'abis': list(abis)})
    if file_hashes(root) != hashes:
        raise RuntimeError('ABI collection changed during verification')
    return {**proof, 'schema': 'alpbahOS.toolchain-guest-evidence/v1', 'result': 'VERIFIED_GUEST_BYTES',
            'abi': results, 'scope': 'received package/DB/payload/ABI evidence only; host/monitor/stage acceptance still required'}


def verify(root, repo, inputs, capsule_raw, authorization, guest_boot_id):
    """Single read-only entry point; authority stays with the stage controller."""
    proof, payload = verify_packages(root, repo, inputs, capsule_raw, authorization, guest_boot_id)
    result = verify_abi(root, proof, payload, proof['source_date_epoch'])
    if (sha(Path(repo) / 'manifests/infra-sources.json') != inputs['sources_sha256']
            or fingerprint(canonical_plan(Path(repo))) != proof['plan_sha256']):
        raise RuntimeError('Toolchain canonical inputs changed across ABI verification')
    return result
