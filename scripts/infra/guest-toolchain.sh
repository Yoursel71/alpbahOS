#!/usr/bin/env bash
set -euo pipefail
umask 022
[[ $# == 0 ]] || { echo 'No toolchain bypass flags accepted'; exit 1; }
source /opt/alp-infra/scripts/infra/guest-guard.sh
guest_guard
python3 /opt/alp-infra/scripts/infra/guest_toolchain.py
