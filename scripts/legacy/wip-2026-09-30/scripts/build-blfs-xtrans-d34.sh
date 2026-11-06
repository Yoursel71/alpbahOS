#!/usr/bin/env bash
set -Eeuo pipefail
exec /bin/bash "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build-blfs-x11-d34.sh"
