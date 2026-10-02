#!/usr/bin/env bash
set -euo pipefail
umask 022
source /opt/alp-infra/scripts/infra/guest-guard.sh
guest_guard
[[ $# == 2 && $1 =~ ^(glibc|binutils|gcc)$ ]] || die 'Test package not allowlisted.'
readonly package=$1 build=$2
[[ $build == /srv/lfs/build/* && $(realpath -e "$build") == "$build" && ! -L $build ]] || die 'Unsafe test build directory.'
python3 - <<'PY'
import sys
sys.path.insert(0, '/opt/alp-infra/scripts/infra')
from package_stage import heavy_recipe_guard
heavy_recipe_guard({'phase': 'toolchain', 'abi': 'multilib-m32'})
PY
flock -u 9
exec 9<&-
readonly unit="alp-check-$package-$(date +%s%N)"
systemd-run --unit="$unit" --property=User=root --property=Type=exec \
    --property=MemoryMax=8G --property=OOMPolicy=stop \
    --property=TimeoutStartSec=infinity --property=RuntimeMaxSec=infinity \
    --property=KillMode=control-group \
    --property=StandardOutput=journal --property=StandardError=journal \
    /bin/bash /opt/alp-infra/scripts/infra/guest-test-worker.sh "$package" "$build"
printf 'Background unit: %s; journalctl -u %s; results=/srv/lfs/results/toolchain-tests\n' "$unit" "$unit"
