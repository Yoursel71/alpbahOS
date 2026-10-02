#!/usr/bin/env bash
set -euo pipefail
umask 022
source /opt/alp-infra/scripts/infra/guest-guard.sh
guest_guard
[[ $# == 2 && $1 =~ ^(glibc|binutils|gcc)$ ]] || die 'Test package not allowlisted.'
# The root guest orchestrator retains fd9. The monitored make child is lfs.
# No host invocation, mount or chroot is performed by this entry point.
exec python3 /opt/alp-infra/scripts/infra/guest_tests.py "$@"
