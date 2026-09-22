# alpbahOS — Güncel durum

Son güncelleme: 22 Eylül 2026

## Tamamlanan M1

- LFS 12.4-systemd x86_64 temel sistem, Linux `6.16.1-alpbahOS` ve GRUB 2.12 hazır.
- Son yerel artifact: `artifacts/alpbahOS-m1-final-v2.vhdx`.
- SHA-256: `07123bf1e653e8b735e6c68324fed20d2402f68ba39657d30a521738f37ade86`.
- QEMU BIOS ve OVMF UEFI açılışları `alpbahos login:` istemine kadar geçti.
- Hyper-V Gen2 açılışı, framebuffer konsolu ve `alpbahos login:` istemi kullanıcı görüntüsüyle doğrulandı.
- M2/BOOT-01 Gen1 testi: ayrı `alpbahOS-M2-Gen1` Hyper-V Generation 1 VM'i 2 GiB sabit RAM ile çalıştırıldı; kullanıcı `alpbahos login:` istemini gördüğünü doğruladı (22 Eylül 2026). DHCP/ping/reboot bu Gen1 VM'inde henüz doğrulanmadı.
- Hyper-V Default Switch üzerinden DHCP ve hosttan ping doğrulandı.
- Kontrollü `Running -> Off -> Running` testi sonrası heartbeat, yeni DHCP adresi ve ping tekrar geçti.
- FAT/ext4 bölümleri çevrimdışı `fsck` kontrolünden hatasız geçti.
- `/etc/shadow`, root kurtarma hesabı, systemd ağ kullanıcıları ve DHCP profili tamamlandı.

## Açık sınırlar

- Hyper-V Gen1 boot-to-login doğrulandı; Gen1 ağ/reboot kapsamı açık.
- Secure Boot geliştirme VM'inde kapalı.
- Grafik masaüstü, BLFS zinciri, canlı ISO ve kurucu henüz yok.
- Büyük VHDX/ISO/rootfs dosyaları Git'e eklenmez.

## Sıradaki teknik iş

BOOT-01 Gen1 kolunu ayrı test VM'inde doğrula; ardından BLFS-01 için sertifika, ağ, grafik ve ses bağımlılıklarına geç. Her çalışmaya başlamadan `AGENTS.md`, bu dosya, `docs/DECISIONS.md`, `docs/MASTER_PLAN.md` ve `docs/WORKLOG.md` okunur.

## Kullanıcı sprinti M2

### Başladı — 22 Eylül 2026

- Sahip: Codex (LFS/BLFS, Gen1 doğrulaması, `alp` entegrasyonu ve Plasma); kullanıcı istemi M2 uygulamasına başladı.
- Ortam: Windows host `C:\alpbahOS`, branch `main`; Builder Ubuntu `sa@172.28.174.11`; mevcut kaynak imaj M1 final VHDX.
- Gen1 giriş istemi doğrulandı; VM `alpbahOS-M2-Gen1`, Generation 1, 2 GiB sabit RAM. Test kaynağı M1 VHDX'in ayrı `F:\alpbahOS-build\vms\alpbahOS-M2-Gen1\alpbahOS-M2-Gen1.vhdx` kopyasıdır.
- `alp` (Claude prototipi, Python 3.13): LFS chroot'unda core yöntemi gerçek `/` altında test fixture'ını kurdu, DB'ye yazdı ve kaldırınca dosya/DB girdisi temizlendi. Recipe yöntemi htop checksum doğrulaması, configure ve make/install ile `/tmp/alp-root` test köküne kuruldu; **kritik hata bulundu:** htop ELF `/usr/bin/htop` modu `0644` oldu, çalıştırılamadı. Claude'un kod sahipliği nedeniyle motor dosyası burada değiştirilmedi. Ayrıntı ve log: `docs/WORKLOG.md`, Builder `/mnt/lfs/tmp/alp-root/var/log/alp/htop-3.3.0.build.log`.
- BLFS ağ/TLS kesiti geçti: libtasn1, libunistring, libidn2, p11-kit (66/67 test; `test-path` SIGSEGV), make-ca, libpsl ve cURL LFS rootfs'ye kuruldu. CA bundle üretildi ve LFS chroot'unda gerçek `curl https://www.example.com/` doğrulandı. Ayrıntı `docs/M2_BLFS_MANIFEST.md` ve `docs/WORKLOG.md`.
- D-Bus rootfs'de 1.16.2 mevcut. Linux-PAM 1.7.1 kaynağı MD5 doğrulandı ve Meson/Ninja build geçti; PAM install + systemd/shadow yeniden yapılandırması bağlı atomik adım olarak bekliyor.
- Sonraki iş: alp dosya modu bulgusunu Claude'a düzeltme için devret; PAM+systemd/logind zincirini tamamla, sonra polkit, DRM/Mesa/Wayland, PipeWire ve Qt6/Plasma.

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
