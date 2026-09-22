# alpbahOS — Güncel durum

Son güncelleme: 22 Eylül 2026

## Tamamlanan M1

- LFS 12.4-systemd x86_64 temel sistem, Linux `6.16.1-alpbahOS` ve GRUB 2.12 hazır.
- Son yerel artifact: `artifacts/alpbahOS-m1-final-v2.vhdx`.
- SHA-256: `07123bf1e653e8b735e6c68324fed20d2402f68ba39657d30a521738f37ade86`.
- QEMU BIOS ve OVMF UEFI açılışları `alpbahos login:` istemine kadar geçti.
- Hyper-V Gen2 açılışı, framebuffer konsolu ve `alpbahos login:` istemi kullanıcı görüntüsüyle doğrulandı.
- Hyper-V Default Switch üzerinden DHCP ve hosttan ping doğrulandı.
- Kontrollü `Running -> Off -> Running` testi sonrası heartbeat, yeni DHCP adresi ve ping tekrar geçti.
- FAT/ext4 bölümleri çevrimdışı `fsck` kontrolünden hatasız geçti.
- `/etc/shadow`, root kurtarma hesabı, systemd ağ kullanıcıları ve DHCP profili tamamlandı.

## Açık sınırlar

- Hyper-V Gen1 testi BOOT-01 altında açık.
- Secure Boot geliştirme VM'inde kapalı.
- Grafik masaüstü, BLFS zinciri, canlı ISO ve kurucu henüz yok.
- Büyük VHDX/ISO/rootfs dosyaları Git'e eklenmez.

## Sıradaki teknik iş

BOOT-01 Gen1 kolunu ayrı test VM'inde doğrula; ardından BLFS-01 için sertifika, ağ, grafik ve ses bağımlılıklarına geç. Her çalışmaya başlamadan `AGENTS.md`, bu dosya, `docs/DECISIONS.md`, `docs/MASTER_PLAN.md` ve `docs/WORKLOG.md` okunur.

## Kullanıcı sprinti M2

Bu bölüm günlük konuşmadaki sprint adını kullanır. `docs/MASTER_PLAN.md` içindeki tarihsel M02 paket prototipi numarasıyla karıştırılmamalıdır; o işin `alp` prototipi Claude tarafından ayrı repoda başlatılmıştır.

M2 hedefi, M1'de açılan metin tabanlı LFS sistemini ilk kullanılabilir grafik oturuma taşımaktır:

1. BOOT-01'i Hyper-V Gen1 testiyle kapat.
2. Sertifika/TLS, indirme araçları, D-Bus/polkit ve temel ağ katmanını kur.
3. Grafik, giriş, font ve PipeWire ses zincirini kurup ayrı ayrı doğrula.
4. Claude'un `alp` paket motorunu gerçek LFS köküne yerleştir; örnek paket için kur/güncelle/kaldır, kilit, checksum ve dosya sahipliği testlerini geçir.
5. Hafif KDE Plasma/KWin oturumunu Hyper-V'de aç; Türkçe Q, ağ, ses ve yeniden başlatma testlerini yap.
6. Doğrulanmış `alpbahOS-m2.vhdx`, checksum ve M2 raporu üret.

Tahmin: ilk Plasma giriş ekranı için 4-7 takvim günü; test edilmiş M2 VHDX için 7-10 gün. Bu tahmin günlük yaklaşık 5 saat, hafta sonu daha uzun çalışma ve Claude katkısı varsayar.

## Artifact saklama kuralı

- Windows'ta yalnız `artifacts/alpbahOS-m1-final-v2.vhdx` son M1 teslimi olarak tutulur.
- Builder'da `alpbahOS-m1-clean.raw` düzenlenebilir temiz kaynak, `alpbahOS-m1-final-v2.vhdx` ise doğrulanmış teslim olarak tutulur.
- Eski boot/debug/framebuffer denemeleri ve geçici loglar M1 kapanışında temizlenmiştir.
