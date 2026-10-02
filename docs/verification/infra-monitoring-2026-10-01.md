# Host izleme ve başarısızlıkta kapanış — 1 Ekim 2026

**Kısmi ilerleme; HAZIR kabulü değildir.** Önceki goal turu disk temizliğiyle ilerledi. Root temizlik/audit sonuçları hâlâ yok; canlı temizlik veya Builder doğrulanmadı. Alp kaynağı aynı SHA-256 ile kaldı: `92d519212d161159f6f083008b14c7b5b22c2d3e7e60f49fe17d493538fe25b2`.

## Değişiklik ve doğrulama

- `host_monitor.py`: salt okunur CPU sıcaklığı, frekans, bellek, mevcut throttle sayaçları ve boot/cursor ile kernel izleme. Kararlılık komutu boyunca yaklaşık 10 saniyede, başlangıç/bitişte ayrıca örnek alınır. Kaydı yazdıktan sonra kernel hata, boot/sayaç değişikliği ve boş alan koşulları değerlendirilir. Eksik sayaç `unavailable` kalır; frekans dalgalanması throttle diye sunulmaz.
- `buildctl.py`: bozuk izleme baseline'ında VM başlamaz. Hata durumunda yerel SSH process group'u kapanır; guest kanıtı toplanmaya çalışılır, sonra poweroff/PID kontrolü yapılır. Toplama/kapanış hataları outcome'a girer ve checkpoint'i engeller. Launch/sync/authorization hatalarında da kapanış denenir. Diskler korunur, canlı snapshot alınmaz.
- `package_stage.py`: manifest capture'a manifestteki epoch ve sabit locale/UTC açıkça aktarılır; önceki yordam caller ortamına bağlıydı. Smoke/stability yaşam döngüsü de sabit ortam/umask kullanır. Alp değiştirilmedi.

**22 host testi geçti:** `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-monitor-tests-20261001.log`; SHA-256 `1cdf3992ac52d93ebc75bf677268455f085dbc1da723d91f31c77e2f3b0c6493`. Journal/cursor, hardware fault, boot/throttle, komut durdurma ve hata kanıtı/kapanışı fixture'larla doğrulandı. Epoch fixture'ı gerçek manifest/archive araçlarını çalıştırır; derleme/chown/extraction taklit edilir. Gerçek guest smoke, hata/kapanış, stability ve uzun suite kabulü değildir. Python AST/Bash syntax ve tracked whitespace kontrolleri geçti.

Frozen root plan/kod değişmedi: plan SHA-256 `67c3b0c8cbd5b660199f60ce30cb7b633d7eae7584782fcad08057c7f55dd675`; kod SHA-256 `b5939acdfbb2b1334e582f0555839900e2f43f3691e2b40bd7f2a1c8c7e2a279`. Kullanıcıya verilen komut değişmedi.

## Host journal bulgusu

Salt okunur monitor exit 1: `journalctl` exit 0 olmasına rağmen stderr şu root-owned kullanıcı journal'ını bozuk olarak bildirip atlıyor:

```text
/var/log/journal/d74c6b44a0f74e65b6deff7f009e91c0/user-1000@00000000000000000000000000000000-0000000000000000-0000000000000000.journal
```

Dosya 16.777.216 byte, UID 0/GID 190/mode 0640; değiştirilmedi/silinmedi/taşınmadı. `journalctl --verify --file <bu tam yol>` exit 1: `Failed to open files: Bad message`. Nedeni ve başlama zamanı bilinmiyor; donanım/OC arızası veya temizliğin sebep olduğu bozulma kanıtı değildir.

Anlık Tctl **37,375°C**, MemAvailable **19.210.096 KiB**. Throttle sayaçları görünmüyor; temiz throttle kabulü yok. Kernel sorgusu 1.012 okunabilir kayıt verdi; stderr nedeniyle temiz journal kabulü verilmedi.

- Gözlem: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-monitor-observation-20261001.json`; SHA-256 `9efe6d1d91be0b170a421b483419af6cfd96fb1a208d73a9f70da394f18511a6`.
- Verify: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-journal-verify-20261001.log`; SHA-256 `0e1431dcafe01c131fb6a15fbe114bb2fb548dc1be6c03ec485da32dfcd86ad3`.

Root temizliği/audit ve journal değerlendirmesi kullanıcı yönetici adımıdır. Alp zaman düzeltmesi engine sahibinde; ardından güncel guest smoke kabulü gerekir. m64+m32 seçili; “OC tamam, başla” yok. SBU/stability/toolchain/ağır derleme yapılmadı. Üretim toolchain/79 paket/kernel/BLFS/Plasma/profiles/ISO tarifleri ve gerçek kabulü açık; bu izleme işi onların yerine geçmez.
