#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

[[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]] || {
    echo 'This continuation must run inside the D34 private candidate namespace.' >&2
    exit 1
}
exec bash "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/install-lfs-gcc-ch8-resume.sh"
