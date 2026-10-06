# Expect test ortamı düzeltmesi — 6 Ekim 2026

Base aşamasının `d86118114a2b59ec26448e9d6dbfb515` koşusu 14 Base paketi kurulduktan sonra Expect `make test` adımında durdu. `artifacts/stage-runs/d86118114a2b59ec26448e9d6dbfb515/guest-base-partial/expect/base-expect.log` içindeki son hata `make: *** [Makefile:267: test] Segmentation fault`; Expect kurulmadı ve bu koşuda stage kabulü yok.

Tanılama core dosyası `/mnt/alpbahOS-data/alpbahos-infra-rebuild/expect-debug/core` konumunda (SHA-256 `ebf2bac556a31890a31c5be1f75095ce50429c52b5973a9c3b02b537de251fb9`). GDB, çöken sürecin Builder `/usr/bin/bash` olduğunu ve LFS `/srv/lfs/usr/lib/libc.so.6` dosyasını eşlediğini gösterdi. Expect'in oluşturduğu test komutu `.alp-tclsh` shell sarmalayıcısını çalıştırmadan önce `LD_LIBRARY_PATH=.:/srv/lfs/usr/lib` atıyor; böylece shell'in yorumlayıcısı betik çalışmadan hedef glibc'yi yüklüyor. Aynı değişken testlerin başlattığı Builder araçlarına da aktarılıyor.

`scripts/infra-base-guest-run.py`, hedef Tcl'yi doğrudan LFS loader ile başlatacak bir `TCLSH_PROG` komutu ve Tcl bootstrap'i üretecek şekilde düzeltildi. Bootstrap doğru `TCL_LIBRARY` değerini ayarlıyor, istenen test dosyası ve argümanlarını iletiyor, `tests/all.tcl` yüklenmeden önce alt süreç ortamındaki `LD_LIBRARY_PATH` değişkenini temizliyor.

Düzeltme, önceden derlenmiş Expect ağacını kullanan geçici tanılama qcow overlay'inde denendi. Yeni `make test` sonucu: `Total 29 Passed 29 Skipped 0 Failed 0`. Tanılama VM'i temiz kapatıldı, geçici overlay'ler kaldırıldı. `test_infra_base_guest_runner` ve `test_base_plan` birlikte 40/40 geçti; Python `compileall` ve `git diff --check` başarılı.

Yeni `scripts/infra-base-guest-run.py` SHA-256 `3304ecc65f965ceb9cce148edd78e917d5f045cb0ac20782b519af2f1e4a77cd`; `tests/test_infra_base_guest_runner.py` SHA-256 `5ee53ce13d1bdc95e1041b6fccc23b0f01356ea131ddba628bb154057588428a`.

Bu tekrar yalnızca test uyarlamasını ve Expect testlerini doğrular. Gerçek Base koşusu, yeni guest-runner SHA'siyle Expect'i yeniden derleyip kurmalı; paket kabulü ancak o zaman verilebilir. Toolchain checkpoint değişmedi; build inputs SHA-256 `d120f4db2e8f69e107069f8c13e3800d76f3f5e2fcae8ee1d547097f209c13cf`.
