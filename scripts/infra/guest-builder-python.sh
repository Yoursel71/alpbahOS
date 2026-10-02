#!/usr/bin/env bash
set -euo pipefail
umask 022
source /opt/alp-infra/scripts/infra/guest-guard.sh
guest_guard
readonly archive=/srv/infra/cpython-3.13.7+20250918-x86_64-unknown-linux-gnu-install_only.tar.gz
readonly expected=0a01bad99fd4a165a11335c29eb43015dfdb8bd5ba8e305538ebb54f3bf3146d
printf '%s  %s\n' "$expected" "$archive" | sha256sum -c -
[[ ! -e /opt/alp-builder-python ]] || die 'Builder runtime exists; do not overwrite it.'
mkdir -m 0755 /opt/alp-builder-python
tar -xf "$archive" --strip-components=1 -C /opt/alp-builder-python
/opt/alp-builder-python/bin/python3 -c 'import sys,tarfile; assert hasattr(tarfile,"data_filter"); print(sys.version); print("safe tar data filter available")'
sha256sum /opt/alp-builder-python/bin/python3.13 > /srv/infra/builder-python.sha256
cat /srv/infra/builder-python.sha256
