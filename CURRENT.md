# alpbahOS — Güncel durum

Son güncelleme: 22 Eylül 2026

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

- Hyper-V Gen1 boot-to-login doğrulandı; Gen1 ağ/reboot kapsamı açık.
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
- D-Bus rootfs'de 1.16.2 mevcut. Linux-PAM 1.7.1 kaynağı MD5 doğrulandı ve Meson/Ninja build geçti; PAM install + systemd/shadow yeniden yapılandırması bağlı atomik adım olarak bekliyor.
- PAM/systemd zinciri tamamlandı: Linux-PAM kuruldu; `pam_systemd.so`, systemd-logind ve systemd 257.8 yeniden kuruldu. Minimal `/etc/pam.d/system-*` yapılandırması mevcut.
- Polkit zinciri kuruldu ve gerçek `pkexec` uçtan uca senaryosu geçti: geçici system D-Bus + polkitd, yalnız `tester` → `/usr/bin/id` için test kuralı; sonuç `uid=0(root)`, exit 0. Bu, test kuralıyla izin yolunu kanıtlar; etkileşimli auth agent/varsayılan kimlik doğrulama akışını kanıtlamaz.
- Ses altyapısı genişletildi: ALSA-lib, ALSA Utilities, libsndfile, PipeWire (`pw-cat` açık), Lua ve WirePlumber LFS rootfs'ye kuruldu; paket testleri geçti. Builder kernelindeki geçici `snd-aloop` ile ALSA PCM playback→capture roundtrip geçti (144000 kare, peak 12000, RMS 7046.61). WirePlumber ile geçici PipeWire null sink'e playback ve monitor-source capture da geçti (48 kHz stereo, 243712 kare, peak 12000, RMS 6522.08). Bunlar sanal testlerdir; ALSA aygıtına yönlendirme ve fiziksel hoparlör/mikrofon doğrulanmadı.
- Yönetim araçları: `iproute2` zaten LFS rootfs'de (`/usr/sbin/ip`), eski M1 VHDX guest'inde yok. `sudo 1.9.17p2` derlenip test edildi; PAM, `%wheel` sudoers kuralı ve `visudo -c` geçti. Builder `/mnt/lfs` rootfs'sinde `sa` kullanıcı hesabı yok (M1 VHDX'te var); parolasını varsaymadan wheel grup üyeliği final imaj entegrasyonuna bırakıldı.
- Grafik tabanı kesiti tamamlandı: libxml2 2.14.5, libdrm 2.4.125 ve Wayland 1.24.0 test/kurulum geçti. Mesa Wayland softpipe tabanıyla kuruldu. QtBase 6.9.2 configure geçti ve derleniyor; QtWayland, Xwayland, KWin ve Plasma henüz kurulu değil.
- Mesa 25.1.8 softpipe yolu build/install edildi; son dosya sistemi incelemesinde `swrast_dri.so`/`kms_swrast_dri.so` bulunmadı. Buna rağmen gerçek surfaceless EGL/GLES smoke testi geçti: `GL_RENDERER=softpipe`, readback pikseli `64,128,191,255`. Gerçek Wayland/compositor oturumu hâlâ sınanmadı.
- BLFS CMake 4.1.0 (MD5 `80ae27faba5068c8ec12c77bf00e6db3`) LFS chroot'unda derlenip kuruldu; `cmake --version` 4.1.0 döndürdü. Qt6 build'i başlamadı; temel doğrulama kapıları bekleniyor.
- Qt6/KWin/Plasma beklemede: Gen1 guest DHCP/reboot çıkış koşulu tamamlandı. Kalan temel kapı PipeWire'ın gerçek PCM playback/capture testi; test için host/guest arasında ses yönlendirmesi veya PCM aygıtı gerekiyor.

Bu bölüm günlük konuşmadaki sprint adını kullanır. `docs/MASTER_PLAN.md` içindeki tarihsel M02 paket prototipi numarasıyla karıştırılmamalıdır; o işin `alp` prototipi Claude tarafından ayrı repoda başlatılmıştır.

## Resmî ana plan M00–M12 durumu — 22 Eylül 2026

Bu tablo `docs/MASTER_PLAN.md` §10'daki M00–M12 aşamalarını izler; yukarıdaki kullanıcı sprint adlarıyla aynı numaralandırma değildir.

| Ana plan aşaması | Durum | Kanıt / açık çıkış koşulu |
|---|---|---|
| M00 — Gereksinimler ve repo | Tamamlandı | Ana plan, kararlar, ajan talimatları ve private repo var. |
| M01 — Linux build hostu | Tamamlandı | Ubuntu 24.04 Builder, SSH, LFS build kökü ve disk alanı doğrulandı. |
| M02 — paket motoru prototipi | Kısmi | D31 ile pacman/Discover yolu bırakılıp `alp` seçildi. Güncel `alp` ile htop install/remove, checksum ve çalıştırma kanıtı var; update/GUI yolu ile paket motorunun tam kabul koşulları yok. |
| M03 — multilib | Kullanıcı kararıyla uygulanmayacak | D32/P01 saf 64-bit kararı; kod veya build değişikliği yapılmadı. ELF32 ölçütü tamamlanmış gibi gösterilmez. |
| M04 — nihai LFS tabanı | Kısmi (LFS 12.4 rootfs hazır) | M1 rootfs, linker ve FAT/ext4 kontrolleri mevcut; fakat `/mnt/lfs/var/lib/alp/db.json` paket listesi boş. Ana plan §10.1'de istenen temel sistem dosya sahipliği kayıtları kanıtlanmadı. |
| M05 — kernel/boot/VM | Tamamlandı | Gen2 DHCP/ping/reboot geçti. Gen1 guest login ve reboot öncesi DHCP lease (`172.28.165.181/20`) doğrulandı; kontrollü reboot + yeniden login sonrası aynı NIC MAC yeni `.171.186` IP'sinde ping 3/3, TTL 64 verdi. |
| M06 — BLFS altyapısı | Kısmi | Ağ/TLS, PAM/logind, pkexec e2e, Mesa EGL ve ALSA sanal PCM roundtrip geçti. PipeWire üzerinden PCM I/O sessiz kaldı; fiziksel audio ve grafik oturumu yok. |
| M07 — Plasma ve temel uygulamalar | Başlamadı | Qt6/KWin/Plasma derlemesi/oturumu yok; M06 kapılarını bekliyor. |
| M08 — ürün UX/terminal/tema | Başlamadı | Masaüstüne bağlı kullanıcı senaryoları tamamlanmadı. |
| M09 — canlı imaj/ISO | Başlamadı | Live rootfs/ISO ve açılış kanıtı yok. |
| M10 — alfa | Başlamadı | M09 yayın adayı/test matrisi yok. |
| M11 — kurucu | Başlamadı | Calamares/offline/BIOS+UEFI kurulum testleri yok. |
| M12 — beta | Başlamadı | Kurulabilir beta, donanım ve güncelleme/kurtarma kabulü yok. |

Sprint adlarının resmî aşamaları atlayarak ilerlemiş gibi görünmesinin nedeni budur: M2 sprinti resmî M02'yi kapatmadı; esasen resmî M05'in Gen1 ek testini ve M06'nın bir bölümünü yürütüyor. Qt/Plasma resmî M07'dir ve şu anda başlamamalı.

M2 hedefi, M1'de açılan metin tabanlı LFS sistemini ilk kullanılabilir grafik oturuma taşımaktır:

1. BOOT-01 Gen1 testini kapat (tamamlandı: DHCP, host ping ve reboot sonrası ping).
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

## M2 temel kapıları — 22 Eylül 2026 denetimi

- **Kararlar:** P01 saf 64-bit olarak güncellendi (D32); mevcut LFS 12.4 tabanıyla eşleşen BLFS 12.4'te kalma gerekçesi D33 olarak kaydedildi. Multilib için kod/build değişikliği yapılmadı.
- **M05:** Gen1 guest `networkctl status` DHCP lease'i `172.28.165.181/20`, gateway/DNS `172.28.160.1` olarak gösterdi; host ping 2/2, TTL 64 ve MAC `00-15-5D-00-02-06` ile doğrulandı. Kullanıcı kontrollü reboot sonrası yeniden login yaptı; host komşu kaydı aynı NIC MAC'i yeni `172.28.171.186` adresinde gösterdi ve ping 3/3, TTL 64 geçti. Gen1 ağ/reboot çıkış koşulu kapandı.
- **p11-kit:** Orijinal 66/67 test koşusunda `test-path` SIGSEGV. LFS `/etc/passwd` içinde UID 1001/1000 yok; bu UID'lerle `/path/expand` çağrısı `getpwuid_r()` üzerinden olmayan kullanıcıyı arayıp testte null sonucu denetlemeden kullandığı için çöküyor. Aynı path testi target `tester` UID 101 ile tam 9/9 geçti. Trust store `trust list --filter=ca-anchors` çalıştı. Bu, build UID/target passwd eşleşmesi kaynaklı test ortamı sorunu; CA/trust store arızası kanıtı değil.
- **Polkit:** geçici test system bus ve polkitd üzerinde, yalnız tester'ın `/usr/bin/id` çağrısını izinleyen geçici kural ile `pkexec --disable-internal-agent /usr/bin/id` `uid=0(root)` döndürdü ve exit 0 verdi. Geçici rule, `/etc/shells` ve bus socket temizlendi. Tam dbusmock suite ve auth-agent akışı çalıştırılmadı.
- **Mesa:** `/mnt/lfs/tmp/alp-mesa-egl-smoke.c` ile derlenen EGL/GLES2 pbuffer testi softpipe renderer'da çizdi ve pikseli geri okudu. Log: `/mnt/lfs/tmp/alp-logs/mesa-egl-smoke.log`; test binary: `/mnt/lfs/tmp/alp-mesa-egl-smoke`. `swrast_dri.so` dosyaları mevcut kurulumda bulunmadı; bu test surfaceless EGL yolunu doğrular, Wayland compositor yolunu değil.
- **Ses:** ALSA Utilities `1.2.14` (MD5 `d098c3d677ee80cf3d9f87783cce2e53`), libsndfile `1.2.2` (`04e2e6f726da7c5dc87f8cf72f250d04`), PipeWire `1.4.7` (`e151f5f67b2f09d0b37e0b9493111ca0`, `pw-cat=enabled`), Lua `5.4.8` (`81cf5265b8634967d8a7480d238168ce`) ve WirePlumber `0.5.10` (`2cbb662f91da2bdce31fa55bef5dfcf5`) kuruldu; testler geçti. Geçici `snd-aloop` ALSA playback/capture roundtrip geçti: 144000 kare, peak 12000, RMS 7046.61, SHA-256 `5d8f31349bd312226a5f4c60fe6a313b32311effdc5bee24c6751997c91c93eb`. PipeWire sanal null-sink monitor kaydı da geçti: 48 kHz stereo, 243712 kare, peak 12000, RMS 6522.08. Bu PipeWire graph PCM I/O'sunu doğrular, ALSA aygıt routing'i veya fiziksel sesi değil; M06'nın audio hardware alt sınırı açık.
- **Yönetim araçları:** Rootfs'de `ip` var; M1 VHDX guest'i eski kaldığından guest'te `ip` komutu yok. `sudo 1.9.17p2` checksum `dcbf46f739ae06b076e1a11cbb271a10`, `make check` ve `visudo -c` geçti; PAM ile kuruldu, `/etc/sudoers.d/00-sudo` `%wheel` kuralı eklendi. Builder rootfs'sinde `sa` hesabı ve `/etc/shadow` yok; M1 imajında doğrulanmış hesabın grup üyeliği final imaj entegrasyonuna kaldı. Hesap/parola oluşturulmadı veya değiştirilmedi.
- **`alp` htop:** `a82f872570c938dbd68d5b868070d72ffe437c27` içindeki güncel `alp.py` builder'a aktarıldı. Htop 3.3.0 checksum doğrulamasıyla geçici `--root` altına kuruldu; `/usr/bin/htop` modu `0755`, `htop 3.3.0` çıktısı doğrulandı; kaldırma sonrası binary ve DB paketi temizlendi. Log `/mnt/lfs/tmp/alp-a82f872-root/var/log/alp/htop-3.3.0.build.log`.
- **Devam kapısı:** M05 Gen1 tamamlandı. PipeWire PCM I/O ve fiziksel audio doğrulanmadı; M06 kapısı tamamlanana kadar Qt6/KWin/Plasma build'ine geçilmeyecek.
