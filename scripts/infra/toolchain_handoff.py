"""Read-only preparation of a stability parent capsule for a future runner.

Caller holds the controller lock and validates current Phase1/input pins.
Prepare runs before launch; bind_guest runs after the runner measures boot.
The runner must preserve/hash-pin the prepared bytes in its private job.
No OC authorization, VM launch, SSH transfer or toolchain execution happens
here. The complete toolchain stage runner/root-before gate is still separate.
"""
import json
import checkpoint_store
import host_stage_audit as audit
import stage_acceptance
import stage_runs
from handoff_binding import SCHEMA, KEYS, valid

PARENT_SCHEMA = 'alpbahOS.toolchain-parent/v1'


def prepare(value, run_sha256, after_audit_id, sources, recipes, vm, expected_argv,
            stopped, space_guard, toolchain_run_id):
    stage_runs.identity(toolchain_run_id)
    if toolchain_run_id == value['run_id']:
        raise RuntimeError('Toolchain preflight requires a distinct new job identity')
    proof = stage_acceptance.verify(value, run_sha256, after_audit_id, sources, recipes,
                                   vm, expected_argv, stopped, space_guard, checkpointed=True)
    receipt_path = stage_runs.RUNS / value['run_id'] / 'acceptance.json'
    receipt_raw, receipt = stage_runs.read(receipt_path)
    if receipt.get('evidence') != proof:
        raise RuntimeError('Stability private receipt differs from recomputed parent proof')
    snapshot = checkpoint_store.inspect_accepted_checkpoint(vm, stopped, space_guard)
    if snapshot['acceptance'] != proof:
        raise RuntimeError('Stability checkpoint changed during handoff preparation; STOP')
    stopped(); space_guard()
    if stage_runs.read(receipt_path)[0] != receipt_raw:
        raise RuntimeError('Stability receipt changed during handoff preparation; STOP')
    capsule = {'schema': PARENT_SCHEMA, 'result': 'VERIFIED_PARENT', 'stage': 'toolchain',
               'mode': value['mode'], 'run_id': toolchain_run_id,
               'parent_run_id': value['run_id'], 'host_boot_id': value['boot_id'],
               'inputs_sha256': value['inputs_sha256'], 'sources_sha256': value['sources_sha256'],
               'parent_receipt_sha256': audit.digest(receipt_raw),
               'parent_proof_sha256': audit.digest(json.dumps(proof, sort_keys=True, separators=(',', ':')).encode()),
               'checkpoint_sha256': snapshot['checkpoint_sha256'],
               'transaction_sha256': snapshot['transaction_sha256'],
               'active_overlay_sha256': {k: v['sha256'] for k, v in snapshot['active_overlays'].items()}}
    return (json.dumps(capsule, sort_keys=True, indent=2) + '\n').encode()


def bind_guest(parent_raw, parent_sha256, toolchain_run_id, guest_boot_id):
    """Format a pinned preflight for transport; this grants no OC permission.

    Parent bytes must be the runner's immutable pre-launch prepare output.
    Rehashing fresh disks after boot would reject legitimate guest writes.
    The future runner must enforce root-before and that pin across launch.
    """
    parent = json.loads(parent_raw)
    stage_runs.identity(toolchain_run_id)
    if (not valid(parent_sha256, '[0-9a-f]{64}') or audit.digest(parent_raw) != parent_sha256
            or not isinstance(parent, dict) or set(parent) != KEYS - {'guest_boot_id'}
            or parent.get('schema') != PARENT_SCHEMA or parent.get('result') != 'VERIFIED_PARENT'
            or parent.get('run_id') != toolchain_run_id
            or parent.get('host_boot_id') != audit.BOOT.read_text().strip()
            or toolchain_run_id == parent.get('parent_run_id') or not valid(guest_boot_id,
                r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
            or guest_boot_id == parent['host_boot_id']):
        raise RuntimeError('Toolchain binding needs current pinned parent/distinct job/guest boot')
    capsule = {**parent, 'schema': SCHEMA, 'run_id': toolchain_run_id, 'guest_boot_id': guest_boot_id}
    return (json.dumps(capsule, sort_keys=True, indent=2) + '\n').encode()
