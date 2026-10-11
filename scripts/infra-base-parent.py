"""Read-only sealed Base parent preflight for the future kernel controller.

Recomputes completed Base evidence and saved checkpoint bytes without restoring
disks or treating current failed overlays as the accepted parent's bytes.
No VM, root capture, authorization or build is launched by this entrypoint.
"""
import importlib.util
import json
import os
import stat
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'scripts/infra'))
import buildctl
import checkpoint_store
import host_stage_audit as audit
import stage_runs


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def stopped():
    if buildctl.pid() is not None:
        raise RuntimeError('Parent inspection requires stopped Builder writers')


def checkpoint(proof, name='base'):
    """Only immutable saved images/ancestors; current overlays are preserved."""
    if os.geteuid() != audit.USER_UID or name not in ('base', 'toolchain'):
        raise RuntimeError('Parent checkpoint inspection requires unprivileged fixed stage')
    vm = buildctl.VM
    stage_runs.private(vm)
    stopped(); buildctl.space_guard(); checkpoint_store.unfinished(vm)
    directory = vm / ('checkpoint-' + name)
    raw, cp = stage_runs.read(directory / 'checkpoint.json')
    tx_raw, tx = stage_runs.read(directory / 'transaction.json')
    if (proof.get('schema') != 'alpbahOS.' + name + '-acceptance/v1'
            or proof.get('stage') != name or proof.get('result') != 'PASS'
            or proof.get('mode') != 'multilib-m32'
            or cp.get('acceptance') != proof or tx.get('acceptance') != proof
            or tx.get('status') != 'COMPLETE' or tx.get('name') != name
            or any(tx.get(k) != list(checkpoint_store.DISKS) for k in ('linked', 'created', 'committed'))
            or type(tx.get('start_ns')) is not int or type(tx.get('end_ns')) is not int
            or tx['end_ns'] < tx['start_ns']
            or any(cp.get(k) != proof.get(k) or tx.get(k) != proof.get(k)
                   for k in ('inputs_sha256', 'sources_sha256'))
            or tx.get('backing_chains') != proof.get('closed_disk_chains')
            or cp.get('active_overlays') != tx.get('active_overlays')
            or set(cp.get('active_overlays', {})) != set(checkpoint_store.DISKS)):
        raise RuntimeError('Sealed parent checkpoint transaction/proof differs')
    originals = proof.get('closed_disk_chains')
    if not isinstance(originals, dict) or set(originals) != set(checkpoint_store.DISKS):
        raise RuntimeError('Sealed parent disk coverage incomplete')
    for disk in checkpoint_store.DISKS:
        stopped(); buildctl.space_guard()
        saved = directory / (disk + '.qcow2')
        identity = checkpoint_store.checked(saved, vm)
        if identity.st_nlink != 1 or stat.S_IMODE(identity.st_mode) != 0o400:
            raise RuntimeError('Sealed parent saved image is writable or aliased')
        original = originals[disk]
        if not original or original[0].get('path') != str(vm / (disk + '-active.qcow2')):
            raise RuntimeError('Sealed parent original active path differs')
        expected = [{'path': str(saved), 'sha256': original[0]['sha256']}, *original[1:]]
        if (cp.get(disk) != expected[0] or cp.get('backing_chains', {}).get(disk) != expected
                or tx.get('original_sha256', {}).get(disk) != original[0]['sha256']):
            raise RuntimeError('Sealed parent relocated path/hash differs')
        rows = json.loads(checkpoint_store.command(['qemu-img', 'info', '--output=json', '--backing-chain', saved]).stdout)
        if ([row.get('filename') for row in rows] != [row['path'] for row in expected]
                or any(row.get('format') != 'qcow2' for row in rows)):
            raise RuntimeError('Sealed parent actual backing chain differs')
        for row in expected:
            stopped()
            path = Path(row['path'])
            before = checkpoint_store.checked(path, vm)
            if before.st_nlink != 1 or stat.S_IMODE(before.st_mode) != 0o400:
                raise RuntimeError('Sealed parent ancestor writable or aliased')
            if checkpoint_store.sha(path) != row['sha256']:
                raise RuntimeError('Sealed parent image bytes changed')
            after = checkpoint_store.checked(path, vm)
            if (before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns):
                raise RuntimeError('Sealed parent image changed during inspection')
            checkpoint_store.command(['qemu-img', 'check', path])
            checked = checkpoint_store.checked(path, vm)
            if (before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) != (checked.st_ino, checked.st_size, checked.st_mtime_ns, checked.st_ctime_ns):
                raise RuntimeError('Sealed parent image changed during qcow2 check')
    stopped(); buildctl.space_guard()
    if (stage_runs.read(directory / 'checkpoint.json')[0] != raw
            or stage_runs.read(directory / 'transaction.json')[0] != tx_raw):
        raise RuntimeError('Sealed parent metadata changed during inspection')
    return {'checkpoint_sha256': audit.digest(raw), 'transaction_sha256': audit.digest(tx_raw)}


def accepted_base():
    if os.geteuid() != audit.USER_UID:
        raise RuntimeError('Base parent preflight requires unprivileged host user')
    stopped(); buildctl.space_guard()
    raw, proof = stage_runs.read(buildctl.ARTIFACTS / 'base-acceptance.json')
    if (proof.get('schema') != 'alpbahOS.base-acceptance/v1' or proof.get('result') != 'PASS'
            or proof.get('stage') != 'base' or proof.get('mode') != 'multilib-m32'
            or proof.get('inputs_sha256') != buildctl.inputs_digest()
            or proof.get('sources_sha256') != buildctl.sha(REPO / 'manifests/infra-sources.json')):
        raise RuntimeError('Current complete Base acceptance is absent or input/source differs')
    evidence = {k: v for k, v in proof.items() if k not in ('checkpoint_sha256', 'transaction_sha256')}
    if checkpoint(evidence) != {k: proof.get(k) for k in ('checkpoint_sha256', 'transaction_sha256')}:
        raise RuntimeError('Base artifact checkpoint metadata hashes differ')
    base = load('base_parent_stage', REPO / 'scripts/infra-base-stage.py')
    tool_raw, tool = stage_runs.read(buildctl.ARTIFACTS / 'toolchain-acceptance.json')
    tool_evidence = {k: v for k, v in tool.items() if k not in ('checkpoint_sha256', 'transaction_sha256')}
    if (checkpoint(tool_evidence, 'toolchain') != {k: tool.get(k) for k in ('checkpoint_sha256', 'transaction_sha256')}
            or any(tool.get(k) != proof.get(k) for k in ('inputs_sha256', 'sources_sha256'))):
        raise RuntimeError('Base original toolchain checkpoint changed')
    run_id, after_id = stage_runs.identity(proof.get('run_id')), stage_runs.identity(proof.get('after_audit_id'))
    artifacts = stage_runs.ARTIFACTS / run_id
    _, install = stage_runs.read(artifacts / 'authorization-install.json')
    _, auth = stage_runs.read(artifacts / 'authorization.json')
    plan = base.base_plan.load(REPO)
    guest = base.validate_guest_export(artifacts / 'guest-base', plan, run_id,
        proof['inputs_sha256'], proof['sources_sha256'], install['toolchain_acceptance_sha256'],
        auth['base_authorization_sha256'])
    receipt = {**tool, 'proof_sha256': audit.digest(tool_raw)}
    if install.get('toolchain_acceptance_sha256') != audit.digest(base.encoded(receipt)) or guest != proof.get('guest'):
        raise RuntimeError('Base guest export/accepted toolchain receipt changed')
    rebuilt = base.accept(run_id, after_id, plan, tool, install,
                          auth['base_authorization_sha256'], checkpointed=True)
    if rebuilt != evidence or stage_runs.read(buildctl.ARTIFACTS / 'base-acceptance.json')[0] != raw:
        raise RuntimeError('Recomputed Base parent differs from stored acceptance')
    return raw, proof


if __name__ == '__main__':
    try:
        if len(sys.argv) != 1:
            raise RuntimeError('No parent bypass/stage/path flags accepted')
        raw, proof = accepted_base()
        print(json.dumps({'result': 'VERIFIED_BASE_PARENT', 'run_id': proof['run_id'],
                          'proof_sha256': audit.digest(raw),
                          'scope': 'saved Base parent only; current launch/guest authorization separate'}, sort_keys=True))
    except (RuntimeError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        raise SystemExit('STOP: ' + str(error))
