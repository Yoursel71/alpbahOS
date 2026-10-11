# Linux 6.16.1 kernel config hazırlığı — 11 Ekim 2026

Sahip Codex; kapsam `scripts/infra-kernel-config.py`, odaklı testler ve durum/kanıt belgeleri. Canlı üretim controller/QEMU bulunmadı. Host kesintisi açıklaması beklerken yalnız bağımsız config hazırlığı ilerletildi; yeni uzun üretim build başlatılmadı.

## Değişiklik ve sınır

Yardımcı deterministik `fragment` üretir ve `verify --config <absolute-path>` ile gerçek Kconfig çıktısını denetler. Mevcut fragmentin 26 seçeneğine LFS 12.4-systemd, QEMU serial console ve seçilen ABI için gereksinimler eklenir; toplam 62 seçenek. IA32 etkin, x32 kapalı; gerekli root/virtio/DRM/framebuffer ve systemd seçenekleri çözümlenmiş değerleriyle zorunlu. Built-in gereken sürücü için `m` kabul edilmez. Alias, fragment hash değişimi, duplicate/malformed semboller, yanlış sürüm/mimari ve dependency nedeniyle düşen seçenekler reddedilir.

Çıktı `CONFIG_VERIFIED` ve açık config-only scope taşır. `expected_source_sha256` beklenen pini bildirir; yardımcı kendi başına source archive doğrulaması yapmış gibi davranmaz. Gelecek guest kernel controller helper baytlarını, accepted Base parent, gerçek kaynak/compiler/payload/sahiplik ve boot kanıtlarını ayrıca bağlamak zorunda. Kernel runner, modül/kernel derlemesi, root kurulumu, boot, gerçek ABI kabulü veya aşama kabulü bu işte yok. Host probe config başlığındaki compiler GCC 16.2.1; gelecekteki guest GCC 15.2 kabulünü kanıtlamaz. Bağımsız ajan incelemesi yapılmadı.

Base canonical girdi digest'i `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306` değişmedi. Helper mevcut Base input enumeration dışında, scripts kökünde; gelecekteki kernel yürütücüsü bunu ayrı SHA ile bağlamalı. Accepted checkpointler ve kesilmiş imajlar değiştirilmedi.

## Gerçek kaynak probe'u

Checksum-doğrulanmış `/mnt/alpbahOS-data/alpbahos-infra-rebuild/cache/linux-6.16.1.tar.xz` geçici `/tmp` ağacına yetkisiz açıldı. Kontrollü PATH/locale/timezone, ayrı HOME/O dizini ve sabit SOURCE_DATE_EPOCH kullanıldı. Sıra: tar → `make ARCH=x86_64 x86_64_defconfig` → upstream `scripts/kconfig/merge_config.sh -m` → `make ARCH=x86_64 olddefconfig` → son yardımcıyla verify. Beş komut exit 0; 62 seçenek PASS. Küçük native Kconfig yardımcı derlemesi config hazırlığıdır; kernel/modül derlenmedi. Disk ve ayrılan alan kontrolleri korundu; geçici ağaç finally ile temizlendi. Önceden pinned kaynak imza kanıtı mevcut; bu probe archive SHA'sını yeniden doğruladı, yeni signature verification yapmadı.

Kanıt kökü `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/`; final receipt `kernel-config-probe-1791699939337780987.json`. Receipt-bound kaynak/helper/config/log hashleri ayrıca yeniden kontrol edildi.

| Nesne | SHA256 |
|---|---|
| Linux 6.16.1 source archive | `ea43491bc7ace1e414b3b2d957f8cf96e7049155123f0acce798accf8da1acba` |
| Mevcut `infra-required.config` | `0af395c208845c45149c6b37a68f4dc71d33371797a087ee9367b57991a2d42c` |
| Son helper | `e32b8ca5e30067870b6780408b19d1d32898d5b17e72f111c464d56aa17d70e4` |
| Üretilen combined fragment | `dac13efa0bc68eb3f089258ad2f28e0305a395a6b2891923e879aee87aba1ef8` |
| Final `.json` receipt | `7d7144b0612e3e706c45f81722a161b751920a6992d5af8ea5a322e98c9076a9` |
| Final `.config` | `e92e59baa353e9afab82a7f410fa82ee7fe6a194cbb909b02dbe1a8d9d8750a9` |
| Final `.log` | `6b55f424ef990300b64c4ccd4b1995cf3633e85977eda8eb2352265bc2ade5fd` |

İlk probe `1791699620083268612`, managed runtime'a açılan upstream source symlink'i yüzünden space guard'da durdu. Yalnız tar çalıştı; geçici ağaç kaldırıldı, koruma değiştirilmedi. Probe /tmp'a taşındı. İkinci `1791699816620680257` kaynak config üretimini tamamladı, fakat ilk doğrulayıcı yanlış `Linux/x86` başlığı ve üst harf-only sembol varsayımıyla reddetti. Gerçek çıktı `Linux/x86_64`, geçerli font sembolleri `FONT_8x8`/`FONT_8x16`; parser/header düzeltildi ve font regresyonu eklendi. Ham ilk kanıtlar korundu; final probe son helper ile baştan tekrarlandı. Hatalı ön denemeler kabul diye sunulmadı.

## Testler ve sonraki adım

- 8 odaklı unittest PASS, 0.005 saniye.
- `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v`: 411 test, 2 skip, PASS, 92.354 saniye. Log `infra-full-tests-kernel-config-20261011.log`, SHA256 `68aa5d34e859aa7518bf95d9a9d2b69e4da78e5de5b15e87d7dd0cbc43141bf7`.
- Python bytecode compilation ve diff whitespace kontrolü PASS.
- `python3 docs/handoffs/claude/tools/check_docs.py`: exit 1, mevcut 31 tarihsel bulgu (1 broken-link, 19 commit-ref, 10 decision-ref, 1 stale-term). Yeni rapor/config işi bulgusu yok; belge suite temiz diye sunulmaz. Log `kernel-config-doc-check-20261011.log`.

Son kontrol: root/SSD/HDD available space yaklaşık %18.69/%20.31/%16.72; üçü de %15 üstünde. Canlı üretim controller/VM yok. Reboot açıklaması sorusu bekliyor; yeni uzun build koruması sürüyor. Tam Base/GCC/Coreutils ve fresh repeat-byte kabulü henüz yok. Sonraki bağımsız uygulama işi, accepted Base ve host güvenlik kapılarıyla bağlanan kernel yürütücüsüdür; gerçek üretim ancak gerekli önceki kabullerden sonra başlatılabilir.
