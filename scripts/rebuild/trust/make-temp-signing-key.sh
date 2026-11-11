#!/bin/bash
# ALP-TRUST-01 step 3: TEMPORARY catalog signing keys for build and test images (host, ordinary user or root).
#
# THESE ARE NOT THE RELEASE KEYS. They sit unprotected (no passphrase) on the build host so that images can be built
# and tested. Where the real signing key lives (hardware token or offline machine) and who holds the backup key is
# the user's decision (D173); before any release the keys made here must be replaced and their fingerprints taken
# out of allowed.txt.
#
# Makes, once, under scratch-lfs-bench/alp-signing/ (mode 700, outside the repository, never copied into an image):
#   primary/  backup/        GnuPG homes with one Ed25519 signing key each (private keys stay here)
#   alpbahos-catalog.gpg     both PUBLIC keys (what the alp-keyring record ships)
#   allowed.txt              both primary-key fingerprints, keyring-version 1
#   FINGERPRINTS             the two fingerprints, for the records
# Usage: make-temp-signing-key.sh [DIR]     (refuses to touch an existing DIR)
set -euo pipefail
export LC_ALL=C
D=${1:-/home/yrslf/alpbahOS/scratch-lfs-bench/alp-signing}
[ ! -e "$D" ] || { echo "make-temp-signing-key: $D exists; nothing done" >&2; exit 1; }
case "$D" in *alpbahOS/wt-*|*/.git/*) echo "make-temp-signing-key: refusing a path inside a worktree" >&2; exit 1 ;; esac
umask 077
mkdir -p "$D/primary" "$D/backup"
gen() { # <home> <name>
    gpg --homedir "$1" --batch --no-tty --pinentry-mode loopback --passphrase '' \
        --quick-generate-key "$2" ed25519 sign never 2> /dev/null
    gpg --homedir "$1" --batch --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}'
}
P=$(gen "$D/primary" "alpbahOS catalog TEMPORARY build key (not for release) <temporary-build-key@alpbahos.invalid>")
K=$(gen "$D/backup" "alpbahOS catalog TEMPORARY backup key (not for release) <temporary-backup-key@alpbahos.invalid>")
{ gpg --homedir "$D/primary" --batch --export "$P"; gpg --homedir "$D/backup" --batch --export "$K"; } > "$D/alpbahos-catalog.gpg"
cat > "$D/allowed.txt" << EOF
# alpbahOS catalog signing keys. TEMPORARY BUILD KEYS, to be replaced before any release (D173).
keyring-version 1
$P
$K
EOF
printf 'primary %s\nbackup  %s\n' "$P" "$K" > "$D/FINGERPRINTS"
gpgconf --homedir "$D/primary" --kill all; gpgconf --homedir "$D/backup" --kill all
chmod 644 "$D/alpbahos-catalog.gpg" "$D/allowed.txt"
chmod 700 "$D"
cat "$D/FINGERPRINTS"
