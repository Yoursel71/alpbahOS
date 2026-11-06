#!/usr/bin/env bash
set -Eeuo pipefail
export ALPBAHOS_D34_PACKAGE=kwindowsystem
export ALPBAHOS_D34_KWINDOWSYSTEM_X11=1
exec /bin/bash "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build-blfs-kf6-package-d34.sh" "$@"
