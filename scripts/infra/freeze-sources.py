#!/usr/bin/env python3
"""Freeze LFS 12.4 sources against the official book MD5, then record SHA256.

SHA256 pins the reviewed local bytes. This is not a claim that upstream signed
the SHA256: provenance records distinguish the official MD5 from local SHA256.
Never executes source content or changes the old cache.
"""
import hashlib
import json
import re
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OLD_CACHE = Path('/mnt/alpbahOS-ssd/alpbahos-builds/active/lfs-source-cache')


def get(url):
    with urllib.request.urlopen(url, timeout=60) as stream:
        return stream.read()


def digest(path, algorithm='sha256'):
    h = hashlib.new(algorithm)
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def main():
    target = REPO / 'manifests/infra-sources.json'
    if target.exists() or target.is_symlink():
        raise SystemExit('Existing source manifest preserved; update pins explicitly from verified bytes')
    base = 'https://www.linuxfromscratch.org/lfs/downloads/12.4-systemd/'
    urls = get(base + 'wget-list-systemd')
    sums = get(base + 'md5sums')
    expected = {}
    for line in sums.decode().splitlines():
        fields = line.split()
        if len(fields) == 2:
            expected[fields[1].lstrip('*')] = fields[0]
    records, excluded = [], []
    for url in urls.decode().splitlines():
        if not url.strip() or url.startswith('#'):
            continue
        name = url.rsplit('/', 1)[1]
        # The upstream wget-list includes five SysV-only extras. The 12.4
        # systemd package page and its MD5 manifest exclude those entries.
        if name not in expected:
            excluded.append({'url': url, 'reason': 'not in official systemd checksum manifest'})
            continue
        path = OLD_CACHE / name
        if path.is_symlink() or not path.is_file():
            raise SystemExit(f'No verified local archive: {name}; do not silently omit it')
        if digest(path, 'md5') != expected[name]:
            raise SystemExit(f'Official LFS MD5 mismatch: {name}')
        records.append({'id': name, 'filename': name, 'url': url,
                        'sha256': digest(path), 'size': path.stat().st_size,
                        'book': 'LFS-12.4-systemd', 'official_md5': expected[name],
                        'signature': None,
                        'provenance': 'official LFS 12.4 MD5 matched; SHA256 computed locally'})
    if {item['filename'] for item in records} != set(expected):
        raise SystemExit('Systemd source coverage incomplete')
    if {entry['url'].rsplit('/', 1)[1] for entry in excluded} != {
        'lfs-bootscripts-20250827.tar.xz', 'sysklogd-2.7.2.tar.gz',
        'sysvinit-3.14.tar.xz', 'udev-lfs-20230818.tar.xz',
        'sysvinit-3.14-consolidated-1.patch'}:
        raise SystemExit('Unexpected source list discrepancy; stop for review')
    # The builder is an immutable upstream release, not the moving latest URL.
    cloud = 'https://cloud.debian.org/images/cloud/bookworm/20260923-2610/'
    cloud_sums = get(cloud + 'SHA512SUMS').decode()
    name = 'debian-12-genericcloud-amd64-20260923-2610.qcow2'
    found = [line.split()[0] for line in cloud_sums.splitlines()
             if line.split() and line.split()[-1].lstrip('*') == name]
    if len(found) != 1 or not re.fullmatch('[0-9a-f]{128}', found[0]):
        raise SystemExit('No unique official builder checksum')
    manifest = {'schema': 'alpbahOS.sources/v1', 'book': '12.4-systemd',
                'blfs_book': '12.4-systemd', 'source_date_epoch': 1756684800,
                'book_inputs': {base + 'wget-list-systemd': hashlib.sha256(urls).hexdigest(),
                                base + 'md5sums': hashlib.sha256(sums).hexdigest()},
                'builder': {'filename': name, 'url': cloud + name,
                            'sha512': found[0], 'sha256': None,
                            'signature': None,
                            'checksum_url': cloud + 'SHA512SUMS',
                            'checksum_document_sha256': hashlib.sha256(cloud_sums.encode()).hexdigest()},
                'alp': {'git_commit': 'e7db520a5e2b513b355dbd58b77a49a45170ec46',
                        'path': 'docs/handoffs/claude/alp-prototype/alp.py',
                        'sha256': '055a416a14fbdf0bfdbe25f16ffbd563b3a47071f33a1fb8861d806cd9b4fa1a'},
                'excluded_non_systemd_entries': excluded, 'sources': records}
    target.parent.mkdir(exist_ok=True)
    target.write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    print(f'{target}: sources={len(records)} sha256={digest(target)}')


if __name__ == '__main__':
    main()
