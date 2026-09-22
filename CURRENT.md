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
