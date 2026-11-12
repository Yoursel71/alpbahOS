#!/bin/bash
# DRIVERS-01 (round 43): Intel Sound Open Firmware. Most Intel laptops since about 2019 (Ice Lake, Tiger Lake, Alder
# Lake, Meteor Lake and later; DMIC microphones) have no audio without it, and it is not part of linux-firmware.
# sof-bin 2026.09.2 (github.com/thesofproject/sof-bin release; sha256 = GitHub's asset digest, sha512 = Fedora's
# alsa-sof-firmware sources), the upstream install.sh layout: the firmware and topology directories under
# /usr/lib/firmware/intel/ (links kept as links), no tools. Record sof-firmware 2026.09.2. Run as root.
set -euo pipefail
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
T=$SB/apps01-src/drivers/sof-bin-2026.09.2.tar.gz
[ "$(sha256sum < "$T" | cut -c1-64)" = 5f7bc30b2b5c1e6b0da55a33fc44e2b7f56ae9b06952edcde614f51ef6b943e1 ] || { echo "sha256 mismatch"; exit 1; }
[ "$(sha512sum < "$T" | cut -c1-128)" = 016c3ba08fb73553fa581e8ce7b9c19ceb5b0575d79d50da46b158a4a3e71ac4a30eba6914fe45f9264f56bd9541453e319dbfe01a5fc57f3e7650f624be8f9f ] || { echo "sha512 != Fedora"; exit 1; }
W=$SB/r43/sof; ST=$W/stage
rm -rf "$W" && mkdir -p "$W" "$ST/usr/lib/firmware/intel" "$ST/usr/share/licenses/sof-firmware"
tar -xzf "$T" -C "$W"
S=$W/sof-bin-2026.09.2
for d in sof sof-tplg sof-ipc4 sof-ipc4-lib sof-ipc4-tplg sof-ace-tplg; do
    [ -e "$S/$d" ] || [ -L "$S/$d" ] || continue
    cp -a "$S/$d" "$ST/usr/lib/firmware/intel/"
done
install -m 644 "$S/LICENCE.Intel" "$S/LICENCE.NXP" "$S/Notice.NXP" "$S/README.Intel" "$ST/usr/share/licenses/sof-firmware/"
find "$ST" -type f -exec chmod 644 {} +; find "$ST" -type d -exec chmod 755 {} +
chown -R root:root "$ST"
echo "staged: $(find "$ST" -type f | wc -l) files, $(find "$ST" -type l | wc -l) links, $(du -sh "$ST" | cut -f1)"
cd "$WT"
bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py sof-firmware 2026.09.2 "$ST" sof-firmware 2026.09.2
ls "$SB/r4-root/usr/lib/firmware/intel/" | grep sof
