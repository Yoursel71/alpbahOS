#!/usr/bin/env bash
set -Eeuo pipefail
export ALPBAHOS_D34_PACKAGE=libwacom
exec /bin/bash "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build-blfs-kwin-deps-d34.sh" "$@"
