# OC sonrası toolchain çalıştırıcı — 1 Ekim 2026

## Sonuç

Kullanıcı OC tamam/başla iznini verdi ve önceki `b` seçimi m64+m32, x32'siz olarak donduruldu. `scripts/infra/buildctl.py toolchain-run --mode multilib-m32 --oc-confirmed --run-id <tek-kullanımlık-id>` Phase 1 raw Alp DB kabul makbuzu olmadan ilerleyemez. Makbuz yok; daha önce iki kuruluma ait raw DB SHA değerleri (`4270ed3a44ebfc5f10cfc1711730c4b6b7247406ee5ec565109ab3fd24185872` ve `f51cf1c9ba97eab2326afff477871aaabe0e1d9887a7de262881ac39184f33a4`) timestamp yüzünden farklıydı. Bu turdaki CLI denemesi aynı engelde durdu; VM/QEMU guest başlatılmadı.

## Kod bağlantısı

`toolchain-run` seçilen ABI ve açık OC bayrağını, Phase 1 kabulünü, mevcut accepted stability parent'ını, güncel root-before inceleme isteğini, tek kullanımlık job/boot bağını ve yeni guest başlangıcını zorunlu kılar. Sabit `/opt/alp-infra/scripts/infra/guest-toolchain.sh` komutu `run_monitored` ile host logu ve telemetry altında çalışır. Normal kapanışta tüm `/srv/lfs/results/toolchain/<run-id>/` ağacı exclusions olmadan toplanır. Ham handoff/authorization ve misafir boot kimliğiyle canonical7 tar/manifest/index/receipt/raw Alp DB/payload-owner ve üç m64/m32 ABI probe doğrulanır. VM kapanıp qcow2 yazıcıları durduktan sonra outcome yalnız `PENDING_PRIVILEGED_POST` olabilir; bu stage kabulü değildir. Sonraki privileged host-after incelemesi, güncel repository/disk/monitor kanıtı, stage acceptance ve checkpoint ayrıca gerekir.

Guest bytes/top-level proof verifier mevcut byte/ABI raporunda açıklanan sentetik fixture kapsamıyla test edilir. Bu runner için positive lifecycle fixture `VERIFIED_GUEST_BYTES` yanıtını enjekte eder; test gerçek VM, Alp DB veya compiler kanıtı sayılmaz. Phase 1 ve root cleanup sonucu olmadan VM/compiler çağrısı yapılmaz.

## Doğrulama

Tam suite `PYTHONPATH=tests python3 -m unittest test_infra_rebuild test_toolchain_evidence -v`: **144 test, 86.639 saniye, OK**. Oturum/CLI Phase1 guard için yeni regresyon testleri dâhil edildi. `py_compile`, 3 Python dosyası AST parse, guest wrapper `bash -n` ve `git diff --check` geçti. Tam suite stdout bir ayrı loga yönlendirilmedi; unittest sonucu bu turn output'unda mevcuttur.

CLI `toolchain-run --mode multilib-m32 --oc-confirmed --run-id a…a` exit 1: `STOP: Phase 1 acceptance absent; resolve Alp DB reproducibility before Phase 2`. Ham kayıt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/toolchain-run-phase1-stop-20261001.log`, SHA-256 `917a2b5e18489a713b60ccedd7478b5d83cb2f0812e7af2d7bf8998c3c232a60`. Structured state `/mnt/alpbahOS-data/alpbahos-infra-rebuild/state/infra-toolchain-runner-verification-20261001.json`, SHA-256 `fa2d4b59d5602a37f0973247a56b1e70e0521e8bdef41c6816516e3e38e3bb1b`.

Son read-only durumu: pinned `manifests/infra-sources.json` SHA `0df6f8614ba0b4c335561f69c9458e972be5a738bd3ffa3c6f955ca12b6c8027`; build inputs `86848345dcf50317a7e43bb9c394219f91460c3cd762b936812058e01c822586`. Phase1 acceptance/root cleanup result/root-after RPM audit dosyaları yok; `pgrep -a qemu-system` boş. Boş alan: NVMe `/` 34.15%, Builder SSD 60.15%, HDD 57.24%. Ana HEAD ve Codex worktree HEAD `a9bac38544955c30c146c175760195ff193a0b76`; Claude HEAD `c6d98d4bc54ed33a4afca22e30e00ac6b1744714`; herhangi birine commit/push yapılmadı.

RAM/CPU listesinde Plasma shell (`plasmashell`, PID 2697, 1,329,600 KiB RSS, 13.1% ps CPU) en büyük bağımsız GUI süreciydi. Kullanıcının önceki talebi kapsamında `systemctl --user stop plasma-plasmashell.service` çalıştırıldı; exit 0, unit `inactive/dead`, PID kalmadı. KWin ve bu Codex ile Claude'un etkin işleri korundu. Son `free -b` çıktısında 17,108,340,736 byte (~15.93 GiB) available RAM görüldü. Kayıt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/state/plasma-resource-stop-20261001.json`, SHA-256 `abb81aad081568d0207dbd67edb0ae8abadac1b2b100748f5e9d5fa20095f278`.

## Açık kapılar ve kapsam

- Root cleanup sonucu ve ayrıcalıklı host RPM/journal audit dosyaları yok.
- Phase 1 Alp raw DB determinism ve `artifacts/phase1-acceptance.json` yok.
- Stability production receipt/checkpoint, toolchain guest kanıtı ve host-after stage kabulü yok.
- M09'un tam Chapter 6 native 79 paket, kernel IA32 emulation/virtio, BLFS 12.4, Plasma Wayland/QEMU virgl GL, Claude profile girdileri, iki byte-matched ISO ve pristine host RPM audit hedefleri açık kalır.
- Ana/Claude ağaçları, Alp kodu, frozen cleanup/root audit producer'ı ve source manifesti bu runner bağlantısı için değiştirilmez. Host root, mount/chroot, host package/CPU değişikliği, commit/push yapılmaz.
