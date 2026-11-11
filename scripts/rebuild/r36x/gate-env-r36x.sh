# sourced on the host (copy of r36x/env.sh): environment and resource gate for the r36x rows (KF, F1, ALP on ISO r36)
export MROUND=r36 MATRIX_WT=/home/yrslf/alpbahOS/wt-r36x LANES_W=/home/yrslf/alpbahOS/wt-r36x/scripts/rebuild/image
export MATRIX_DIR=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r36x
export KF_IMG=/home/yrslf/alpbahOS/scratch-lfs-bench/images/inst-bios-kf-r36x.raw KF_PW=/home/yrslf/alpbahOS/scratch-lfs-bench/test-secrets/r36x-kf.pw
export F1_IMG=/home/yrslf/alpbahOS/scratch-lfs-bench/images/inst-bios-f1-r36x.raw
M=/home/yrslf/alpbahOS/wt-r36x/scripts/rebuild/r21/matrix-r21.sh
D=$MATRIX_DIR
gate() { # resource gate: total QEMU <= 2, available >= 9 GiB, /home free >= 50 GiB; wait up to 90 min
  local i n a f
  for i in $(seq 1 90); do
    n=$(pgrep -c qemu-system); a=$(free -g | awk '/^Mem:/ {print $7}'); f=$(df -BG --output=avail /home | tail -1 | tr -dc 0-9)
    if [ "$n" -le 2 ] && [ "$a" -ge 9 ] && [ "$f" -ge 50 ]; then echo "gate ok $(date +%T): qemu=$n avail=${a}G free=${f}G"; return 0; fi
    echo "gate wait $(date +%T): qemu=$n avail=${a}G free=${f}G"; sleep 60
  done; echo "gate timeout"; return 1; }
