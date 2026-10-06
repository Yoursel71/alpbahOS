# Base koşusu e5bef10f: host kapanışında kesildi

Base koşusu `e5bef10fcd90e1ca32dfd67bbc2d0285`, `multilib-m32` kipinde ve girdi özeti SHA-256 `d120f4db2e8f69e107069f8c13e3800d76f3f5e2fcae8ee1d547097f209c13cf` ile başladı. Guest içindeki `alpbahos-base-e5bef10fcd90e1ca32dfd67bbc2d0285.service` glibc `make -k check` çalışırken host kapandı. Yeni boot'ta VM veya stage denetleyicisi çalışmıyordu; guest `summary.json`, Base kabul makbuzu ve `checkpoint-base` oluşmadı. Bu koşu başarısız/eksik sayılır ve kabul edilmez.

## Kurtarılan kanıt

- Host günlüğü, önceki boot'un 6 Ekim 12:16'da normal `poweroff.target` akışıyla sonlandığını ve yeni boot'un 12:53'te başladığını gösteriyor (`journalctl --list-boots`, `journalctl -b -1`). İncelenen önceki-boot kernel günlüğünde MCE, donanım hatası, OOM-kill, termal kapanma veya panic olayı yok. Kapanış isteğinin kaynağı eldeki kayıttan belirlenemiyor.
- `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/e5bef10fcd90e1ca32dfd67bbc2d0285/base.host.jsonl` içinde 192 geçerli örnek var; `errors` ve `kernel_faults` dizileri hepsinde boş. Tctl aralığı 48,0–61,5 °C. En son geçerli örnek 6 Ekim 08:17:58 UTC; son satır kapanış sırasında tamamlanmadığı için JSON olarak geçersiz. Boş alanın örneklerdeki en düşük değeri `/` 65,44 GiB, SSD 43,99 GiB, HDD 68,97 GiB.
- Kapanmış `builder-active.qcow2` ve `lfs-active.qcow2` için `qemu-img check` “No errors were found on the image” döndürdü. LFS overlay zinciri `checkpoint-toolchain` → `checkpoint-stability` → `checkpoint-smoke` → `checkpoint-prepared` olarak duruyor. Bu overlay'ler ve checkpoint'ler korunuyor.
- LFS qcow2'den salt okunur kurtarılan guest sonuçları `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/e5bef10fcd90e1ca32dfd67bbc2d0285/guest-base-interrupted/e5bef10fcd90e1ca32dfd67bbc2d0285/` altında. Yalnız `man-pages` ve `iana-etc` için `.installed.json` makbuzu var. `ncurses` bootstrap arşivi üretilmiş ama kurulum makbuzu yok. Glibc logu `stdio-common/tst-printf-format-vsn-double-F` civarında kesiliyor; kopya SHA-256 `38910bfbe8f7cc9bf62559e581fda75fc09fe32c4198abc002240621aa4c905f`.
- Makinece okunur dosya manifesti ve disk/telemetri özetleri: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/e5bef10fcd90e1ca32dfd67bbc2d0285/recovery.json`, SHA-256 `b28c7e50b6fc410a120c5e72be5648b370affbc117097f165d50853546a124e7`.

## Devam

Yarım glibc derleme/test durumu paket kabulü değildir. Guest runner, `build-started.json` olup doğrulanmış `built.json` olmayan kesilmiş paketi sürdürmeyi reddediyor; bu nedenle sonraki Base koşusu doğrulanmış `checkpoint-toolchain`'den yeni run kimliğiyle başlatılmalı. Bu koşunun overlay'i, host telemetrisi ve salt okunur guest sonuçları inceleme kanıtı olarak tutuluyor. Temizlik makbuzu `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-failed-base-images-20261006.json` SHA-256 `fb6658391125f9c9eaa76d66f1e591bec2ad199596b3f65035f0db8d2eb458d1`.
