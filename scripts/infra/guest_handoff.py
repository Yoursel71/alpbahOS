"""Bounded, single-use capsule/auth delivery under the guest writer lock.

No package, source, Alp DB or host settings are changed. The guarded shell
wrapper and guest_install_guard require the dedicated QEMU/KVM LFS disk.
"""
import hashlib
import json
import os
import secrets
import stat
import sys
from pathlib import Path
import handoff_binding
from package_install import guest_install_guard

INFRA = Path('/srv/infra')
REPO = Path('/opt/alp-infra')
LFS = Path('/srv/lfs')
BOOT = Path('/proc/sys/kernel/random/boot_id')
MAX_BYTES = 65536


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def directory(path):
    value = path.stat()
    if (path.resolve() != path or path.is_symlink() or not path.is_dir()
            or value.st_uid != os.getuid() or value.st_mode & 0o022):
        raise RuntimeError('Guest handoff directory owner/alias/write permissions invalid')


def existing(path):
    if path.exists() or path.is_symlink():
        value = path.lstat()
        if (path.resolve() != path or not stat.S_ISREG(value.st_mode) or value.st_nlink != 1
                or value.st_uid != os.getuid() or value.st_mode & 0o022):
            raise RuntimeError('Guest handoff record alias/type/owner/write permission invalid')


def exclusive(path, raw):
    directory(path.parent)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(raw); stream.flush(); os.fsync(stream.fileno())
    parent = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try: os.fsync(parent)
    finally: os.close(parent)


def replace(path, raw):
    existing(path)
    pending = path.with_name(path.name + '.pending-' + secrets.token_hex(16))
    exclusive(pending, raw)
    existing(path)
    pending.replace(path)
    parent = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try: os.fsync(parent)
    finally: os.close(parent)


def install(raw):
    if os.geteuid() != 0:
        raise RuntimeError('Handoff requires guarded guest root; host invocation refused')
    guest_install_guard(LFS, LFS / 'results/handoff')
    directory(INFRA)
    if not isinstance(raw, bytes) or len(raw) > MAX_BYTES:
        raise RuntimeError('Guest handoff payload exceeds bounded transport size')
    payload = json.loads(raw)
    if (not isinstance(payload, dict) or set(payload) != {'capsule', 'authorization'}
            or not isinstance(payload['capsule'], str) or not isinstance(payload['authorization'], dict)):
        raise RuntimeError('Guest handoff transport schema invalid')
    for path in (INFRA / 'inputs.json', REPO / 'manifests/infra-sources.json'):
        existing(path)
    inputs = json.loads((INFRA / 'inputs.json').read_bytes())
    source_raw = (REPO / 'manifests/infra-sources.json').read_bytes()
    if (hashlib.sha256(source_raw).hexdigest() != inputs.get('sources_sha256')
            or json.loads(source_raw).get('abi_selection', {}).get('mode') != 'multilib-m32'):
        raise RuntimeError('Guest handoff current source/ABI changed before transfer')
    capsule_raw = payload['capsule'].encode()
    auth = payload['authorization']
    capsule = handoff_binding.validate(capsule_raw, auth, inputs, BOOT.read_text().strip())
    paths = (INFRA / 'stability-acceptance.json', INFRA / 'phase2-authorization.json')
    for path in paths: existing(path)
    store = INFRA / 'handoffs'
    if not store.exists(): store.mkdir(mode=0o700)
    directory(store)
    if store.stat().st_mode & 0o077:
        raise RuntimeError('Guest handoff attempts store must be private')
    marker = store / (capsule['run_id'] + '.attempt.json')
    # Never retry/overwrite a complete or partial delivery for the same job.
    exclusive(marker, encoded({'schema': 'alpbahOS.guest-handoff-attempt/v1',
                              'run_id': capsule['run_id'], 'payload_sha256': hashlib.sha256(raw).hexdigest()}))
    auth_raw = encoded(auth)
    replace(paths[0], capsule_raw)
    replace(paths[1], auth_raw)  # Authorization last; interrupted pairs fail raw SHA/nonce checks.
    if paths[0].read_bytes() != capsule_raw or paths[1].read_bytes() != auth_raw:
        raise RuntimeError('Guest handoff committed bytes changed; preserve attempt')
    handoff_binding.validate(paths[0].read_bytes(), json.loads(paths[1].read_bytes()), inputs, BOOT.read_text().strip())
    response = {'schema': 'alpbahOS.guest-handoff-response/v1', 'result': 'HANDOFF_BOUND',
                'run_id': capsule['run_id'], 'parent_run_id': capsule['parent_run_id'],
                'guest_boot_id': capsule['guest_boot_id'], 'host_boot_id': capsule['host_boot_id'],
                'inputs_sha256': capsule['inputs_sha256'], 'sources_sha256': capsule['sources_sha256'],
                'handoff_sha256': hashlib.sha256(capsule_raw).hexdigest(),
                'authorization_sha256': hashlib.sha256(auth_raw).hexdigest()}
    exclusive(store / (capsule['run_id'] + '.completed.json'), encoded(response))
    return response


def main():
    raw = sys.stdin.buffer.read(MAX_BYTES + 1)
    print(json.dumps(install(raw), sort_keys=True))


if __name__ == '__main__':
    main()
