# M2 — LFS 12.4 ile uyumlu BLFS manifesti

Durum: Başlangıç manifesti; yalnız `[verified-lfs-12.4]` olarak işaretlenen paketler BLFS kitabında açıkça LFS 12.4 üzerinde bilinir olarak belirtilmiştir. Build/test başarıları `WORKLOG.md`'ye ayrıca kaydedilir.

## Platform sabitlemesi

- LFS: `12.4-systemd`, x86_64 (M1 mevcut rootfs).
- BLFS: `12.4-systemd`, sürüm sayfası `https://www.linuxfromscratch.org/blfs/view/12.4-systemd/`.
- Builder rootfs: `/mnt/lfs`; builder `/` Ubuntu 24.04 host'tur. Derleme komutları chroot'ta `/mnt/lfs` üzerinde, paket bazlı ayrı `/sources`/`build` ve log ile yürütülür.
- Kaynak checksum'ları indirmeden önce kitap sayfasındaki doğrulama bilgisine göre kayıt altına alınır. Bu ilk manifest URL ve sürümleri tanımlar; checksum eksik olan paket indirilmez.

## İlk ağ/TLS kesiti

| Sıra | Paket | BLFS sürümü | Kaynak | Durum |
|---:|---|---|---|---|
| 1 | make-ca | 1.16.1 | `https://github.com/lfs-book/make-ca/archive/v1.16.1/make-ca-1.16.1.tar.gz` | Kurulmadı; CA verisi/build adımları ayrıca kontrol edilecek |
| 2 | libpsl | 0.21.5 | BLFS 12.4 `postlfs/libpsl.html` | cURL için güvenlik açısından önerilen bağımlılık; henüz sabit checksum alınmadı |
| 3 | cURL | 8.15.0 | `https://curl.se/download/curl-8.15.0.tar.xz` | Kitapta LFS 12.4 uyumlu; OpenSSL backend, `/etc/ssl/certs` CA yolu |
| 4 | TLS doğrulama | — | `curl https://www.example.com/` | Henüz çalıştırılmadı |

## `alp` entegrasyon kanıtı

- Paket yöneticisi sahibi Claude; ana repodaki dosya sahipliği kuralına göre motoru yeniden yazma/değiştirme yok.
- Kaynak: `Yoursel71/alpbahOS-alp`, checkout commit `f591c9770f0b90ab47dc31894d83b0ec7cbbd166`.
- Prototip: Claude dalındaki `docs/handoffs/claude/alp-prototype/alp.py`; LFS Python 3.13 üzerinde test edilecek.
- İlk recipe test girdisi `htop 3.3.0`, SHA-256 `a69acf9b42ff592c4861010fce7d8006805f0d6ef0e8ee647a6ee6e59b743d5c`. `alp install` test root'una indir/build/stage/merge; `list`, DB sahipliği ve `remove` testleri.
- Htop LFS 12.4 chroot'unda `ncurses` başlık/kütüphane gerektirir; eksik bağımlılık saptanırsa paket kaydı olmadan durur. Flatpak/GUI entegrasyonu bu dar test kapsamına girmez.

## Sonraki altyapı kesitleri

Sürümler BLFS 12.4 kitabının paket ve bağımlılık tablolarından build başlamadan tek tek sabitlenecek.

1. D-Bus, Linux-PAM, Polkit ve PAM ile logind destekli systemd varyantı.
2. Xorg/Wayland tabanı, libdrm, Mesa; giriş yöneticisi.
3. PipeWire/WirePlumber ve ALSA userspace.
4. Qt6 ve Plasma/KWin; önce düşük paket kümesi, sonra temiz kullanıcıyla oturum ölçümü.

Plasma için M1 kernel grafik, DRM, input ve sound yapılandırması ayrıca kontrol edilmeden donanım desteği varsayılmaz.
