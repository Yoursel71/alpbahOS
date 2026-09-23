# alpbahOS — Güncel durum

Son güncelleme: 23 Eylül 2026

## Tamamlanan M1

- LFS 12.4-systemd x86_64 temel sistem, Linux `6.16.1-alpbahOS` ve GRUB 2.12 hazır.
- Son yerel artifact: `artifacts/alpbahOS-m1-final-v2.vhdx`.
- SHA-256: `07123bf1e653e8b735e6c68324fed20d2402f68ba39657d30a521738f37ade86`.
- QEMU BIOS ve OVMF UEFI açılışları `alpbahos login:` istemine kadar geçti.
- Hyper-V Gen2 açılışı, framebuffer konsolu ve `alpbahos login:` istemi kullanıcı görüntüsüyle doğrulandı.
- M2/BOOT-01 Gen1 testi: ayrı `alpbahOS-M2-Gen1` Hyper-V Generation 1 VM'i 2 GiB sabit RAM ile çalıştırıldı; kullanıcı `alpbahos login:` istemini ve reboot öncesi `networkctl status` içindeki `eth0` DHCP adresini (`172.28.165.181/20`, gateway/DNS `172.28.160.1`) ekran görüntüsüyle doğruladı. Kontrollü reboot + yeniden login sonrası hostta aynı VM NIC MAC (`00-15-5D-00-02-06`) yeni `172.28.171.186` adresinde göründü; ping 3/3, TTL 64 geçti. BOOT-01 Gen1 ağı/reboot'u doğrulandı.
- Hyper-V Default Switch üzerinden DHCP ve hosttan ping doğrulandı.
- Kontrollü `Running -> Off -> Running` testi sonrası heartbeat, yeni DHCP adresi ve ping tekrar geçti.
- FAT/ext4 bölümleri çevrimdışı `fsck` kontrolünden hatasız geçti.
- `/etc/shadow`, root kurtarma hesabı, systemd ağ kullanıcıları ve DHCP profili tamamlandı.

## M1 kapanışındaki açık sınırlar (tarihsel kayıt)

- M1 kapanış anındaki tarihsel not: Hyper-V Gen1 boot-to-login doğrulanmış, ağ/reboot kapsamı açıktı. Bu açık nokta M2 testinde sonradan kapatıldı (aşağıdaki M05 kanıtı).
- Secure Boot geliştirme VM'inde kapalı.
- M1 kapanış anında grafik masaüstü, BLFS zinciri, canlı ISO ve kurucu henüz yoktu; sonraki BLFS ilerlemesi aşağıda sprint M2 altında kayıtlıdır.
- Büyük VHDX/ISO/rootfs dosyaları Git'e eklenmez.

## M1 kapanışında sıraya konan iş (tarihsel kayıt)

Plan, BOOT-01 Gen1 kolunu ayrı test VM'inde doğrulayıp ardından BLFS-01 sertifika, ağ, grafik ve ses bağımlılıklarına geçmekti. Gerçek güncel durum aşağıdaki sprint M2 ve resmî M00–M12 tablolarında tutulur.

## Kullanıcı sprinti M2

### Başladı — 22 Eylül 2026

- Sahip: Codex (LFS/BLFS, Gen1 doğrulaması, `alp` entegrasyonu ve Plasma); kullanıcı istemi M2 uygulamasına başladı.
- Ortam: Windows host `C:\alpbahOS`, branch `main`; Builder Ubuntu `sa@172.28.174.11`; mevcut kaynak imaj M1 final VHDX.
- Gen1 giriş istemi doğrulandı; VM `alpbahOS-M2-Gen1`, Generation 1, 2 GiB sabit RAM. Test kaynağı M1 VHDX'in ayrı `F:\alpbahOS-build\vms\alpbahOS-M2-Gen1\alpbahOS-M2-Gen1.vhdx` kopyasıdır.
- `alp` htop recipe'i düzeltme commit'i `a82f872` ile test köküne yeniden kuruldu: ELF modu `0755`, `htop 3.3.0 --version` geçti; `alp remove` dosya ve DB kaydını temizledi. Ayrıntı/log ve checksum `docs/WORKLOG.md` içinde.
- BLFS ağ/TLS kesiti geçti: libtasn1, libunistring, libidn2, make-ca, libpsl ve cURL LFS rootfs'ye kuruldu. `p11-kit` ilk test koşusundaki `test-path` SIGSEGV'in hedef rootfs'de bulunmayan build UID'sinden kaynaklandığı araştırıldı; mevcut `tester` kullanıcısıyla 9/9 path alt testi geçti. CA bundle üretildi, `trust list` çalıştı ve önceki LFS chroot TLS testi geçti. Ayrıntı `docs/M2_BLFS_MANIFEST.md` ve `docs/WORKLOG.md`.
- D-Bus 1.16.2; Linux-PAM 1.7.1, `pam_systemd.so`, systemd-logind/systemd 257.8 rootfs'ye kuruldu. Minimal `/etc/pam.d/system-*` yapılandırması var; PAM+logind kurulumu tamamlandı.
- Polkit zinciri kuruldu ve gerçek `pkexec` uçtan uca senaryosu geçti: geçici system D-Bus + polkitd, yalnız `tester` → `/usr/bin/id` için test kuralı; sonuç `uid=0(root)`, exit 0. Bu, test kuralıyla izin yolunu kanıtlar; etkileşimli auth agent/varsayılan kimlik doğrulama akışını kanıtlamaz.
- Ses altyapısı genişletildi: ALSA-lib, ALSA Utilities, libsndfile, PipeWire (`pw-cat` açık), Lua ve WirePlumber LFS rootfs'ye kuruldu; paket testleri geçti. Builder kernelindeki geçici `snd-aloop` ile ALSA PCM playback→capture roundtrip geçti (144000 kare, peak 12000, RMS 7046.61). WirePlumber ile geçici PipeWire null sink'e playback ve monitor-source capture da geçti (48 kHz stereo, 243712 kare, peak 12000, RMS 6522.08). Bunlar sanal testlerdir; ALSA aygıtına yönlendirme ve fiziksel hoparlör/mikrofon doğrulanmadı.
- Yönetim araçları: `iproute2` zaten LFS rootfs'de (`/usr/sbin/ip`), eski M1 VHDX guest'inde yok. `sudo 1.9.17p2` derlenip test edildi; PAM, `%wheel` sudoers kuralı ve `visudo -c` geçti. M2 aday VHDX oluşturulurken M1 `sa` hesabı/parola özeti korundu ve `sa` `wheel` grubuna eklendi.
- Grafik/masaüstü bileşenleri: libxml2 2.14.5, libdrm 2.4.125, Wayland 1.24.0, Mesa softpipe, Qt 6.9.2 ve KDE/Plasma 6.4.4 bileşenleri kuruldu. KWin, Workspace, Plasma Integration ve Breeze QQC2 build/install geçti; temiz kaynak arşivinde dry-run doğrulanan Wayland-only yamaları repoda. Gerçek Wayland/Plasma oturumu henüz çalıştırılmadı.
- Mesa 25.1.8 softpipe yolu build/install edildi; son dosya sistemi incelemesinde `swrast_dri.so`/`kms_swrast_dri.so` bulunmadı. Buna rağmen gerçek surfaceless EGL/GLES smoke testi geçti: `GL_RENDERER=softpipe`, readback pikseli `64,128,191,255`. Gerçek Wayland/compositor oturumu hâlâ sınanmadı.
- CMake 4.1.0, Qt 6.9.2 alt bileşenleri ve KF6/Plasma bağımlılıkları kuruldu. Shared-mime-info testinde 9/10 geçti; `test-mime` 30 saniyelik test sınırında başarısız kaldı, buna karşın install/database generation geçti. Bu başarısız test saklanmıyor; kapsamı `docs/WORKLOG.md`'de kayıtlıdır.
- LFS rootfs'de `/etc/profile` yoktu; bu nedenle `/opt/qt6/bin` ve masaüstü ortam değişkenleri login kabuğuna gelmiyordu. Login profili, Qt6/KF6 profile parçaları ve dynamic-loader yolları eklendi; QMake 6.9.2 ve QCA 2.3.10 artık login ortamında çalışıyor.

Bu bölüm günlük konuşmadaki sprint adını kullanır. `docs/MASTER_PLAN.md` içindeki tarihsel M02 paket prototipi numarasıyla karıştırılmamalıdır; o işin `alp` prototipi Claude tarafından ayrı repoda başlatılmıştır.

## Resmî ana plan M00–M12 durumu — 23 Eylül 2026

Bu tablo `docs/MASTER_PLAN.md` §10'daki M00–M12 aşamalarını izler; yukarıdaki kullanıcı sprint adlarıyla aynı numaralandırma değildir.

| Ana plan aşaması | Durum | Kanıt / açık çıkış koşulu |
|---|---|---|
| M00 — Gereksinimler ve repo | Tamamlandı | Ana plan, kararlar, ajan talimatları ve private repo var. |
| M01 — Linux build hostu | Tamamlandı | Ubuntu 24.04 Builder, SSH, LFS build kökü ve disk alanı doğrulandı. |
| M02 — paket motoru prototipi | Kısmi | D31 ile pacman/Discover yolu bırakılıp `alp` seçildi. Güncel `alp` ile htop install/remove, checksum ve çalıştırma kanıtı var; update/GUI yolu ile paket motorunun tam kabul koşulları yok. |
| M03 — multilib | Kullanıcı kararıyla uygulanmayacak | D32/P01 saf 64-bit kararı; kod veya build değişikliği yapılmadı. ELF32 ölçütü tamamlanmış gibi gösterilmez. |
| M04 — nihai LFS tabanı | Kısmi (LFS 12.4 rootfs hazır) | M1 rootfs, linker ve FAT/ext4 kontrolleri mevcut; fakat `/mnt/lfs/var/lib/alp/db.json` paket listesi boş. Ana plan §10.1'de istenen temel sistem dosya sahipliği kayıtları kanıtlanmadı. |
| M05 — kernel/boot/VM | M1 hedefi tamamlandı; yeni M2 kernel boot testi bekliyor | M1 tabanlı Gen1 VM'de DHCP/ping ve kontrollü reboot sonrası yeni adres ping'i geçti. Ayrı M2 adayında Hyper-V kernel boot henüz test edilmedi. |
| M06 — BLFS altyapısı | Kısmi | Ağ/TLS, PAM/logind, pkexec e2e, Mesa softpipe EGL çizim/readback, ALSA loopback ve PipeWire null-sink graph PCM roundtrip kanıtı var. Fiziksel ses aygıtı ve gerçek masaüstü oturumu henüz yok. |
| M07 — Plasma ve temel uygulamalar | Devam ediyor | KWin 6.4.4, Plasma Workspace, Plasma Integration ve Breeze QQC2 kuruldu. `plasmashell --version` offscreen ortamda 6.4.4 verdi; loader taramasında eksik dinamik bağımlılık yok. Wayland-only yamaları temiz BLFS arşivine karşı `patch --dry-run` ile doğrulandı. Gen1 DRM kernel'i derlenip ayrı aday VHDX'e kuruldu. F: artifact SHA-256 ile doğrulandı; read-only rootfs smoke testleri geçti. Ayrı Hyper-V guest boot ve gerçek Plasma oturumu bekliyor. Windows `sshd` çalışıyor, fakat mevcut anahtar admin SSH için kabul edilmedi; kullanıcı erişim bilgisi/anahtar yetkilendirmesi bekleniyor. |
| M08 — ürün UX/terminal/tema | Başlamadı | Masaüstüne bağlı kullanıcı senaryoları tamamlanmadı. |
| M09 — canlı imaj/ISO | Başlamadı | Live rootfs/ISO ve açılış kanıtı yok. |
| M10 — alfa | Başlamadı | M09 yayın adayı/test matrisi yok. |
| M11 — kurucu | Başlamadı | Calamares/offline/BIOS+UEFI kurulum testleri yok. |
| M12 — beta | Başlamadı | Kurulabilir beta, donanım ve güncelleme/kurtarma kabulü yok. |

Sprint adlarının resmî aşamaları atlayarak ilerlemiş gibi görünmesinin nedeni budur: M2 sprinti resmî M02'yi kapatmadı; esasen resmî M05'in Gen1 ek testini ve M06'nın bir bölümünü yürütüyor. Qt alt bileşenleri kurulmuş olsa da KWin/Plasma oturumu M07'nin kalan işidir.

M2 hedefi, M1'de açılan metin tabanlı LFS sistemini ilk kullanılabilir grafik oturuma taşımaktır:

1. BOOT-01 Gen1 testini kapat (tamamlandı: DHCP, host ping ve reboot sonrası ping).
2. Sertifika/TLS, indirme araçları, D-Bus/polkit ve temel ağ katmanını kur.
3. Grafik, giriş, font ve PipeWire ses zincirini kurup ayrı ayrı doğrula (EGL ve PipeWire sanal graph kanıtı var; fiziksel aygıt ve gerçek oturum açık).
4. Claude'un `alp` paket motorunu gerçek LFS köküne yerleştir; örnek paket için kur/güncelle/kaldır, kilit, checksum ve dosya sahipliği testlerini geçir.
5. Hafif KDE Plasma/KWin oturumunu Hyper-V'de aç; Türkçe Q, ağ, ses ve yeniden başlatma testlerini yap.
6. Doğrulanmış `alpbahOS-m2.vhdx`, checksum ve M2 raporu üret.

Tahmin: ilk Plasma giriş ekranı için 4-7 takvim günü; test edilmiş M2 VHDX için 7-10 gün. Bu tahmin günlük yaklaşık 5 saat, hafta sonu daha uzun çalışma ve Claude katkısı varsayar.

## Artifact saklama kuralı

- Windows'ta M1 teslimi `C:\alpbahOS\artifacts\alpbahOS-m1-final-v2.vhdx` olarak korunur. Kullanıcının isteğiyle yeni release ve test artifact'leri `F:\alpbahOS-build\artifacts` altına yazılır.
- Builder'da `alpbahOS-m1-clean.raw` düzenlenebilir temiz kaynak, `alpbahOS-m1-final-v2.vhdx` ise doğrulanmış teslim olarak tutulur.
- Eski boot/debug/framebuffer denemeleri ve geçici loglar M1 kapanışında temizlenmiştir.

## M2 temel kapıları — 22 Eylül 2026 denetimi

- **Kararlar:** P01 saf 64-bit olarak güncellendi (D32); mevcut LFS 12.4 tabanıyla eşleşen BLFS 12.4'te kalma gerekçesi D33 olarak kaydedildi. Multilib için kod/build değişikliği yapılmadı.
- **M05:** Gen1 guest `networkctl status` DHCP lease'i `172.28.165.181/20`, gateway/DNS `172.28.160.1` olarak gösterdi; host ping 2/2, TTL 64 ve MAC `00-15-5D-00-02-06` ile doğrulandı. Kullanıcı kontrollü reboot sonrası yeniden login yaptı; host komşu kaydı aynı NIC MAC'i yeni `172.28.171.186` adresinde gösterdi ve ping 3/3, TTL 64 geçti. Gen1 ağ/reboot çıkış koşulu kapandı.
- **p11-kit:** Orijinal 66/67 test koşusunda `test-path` SIGSEGV. Hedef `/etc/passwd`'de UID 1000 yok: aynı `common/test-path` ikilisi `tester` UID 101 ile 9/9 geçti; numeric UID 1000 ile kontrollü tekrar signal 11/exit 139 verdi. `trust list --filter=ca-anchors` 172 trust anchor döndürdü. Bu, build UID'nin hedefte kullanıcı kaydı olmadan test edilmesiyle sınırlı; gerçek trust-store hatası belirtisi bulunmadı. Karşılaştırma logu `/mnt/lfs/tmp/alp-logs/p11-kit-uid-compare.log`.
- **Polkit:** geçici test system bus ve polkitd üzerinde, yalnız tester'ın `/usr/bin/id` çağrısını izinleyen geçici kural ile `pkexec --disable-internal-agent /usr/bin/id` `uid=0(root)` döndürdü ve exit 0 verdi. Geçici rule, `/etc/shells` ve bus socket temizlendi. Tam dbusmock suite ve auth-agent akışı çalıştırılmadı.
- **Mesa:** `/mnt/lfs/tmp/alp-mesa-egl-smoke.c` ile derlenen EGL/GLES2 pbuffer testi softpipe renderer'da çizdi ve pikseli geri okudu. Log: `/mnt/lfs/tmp/alp-logs/mesa-egl-smoke.log`; test binary: `/mnt/lfs/tmp/alp-mesa-egl-smoke`. `swrast_dri.so` dosyaları mevcut kurulumda bulunmadı; bu test surfaceless EGL yolunu doğrular, Wayland compositor yolunu değil.
- **Ses:** ALSA Utilities `1.2.14` (MD5 `d098c3d677ee80cf3d9f87783cce2e53`), libsndfile `1.2.2` (`04e2e6f726da7c5dc87f8cf72f250d04`), PipeWire `1.4.7` (`e151f5f67b2f09d0b37e0b9493111ca0`, `pw-cat=enabled`), Lua `5.4.8` (`81cf5265b8634967d8a7480d238168ce`) ve WirePlumber `0.5.10` (`2cbb662f91da2bdce31fa55bef5dfcf5`) kuruldu; paket testleri geçti. `snd-aloop` üzerinden ALSA playback/capture ve PipeWire null-sink graph'ında `pw-play`→monitor `pw-record` roundtrip geçti: 48 kHz stereo, 243712 kare, peak 12000, RMS 6522.08, PCM SHA-256 `5c0547fd620ba0fd4e7128e9c11594d7128fa324ac450da0d63192263bc6e7b3`. Bu gerçek PipeWire graph PCM I/O kanıtıdır; ALSA aygıt routing'i veya fiziksel hoparlör/mikrofon doğrulanmış değildir.
- **Yönetim araçları:** Rootfs'de `ip` var; M1 VHDX guest'i eski kaldığından guest'te `ip` komutu yok. `sudo 1.9.17p2` checksum `dcbf46f739ae06b076e1a11cbb271a10`, `make check` ve `visudo -c` geçti; PAM ile kuruldu, `/etc/sudoers.d/00-sudo` `%wheel` kuralı eklendi. Builder rootfs'sinde `sa` hesabı ve `/etc/shadow` yok; M1 imajında doğrulanmış hesabın grup üyeliği final imaj entegrasyonuna kaldı. Hesap/parola oluşturulmadı veya değiştirilmedi.
- **`alp` htop:** `a82f872570c938dbd68d5b868070d72ffe437c27` içindeki güncel `alp.py` Builder'a aktarıldı ve 23 Eylül'de tekrar test edildi. Htop 3.3.0 checksum doğrulamasıyla geçici `--root` altına kuruldu; `/usr/bin/htop` modu `0755`, `htop 3.3.0` çıktısı doğrulandı; kaldırma sonrası binary ve DB paketi temizlendi. Yeniden test logu `/mnt/lfs/tmp/alp-logs/alp-a82f872-rerun.log`; kaynak repo/commit ve özet WORKLOG'da.
- **23 Eylül temel-kapı denetiminin o andaki sonucu:** M1 Gen1 ağ/reboot kanıtı ile p11-kit, polkit, Mesa EGL, PipeWire PCM ve `alp` kontrolleri kayıtlıydı. Bu noktanın ardından Qt/KWin/Plasma build'lerine devam edildi; bugün gerçek Wayland/Plasma oturumu hâlâ doğrulanmadı. Fiziksel ses aygıtı da test edilmedi.

## 23 Eylül 2026 — KF6 derlemesi başladı

- QtTools 6.9.2 resmi arşivi doğrulandı (MD5 `28c3b5c9533fbc96d4d8f4ca4488c410`); `ninja -j2` ve kurulum geçti. KF6'nın çeviri derlemesi için gereken Qt6LinguistTools artık mevcut.
- KF6 zincirinde `attica`, ardından `karchive` (Qt LinguistTools eksikliği giderildikten sonra), `kcodecs`, `kconfig`, `kcoreaddons` başarıyla derlenip kuruldu; sonraki paket `kdbusaddons` çalışıyor. Loglar `/mnt/lfs/tmp/alp-logs/kf6/` altında tutuluyor.
- `kapidox` wheel oluşturma başarılıydı ancak BLFS pip adımı `doxypypy` bağımlılığını bulamadığı için durdu. Bu belge üretim aracı ilk Plasma oturumu için gerekli olmadığından etkin framework manifestinin devamında bırakıldı; durum M2 raporunda açıkça belirtilecek.

- **KF6 devam durumu:** `kdbusaddons`, `kguiaddons`, `kidletime` için Wayland hedefi korunup `WITH_X11=OFF` yapılandırması kullanıldı; `kwindowsystem` için karşılık gelen `KWINDOWSYSTEM_X11=OFF` seçeneği kullanıldı. `kdnssd`, `ki18n`, `kimageformats`, `kitemmodels`, `kitemviews`, `kplotting`, `kwidgetsaddons`, `solid`, `sonnet` geçti. Sonnet için BLFS Aspell 0.60.8.1 (MD5 `187bd142f522ada555c7aa6b9cbf56e6`) kuruldu; GCC 15 düzeltmesi uygulandı, upstream paket test suite sunmuyor. `threadweaver` sırada.


## 23 Eylül 2026 — İlk Wayland Plasma oturumu (devam ediyor)

- `libplasma` 6.4.4 derlenip `/opt/kf6` altına kuruldu. BLFS kaynağında `WITHOUT_X11=ON` durumunda da açık kalan X11 derleme dalları (`appletpopup`, `dialog`, `plasmawindow`, `windowthumbnail`, `theme`, `contrasteffectwatcher`) Wayland koşullu hale getirildi; derleme geçti. Ayrıntılı log `/mnt/lfs/tmp/alp-logs/plasma/libplasma-{build,install}.log`.
- Plasma çekirdeği için `kdecoration`, `breeze`, `layer-shell-qt`, `plasma-activities`, `kglobalacceld` ve `kwayland` başarılı kuruldu. `libkscreen` de Wayland/QScreen/fake backend'leriyle kuruldu; QtBase'de XCB kapalı olduğundan libkscreen'in XRandR/DPMS backend'i devre dışı bırakıldı.
- KWin'in configure kapısında gereken Qt Sensors 6.9.2 (BLFS Qt alt modül listesi MD5 `f7b2fae56c39a7f6a556a2b3a2d364b7`), libepoxy 1.5.10, Little CMS 2.17 ve Wayland Protocols 1.45 resmi BLFS checksum'larıyla doğrulanıp kuruldu. BLFS X11 client alt kümesi (xorgproto, libXau, libXdmcp, xcb-proto, libxcb, xtrans, libX11, xcb-util-keysyms) da KScreenLocker'ın CMake gereksinimi için kuruldu; Xorg sunucusu kurulmadı.
- KScreenLocker 6.4.4, X11 greeter'ında Qt'nin `QX11Application`/XCB plugin özel arayüzünü istiyor. Bu QtBase XCB'siz yapılandırıldığı ve ilk oturum Wayland hedefli olduğu için KWin'de `KWIN_BUILD_SCREENLOCKER=OFF` kullanılıyor; ekran kilidi ilk oturumun doğrulama kapsamına dahil değil. KWin Wayland 6.4.4 build/install geçti.
- **Gerçek LFS `alp` testi:** `alp` `/usr/bin/alp` wrapper'ı, Python motoru `/usr/lib/alp/alp.py`, htop recipe/index `/etc/alp` altında gerçek LFS rootfs'ye yerleştirildi. htop 3.3.0 kur/list/çalıştır/kaldır döngüsü chroot'ta geçti: dosya modu `0755`, doğru sürüm, kaldırma sonrası dosya yok ve DB boş. Gerçek kurulumda bulunan `copyfile` mod kusuru `copy2` ile düzeltildi; patch Claude'un kanonik özel repo'suna henüz aktarılmadı. Htop dışı katalog, `alp update`, lock ve bağımlılık çözümleme doğrulanmadı.
- **Qt/KWin:** QtBase `FEATURE_xkbcommon=ON` yeniden derlemesi/kurulumu geçti; private header ve QXkbCommon sembolleri kuruldu. KWin Wayland/DRM 6.4.4 `KWIN_BUILD_X11=OFF`, `KWIN_BUILD_SCREENLOCKER=OFF` ile geçti; `kwin_wayland --version` doğrulandı. Plasma5support ve Plasma Workspace kuruldu. Gen1 DRM kernel config'i `CONFIG_DRM_HYPERV=y`, `CONFIG_DRM_FBDEV_EMULATION=y`, `CONFIG_FRAMEBUFFER_CONSOLE=y`; `CONFIG_FB_HYPERV` kapalı. Linux 6.16.1 `bzImage` ve modüller derlenip kuruldu; `kernel.release` ve config doğrulandı. Kernel SHA-256 `4d040d470de49ff61f77848e8296f2eabf92ecfbea64b45d82169af56ffc6b44`, build log SHA-256 `6e9782692a3c779c10df7befbcf22fc19cc6628abe2af1547472e65e65af85e6`.
- Türkçe Q girdi verisi için BLFS 12.4 XKeyboardConfig 2.45 kuruldu (MD5 `cebc84ec99d3273e07aee8ecff3e3519`); `xkbcli compile-keymap --layout tr` exit 0 ve Turkish keymap verdi. Paket pytest suite'i isteğe bağlı pytest aracı kurulu olmadığından çalıştırılmadı.
- Plasma Workspace 6.4.4 derleme/kurulum geçti (`PLASMA_WORKSPACE_PASS`). `WITH_X11=OFF` ortak kodda yine de derlenen X11 API kullanımlarını koşullu yapan yama `docs/patches/plasma-workspace-6.4.4-wayland-no-x11.patch` olarak kaydedildi. Paketin temiz BLFS arşivine `patch --dry-run -p1` uygulaması geçti. Build/install logları `/mnt/lfs/tmp/alp-logs/plasma/plasma-workspace{,-install}.log`; SHA-256 sırasıyla `afc8c86448ee9382ba5e2cd08c06cb1fc43487f4f30f55c3d9d86b8964361b5b` ve `8949a73da4ff5057aaf3add0b35e0cb5f4de761d93ff8b97ed0d019c6ce7a9bd`.
- Plasma Integration 6.4.4 Wayland platform theme ve Breeze QQC2 style 6.4.4 build/install geçti. `plasma-integration` X11-only `x11integration.cpp` no-X11 kaynağından çıkarıldı; CMake `CMAKE_DISABLE_FIND_PACKAGE_X11=TRUE`, `BUILD_QT5=OFF` ile yapılandırıldı. Patch `docs/patches/plasma-integration-6.4.4-wayland-no-x11.patch`, temiz arşiv `patch --dry-run` kontrolü geçti. Final loglar `/mnt/lfs/tmp/alp-logs/plasma/plasma-integration-build-install.log` (SHA-256 `7fad4d6da21c5863daef3fc8016018e30ce59dcfccae61c329bc46d3b5175d73`) ve `/mnt/lfs/tmp/alp-logs/plasma/qqc2-breeze-style-build-install.log` (SHA-256 `124da3f895ccfe50a038f788e44d8efe38dfccdd1cdb5f26707aa168ea24b360`).
- Runtime kesiti: `plasmashell --version` `QT_QPA_PLATFORM=offscreen` ile `plasmashell 6.4.4` verdi. `startplasma-wayland` ve `plasmashell` için hedef dynamic loader bağımlılık listeleri `/mnt/lfs/tmp/alp-logs/plasma/{startplasma,plasmashell}-loader.log`; `not found` yok. `startplasma-wayland --help` programın desteklemediği bir çağrıydı; D-Bus yokluğu nedeniyle başlatıcı hemen çıktı. Bu bir Plasma oturumu doğrulaması değildir. Hyper-V'de gerçek Plasma oturumu henüz çalıştırılmadı.
- Gen1 DRM config'teki Linux 6.16.1 `bzImage` + modules derlemesi tamamlandı. `file` çıktısı Linux 6.16.1-alpbahOS x86 boot executable gösteriyor; kernel.release aynı sürümü verdi. `CONFIG_DRM_HYPERV=y`, `CONFIG_DRM_FBDEV_EMULATION=y`, `CONFIG_FRAMEBUFFER_CONSOLE=y` doğrulandı. Aday VHDX F: diskinde hazır; M1 VHDX ve çalışan Gen1 VM değiştirilmedi. Yeni release/test artifact'leri kullanıcı isteğiyle F: diskinde tutuluyor.

## 23 Eylül 2026 — Wayland Plasma build sonucu ve temel denetim devamı

- Bu oturumda M00–M12 tablosu ve BLFS temel kanıtları yeniden denetlendi. M05 için reboot sonrası Gen1 adresine canlı `ping -n 4` 4/4, %0 kayıp, TTL 64 döndü; önceki kullanıcı kontrollü reboot/login kanıtı kayıtlı. Bu PowerShell oturumunda `Get-VM` erişimi yönetici yetkisi istedi; VM power state cmdlet ile okunmadı.
- P01 saf 64-bit kararının kapalı olduğu ve D33 LFS 12.4 / BLFS 12.4 eşleşme gerekçesi kontrol edildi. Bu karar için hiçbir kod/build değişikliği yapılmadı. p11-kit UID kıyaslaması, Polkit son başarılı pkexec, PipeWire capture PCM istatistik/hash, Mesa softpipe readback, `alp` htop rerun logları tekrar okundu; her kanıt, test kapsam sınırıyla birlikte yukarıdaki 23 Eylül temel-kapı bölümünde kayıtlıdır.
- M07 Workspace derlemesindeki `KWindowInfo`, `KX11Extras`, `KStartupInfo` hataları ilgili Wayland-only kod kolları koşullu yapılarak giderildi. Workspace 6.4.4 build/install geçti. Plasma Integration'ın X11-only kaynağı no-X11 derlemede çıkarıldı; Plasma Integration ve Breeze QQC2 build/install geçti. Değişiklikler `docs/patches/plasma-workspace-6.4.4-wayland-no-x11.patch` ve `docs/patches/plasma-integration-6.4.4-wayland-no-x11.patch`; her ikisi de temiz BLFS arşivinde `patch --dry-run -p1` ile geçti.
- `plasmashell --version` offscreen Qt platformında `6.4.4` döndürdü. `plasmashell` ve `startplasma-wayland` hedef loader taramalarında `not found` yok. D-Bus içermeyen chroot'ta `startplasma-wayland --help` çağrısı programı oturum başlatmaya yöneltti ve D-Bus olmadığı için çıktı; gerçek Plasma oturum test edilmedi.
- Bu ara kayıt anında Linux 6.16.1 DRM kernel derlemesi sürüyordu. Sonraki tamamlanmış kayıt kernel `bzImage`/modüllerinin kurulduğunu ve F: üzerindeki ayrı aday VHDX'in hash doğrulamasını gösterir. M1 kaynak VHDX ve çalışan Gen1 test VM diski değiştirilmedi.
