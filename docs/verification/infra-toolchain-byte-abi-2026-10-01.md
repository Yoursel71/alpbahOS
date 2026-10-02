# Toolchain paket/DB/payload ve ABI kanıtı — 1 Ekim 2026

**Hazırlık doğrulandı; Faz 1/2 veya ürün kabulü değildir.** Own `codex/infra-rebuild` ağacında yedi canonical Chapter4/5 paketi için guest export producer ve salt okunur host byte verifier eklendi. Controller'a canlı compiler/collector action bağlanmadı; toolchain session kabul slot'u kapalı ve normal çıkış hâlâ FAIL. Root temizliği/audit, deterministik Alp DB ve Phase1 kabulü yok; “OC tamam, başla” verilmedi.

## Değişiklik

- `package_install.py`: her toolchain kurulumunda gerçek ham DB baytları EXCL/fsync snapshot'a alınır ve orijinal receipt SHA'sına bağlanır. Resume aynı snapshot'ı doğrular. DB yazma, normalizasyon veya alan dışlama yok.
- `toolchain_plan.py`: host/guest ortak canonical7 sıra, recipe/dependency/ABI/source pin okuması. `guest_toolchain.py`: yeni job/run/guest boot/handoff/input bağlı sonuç dizini ve export.
- `toolchain_artifacts.py`: gerçek kurulu yollar mevcut manifestle tekrar ölçülür; yedi paketin full resume kontrolünden sonra observed metadata/hash kayıtları ve byte-exact son DB kopyası ayrı EXCL dosyalara yazılır. Birlikte atomik değildir; eksik dosya/prefix kabul edilmez, kısmi kanıt korunur.
- `toolchain_sanity.py`: sabit C/C++ probe kaynağı, saf raw trace parser; komut başına argv/input/cwd/guest boot/handoff/exit/errors/wall/monotonic terminal kaydı. C++ kütüphanesinin actual selected link inputs içinde bulunması gerekir.
- `toolchain_evidence.py`: actual tar/manifest baytları, canonical kaynak/recipe, fixed guest job paths, protected index/receipts, install-time raw DB prefix'leri ve değişmemiş package records, final DB ve installed observation karşılaştırılır. LFS alias çözümü host `/srv/lfs` dosya sistemini kullanmaz; cycle/escape, olmayan parent, eksik/çakışan/extra claim ve x32 layout reddedilir.
- Aynı verifier üç ABI probe'unun gerçek kaydedilmiş ELF class/machine/PT_INTERP baytlarını, compiler/linker stdout/stderr, sysroot, CRT/libc/loader/C++ owner ve seçilen dosyalarını tekrar inceler. Exact command/argv/input sırası, success exit, current boot/input ve before/start/during/after space telemetry coverage/%15/time gap denetlenir. RPATH/RUNPATH ve host search reddedilir. `VERIFIED_GUEST_BYTES` bağımsız root/host/stage certificate değildir.

## Doğrulama

Komut: `PYTHONPATH=tests python3 -m unittest test_infra_rebuild test_toolchain_evidence -v`

**142 test / 84,096 saniye / OK**, 16 yeni byte/ABI testi. Log:
`/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-toolchain-byte-abi-verified-tests-20261001.log`

SHA-256: `aa8e932222d4c9d24bab3adc0edc3e28d73b47ebf0b7e0c70a24405c2bed6da9`.

Negatif senaryolar hash alanları fixture içinde yeniden bağlanarak da denendi: ham snapshot whitespace/prefix/old-record, observed payload mismatch, eksik/extra/conflicting owner, yanlış source/run/boot/index, tar drift, aliases/hardlinks/write permissions; actual x32/interpreter/multilib, failed command/changed probe input/native flag, eksik veya <%15/gap telemetry, host headers/libraries, eksik C++ selected input, runtime path, eksik stage/command order ve package-verification sonrası artifact drift. Saf packet-only evidence full guest proof olamaz.

İlk 8 focused ve son 17 focused invocation geçti; ikinci invocation imported iki mevcut ABI testi de içeriyordu. Import temizlendi; final suite iki kez saymadan 16 yeni testi kapsar. Ara141 test/82,497s logu public entry/epoch binding eklenmeden öncedir ve final code kabulü yerine kullanılmaz. Bu bileşende başarısız derleme veya test koşusu yok. Önceki session helper hatalarının logları korunur.

29 Python AST (iki test dosyası dahil), 10 `bash -n`, `git diff --check`, DECISIONS empty diff, CLI help ve runtime path/space/300GB guard geçti. Current input SHA:
`02e473fbe2f2fb47d290160dd145a50342a6c92f4d5636bd7b4dccb3a3f50c53`.

Code SHA'ları ve durum:
`/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-toolchain-byte-abi-verification-20261001.json`

SHA-256: `1e7b3ad8fe90d7a54db2acedc32163d5624b678785faa3050a2cc11ae17f33be`.

## Gerçek kapsam ve açık kapılar

Yeni pozitif kanıtlar gerçek tar/manifest/JSON baytlarıyla **yapay fixture**'lardır; paket DB/komut çıktısı/telemetry ve minimal ELF başlıkları üretilmiş test verisidir. Genuine compiler, ABI runtime, QEMU boot, guest root export veya root audit çalıştırılmadı. Existing suite tiny unprivileged qemu-img/qemu-io fixture kullanır; production disk/ISO değişmez. Gerçek guest exporter'ın uçtan uca aktarımı ve monitored compiler action/controller root-after/toolchain stage acceptance henüz bağlı değildir. Native 79 paket, kernel, BLFS, Plasma GL, Claude profiles, iki eşit ISO ve transactional restore açık kalır.

Own Builder PID null; erişilebilir QEMU inventory boş. Bu, başka ajanın önceki VM kapanışını kabul etmez. Main/Claude/own HEAD ve dalları aynı; başka çalışma ağacına, Alp motoruna veya DECISIONS'a yazılmadı. Frozen cleanup script/plan ve canonical source SHA değişmedi. Commit/push/sudo/root/mount/chroot/host package/CPU/production VM/compiler/systemd ve ek eski imaj silme yok.

NVMe/SSD/HDD boş oranları %34,15/%60,15/%57,24; boş alan 173919387648 / 72199700480 / 281103962112 bayt. Önceki yetkisiz temizlik net yaklaşık279GiB; kalan 1117 root subvolume +199 artık dizin tamamlandı sayılmaz. `cleanup-root-result.json`, root audit, Phase1, production stage store ve stability checkpoint yok. Final state actual root producer STORE `/var/lib/alpbahos-infra-audits` yolunu denetler; önceki observation dosyasındaki runtime candidate path alanı bu kabul için kullanılmaz.

Sonraki iş: mevcut kapılar altında gerçek guest export/host transfer/monitored action ve root-after acceptance entegrasyonu. Canlı çalıştırma ancak Phase1, root denetimler, ham DB eşitliği ve açık OC/başla yetkisiyle yapılır. “devam” hazırlık devamıdır; heavy authorization değildir.
