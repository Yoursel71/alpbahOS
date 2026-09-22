# M2 — LFS 12.4 ile uyumlu BLFS manifesti

Durum: Başlangıç manifesti; yalnız `[verified-lfs-12.4]` olarak işaretlenen paketler BLFS kitabında açıkça LFS 12.4 üzerinde bilinir olarak belirtilmiştir. Build/test başarıları `WORKLOG.md`'ye ayrıca kaydedilir.

## Platform sabitlemesi

- LFS: `12.4-systemd`, x86_64 (M1 mevcut rootfs).
- BLFS: `12.4-systemd`, sürüm sayfası `https://www.linuxfromscratch.org/blfs/view/12.4-systemd/`.
- Builder rootfs: `/mnt/lfs`; builder `/` Ubuntu 24.04 host'tur. Derleme komutları chroot'ta `/mnt/lfs` üzerinde, paket bazlı ayrı `/sources`/`build` ve log ile yürütülür.
- Kaynak checksum'ları indirmeden önce kitap sayfasındaki doğrulama bilgisine göre kayıt altına alınır. Bu ilk manifest URL ve sürümleri tanımlar; checksum eksik olan paket indirilmez.

## M1 Gen1 doğrulamasında görülen yönetim aracı açığı

- Guest içinden `networkctl status` DHCP lease'i doğruladı; aynı ekranda `ip` ve `sudo` komutları yoktu. Bu, minimal M1 imajındaki mevcut durumdur; M2 son kullanıcı imajına bırakılmayacak.
- M2 final paket kümesine `sudo` eklenecek. LFS 12.4 temel rootfs'de `iproute2` zaten kurulu (`/usr/sbin/ip`), fakat boot edilmiş M1 VHDX daha eski olduğundan guest'te `ip` görünmüyordu.

### M2 yönetim araçlarının sürüm kararı

| Paket | Sürüm | Kaynak | BLFS/LFS checksum | Durum |
|---|---|---|---|---|
| IPRoute2 | 6.16.0 | `https://www.kernel.org/pub/linux/utils/net/iproute2/iproute2-6.16.0.tar.xz` | MD5 `4bf5a10f287501ee8e8ebe00ef62b2c2` | Rootfs'de `/usr/sbin/ip` mevcut; test imajına aktarımda tekrar doğrulanacak |
| sudo | 1.9.17p2 | `https://www.sudo.ws/dist/sudo-1.9.17p2.tar.gz` | MD5 `dcbf46f739ae06b076e1a11cbb271a10` | `make check` geçti; kuruldu; PAM, `%wheel` kuralı ve `visudo -c` geçti. Builder `/mnt/lfs` rootfs'sinde `sa` hesabı yok; doğru imaj hesabına wheel üyeliği entegrasyonda yapılacak |
| ALSA Utilities | 1.2.14 | `https://www.alsa-project.org/files/pub/utils/alsa-utils-1.2.14.tar.bz2` | MD5 `d098c3d677ee80cf3d9f87783cce2e53` | `make check` 2/2 geçti; `aplay`, `arecord`, `alsamixer`, `speaker-test` kuruldu |

### Ses runtime paketleri

| Paket | Sürüm | Kaynak | MD5 | Durum |
|---|---:|---|---|---|
| Lua | 5.4.8 | `https://www.lua.org/ftp/lua-5.4.8.tar.gz` | `81cf5265b8634967d8a7480d238168ce` | BLFS shared-library yamasıyla kuruldu; `make test` geçti |
| libsndfile | 1.2.2 | `https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz` | `04e2e6f726da7c5dc87f8cf72f250d04` | GCC-15 ALAC düzeltmesiyle kuruldu; testler geçti |
| PipeWire | 1.4.7 | `https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/1.4.7/pipewire-1.4.7.tar.bz2` | `e151f5f67b2f09d0b37e0b9493111ca0` | `pw-cat=enabled`; build/test/install geçti; runtime I/O turu sessiz kaldı |
| WirePlumber | 0.5.10 | `https://gitlab.freedesktop.org/pipewire/wireplumber/-/archive/0.5.10/wireplumber-0.5.10.tar.bz2` | `2cbb662f91da2bdce31fa55bef5dfcf5` | Lua entegrasyonu; `ninja test` ve install geçti |

## İlk ağ/TLS kesiti

| Sıra | Paket | BLFS sürümü | Kaynak | Durum |
|---:|---|---|---|---|
| 1 | libtasn1 | 4.20.0 | `https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.20.0.tar.gz` | MD5 eşleşti; `make check` ve install geçti |
| 2 | libunistring | 1.3 | `https://ftp.gnu.org/gnu/libunistring/libunistring-1.3.tar.xz` | MD5 eşleşti; tam `make check` ve install geçti |
| 3 | libidn2 | 2.3.8 | `https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz` | MD5 eşleşti; `make check` ve install geçti |
| 4 | p11-kit | 0.25.5 | `https://github.com/p11-glue/p11-kit/releases/download/0.25.5/p11-kit-0.25.5.tar.xz` | MD5 ve install geçti; ilk 66/67 koşusundaki `test-path` çökmesi build UID'sinin hedef `/etc/passwd` içinde olmamasıyla açıklandı; hedef `tester` UID 101 ile alt testler 9/9 geçti; ayrıntı WORKLOG |
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
- Duktape `2.7.0` (MD5 `b3200b02ab80125b694bae887d7c1ca6`) ve GLib `2.84.4` (MD5 `5655d0ff809b98dd77c02490609fadde`) build/install geçti. Polkit `126` (MD5 `db4ce0a42d5bf8002061f8e34ee9bdd0`) `session_tracking=logind`, PAM ve LFS OS türüyle kuruldu. Geçici system bus/polkitd ve test kuralıyla `tester` → `pkexec /usr/bin/id` uçtan uca senaryosu `uid=0(root)`, exit 0 verdi; tam dbusmock suite ve grafik auth-agent akışı henüz çalıştırılmadı. Ayrıntı/log: WORKLOG.
- ALSA-lib `1.2.14` (MD5 `d0efd7930da31f0034baddc0b993fa03`) GCC uyumlu test düzeltmesiyle `make check` ve install geçti. PipeWire `1.4.7` (MD5 `e151f5f67b2f09d0b37e0b9493111ca0`) `-D pw-cat=enabled` ile yeniden build/test/install edildi. Bunun için libsndfile `1.2.2` (MD5 `04e2e6f726da7c5dc87f8cf72f250d04`) GCC-15 ALAC uyum düzeltmesiyle build/test/install edildi; `pw-cat`, `pw-play`, `pw-record` mevcut.
- WirePlumber `0.5.10` MD5 `2cbb662f91da2bdce31fa55bef5dfcf5` ve Lua `5.4.8` MD5 `81cf5265b8634967d8a7480d238168ce` (BLFS shared-library patch'iyle) kuruldu; Lua `make test`, WirePlumber `ninja test` geçti. ALSA Utilities `1.2.14` MD5 `d098c3d677ee80cf3d9f87783cce2e53` kuruldu; `make check` 2/2 geçti.
- Builder kernel `snd-aloop` modülü geçici yüklenerek hedef chroot'tan 48 kHz stereo 16-bit ALSA playback (`aplay hw:Loopback,0,0`) → capture (`arecord hw:Loopback,1,0`) roundtrip yapıldı. Geçti: 144000 kare, peak 12000, RMS 7046.61, PCM SHA-256 `5d8f31349bd312226a5f4c60fe6a313b32311effdc5bee24c6751997c91c93eb`. Bu ALSA sanal PCM kanıtıdır; fiziksel hoparlör/mikrofon değildir. Modül testten sonra kaldırıldı.
- PipeWire/WirePlumber oturumu Loopback kartını buldu; otomatik sink ve source ikisi de device 0'ı kullandı. `pw-play` → `pw-record` sessiz WAV aldı (peak/RMS 0); device 1'i PipeWire source olarak ekleme denemesi çalışan PCM node üretmedi. Paket testleri geçti, PipeWire I/O bu test yolunda başarısız kaldı ve M06 ses kapısı kısmi. Loglar `/mnt/lfs/tmp/alp-logs/` ve `/mnt/lfs/tmp/m2-*` altında.
- Grafik tabanı: libxml2 `2.14.5` (MD5 `59aac4e5d1d350ba2c4bddf1f7bc5098`), libdrm `2.4.125` (MD5 `3baec8e685510892b3355a7074baa874`) ve Wayland `1.24.0` (MD5 `fda0b2a73ea2716f61d75767e02008e1`) test/kurulum geçti. Mesa ve Qt/Plasma sonraki kesit.
- Mesa 25.1.8: MD5 `fe3eb39e8a3c6fbb36eb3da57be022e7`; Mako 1.3.10, PyYAML 6.0.2; `platforms=wayland`, `gallium-drivers=softpipe`, `vulkan-drivers=[]`, `glx=disabled`, `llvm=disabled` build/install geçti. EGL/GLES surfaceless smoke testi software rendering/readback yaptı (`GL_RENDERER=softpipe`, pixel `64,128,191,255`); test Wayland compositor oturumunu doğrulamaz. Kurulu rootfs'de `swrast_dri.so`/`kms_swrast_dri.so` bulunmadı; eski manifest iddiası düzeltilmiştir. Log `/mnt/lfs/tmp/alp-logs/mesa-egl-smoke.log`.
- p11-kit test istisnası kapatıldı: ilk `common/test-path` çökmesi gerçek trust-store arızası değil, build UID 1000/1001 için hedef passwd kaydı bulunmaması. `/path/expand` testinde `getpwuid_r()` kullanıcı bulamadıktan sonra test null sonucu korumasız kullandığı için SIGSEGV oluştu. Aynı dokuz path testi hedef `tester` UID 101 altında 9/9 geçti; `trust list --filter=ca-anchors` çalıştı. Log `/mnt/lfs/tmp/alp-logs/p11-kit-test-path-tester.log`.

Plasma için M1 kernel grafik, DRM, input ve sound yapılandırması ayrıca kontrol edilmeden donanım desteği varsayılmaz.
