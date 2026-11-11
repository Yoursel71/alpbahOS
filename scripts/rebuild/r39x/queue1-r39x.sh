#!/bin/bash
# r39x queue 1: KVM installed rows, one guest at a time, each behind the gate
cd /home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r39x && . ./env.sh
step() { local n=$1; shift; gate 20 >> run-$n.out 2>&1 || { echo "[$(date +%T)] $n gate timeout" >> queue1.log; return; }
  echo "[$(date +%T)] $n start" >> queue1.log; "$@" >> run-$n.out 2>&1; echo "[$(date +%T)] $n end rc=$?" >> queue1.log; }
step B3 bash $M diag B3
step U2 bash $M diag U2
step FPGUI bash $M fpgui
step S1 bash $M s1
step R1 bash $M r1
step REC1 bash -c ". ./env.sh; bash \$M recprep bios REC1 && bash \$M reclive bios REC1 /dev/vda1 && bash \$M recboot bios REC1"
step REC2 bash -c ". ./env.sh; bash \$M recprep uefi REC2 && bash \$M reclive uefi REC2 '/dev/vda2 /dev/vda1' && bash \$M recboot uefi REC2"
echo "[$(date +%T)] QUEUE1 DONE" >> queue1.log
