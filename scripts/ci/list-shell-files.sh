#!/bin/bash
# Print tracked shell scripts (*.sh or a sh/bash shebang), minus legacy and archive folders.
set -euo pipefail
git ls-files -z -- . ':!scripts/legacy' ':!tests/legacy' ':!docs/archive' |
while IFS= read -r -d '' f; do
    # Known shellcheck errors that are not one-line fixes; see
    # docs/verification/shellcheck-baseline-2026-11-10.md.
    case "$f" in
    scripts/lfs-blfs/build-cmds/packages/064-NetworkManager-1.54.0.sh | \
        scripts/lfs-blfs/build-cmds/packages/184-cups-2.4.12.sh | \
        scripts/lfs-blfs/build-cmds/packages/200-sddm-0.21.0.sh | \
        scripts/lfs-blfs/build_image7.sh) continue ;;
    esac
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    case "$f" in
    *.sh) printf '%s\n' "$f" ;;
    *) if head -n1 "$f" 2>/dev/null | LC_ALL=C grep -aqE '^#![[:space:]]*(/usr/bin/env[[:space:]]+)?(/bin/)?(ba)?sh([[:space:]]|$)'; then printf '%s\n' "$f"; fi ;;
    esac
done
