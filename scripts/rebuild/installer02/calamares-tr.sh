#!/bin/bash
# INSTALLER-02 (round 46): clearer Turkish status lines while the installer copies the system. Calamares 3.3.14's own
# Turkish catalogue for its Python jobs (lang/python/tr_TR/LC_MESSAGES/python.po, the image's calamares-python.mo is
# compiled from it byte for byte) says "Dosya sistemi genişletiliyor." for "Filling up filesystems." (it means
# "the file system is being enlarged") and "Açılan kurulum medyası 1/1, dışa aktarılan dosya sayısı X/Y" during the
# copy. Only the msgstr of the job titles our exec sequence shows are replaced; every other line stays upstream's.
# msgfmt runs in a chroot of r4-root (the image's gettext). Record alpbahos-calamares-tr-r46 takes
# /usr/share/locale/tr_TR/LC_MESSAGES/calamares-python.mo over from calamares (REPLACE=1). Run as root on the host.
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
R4=$SB/r4-root
T=$SB/blfs-src-13.1/calamares-3.3.14.tar.gz
W=$SB/installer02/calamares-tr
[ "$(sha256sum < "$T" | cut -c1-64)" = "$(python3 -c '
import json,sys; print(json.load(open(sys.argv[1]))["packages"]["calamares"]["source"]["sha256"])' "$R4/var/lib/alp/db.json")" ] \
    || { echo "calamares tarball differs from the recorded source"; exit 1; }
rm -rf "$W"; mkdir -p "$W" "$W/stage/usr/share/locale/tr_TR/LC_MESSAGES"
tar -xzOf "$T" calamares-3.3.14/lang/python/tr_TR/LC_MESSAGES/python.po > "$W/upstream.po"
python3 - "$W/upstream.po" "$W/alpbahos.po" << 'EOF'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
NEW = {
    "Filling up filesystems.": "Dosyalar diske kopyalanıyor.",
    "Unpacking image {}/{}, file {}/{}": "Dosyalar kopyalanıyor: görüntü {}/{}, dosya {}/{}",
    "Starting to unpack {}": "{} açılmaya başlanıyor",
    "Writing fstab.": "Disk bağlama tablosu (fstab) yazılıyor.",
    "Configure GRUB.": "GRUB yapılandırılıyor.",
    "Saving network configuration.": "Ağ ayarları kaydediliyor.",
    "Configure systemd units": "Sistem servisleri ayarlanıyor",
}
text = open(src, encoding="utf-8").read()
done = set()
def repl(m):
    msgid = m.group(1)
    if msgid in NEW:
        done.add(msgid)
        return 'msgid "%s"\nmsgstr "%s"' % (msgid, NEW[msgid])
    return m.group(0)
out = re.sub(r'msgid "((?:[^"\\]|\\.)*)"\nmsgstr "(?:[^"\\]|\\.)*"', repl, text)
missing = set(NEW) - done
if missing:
    sys.exit("not found in the catalogue: %s" % sorted(missing))
open(dst, "w", encoding="utf-8").write(out)
print("replaced %d strings" % len(done))
EOF
cp "$W/alpbahos.po" "$R4/tmp/alpbahos-calamares-tr.po"
chroot "$R4" /usr/bin/msgfmt --check-format -o /tmp/alpbahos-calamares-tr.mo /tmp/alpbahos-calamares-tr.po
mv "$R4/tmp/alpbahos-calamares-tr.mo" "$W/stage/usr/share/locale/tr_TR/LC_MESSAGES/calamares-python.mo"
rm -f "$R4/tmp/alpbahos-calamares-tr.po"
chmod 644 "$W/stage/usr/share/locale/tr_TR/LC_MESSAGES/calamares-python.mo"
diff <(msgunfmt "$R4/usr/share/locale/tr_TR/LC_MESSAGES/calamares-python.mo") \
     <(msgunfmt "$W/stage/usr/share/locale/tr_TR/LC_MESSAGES/calamares-python.mo") | grep '^[<>] msgstr' || true
cd "$WT"
REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-calamares-tr-r46 0.9-r46 \
    "$W/stage" alpbahos-calamares-tr-r46 0.9-r46
