# Kernel guest producer hazırlığı — 11 Ekim 2026

Codex sahipliğinde `scripts/infra-kernel-build.py` ve odaklı testler eklendi. Canlı production servis/controller/QEMU yeniden keşifte yok. Kesilen Base koşusu `fa5accc90d3627ccbcd6ea32323be518` için outcome ve tam Base acceptance hâlâ yok; host kesintisi açıklaması bekleniyor. Yeni uzun üretim build başlatılmadı, accepted checkpointler ve current/interrupted imajlar değiştirilmedi.

## Producer kapsamı ve kapıları

Bu dosya gelecekteki ölçülmüş host controller'ın **accepted Base** üzerinden açtığı Builder guest için source → unprivileged build → DESTDIR → candidate bundle akışını tanımlar. Mevcut host launcher'a bağlanmadı; authorization producer/handoff transport henüz yok. Root-only QEMU/dedicated ext4 `ALP_LFS_V1`, `/srv/lfs`, inherited FD9 writer lock ve yüzde 15 alan guard'ı ilk işlemden önce zorunlu. Repo tam `/opt/alp-infra` olmalı. Host'tan invocation yazı/command öncesi reddedilir.

Root-owned, regular, single-link, aliassız ve group/world-write kapalı records gerekir: `inputs.json`, `kernel-build-authorization.json`, `kernel-base-acceptance.json`, `kernel-parent.json`. Current guest/host boot, yeni run, Base run, source/input digest, checkpoint/transaction SHA ve üç kernel helper SHA ayrı bağlanır. Yalnız `PASS` Base + `VERIFIED_GUEST_BYTES` 79 paket kanıtı kabul edilir. Gelecekteki host controller gerçek before/after audit, telemetry, accepted checkpoint/backing zinciri ve kaynak imzalarını tekrar doğrulayıp bu records'u ölçülmüş guest'e teslim etmelidir; salt JSON iddiası host kabulü değildir.

Guest önce raw Alp DB SHA, exact 79 Base + 7 toolchain package set, accepted exported manifest SHA, package/source identity, ortak ownership checker ve her installed entry'nin actual mode/owner/hash/link bytes eşitliğini denetler. Candidate üretildikten sonra DB ve 79 payload tekrar okunur; input/auth/parent/helper/source baytları tekrar kontrol edilir. Base kaynak girdileri ve acceptance politikası değişmedi.

Yeni build/stage/result alias veya önceki attempt varsa yürütme reddedilir. İlk mutable işlem öncesi root-owned exclusive/fsynced 0600 attempt marker yazılır. Başarısız/kesilen ağaç ve marker korunur; resume/overwrite yok, accepted Base'ten fresh restore gerekir. SIGTERM/SIGINT ortak process-group cleanup'a girer; SIGKILL/power loss sonrası marker kalır. Bu dosya host controller veya VM kapatma işini yapmaz.

## Kaynak ve komut akışı

Linux 6.16.1 archive SHA `ea43491bc7ace1e414b3b2d957f8cf96e7049155123f0acce798accf8da1acba` ve actual Makefile, module install, depmod wrapper, x86 boot header kaynak hook SHA'ları pinli. Source extraction unprivileged Builder `lfs` UID/GID 1001 ile; asıl compiler accepted LFS chroot'unda aynı numeric kullanıcıyla çalışır. `gcc -dumpfullversion` 15.2.0 zorunlu. Chroot içinde `env -i`; locale/TZ/epoch/build user-host-version/path sabit. Native Builder data/packaging komutları ayrıca temiz environment alır; caller `PATH`, `TAR_OPTIONS`, compiler/loader flags sızmaz.

Upstream `mrproper`, `x86_64_defconfig`, source cwd'de `merge_config.sh -m`, `olddefconfig`, dört işte `bzImage modules`, gerçek `modules_install`/depmod çağrılır. Config helper'ın 62 seçeneği yanında empty LOCALVERSION, LOCALVERSION_AUTO=n, uncompressed/unsigned module, RANDSTRUCT_NONE=y ve sabit BUILD_SALT doğrulanır. `.tmp`, mrproper'dan sonra oluşturulur. Her guest command ortak beş saniyelik alan monitor'undan geçer; çalışma süresi cutoff yok.

Yalnız exact upstream `/build/kernel-6.16.1` build alias kontrol edilip kaldırılır; staged `/lib/modules/6.16.1` usr-merge için `/usr/lib/modules/6.16.1` altına taşınır. Wrong alias veya destination parent alias önce reddedilir. Boot image/System.map/config ve source Documentation stage'e kopyalanır; numeric owner 0:0 normalleştirilir. Actual archive içindeki tek documentation symlink `Changes → process/changes.rst`, staged documentation içinde kalır. Ortak manifest/archive producer, kernel candidate verifier ve archive-manifest validator kullanılır.

Sonuç **BUILT_CANDIDATE** olabilir; `alp` ile kurulumu, installed kernel ownership, host after audit, checkpoint, BIOS/UEFI boot veya stage acceptance değildir. Mevcut installer kernel phase'i kabul etmediği için bu kapı bypass edilmez ve kernel `base` diye etiketlenmez. Bu producer'ın tam guest yürütmesi henüz denenmedi.

## Gerçek kaynak config probe'u

Yetkisiz host `/tmp` ağacında checksum-doğrulanmış actual Linux source ile yalnız Kconfig/helper programları çalıştırıldı; kernel veya modül derlenmedi. Beş komut exit 0: tar, mrproper, x86_64_defconfig, merge_config, olddefconfig. 62 required seçenek ve altı ek kontrol final actual config'te geçti. Geçici ağaç temizlendi; her command öncesi host disk yüzde 15 ve managed budget guard'ı çalıştı.

İlk probe upstream merge script'ini source cwd dışında çalıştırdı; `.config` repo cwd'sine yazıldı, source olddefconfig required seçenekleri alamadı ve verifier FAIL verdi. Production producer zaten explicit `cd /build/kernel-6.16.1` kullanıyordu. Probe cwd düzeltildi; failed receipt/log/config korunup yalnız kimliği ve kopya hash'i doğrulanan kendi generated repo `.config` çıktısı kaldırıldı. Hata gizlenmedi. Son native environment izolasyonu değişikliğinden sonra final helper actual PASS config baytlarını tekrar doğruladı; final binding receipt producer/source/probe/config SHA'larını bağlar. Bu, yeni kernel derleme kanıtı değildir.

Receipt/log kökü `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/`:

| Nesne | SHA256 |
|---|---|
| Final producer | `0a5c88bdea4daf978732d0d3edc124305601d4aa63ff0fee687d7e43835cc488` |
| `kernel-build-controls-source-probe-cwd-fixed-20261011.json` | `97dcf1b5db306f88c18487f9be46413e965445216a3b71a78b4066835c66cb49` |
| Actual config | `da23df5c49f442c323584feee9c79735fdcaf667fe6536ee1dbbeda4c0b51599` |
| Actual source probe log | `87ca6bdfeb9659fb334f3a93b1b05ab88aa1038c926c7ce636296bdfc61ec12e` |
| `kernel-build-controls-final-binding-20261011.json` | `23ff79948bd60c54eed69c9b8eb576feb78e73c0d9d423ea8cd63ab6dce181d2` |
| Failed initial probe receipt | `c2d6c7ca1d2e431fb06716bf5a679b05c21de5777cd20245f94c59ef5fd8f52c` |
| Failed initial probe log | `19977d87546a21c43425731ce8778df1f2793e9de76c6c2aa6013d8b2eb17ca0` |
| Failed cwd config | `d9f2ff99a2cd71193c09f56c2c89b986e4dc69fc6303da3c515e703e0b2be3a1` |
| Final focused test log | `4d2c19e31e90de773ee24dd60be676f4fcb829cbc861b308576a10651d7103b5` |
| Host read-only sample | `7c2c8bc94b735326202e5d4e5114fc5373e19f453cde170e363269f390672aa6` |

## Test ve kalan iş

10 odaklı test PASS (0,498 sn): partial Base/missing checkpoint, stale boot/parent/helper/source/auth, host invocation, environment poison, dropped Kconfig control, wrong module alias/destination escape, raw DB ve installed payload drift reddedildi. 79-package unit fixture gerçek Base kabulü değildir. İlk full suite 431 test/2 skip PASS (92,874 sn). Native data-command environment ayrıca izole edildikten sonra final full suite de 431 test/2 skip PASS (91,331 sn). Komut `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v`; final log `infra-full-tests-kernel-build-final-20261011.log`, SHA256 `a4ef6fad3a6e59d0110c9e1dac69e55b687ee04a21893dff91f3867eabc6a638`. Python compilation ve whitespace kontrolü PASS. Docs checker exit 1, aynı 31 tarihsel bulgu (1 broken-link, 19 commit-ref, 10 decision-ref, 1 stale-term); yeni kernel producer bulgusu yok, temiz olduğu iddia edilmez. Log `kernel-build-doc-check-final-20261011.log`.

Managed allocated 142.427.668.480 byte, 300 GB budget altında. Base canonical input digest `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306` aynı; helper scripts kökünde ve gelecekteki controller tarafından ayrı SHA-bound olmalı. Host örneği boot `96d39e6d-37a7-4303-acb4-61235026c4cc`, 0 errors/faults, Tctl 39,75°C; root/SSD/HDD free yüzde 18,687/20,307/16,720. Bunlar tek read-only sample; kesilen koşunun tam monitor acceptance'ı değildir. Bağımsız ajan incelemesi yapılmadı.

Sonraki iş: accepted-Base host controller/auth transport, gerçek guarded guest build, kernel phase için ortak Alp ownership kurulumu ve installed evidence, controlled BIOS/UEFI boot, host after/checkpoint acceptance. Yeni tam GCC/Coreutils/Base ve complete fresh repeat-byte kabulü; BLFS/Plasma/GL/profiles/ISO kabulü hâlâ açık. Host reboot açıklaması beklenirken uzun production build başlatma koruması sürüyor.
