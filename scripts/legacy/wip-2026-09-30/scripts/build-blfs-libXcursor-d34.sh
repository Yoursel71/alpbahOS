#!/usr/bin/env bash
set -Eeuo pipefail
export ALPBAHOS_D34_PACKAGE=libXcursor
exec /bin/bash "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build-blfs-x11-d34.sh" "$@"
