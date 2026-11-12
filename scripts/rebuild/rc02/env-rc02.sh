# sourced on the host: environment and resource gate for the BETA-RC-02 matrix (ISO rc02)
B=/home/yrslf/alpbahOS/scratch-lfs-bench
RCD=$B/rc02
export MROUND=rc02 MATRIX_WT=/home/yrslf/alpbahOS/wt-rc02 LANES_W=/home/yrslf/alpbahOS/wt-rc02/scripts/rebuild/image
export MATRIX_DIR=$B/lfs13-logs/iso-beta-0.9/rc02/matrix OUTD=$B/lfs13-logs/iso-beta-0.9/rc02/matrix
export ISO_PATH=$RCD/alpbahos-beta-0.9-rc02-2026-11-12.iso
export IMGB_PATH=$RCD/inst-bios-msdos-rc02.raw IMGU_PATH=$RCD/inst-uefi-gpt-rc02.raw
export IMGB_OUT=$IMGB_PATH IMGU_OUT=$IMGU_PATH
export DIAG_PWF=$B/test-secrets/rc02.pw
export KF_IMG=$RCD/inst-bios-kf-rc02.raw KF_PW=$B/test-secrets/rc02-kf.pw F1_IMG=$RCD/inst-bios-f1-rc02.raw
M=/home/yrslf/alpbahOS/wt-rc02/scripts/rebuild/r21/matrix-r21.sh
D=$MATRIX_DIR
gate() { # gate [min-free-GiB]: total QEMU <= 2, available >= 9 GiB, /home free >= min (default 30); wait up to 90 min
  local i n a f min=${1:-30}
  for i in $(seq 1 90); do
    n=$(pgrep -c qemu-system); a=$(free -g | awk '/^Mem:/ {print $7}'); f=$(df -BG --output=avail /home | tail -1 | tr -dc 0-9)
    if [ "$n" -le 2 ] && [ "$a" -ge 9 ] && [ "$f" -ge "$min" ]; then echo "gate ok $(date +%T): qemu=$n avail=${a}G free=${f}G (min ${min}G)"; return 0; fi
    echo "gate wait $(date +%T): qemu=$n avail=${a}G free=${f}G (min ${min}G)"; sleep 60
  done; echo "gate timeout"; return 1; }
