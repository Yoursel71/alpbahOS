#!/usr/bin/env bash
set -euo pipefail
umask 077
[[ $# == 0 ]] || { echo 'No kernel authorization bypass flags accepted'; exit 1; }
source /opt/alp-infra/scripts/infra/guest-guard.sh
guest_guard
exec /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C LANG=C TZ=UTC \
    /usr/bin/python3 /opt/alp-infra/scripts/infra-kernel-authorize.py
