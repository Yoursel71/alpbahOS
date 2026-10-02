#!/usr/bin/env bash
set -euo pipefail
umask 022
source /opt/alp-infra/scripts/infra/guest-guard.sh
guest_guard
[[ -f /srv/infra/phase2-authorization.json ]] || die 'Phase 2 authorization absent.'
python3 /opt/alp-infra/scripts/infra/guest-stability.py
