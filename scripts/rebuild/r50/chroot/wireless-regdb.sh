#!/bin/bash
# wireless-regdb (kernel.org wens tree, snapshot master-2026-09-03): only data. regulatory.db and its signature go to
# /usr/lib/firmware, where the kernel's cfg80211 looks for them (/lib/firmware is a symlink to /usr/lib/firmware here).
set -e
install -d "$STAGE/usr/lib/firmware"
install -m 644 regulatory.db regulatory.db.p7s "$STAGE/usr/lib/firmware/"
install -d "$STAGE/usr/share/doc/wireless-regdb"
install -m 644 LICENSE "$STAGE/usr/share/doc/wireless-regdb/" 2>/dev/null || true
