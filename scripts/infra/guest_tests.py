"""Guarded background suite runner; native/chroot pipeline integration pending.

The orchestrator is root only in the isolated Builder; make runs as lfs.
This runner's PASS is limited to its supplied guest build tree and policy.
"""
import importlib.util
import json
import subprocess
import sys
import time
from pathlib import Path

from package_install import guest_install_guard
from package_stage import INFRA, LFS, REPO, heavy_recipe_guard, sha
from guest_process import run_logged

PACKAGES = ('glibc', 'binutils', 'gcc')


def write_json(path, value):
    with path.open('x') as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write('\n')


def summary_files(build):
    files = sorted(build.rglob('*.sum'))
    if any(not p.is_file() or p.is_symlink() or p.resolve() != p or build not in p.parents for p in files):
        raise RuntimeError('Unsafe suite summary path')
    return files


def run_suite(package, build):
    base = LFS / 'results/toolchain-tests'
    guest_install_guard(LFS, base)  # Host invocation fails before any write.
    heavy_recipe_guard({'phase': 'toolchain', 'abi': 'multilib-m32'})
    build = Path(build)
    if package not in PACKAGES or (LFS / 'build') not in build.parents or not build.is_dir() or build.resolve() != build:
        raise RuntimeError('Suite package/build path not allowlisted')
    if not (build / 'Makefile').is_file() or (build / 'Makefile').is_symlink():
        raise RuntimeError('Suite Makefile missing/aliased')
    if summary_files(build):
        raise RuntimeError('Existing suite summaries require a fresh build/checkpoint; never reuse or delete evidence')
    policies_path = REPO / 'manifests/infra-test-policy.json'
    if not policies_path.is_file() or policies_path.resolve() != policies_path:
        raise RuntimeError('Unsafe suite policy')
    policy = json.loads(policies_path.read_text())[package]
    policy_hash = sha(policies_path)
    inputs = json.loads((INFRA / 'inputs.json').read_text())
    sources_path = REPO / 'manifests/infra-sources.json'
    sources = json.loads(sources_path.read_text())
    if sha(sources_path) != inputs['sources_sha256']:
        raise RuntimeError('Suite source inputs changed')
    spec = importlib.util.spec_from_file_location('suite_policy', REPO / 'scripts/infra/test-policy.py')
    evaluator = importlib.util.module_from_spec(spec); spec.loader.exec_module(evaluator)
    base.mkdir(exist_ok=True)
    directory = base / f'{package}-{time.time_ns()}'
    directory.mkdir()  # Exclusive new directory; previous evidence stays intact.
    binding = {'package': package, 'build': str(build), 'inputs_sha256': inputs['inputs_sha256'],
               'sources_sha256': inputs['sources_sha256'], 'policy_sha256': policy_hash,
               'source_date_epoch': sources['source_date_epoch'], 'makefile_sha256': sha(build / 'Makefile')}
    write_json(directory / 'started.json', {**binding, 'time_ns': time.time_ns()})
    env = {'PATH': '/usr/bin:/bin:/usr/sbin:/sbin', 'LC_ALL': 'C', 'LANG': 'C', 'TZ': 'UTC',
           'SOURCE_DATE_EPOCH': str(sources['source_date_epoch'])}
    argv = ['runuser', '-u', 'lfs', '--', 'env', '-i', 'HOME=/home/lfs',
            'PATH=' + str(LFS / 'tools/bin') + ':/usr/bin:/bin',
            'LC_ALL=C', 'LANG=C', 'TZ=UTC', 'SOURCE_DATE_EPOCH=' + str(sources['source_date_epoch']),
            'make', '-j2', '-k', 'check']
    errors, code, result = [], None, None
    try:
        try:
            run_logged(argv, directory / 'make-check.log', cwd=build, env=env)
            code = 0
        except subprocess.CalledProcessError as error:
            code = error.returncode  # Policy decides completed known FAILs only.
        (directory / 'make-exit').write_text(str(code) + '\n')
        guest_install_guard(LFS, directory)
        heavy_recipe_guard({'phase': 'toolchain', 'abi': 'multilib-m32'})
        if (json.loads((INFRA / 'inputs.json').read_text()) != inputs or sha(policies_path) != policy_hash
                or sha(build / 'Makefile') != binding['makefile_sha256']):
            raise RuntimeError('Suite inputs/policy/Makefile changed during command')
        files = summary_files(build)
        raw = directory / 'summaries'; raw.mkdir()
        saved = []
        for path in files:
            copy = raw / path.relative_to(build)
            copy.parent.mkdir(parents=True, exist_ok=True)
            with copy.open('xb') as stream:
                stream.write(path.read_bytes())
            if sha(copy) != sha(path):
                raise RuntimeError('Suite summary changed during evidence collection')
            saved.append(copy)
        result = evaluator.evaluate(package, saved, code, policy)
        result['summary_sha256'] = {str(p.relative_to(raw)): sha(p) for p in saved}
        write_json(directory / 'policy.json', result)
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        errors.append(repr(error))
    artifacts = {str(p.relative_to(directory)): sha(p) for p in directory.rglob('*') if p.is_file() and not p.is_symlink()}
    outcome = {**binding, 'result': 'PASS' if not errors and result and result['accepted'] else 'FAIL',
               'make_exit': code, 'errors': errors, 'artifacts_sha256': artifacts,
               'time_ns': time.time_ns(), 'scope': 'guest build-tree suite only; native/chroot/host acceptance required'}
    write_json(directory / 'outcome.json', outcome)
    return directory, outcome


def main():
    if len(sys.argv) != 3:
        raise RuntimeError('Usage: guest_tests.py <glibc|binutils|gcc> <dedicated build directory>')
    directory, outcome = run_suite(sys.argv[1], sys.argv[2])
    print(json.dumps({'directory': str(directory), **outcome}, sort_keys=True))
    return 0 if outcome['result'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
