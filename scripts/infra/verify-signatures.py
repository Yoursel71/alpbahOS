#!/usr/bin/env python3
"""Offline verification of the four pinned toolchain/kernel signatures."""
import hashlib
import json
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DATA = Path('/mnt/alpbahOS-data/alpbahos-infra-rebuild')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def main():
    m = json.loads((REPO / 'manifests/infra-sources.json').read_text())
    trust = {key['id']: key for key in m['trust_keys']}
    for key in trust.values():
        if sha(DATA / 'cache' / key['filename']) != key['sha256']:
            raise SystemExit('STOP: public keyring hash changed')
    results = []
    for record in m['sources']:
        sig = record.get('signature')
        if not sig:
            continue
        cache = DATA / 'cache'
        if sha(cache / record['filename']) != record['sha256'] or sha(cache / sig['filename']) != sig['sha256']:
            raise SystemExit('STOP: source/signature hash changed')
        key = trust[sig['keyring']]
        argv = ['gpgv', '--status-fd', '1', '--keyring', str(cache / key['filename']), str(cache / sig['filename'])]
        decompressor = None
        if sig['signed_content'] == 'decompressed tar':
            decompressor = subprocess.Popen(['xz', '-cd', str(cache / record['filename'])], stdout=subprocess.PIPE)
            result = subprocess.run(argv + ['-'], stdin=decompressor.stdout, capture_output=True, text=True)
            decompressor.stdout.close()
            if decompressor.wait() != 0:
                raise SystemExit('STOP: source decompression failed')
        else:
            result = subprocess.run(argv + [str(cache / record['filename'])], capture_output=True, text=True)
        valid = [line.split()[2] for line in result.stdout.splitlines() if line.startswith('[GNUPG:] VALIDSIG ')]
        if result.returncode != 0 or valid != [sig['signing_fingerprint']]:
            raise SystemExit('STOP: signature or signing identity mismatch: ' + record['filename'])
        results.append({'source': record['filename'], 'validsig': valid[0], 'keyring_sha256': key['sha256']})
    output = DATA / 'logs/signature-verification.json'
    output.write_text(json.dumps(results, indent=2, sort_keys=True) + '\n')
    print(f'Signatures PASS={len(results)} log={output} sha256={sha(output)}')


if __name__ == '__main__':
    main()
