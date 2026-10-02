"""Guest transport binding for a host-revalidated stability parent.

SHA binding authenticates the exact capsule delivered with authorization by
the controller's SSH channel. It is not a standalone privileged certificate.
"""
import hashlib
import json
import re

SCHEMA = 'alpbahOS.toolchain-handoff/v1'
KEYS = {'schema', 'result', 'stage', 'mode', 'run_id', 'parent_run_id',
        'host_boot_id', 'guest_boot_id', 'inputs_sha256', 'sources_sha256',
        'parent_receipt_sha256', 'parent_proof_sha256', 'checkpoint_sha256',
        'transaction_sha256', 'active_overlay_sha256'}


def valid(value, pattern):
    return isinstance(value, str) and re.fullmatch(pattern, value) is not None


def validate(raw, authorization, inputs, guest_boot_id):
    receipt = json.loads(raw)
    hashes = ('inputs_sha256', 'sources_sha256', 'parent_receipt_sha256',
              'parent_proof_sha256', 'checkpoint_sha256', 'transaction_sha256')
    boot_pattern = r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    if (not isinstance(receipt, dict) or set(receipt) != KEYS
            or receipt.get('schema') != SCHEMA or receipt.get('result') != 'VERIFIED_PARENT'
            or receipt.get('stage') != 'toolchain' or receipt.get('mode') != 'multilib-m32'
            or not all(valid(receipt.get(k), '[0-9a-f]{64}') for k in hashes)
            or not all(valid(receipt.get(k), '[0-9a-f]{32}') for k in ('run_id', 'parent_run_id'))
            or receipt['run_id'] == receipt['parent_run_id']
            or not all(valid(receipt.get(k), boot_pattern) for k in ('host_boot_id', 'guest_boot_id'))
            or receipt['host_boot_id'] == receipt['guest_boot_id']
            or receipt['guest_boot_id'] != guest_boot_id):
        raise RuntimeError('Toolchain handoff schema/run/guest boot invalid')
    overlays = receipt.get('active_overlay_sha256')
    if (not isinstance(overlays, dict) or set(overlays) != {'builder', 'lfs'}
            or not all(valid(v, '[0-9a-f]{64}') for v in overlays.values())):
        raise RuntimeError('Toolchain handoff fresh disk hashes missing')
    if (authorization.get('oc_confirmed') is not True or authorization.get('stage') != 'toolchain'
            or authorization.get('run_id') != receipt['run_id']
            or authorization.get('boot_id') != receipt['host_boot_id']
            or authorization.get('guest_boot_id') != receipt['guest_boot_id']
            or authorization.get('mode') != receipt['mode']
            or authorization.get('handoff_sha256') != hashlib.sha256(raw).hexdigest()
            or any(receipt[k] != inputs.get(k) or authorization.get(k) != inputs.get(k)
                   for k in ('inputs_sha256', 'sources_sha256'))):
        raise RuntimeError('Toolchain authorization/handoff raw bytes or inputs mismatch')
    return receipt
