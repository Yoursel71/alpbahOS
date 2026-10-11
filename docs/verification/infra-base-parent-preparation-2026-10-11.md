# 11 Ekim 2026 — Base parent kanıtının kernel geçişi için yeniden doğrulanması

Host tarafında salt okunur Base parent preflight ve completed-run audit doğrulaması eklendi. Bu hazırlık gerçek Base/kernel kabulü veya yeni başlatma yetkisi değildir. Canlı production controller/VM yok; accepted Base artifact henüz bulunmuyor. Reboot nedeni açıklanmadan uzun üretim koşusu başlatma koruması sürüyor.

## Somut değişiklik

`scripts/infra-parent-audit.py` root-owned ham capture, producer SHA, recorded boot, command argv/exit/timing, stream SHA ve mevcut strict RPM/kernel politikasını yeniden doğrular. Before/after kayıtları stage sınırlarını aynı boot/run/girdiyle çevrelemeli. Request yaşı **root capture anında** en fazla 24 saat olabilir; tamamlanan koşunun günler sonra okunması bugünün boot/time kimliğiyle reddedilmez. Core `host_stage_audit` ve yeni stage before/capture freshness kapısı değişmedi. Historical kanıt yeni current-boot audit yerine kullanılamaz.

`scripts/infra-base-parent.py` yalnız sabit Base acceptance yolunu okur. Current canonical input/source pinleri, complete saved Base/toolchain checkpoint transaction ve metadata hashleri, raw 79-package export/manifest/payload/DB, toolchain receipt ve Base controller evidence yeniden doğrulanır. Base `accept()` ortak host/telemetry/repository/guest/raw artifact kontrollerini tekrar çalıştırır; sonuç stored proof ile aynı olmalıdır. Sealed disk yolu yalnız eski active filename → saved checkpoint filename şeklinde taşınır; original SHA ve bütün gerçek qcow2 ancestor path/hash/ABI-format/check/stat/owner/mode/alias kapıları korunur. Current failed/future overlays parent baytları sayılmaz ve değiştirilmez. Yeni controller launch öncesinde ayrıca accepted Base restore, fresh child pinleri, controller lock, current before audit ve host/guest boot-bound authorization gerekir; bu bileşen burada henüz yok.

Base host controller iki helper SHA'sını pinler. İlk kabulde current closed disk inspect/check/hash kapısı sürer; yalnız internal checkpointed revalidation kolu complete saved transaction ve gerçek saved bytes ister. CLI resume/bypass/path flags kabul etmez. Root audit, VM launch, build, disk restore veya acceptance yazımı yapılmaz. Core canonical dosyalar, guest GCC adapter/test policy ve accepted checkpointler değiştirilmedi. Host controller hashinin değişmesi nedeniyle eski interrupted run replay edilmez; sonraki yetkili fresh Base koşusu yeni host controller hashini bağlamalıdır. Guest runner aynı `f8f64ce` baytlarıdır.

## Test ve gerçek gözlem

Final odaklı testler: 17 PASS. Gerçek küçük layered qcow2 dosyalarında checkpoint relocation, current child mutation sonrası immutable parent doğrulaması ve byte-exact no-write kanıtlandı. Saved image byte/mode/alias/ancestor drift, incomplete transaction, live writer, missing Base ve helper drift reddedildi. Base first acceptance current disk kapısı ile sealed replay kapısı ayrı test edildi. Fixture proof üretim Base acceptance değildir.

Mevcut **gerçek root-owned historical toolchain** before/after capture'ları yeniden okundu; strict original output policy ile elde edilen proof mevcut toolchain acceptance `host` alanıyla tam aynı çıktı. Root capture yeniden çalıştırılmadı. Synthetic audit testleri stale-at-capture, cross-boot/run, producer/UID/raw-byte/command/timing/filename drift, kernel panic ve RPM verifier script inventory durumlarını reddetti; eski request yeni launch için core checked_request tarafından hâlâ reddediliyor. Bağımsız AI/Claude incelemesi yapılmadı.

İlk full suite host boot değişimi sırasında kesildi: eski boot `96d39e6d-37a7-4303-acb4-61235026c4cc`, yeni boot `473f996d-f872-4b90-8b7d-eda73cfdda70`. Sonuç özeti yok; `base-parent-full-20261011.log` 53.248 byte ve 3.058 trailing NUL byte içeriyor. Bu koşu PASS değildir. Önceki journal'ın son kaydı 11 Ekim 10:18:43 +03; captured tail exact shutdown nedenini göstermiyor. Sonraki boot envanterinde saat sıçramaları var; kullanıcı mı/reset mi olduğu kanıtlanmadı. Interrupted log ve journal/unit capture'ları korunuyor. Tests içinde VM/session lifecycle çağrıları fixture mock; testte host shutdown komutu yok. Yeni uzun production stage açılmadı.

Eksik `PYTHONPATH` ile yapılan ikinci full invocation 443 test/2 skip içinde yalnız `test_base_plan` import error verdi (`ModuleNotFoundError: base_plan`); bu PASS değil ve ham log korunuyor. Canonical `PYTHONPATH=scripts/infra` ortamıyla final suite yeniden koşuldu: 457 test, 2 skip, PASS (91,724 sn), NUL byte yok. Python compilation ve whitespace kontrolü PASS. Docs checker önceki aynı 31 tarihsel bulguyla exit 1; yalnız line numaraları değişti, yeni bulgu yok (temiz docs acceptance iddia edilmez).

Actual unprivileged CLI: eksik `base-acceptance.json` için exit 1/STOP/stdout boş; `--resume` için exit 1, bypass flags refused. Bu absent gate negatif kanıtıdır; tam Base parent success kanıtı değildir. Initial host sample errors/faults 0, Tctl 33,25°C; bu kesintinin sebebini açıklamaz veya stability acceptance sağlamaz. Final test sonrası host sample errors/faults 0, Tctl 53.375°C; root/SSD/HDD available [18.836, 20.307, 16.719]%. Final binding ve test sonrası örnek aynı boot kimliğinde; bu overall stability acceptance değildir. Every-volume 15% floor korunuyor; artifact cleanup yapılmadı.

Base canonical digest: `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`.

## Kanıtlar

Runtime kökü `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/`.

| Nesne | SHA256 |
|---|---|
| `scripts/infra-parent-audit.py` | `7dd4e8513ad42b1eb8752539dda63214ebac04a153b3156be64d62549f3567e7` |
| `scripts/infra-base-parent.py` | `5deaac7c59e59fff9717988d775d5df11de7178948e8a1095a197f2b41867a23` |
| `scripts/infra-base-stage.py` | `477e3675bbe660127b56bc9fc56564315365f3eada452acbb9593e631ca3c22e` |
| `scripts/infra-base-guest-run.py` | `0a23a98747ffe066287f4dca76314effa8a1392c853eea002e323c67991bdd41` |
| `base-parent-preparation-probe-20261011.json` | `1e2a08aad753de752be7b10459c6c8ae4ed3c31ec9788bf387cbf722330e0884` |
| `base-parent-tests-interruption-20261011.json` | `f0dd11615a454a429dadadeb017f06419da19604f3716389766bf1b8428ba28b` |
| `base-parent-full-20261011.log` | `9db98c24d6ba975b09bafa82056b92bc2564140114f63d7c7eb84a5da63851a3` |
| `base-parent-focused-final-20261011.log` | `ad2ea69a526816d042ca73b96c8aa1ada962e6bb2c41a7c2c0cbec55d6ca5124` |
| `base-parent-full-correct-env-20261011.log` | `80c2ff6a39e40951bc36c63af0dfdc03cc8c34876eba0a4ff50145132ecf838b` |
| `base-parent-full-final-20261011.log` | `2ce61bbaa197b0afe2ac207fe666ee90a0b19e9a80f208e60b65a83c621776fe` |
| `base-parent-final-binding-20261011.json` | `4a17061a5ee3ff031692f9dfaad270f664a7b004bfa00ec415956f6a98ae0c53` |
| `base-parent-validation-summary-20261011.json` | `10b13f2131f379c928f5906d09de95733ac3fcf2fefcc083bfd8d96dcf72634a` |
| `base-parent-doc-check-20261011.log` | `4a28e51623a5293e5ae9b766f08e43a4c9bedee8ad68ef6e94c55ee6fcf63d9b` |
| `base-parent-doc-check-final-20261011.log` | `15afc63b962f67b73a3d7276b195ee89f1a6f12a99254df49f005b2fc4bed707` |

Eksik gerçek kabul: yeni tam GCC/plugin/Coreutils/Base, fresh complete repeat-byte verification, accepted Base → kernel current-boot host controller/authorization/SSH launch, gerçek kernel build/Alp install/boot/host acceptance ve BLFS/Plasma GL/ISO pipeline. Bu hazırlık bu aşamaları tamamlandı saymaz.
