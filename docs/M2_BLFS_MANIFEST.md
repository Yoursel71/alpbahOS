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
| 1 | libtasn1 | 4.20.0 | `https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.20.0.tar.gz` | MD5 eşleşti; `make check` ve install geçti |
| 2 | libunistring | 1.3 | `https://ftp.gnu.org/gnu/libunistring/libunistring-1.3.tar.xz` | MD5 eşleşti; tam `make check` ve install geçti |
| 3 | libidn2 | 2.3.8 | `https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz` | MD5 eşleşti; `make check` ve install geçti |
| 4 | p11-kit | 0.25.5 | `https://github.com/p11-glue/p11-kit/releases/download/0.25.5/p11-kit-0.25.5.tar.xz` | MD5 eşleşti; 66/67 test geçti, `test-path` SIGSEGV istisnası; install geçti |
| 5 | make-ca | 1.16.1 | `https://github.com/lfs-book/make-ca/archive/v1.16.1/make-ca-1.16.1.tar.gz` | MD5 eşleşti; install + `/usr/sbin/make-ca -g` CA bundle üretimi geçti |
| 6 | libpsl | 0.21.5 | `https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz` | MD5 eşleşti; Meson/Ninja test ve install geçti |
| 7 | cURL | 8.15.0 | `https://github.com/curl/curl/releases/download/curl-8_15_0/curl-8.15.0.tar.xz` | BLFS kaynağıyla aynı MD5; OpenSSL backend, `/etc/ssl/certs` CA yolu; build/install geçti |
| 8 | TLS doğrulama | — | `curl --fail https://www.example.com/` | LFS chroot'unda geçti; log `curl-tls-test.log` |

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

## 22 Eylül oturum kanıtı

- CMake `4.1.0`: BLFS 12.4 kaynağı `https://cmake.org/files/v4.1/cmake-4.1.0.tar.gz`, MD5 `80ae27faba5068c8ec12c77bf00e6db3`; LFS chroot'unda build/install geçti, `cmake --version` doğrulandı. Log: `/mnt/lfs/tmp/alp-logs/cmake-bootstrap.log`.

- D-Bus: M1 rootfs'de `dbus-daemon 1.16.2` zaten mevcut.
- Linux-PAM: `1.7.1`, MD5 `92812d7dd414d816fba8d649e84e68ca`; LFS chroot'unda Meson/Ninja build geçti. Install + PAM yapılandırması ve systemd/shadow yeniden kurulumu aynı bağlı adım olarak bekliyor.
- Linux-PAM install tamamlandı; minimal `system-account`, `system-auth`, `system-session`, `system-password` ve restrictive `other` dosyaları oluşturuldu. Systemd 257.8 `-D pam=true` ile yeniden derlenip kuruldu; `/usr/lib/security/pam_systemd.so` ve `systemd-logind` doğrulandı.
- Duktape `2.7.0` (MD5 `b3200b02ab80125b694bae887d7c1ca6`) ve GLib `2.84.4` (MD5 `5655d0ff809b98dd77c02490609fadde`) build/install geçti. Polkit `126` (MD5 `db4ce0a42d5bf8002061f8e34ee9bdd0`) `session_tracking=logind`, PAM ve LFS OS türüyle kuruldu. Polkit testleri dbusmock eksikliği nedeniyle çalıştırılmadı.
- ALSA-lib `1.2.14` (MD5 `d0efd7930da31f0034baddc0b993fa03`) GCC uyumlu test düzeltmesiyle `make check` ve install geçti. PipeWire `1.4.7` (MD5 `e151f5f67b2f09d0b37e0b9493111ca0`) `session-managers=[]` ile `ninja test` ve install geçti. Gerçek aygıt/ses çıkışı testi sonraki Hyper-V oturumunda.
- Grafik tabanı: libxml2 `2.14.5` (MD5 `59aac4e5d1d350ba2c4bddf1f7bc5098`), libdrm `2.4.125` (MD5 `3baec8e685510892b3355a7074baa874`) ve Wayland `1.24.0` (MD5 `fda0b2a73ea2716f61d75767e02008e1`) test/kurulum geçti. Mesa ve Qt/Plasma sonraki kesit.
- Mesa 25.1.8: MD5 `fe3eb39e8a3c6fbb36eb3da57be022e7`; Mako 1.3.10 ve PyYAML 6.0.2 Python bağımlılıkları kuruldu. Wayland yazılım yolu için `platforms=wayland`, `gallium-drivers=softpipe`, `vulkan-drivers=[]`, `glx=disabled`, `llvm=disabled` build/install geçti. `libEGL`, GLES ve DRI software sürücüleri bulundu. Qt/KWin/Plasma sonraki kesit.
- p11-kit test istisnası: 66/67 geçti; `common/test-path` SIGSEGV. Kurulum kanıtı logda tutuluyor.

Plasma için M1 kernel grafik, DRM, input ve sound yapılandırması ayrıca kontrol edilmeden donanım desteği varsayılmaz.
