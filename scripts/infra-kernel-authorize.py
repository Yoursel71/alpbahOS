#!/usr/bin/env python3
"""Single-use accepted-Base authorization delivery inside the guarded Builder.

The future host controller must recompute Base/audit/checkpoint acceptance and
measure the current guest boot before sending this bounded payload over SSH.
This transport cannot issue host acceptance, launch a VM or start compilation.
"""
import hashlib
import importlib.util
import json
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('kernel_handoff_build', REPO / 'scripts/infra-kernel-build.py')
kernel = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(kernel)
INFRA = Path('/srv/infra')
LFS = Path('/srv/lfs')
BOOT = Path('/proc/sys/kernel/random/boot_id')
MAX_BYTES = 2 * 1024 * 1024


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def decode(raw):
    if not isinstance(raw, bytes) or len(raw) > MAX_BYTES:
        raise RuntimeError('Kernel handoff exceeds bounded transport size')
    value = json.loads(raw)
    if (not isinstance(value, dict) or set(value) != {'base_raw', 'parent_raw', 'authorization'}
            or not isinstance(value['base_raw'], str) or not isinstance(value['parent_raw'], str)
            or not isinstance(value['authorization'], dict)):
        raise RuntimeError('Kernel handoff transport schema invalid')
    proof_raw, parent_raw = value['base_raw'].encode(), value['parent_raw'].encode()
    proof, parent = json.loads(proof_raw), json.loads(parent_raw)
    if not isinstance(proof, dict) or not isinstance(parent, dict):
        raise RuntimeError('Kernel parent/Base evidence must be objects')
    return proof_raw, proof, parent_raw, parent, value['authorization']


def deliver(raw, current, proof_raw, parent_raw, auth_raw):
    """Validated records only; guard again before each write, auth last.

    Caller holds the guest lock and has rehashed the installed Base. Durable
    attempts/completion receipt make partial and replayed delivery fail closed.
    This internal function has no CLI or arbitrary destination arguments.
    """
    guard = kernel.package_install.guest_install_guard
    records = ((INFRA / 'kernel-base-acceptance.json', proof_raw),
               (INFRA / 'kernel-parent.json', parent_raw),
               (INFRA / 'kernel-build-authorization.json', auth_raw))
    guard(LFS, LFS / 'results/handoff')
    kernel.guest_handoff.directory(INFRA)
    for path, _ in records:
        kernel.guest_handoff.existing(path)
        if os.path.lexists(path):
            raise RuntimeError('Existing kernel handoff preserved; restore accepted Base')
    store = INFRA / 'kernel-handoffs'
    if not store.exists():
        store.mkdir(mode=0o700)
        fd = os.open(INFRA, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    kernel.guest_handoff.directory(store)
    if store.stat().st_mode & 0o077:
        raise RuntimeError('Kernel handoff store must be private')
    run_id = current['run_id']
    kernel.guest_handoff.exclusive(store / (run_id + '.attempt.json'), kernel.guest_handoff.encoded({
        'schema': 'alpbahOS.kernel-handoff-attempt/v1', 'run_id': run_id,
        'payload_sha256': digest(raw), 'authorization_sha256': digest(auth_raw)}))
    # A crash at any write leaves records/marker protected. The producer also
    # requires the completed receipt, so even an auth-last crash cannot run.
    for path, contents in records:
        guard(LFS, LFS / 'results/handoff')
        kernel.guest_handoff.exclusive(path, contents)
    for path, contents in records:
        actual, _ = kernel.read_record(path)
        if actual != contents:
            raise RuntimeError('Kernel delivered bytes changed; preserve attempt')
    response = {'schema': 'alpbahOS.kernel-handoff-response/v1', 'result': 'HANDOFF_BOUND',
                'run_id': run_id, 'host_boot_id': current['host_boot_id'],
                'guest_boot_id': current['guest_boot_id'],
                'base_acceptance_sha256': digest(proof_raw), 'parent_sha256': digest(parent_raw),
                'authorization_sha256': digest(auth_raw), 'payload_sha256': digest(raw),
                'helper_sha256': current['helper_sha256']}
    encoded = kernel.guest_handoff.encoded(response)
    kernel.completed_handoff(encoded, current, auth_raw)
    guard(LFS, LFS / 'results/handoff')
    kernel.guest_handoff.exclusive(store / (run_id + '.completed.json'), encoded)
    return response


def install(raw):
    if os.geteuid() != 0:
        raise RuntimeError('Kernel handoff requires guarded guest root; host invocation refused')
    kernel.package_install.guest_install_guard(LFS, LFS / 'results/handoff')
    if REPO != Path('/opt/alp-infra') or kernel.REPO != REPO:
        raise RuntimeError('Kernel handoff requires guarded Builder repository')
    proof_raw, proof, parent_raw, parent, auth = decode(raw)
    inputs_raw, inputs = kernel.read_record(INFRA / 'inputs.json')
    sources_raw, sources = kernel.read_record(REPO / 'manifests/infra-sources.json')
    hashes = {}
    for name in kernel.HELPERS:
        path = REPO / 'scripts' / name
        kernel.guest_handoff.existing(path)
        hashes[name] = kernel.sha(path)
    current = kernel.binding(auth, proof, parent, inputs, BOOT.read_text().strip(),
                             hashes, digest(proof_raw), digest(parent_raw))
    if (inputs['inputs_sha256'] != kernel.buildctl.inputs_digest()
            or inputs['sources_sha256'] != digest(sources_raw)
            or sources.get('abi_selection', {}).get('mode') != 'multilib-m32'):
        raise RuntimeError('Kernel delivery current source/input/ABI differs')
    kernel.base_payload(proof, kernel.base_plan.load(REPO))
    if ((INFRA / 'inputs.json').read_bytes() != inputs_raw
            or (REPO / 'manifests/infra-sources.json').read_bytes() != sources_raw
            or {name: kernel.sha(REPO / 'scripts' / name) for name in kernel.HELPERS} != hashes):
        raise RuntimeError('Kernel delivery input/helper drift before writes')
    # The accepted Base contains results/base, not necessarily results/kernel.
    # Create only this exact evidence parent after all parent validation.
    results = LFS / 'results'
    kernel.guest_handoff.directory(results)
    target = results / 'kernel'
    if not os.path.lexists(target):
        target.mkdir(mode=0o700)
        fd = os.open(results, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    kernel.guest_handoff.directory(target)
    return deliver(raw, current, proof_raw, parent_raw, kernel.guest_handoff.encoded(auth))


if __name__ == '__main__':
    try:
        if len(sys.argv) != 1:
            raise RuntimeError('No kernel handoff bypass/resume flags accepted')
        print(json.dumps(install(sys.stdin.buffer.read(MAX_BYTES + 1)), sort_keys=True))
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        raise SystemExit('STOP: ' + str(error))
