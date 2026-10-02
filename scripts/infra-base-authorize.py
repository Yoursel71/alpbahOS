#!/usr/bin/env python3
"""Install a fresh, measured-boot base-stage authorization inside the Builder."""
import hashlib
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, '/opt/alp-infra/scripts/infra')
import guest_handoff
import handoff_binding
from package_install import guest_install_guard

INFRA = Path('/srv/infra')
LFS = Path('/srv/lfs')
BOOT = Path('/proc/sys/kernel/random/boot_id')
SOURCES = Path('/opt/alp-infra/manifests/infra-sources.json')
GUEST_RUNNER = Path('/opt/alp-infra/infra-base-guest-run.py')
HEX64 = re.compile(r'[0-9a-f]{64}')
HEX32 = re.compile(r'[0-9a-f]{32}')


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def install(payload_raw):
    if os.geteuid() != 0 or len(payload_raw) > 262144:
        raise RuntimeError('Base authorization requires guarded guest root and bounded input')
    payload = json.loads(payload_raw)
    required = {'toolchain_raw', 'toolchain_receipt', 'parent_raw', 'handoff_raw',
                'authorization', 'base_authorization', 'controller_sha256',
                'guest_runner_sha256'}
    if not isinstance(payload, dict) or set(payload) != required:
        raise RuntimeError('Base authorization payload schema invalid')
    guest_install_guard(LFS, LFS / 'results/base')
    controller = payload['controller_sha256']
    guest_runner = payload['guest_runner_sha256']
    if (not isinstance(controller, str) or not HEX64.fullmatch(controller)
            or not isinstance(guest_runner, str) or not HEX64.fullmatch(guest_runner)):
        raise RuntimeError('Base controller source pin malformed')
    if digest(GUEST_RUNNER.read_bytes()) != guest_runner:
        raise RuntimeError('Guest base runner bytes differ from controller pin')

    toolchain_raw = payload['toolchain_raw'].encode()
    toolchain = json.loads(toolchain_raw)
    receipt_raw = encoded(payload['toolchain_receipt'])
    receipt = json.loads(receipt_raw)
    parent_raw = payload['parent_raw'].encode()
    parent = json.loads(parent_raw)
    handoff_raw = payload['handoff_raw'].encode()
    handoff = json.loads(handoff_raw)
    authorization = payload['authorization']
    auth_raw = encoded(authorization)
    base = payload['base_authorization']
    base_raw = encoded(base)
    inputs_path = INFRA / 'inputs.json'
    sources_path = SOURCES
    for path in (inputs_path, sources_path, INFRA / 'phase2-authorization.json',
                 INFRA / 'stability-acceptance.json'):
        guest_handoff.existing(path)
    inputs = json.loads(inputs_path.read_bytes())
    sources = json.loads(sources_path.read_bytes())
    boot_id = BOOT.read_text().strip()
    old_auth = json.loads((INFRA / 'phase2-authorization.json').read_bytes())
    old_handoff_raw = (INFRA / 'stability-acceptance.json').read_bytes()
    old_handoff = json.loads(old_handoff_raw)

    if (not isinstance(toolchain, dict) or toolchain.get('schema') != 'alpbahOS.toolchain-acceptance/v1'
            or toolchain.get('result') != 'PASS' or toolchain.get('stage') != 'toolchain'
            or toolchain.get('mode') != 'multilib-m32'
            or digest(toolchain_raw) != receipt.get('proof_sha256')
            or {k: v for k, v in receipt.items() if k != 'proof_sha256'} != toolchain
            or receipt.get('proof_sha256') != digest(toolchain_raw)
            or receipt.get('checkpoint_sha256') != toolchain.get('checkpoint_sha256')
            or not HEX32.fullmatch(str(toolchain.get('run_id', '')))
            or digest(parent_raw) != toolchain.get('parent_sha256')
            or digest(parent_raw) != toolchain.get('parent_capsule_sha256')
            or parent.get('schema') != 'alpbahOS.toolchain-parent/v1'
            or parent.get('result') != 'VERIFIED_PARENT' or parent.get('stage') != 'toolchain'
            or parent.get('run_id') != toolchain.get('run_id')
            or parent.get('mode') != toolchain.get('mode')
            or parent.get('inputs_sha256') != inputs.get('inputs_sha256')
            or parent.get('sources_sha256') != inputs.get('sources_sha256')
            or parent.get('host_boot_id') != authorization.get('boot_id')
            or sources.get('abi_selection', {}).get('mode') != 'multilib-m32'
            or authorization.get('stage') != 'toolchain'
            or authorization.get('run_id') != toolchain.get('run_id')
            or authorization.get('guest_boot_id') != boot_id
            or authorization.get('handoff_sha256') != digest(handoff_raw)
            or authorization.get('oc_confirmed') is not True
            or any(authorization.get(k) != inputs.get(k) for k in ('inputs_sha256', 'sources_sha256'))
            or any(handoff.get(k) != parent.get(k) for k in (
                'result', 'stage', 'mode', 'run_id', 'parent_run_id', 'host_boot_id',
                'inputs_sha256', 'sources_sha256', 'parent_receipt_sha256',
                'parent_proof_sha256', 'checkpoint_sha256', 'transaction_sha256',
                'active_overlay_sha256'))
            or handoff.get('schema') != 'alpbahOS.toolchain-handoff/v1'
            or handoff.get('guest_boot_id') != boot_id):
        raise RuntimeError('Accepted toolchain, parent and measured guest handoff disagree')

    # The checkpoint contains an earlier handoff. Verify its raw pairing before
    # atomically refreshing the pair for this new guest boot.
    if (old_auth.get('stage') != 'toolchain' or old_auth.get('oc_confirmed') is not True
            or old_auth.get('run_id') != toolchain.get('run_id')
            or old_auth.get('handoff_sha256') != digest(old_handoff_raw)
            or old_handoff.get('schema') != 'alpbahOS.toolchain-handoff/v1'
            or old_handoff.get('run_id') != toolchain.get('run_id')
            or old_handoff.get('guest_boot_id') != old_auth.get('guest_boot_id')):
        raise RuntimeError('Checkpoint handoff bytes are not a valid prior paired record')
    handoff_binding.validate(handoff_raw, authorization, inputs, boot_id)
    if (base.get('schema') != 'alpbahOS.base-authorization/v1'
            or base.get('result') != 'AUTHORIZED' or base.get('stage') != 'base'
            or base.get('mode') != 'multilib-m32' or base.get('oc_confirmed') is not True
            or base.get('guest_boot_id') != boot_id
            or base.get('phase2_authorization_sha256') != digest(auth_raw)
            or base.get('stability_acceptance_sha256') != digest(handoff_raw)
            or base.get('toolchain_acceptance_sha256') != digest(receipt_raw)
            or base.get('controller_sha256') != controller
            or base.get('guest_runner_sha256') != guest_runner
            or base.get('inputs_sha256') != inputs.get('inputs_sha256')
            or base.get('sources_sha256') != inputs.get('sources_sha256')
            or not HEX32.fullmatch(str(base.get('run_id', '')))
            or type(base.get('authorized_at_ns')) is not int or base['authorized_at_ns'] <= 0):
        raise RuntimeError('Base authorization does not bind current accepted receipts')

    acceptance_path = INFRA / 'toolchain-acceptance.json'
    base_path = INFRA / 'base-authorization.json'
    guest_handoff.existing(acceptance_path)
    guest_handoff.existing(base_path)
    if acceptance_path.exists() or base_path.exists():
        raise RuntimeError('Existing base-stage authorization preserved; restore checkpoint')
    # Install the accepted evidence and base token first. Authorization is last,
    # so an interrupted refresh cannot leave a runnable, partially bound stage.
    guest_handoff.exclusive(acceptance_path, receipt_raw)
    guest_handoff.replace(INFRA / 'stability-acceptance.json', handoff_raw)
    guest_handoff.replace(INFRA / 'phase2-authorization.json', auth_raw)
    guest_handoff.exclusive(base_path, base_raw)
    return {'schema': 'alpbahOS.base-authorization-install/v1', 'result': 'INSTALLED',
            'run_id': base['run_id'], 'guest_boot_id': boot_id,
            'guest_runner_sha256': guest_runner,
            'toolchain_acceptance_sha256': digest(receipt_raw),
            'handoff_sha256': digest(handoff_raw), 'base_authorization_sha256': digest(base_raw)}


if __name__ == '__main__':
    try:
        print(json.dumps(install(sys.stdin.buffer.read(262145)), sort_keys=True))
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        print('STOP: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
