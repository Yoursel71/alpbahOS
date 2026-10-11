# Kernel guest handoff ve kilitli girişler — 11 Ekim 2026

Codex dosya sınırı: yeni `scripts/infra-kernel-authorize.py`, authorization/build shell girişleri, kernel producer receipt/helper pinleri, odaklı testler ve kanıt/durum belgeleri. Önceki goal turu ilerlemeydi: producer c67ae0a push edildi. Bu turda canlı production service/controller/QEMU yeniden keşfedildi; yok. Referans attachment tekrar okundu. Kesilen Base koşusunun host reboot açıklaması hâlâ bekleniyor; accepted Base yok ve yeni uzun build başlatılmadı.

## Bağlanan akış

Future host controller'ın SSH üzerinden teslim edeceği payload exact üç alanlı ve 2 MiB bounded: `base_raw`, `parent_raw`, `authorization`. Base/parent raw JSON baytları yeniden serialize edilmez; SHA onların tam baytlarına bağlıdır. Authorization taşıyan JSON object guest'te sabit canonical encoding ile yazılır; raw SHA tamamlanma receipt'ine bağlanır. Transport root ve mevcut QEMU/dedicated ext4 volume/writer/alan guard'ını ilk işlemden önce ister. `/opt/alp-infra` dışında host invocation reddedilir.

Yazı öncesi producer'ın ortak binding fonksiyonu current guest/host boot, distinct new kernel/Base run, complete Base guest proof, checkpoint/transaction/source/input ve **altı** helper pinini doğrular. Producer/config/payload yanında transport ve iki shell entry de ayrı SHA-bound. Host ve guest boot'un aynı olması reddedilir. Source manifest ve canonical input tekrar okunur; exact 79 Base installed manifest/payload ve raw Alp DB mevcut ortak verifier üzerinden tekrar denetlenir. Bunlar host before/after audit revalidation yerine geçmez; future controller gerçek kabulü doğrulamadan token üretemez.

Guest'te yalnız evidence parent `/srv/lfs/results/kernel` root-owned biçimde hazırlanır. Root-owned private `kernel-handoffs` altında exclusive 0600/fsynced attempt marker sonra Base record, parent record, authorization **en son** yazılır. Her record exclusive; existing/partial/replay veya alias değiştirilmez. Guard her write öncesi tekrar çağrılır; committed raw bytes tekrar okunur. Son `HANDOFF_BOUND` receipt auth/Base/parent/helper/run/boot/payload SHA'larını taşır ve exclusive/fsynced yazılır.

Kernel producer artık bu completed receipt'i ilk mutation öncesi zorunlu ister; receipt SHA build binding'e eklenir ve üretim sonunda tekrar kontrol edilir. Authorization yazılmış olsa bile completion eksikse build başlayamaz. Kesinti sonrası attempt/partial records korunur, aynı run tekrar kurulmaz; accepted Base restore üzerinden yeni attempt gerekir. Transport derleme, Alp install, VM launch veya host acceptance yapmaz.

İki shell entry `set -euo pipefail`, arg reddi ve ortak `guest-guard.sh` kullanır; FD9 tek yazıcı kilidi Python'a exec boyunca taşınır. Python temiz `env -i` PATH/locale/TZ altında çalışır. Build entry mevcut guarded producer'ı çağırır; bypass/resume/job flags yok. Host launcher/accepted-Base authorization üreticisi ve ölçülmüş SSH transfer henüz entegre değil.

## Doğrulama ve sınırlar

37 odaklı test PASS (0,550 sn): kernel config/payload/producer ve yeni dokuz transport testi. Gerçek temporary exclusive/fsync file operations kullanıldı; fixture guest guard mock edildi, production root/volume kimliği kanıtlanmadı. Her Base/parent/auth/completion write öncesinde exception enjekte edildi: attempt kaldı, completion oluşmadı ve replay reddedildi. Tam delivery byte/mode sırası, alias korunması, post-write drift, auth/boot/helper/payload/extra-field completion drift ve oversized/wrong schema reddi denetlendi. Fixture Base/token gerçek authorization değildir. Bağımsız ajan incelemesi yapılmadı.

Yetkisiz gerçek CLI probe'u iki Python entry'yi host üzerinde çalıştırdı: exit 1, `host invocation refused`, stdout boş; herhangi bir stage başlamadı. İki actual shell entry `--resume` ile source/guard/helper çağırmadan exit 1 verdi. Bu shell arg testi actual guest guard/FD9 acceptance değildir. Final producer önceki checksum-doğrulanmış actual source config baytlarında 62 required seçenek/altı kontrolü tekrar doğruladı; kernel/module derlemesi yok.

Full suite `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v`: 440 test, 2 skip, PASS (91,172 sn). Log `infra-full-tests-kernel-handoff-20261011.log`, SHA256 `3f948891889f73f17f11b9aefc0417a7cb8d9ffaa2c6bf6976f5b2e795ab6821`. Docs checker aynı 31 tarihsel bulguyla exit 1; line number dışında önceki bulgularla aynı, yeni handoff bulgusu yok. Log `kernel-handoff-doc-check-20261011.log`; temiz dokümantasyon kabulü iddia edilmez. Python compilation, shell syntax ve whitespace kontrolü geçti. Base canonical input digest aynı: `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`. Scripts kökü helper'ları future controller tarafından ayrıca SHA-bound; accepted checkpoint ve core build girdileri değiştirilmedi.

Runtime receipt/log kökü `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/`:

| Nesne | SHA256 |
|---|---|
| Kernel producer | `3ea2d440fa4c54e8cf0ff1fca3489c6125aa7b3f17c726b51de40011b740ff80` |
| Authorization transport | `ce6f2b817b2454179983694b81f336b2c99701ce76e72c8de2fd14cb8592b6a9` |
| Authorization entry | `fb41a3b88f78eee5f5e89299a4abe8096ff61c310a14ee5d35b64c9b662181a6` |
| Build entry | `f332252504871456365b806523e8fdb5a9875600a15525cc4fa9fc69cb203779` |
| `kernel-handoff-host-entry-probe-20261011.json` | `13de1c2db3cba3228bb8fc7dba79c966df9d71e4fb3627a2a289a6cbafc7f3fa` |
| Actual config revalidated | `da23df5c49f442c323584feee9c79735fdcaf667fe6536ee1dbbeda4c0b51599` |
| `kernel-handoff-focused-tests-final-20261011.log` | `4fb4e234d0e4de2209d80339c23ddacd803765018e7c6b24d69b9d485313f12e` |
| `kernel-handoff-preparation-host-sample-20261011.json` | `e91fc5c3a47a23722c4a1c48f3857cac00bbd21ee6c1db5daca98fde97a01700` |

Host read-only sample boot `96d39e6d-37a7-4303-acb4-61235026c4cc`, zero errors/kernel faults, Tctl 36,125°C; available root/SSD/HDD yüzde 18,687/20,307/16,720. Managed allocated 142.430.072.832 byte, 300 GB altında. Tek sample kesilen production koşusunun monitor acceptance'ı değildir. Unit temporary directories temizlendi.

Sonraki tek iş: tam accepted-Base kanıtını yeniden hesaplayan host kernel controller/authorization producer'ı ve ölçülmüş guest transfer/launch akışını bağlamak. Actual guest handoff/build, Alp kernel phase installation/ownership, host after/checkpoint, controlled BIOS+UEFI boot ve complete fresh repeat-byte hâlâ açık. Yeni tam GCC/Coreutils/Base ve BLFS/Plasma/GL/profiles/ISO kabulü de açık; host reboot açıklaması gelmeden başka uzun production stage başlatılmaz.
