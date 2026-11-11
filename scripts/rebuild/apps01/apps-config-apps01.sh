#!/bin/bash
# APPS-01 step 4 (after Firefox, VLC and LibreOffice are recorded): two records.
#   firefox-alpbahos-config 0.9-apps01: the Turkish language pack of Firefox 153.2.0esr (tr.xpi from
#     archive.mozilla.org; SHA256SUMS signed by Mozilla Software Releases, primary key
#     14F2 6682 D091 6CDD 81E3 7B6D 61B7 B526 D98F 0353, checked with gpgv; the xpi's sha256 is in that list) in
#     distribution/extensions (installed into each new profile), and vendor prefs: UI language follows the system
#     locale (D120), no default-browser prompt (mimeapps.list already makes Firefox the default, D127).
#   hicolor-icon-cache-apps01 0.9-apps01: the hicolor icon cache regenerated with the apps' icons (takes the file
#     over from hicolor-icon-cache-r9, REPLACE=1; hicolor-cache-r8.sh makes it in a copy).
# Run as root.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
D=$SB/apps01-src/ff-tr
cd "$WT"
[ -d "$R4/usr/lib/firefox" ] || { echo "Firefox is not in r4-root"; exit 1; }
gpgv --keyring "$D/mozilla.gpg" "$D/SHA256SUMS.asc" "$D/SHA256SUMS"
want=$(awk '$2=="linux-x86_64/xpi/tr.xpi"{print $1}' "$D/SHA256SUMS")
got=$(sha256sum "$D/tr.xpi" | cut -d' ' -f1)
[ -n "$want" ] && [ "$want" = "$got" ] || { echo "tr.xpi sha256 mismatch"; exit 1; }
ST=$SB/apps01/stage-firefox-config
rm -rf "$ST" && mkdir -p "$ST/usr/lib/firefox/distribution/extensions" "$ST/usr/lib/firefox/browser/defaults/preferences"
install -m644 "$D/tr.xpi" "$ST/usr/lib/firefox/distribution/extensions/langpack-tr@firefox.mozilla.org.xpi"
cat > "$ST/usr/lib/firefox/browser/defaults/preferences/alpbahos.js" <<'EOF'
// alpbahOS vendor defaults (APPS-01). Users can change both in Firefox's settings.
// Empty string: the UI language follows the system locale (tr_TR with the Turkish language pack).
pref("intl.locale.requested", "");
// The system default browser is set in /etc/xdg/mimeapps.list.
pref("browser.shell.checkDefaultBrowser", false);
EOF
REPLACE=0 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py firefox-alpbahos-config 0.9-apps01 \
    "$ST" firefox-alpbahos-config 0.9-apps01
HC=$SB/apps01/stage-hicolor
rm -rf "$HC" && mkdir -p "$HC"
bash scripts/rebuild/r8/hicolor-cache-r8.sh "$R4" "$HC"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py hicolor-icon-cache-apps01 0.9-apps01 \
    "$HC" hicolor-icon-cache-apps01 0.9-apps01
echo "apps-config-apps01 done $(date +%T)"
