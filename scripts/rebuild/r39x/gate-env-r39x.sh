# sourced on the host: environment and resource gate for the r39x matrix rows
# copy of r39x/env.sh: environment and resource gate for the r39x rows (ISO r39 kept copy)
B=/home/yrslf/alpbahOS/scratch-lfs-bench
K=$B/keep-r39
export MROUND=r39 MATRIX_WT=/home/yrslf/alpbahOS/wt-r39x LANES_W=/home/yrslf/alpbahOS/wt-r39x/scripts/rebuild/image
export MATRIX_DIR=$B/lfs13-logs/iso-beta-0.9/r39x
export ISO_PATH=$K/alpbahos-beta-0.9-2026-11-09-r39.iso IMGB_PATH=$K/inst-bios-msdos-r39.raw IMGU_PATH=$K/inst-uefi-gpt-r39.raw
export DIAG_PWF=$B/test-secrets/r39.pw
export KF_IMG=$B/lfs13-logs/iso-beta-0.9/r39x/inst-bios-kf-r39x.raw KF_PW=$B/test-secrets/r39x-kf.pw
export F1_IMG=$B/lfs13-logs/iso-beta-0.9/r39x/inst-bios-f1-r39x.raw
M=/home/yrslf/alpbahOS/wt-r39x/scripts/rebuild/r21/matrix-r21.sh
D=$MATRIX_DIR
gate() { # gate [min-free-GiB]: total QEMU <= 2, available >= 9 GiB, /home free >= min (default 20); wait up to 90 min
  local i n a f min=${1:-20}
  for i in $(seq 1 90); do
    n=$(pgrep -c qemu-system); a=$(free -g | awk '/^Mem:/ {print $7}'); f=$(df -BG --output=avail /home | tail -1 | tr -dc 0-9)
    if [ "$n" -le 2 ] && [ "$a" -ge 9 ] && [ "$f" -ge "$min" ]; then echo "gate ok $(date +%T): qemu=$n avail=${a}G free=${f}G (min ${min}G)"; return 0; fi
    echo "gate wait $(date +%T): qemu=$n avail=${a}G free=${f}G (min ${min}G)"; sleep 60
  done; echo "gate timeout"; return 1; }
