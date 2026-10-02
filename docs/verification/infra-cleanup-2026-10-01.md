# Üç disk temizlik kaydı — 1 Ekim 2026

Kullanıcının yeni açık talimatı eski ISO/AlpbahOS artıklarını silip büyük milestone çıktılarının korunmasıdır; önceki mevcut imajları koruma sınırı bu temizlik kapsamında değişti. Host sudo işlemleri kullanıcıya bırakılmaya devam eder. Kaynak Git depolarına ve Claude ağacına yazılmadı.

## Yapılan temizlik

- İlk listede 136 eski/tekrarlanan ISO, VHDX ve SquashFS vardı: 134 dosya doğrudan silindi; kalan iki dosya sonraki dizin temizliğinde kalktı. Boyut toplamı Btrfs paylaşımları nedeniyle gerçek kazanım yerine geçmez.
- Eski Kali, Arch ve Windows kurulum ISO'ları ayrıca silindi; kullanıcı diğer dosyalarına temizlik uygulanmadı.
- 980 artık build/backup hedefi yetkisiz kullanıcıyla kaldırıldı. 199 hedef root izinleri nedeniyle kısmen kaldı; bunlar tamamlandı sayılmadı.
- 708 doğrulanmış duplicate kaynak/başarısız overlay dosyası kaldırıldı. Kaynak kopyaları aktif cache'e karşı byte SHA-256 ile eşleşti. Eski başarısız iki qcow2 katmanı mevcut disk backing chain'inde değildi; prepared ve aktif katmanlar korundu.
- Son başarılı D34 kökü **silinmedi**: `libwacom-20260930T193342Z-37efbf1e/after-ro`, UUID `c57a57dc-9b42-084a-8304-9151bfa384f9`, subvol 1447. Ledger COMPLETE: 79/79 resmi +196 supplemental, 156.181 owner. Ledger SHA-256 `10ea29d686afca620304185710ab9a3ae83b235b12f9c76a3dae678a82f4f961`.

| Disk | İlk boş alan | Son ölçüm | Son boş oran |
|---|---:|---:|---:|
| NVMe `/` | 22,33 GiB | **163,96 GiB** | **%34,57** |
| SSD | 65,91 GiB | **67,24 GiB** | **%60,15** |
| HDD | 126,17 GiB | **261,80 GiB** | **%57,24** |

Net boş alan artışı yaklaşık **279 GiB**. %15 engeli kalktı. Ölçüm `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-final-state.json`, SHA-256 `5844f9d559b2c0dd7f8cdee267a2ac6cf390a61cc88c8fe819eda5043ee0f558`.

## Korunan büyük çıktılar

Tam yollar, boyut/inode/device ve SHA-256 envanteri: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-retained-milestones.json`; SHA-256 `1534ae435636943fa85e5251194a015b414cefdaeeeb6486ae057368cb5420c0`.

| Çıktı | Konum / kapsam |
|---|---|
| M02/M05 Gen2 SSH tabanı | HDD `alpbahOS-build/artifacts/alpbahOS-m2-ssh-gen2-test.vhdx` |
| M07 Spectacle/masaüstü checkpoint'i | HDD `alpbahOS-build/backups/m07-build-tree-sata-pre-nvme-20260928/alpbahOS-m07-spectacle-test-20260928.vhdx` |
| M09 VirGL desktop adayı | NVMe `builds/m07/m09-live-iso-20260929T153622Z/alpbahOS-live-m09.iso` |
| M09 BIOS/UEFI ses/uygulama adayı | HDD `alpbahOS-build/m06-m10-progress-20260929/m06-audio-hda-final-20260929/artifacts/alpbahOS-live-m09.iso` |
| Son arşivlenmiş M10 adayı | HDD `alpbahOS-build/artifacts/m10-packagekit-simhelper-20260930/alpbahOS-live-m10-pk-sim-helper.iso`; alfa kabulü değildir |
| LFS geçici toolchain arşivi | HDD `alpbahOS-build/archives/lfs-temp-tools-12.4-systemd-20260926T172735Z.tar.xz` |

Bu kayıt yeni build/boot kabulü değildir. M01'in eski Windows yolu yerel Linux imajı varmış gibi gösterilmedi. Mevcut Builder, prepared qcow2 checkpoint'i, kaynak cache ve Git/Claude ağaçları korundu. Silinen ara ISO/stage yollarını referanslayan tarihsel raporlar için çıktılar artık elde tutulmuyor.

## Root'a ait kalan bölüm

**Henüz çalıştırılmadı / tamamlanmadı:** 1.117 eski D34 subvolume'u ve 199 artık dizin. Frozen plan `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-root.plan.json`; SHA-256 `67c3b0c8cbd5b660199f60ce30cb7b633d7eae7584782fcad08057c7f55dd675`. Plan son başarılı D34 kökünü, temiz bootstrap kökünü ve yukarıdaki büyük imajları dışarıda bırakır. Kalan eski replay snapshot'ları kaldırılınca tarihsel replay yolları yeniden yürütülebilir sayılmaz; güncel kök ve ledger referans olarak kalır.

Kullanıcının terminalinde çalıştıracağı komut:

```bash
sudo python3 /home/yrslf/alpbahOS-infra-rebuild/scripts/infra/cleanup-old-artifacts.py --plan /mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-root.plan.json --plan-sha256 67c3b0c8cbd5b660199f60ce30cb7b633d7eae7584782fcad08057c7f55dd675 --apply --host-audit
```

Betik önce live build/QEMU, izinli yol, mount/symlink, inode/device, korunan milestone ve ledger kontrollerini yapar; Btrfs UUID'lerini root yetkisiyle doğrular. Plan değişmişse veya kimlik/mount/writer koşulu bozulmuşsa durur. Root bölümünde `btrfs subvolume delete`, izinli eski dizin kaldırma ve `btrfs filesystem sync` kullanır; mount/chroot/host paket/CPU değişikliği yoktur. Önce/sonra root `rpm -Va` ve boot kernel journal çıktısını private log dizinine alır. Codex bu sudo komutunu çalıştırmadı.

Kod SHA-256 `b5939acdfbb2b1334e582f0555839900e2f43f3691e2b40bd7f2a1c8c7e2a279`. Dry-run 1.316 kalan hedefi, 7 korunan milestone/kökü doğruladı. Yetkisiz root apply ve değiştirilmiş plan hash'i reddedildi: `logs/cleanup-safety-checks.log`. Root kısmının uygulama kabulü ancak `cleanup-root-result.json` terminal `complete:true`, root audit logları ve son disk/kök doğrulamasıyla verilir. Sistem dosyası değişikliği varsa ayrı bildirilecek, gizlenmeyecek.

## Altyapı işine devam

Temizlik sonrası 90 kaynak + Builder cache hash doğrulaması geçti (`logs/cleanup-preserved-cache-check.log`). Aktif iki qcow2 `qemu-img check` exit 0. Python ve Bash statik syntax kontrolleri geçti; main HEAD/dal/342 dirty kayıt ve Claude temizliği aynı.

Temizlik sonrası salt okunur host karşılaştırması exit 0: yeni okunabilir missing/system RPM farkı yok. Kanıt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/host-compare-1790831327824561757.json`, SHA-256 `68b68be57843a4347dc7f4d4b363f30421b9666a749834f71be38316da24cafa`. Bu, ayrıcalıklı tam RPM temizliği kabulü değildir; root audit henüz yok. Son kontrolde `cleanup-root-result.json` ve `root-host-audit-after.json` bulunmadı, canlı temizlik işlemi görülmedi; kalan root bölümü tamamlandı sayılmadı.

13 ardından 15 sınır/regression testi geçti (`logs/infra-boundary-tests-after-cleanup.log`, son SHA-256 `e8b8442dd0d56ba16db81656c8610afce5256b5023cbe5171e7c57254d43ca66`). Yeni kontroller:

- `ERROR`, `UNRESOLVED`, `XPASS`, eksik test bileşeni ve yarım summary başarı sayılmaz. GCC istisnası kitap ve sabit kaynakta doğrulanan `gcc.target/i386/pr90579.c` dört scan-assembler FAIL'iyle sınırlıdır; yanlış `gcc.dg` yolu düzeltildi. [LFS 12.4 GCC](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/gcc.html).
- Güncel girdi/Alp/epoch ile iki ham DB hash'i eşleşmeden Faz 1 acceptance makbuzu oluşmaz; makbuz yokken OC/ABI bayrakları verilse bile Phase 2 VM açamaz. Başarısız smoke DB kanıtı da toplanır; eski makbuz yeni deneme başında arşivlenir.
- Kullanıcı sahipli boş dosya root audit sayılmaz: root-owned metadata/log hash'i, UID, boot, yaş, gerçek komut ve tam sonuç kontrol edilir. Root'a ait cache geçmişi /usr bozulmasını gizlemez.

Bu testler host fixture'larıdır; gerçek GCC/glibc uzun suite kabulü veya yeni guest smoke kabulü değildir. Alp kaynak pini hâlâ aynı ve deterministik DB engeli sürüyor; ortak smoke refaktörü guest'te henüz çalıştırılmadı. m64+m32 seçili; **“OC tamam, başla” verilmedi**, ağır derleme başlamadı. Üretim 79 paket/BLFS/ISO tarifleri de açık.
