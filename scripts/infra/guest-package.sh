#!/usr/bin/env bash
set -euo pipefail
umask 022
source /opt/alp-infra/scripts/infra/guest-guard.sh
guest_guard
[[ ${1:-} == zlib-smoke && $# == 1 ]] || die 'Recipe not allowlisted.'
mkdir -p "$LFS/results/zlib-smoke"
bash /opt/alp-infra/scripts/infra/version-check.sh > "$LFS/results/zlib-smoke/version-check.log" 2>&1
python3 /opt/alp-infra/scripts/infra/guest-smoke.py
