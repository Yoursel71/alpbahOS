# alpbahOS — Yeni sohbet / ajan teknik devri

Son canlı doğrulama: 23 Eylül 2026, Europe/Istanbul

Bu belge yeni Codex/Claude sohbetinin ortamı yeniden keşfetmeye çalışırken yanlış VM'i, diski veya rootfs'yi değiştirmesini önlemek içindir. Önce bunu, sonra `AGENTS.md`, `CURRENT.md` ve `docs/WORKLOG.md` dosyalarını oku.

## 1. Değiştirilemez güvenlik kuralları

- Windows hostu kapatma, yeniden başlatma veya oturumdan çıkarma. Kullanıcı uzakta olabilir.
- Fiziksel Windows disklerini, Windows boot kaydını veya kullanıcı dosyalarını değiştirme.
- M1 final VHDX'i yerinde değiştirme. Yeni test için kopya veya differencing disk kullan.
- Çalışan Builder VM'i yalnız görev gerçekten gerektiriyorsa ve kullanıcı bağlamı uygunsa kapat.
- `git reset --hard`, `git clean`, toplu checkout veya kaynağı belirsiz dosya silme kullanma.
- Aynı `/mnt/lfs` köküne iki ajan eşzamanlı paket kuramaz. Derleme/rootfs için tek yazıcı olmalı.
- Başarıyı tahmin etme: build, install, boot, login ve gerçek Plasma oturumu ayrı kanıtlardır.

## 2. Kaynak kod ve Git gerçeği

- Kanonik Windows çalışma ağacı: `C:\alpbahOS`
- Kanonik branch: `main`
- Uzak repo: private `origin`
- 23 Eylül son kontrolünde yerel `main`, `origin/main` önünde 16 commit idi ve çalışma ağacında başka ajanlara ait commitlenmemiş değişiklikler vardı.
- Bu nedenle yeni ajan önce `git status --short --branch` ve `git log --oneline --decorate -20` çalıştırmalı; mevcut değişiklikleri silmemeli, yeniden biçimlendirmemeli veya `git add -A` ile topluca sahiplenmemeli.
- Builder içindeki `/home/sa/alpbahOS` deposu `master` dalında eski/yardımcı kopyadır; Windows reposunun yerine geçmez. Builder'daki `artifacts/` untracked olabilir.
- Büyük VHDX, RAW, ISO ve rootfs dosyaları Git'e eklenmez.

## 3. Windows host ve yönetim erişimi

- Hyper-V host: Windows 11, bilgisayar adı `YRSLF`.
- Yönetici PowerShell gerektiğinde Windows'un kendi OpenSSH hizmeti üzerinden kullanılabilir:

```powershell
ssh -i C:\Users\thewo\.ssh\codex_alpbahos_m1 thewo@localhost
```

- Bu anahtar yalnız yerel yönetim içindir; özel anahtar içeriğini sohbete, loga veya repoya kopyalama.
- Hyper-V komutlarını normal, yetkisiz PowerShell'de deneyip sonuç alamazsan VM yokmuş gibi raporlama; yukarıdaki yönetici oturumuyla salt okunur envanter al.
- Ana Hyper-V switch: `Default Switch`. DHCP adresleri reboot sonrası değişebilir; sabit IP varsayma.

## 4. Canlı Hyper-V envanteri

23 Eylül tarihli canlı envanter; Gen1 test VM'i sonradan silinmiştir (aşağıdaki güncel not):

| VM | Durum | Nesil | Kaynak | Disk | MAC |
|---|---|---:|---|---|---|
| `alpbah-builder` | Running | Gen2 | 4 vCPU, dinamik RAM 3–6 GiB | `F:\alpbahOS-build\vhdx\alpbah-builder.vhdx` | `00-15-5D-00-02-04` |
| `Yeni Sanal Makine` | Off | Gen1 | Eski/alakasız VM; kullanma | `C:\ProgramData\Microsoft\Windows\Virtual Hard Disks\Yeni Sanal Makine.vhdx` | `00-15-5D-00-02-03` |

Güncel salt okunur envanter `ssh ... thewo@localhost` üzerinden alındı: Hyper-V'de `alpbah-builder` (Running, Gen2), `alpbahOS-M2-SSH-Gen2` (Running, Gen2) ve alakasız `Yeni Sanal Makine` (Off, Gen1) görünüyor. `alpbahOS-M2-SSH-Gen1` VM kaydı artık yok. Gen1 release artifact'i `F:\alpbahOS-build\artifacts\alpbahOS-m2-ssh-gen1.vhdx` ve eski Gen1 çalışma diski `F:\alpbahOS-build\vms\alpbahOS-M2-SSH-Gen1\alpbahOS-M2-SSH-Gen1.vhdx` hâlâ mevcut; VM silinmesi disk dosyalarının silindiği anlamına gelmiyor. `Yeni Sanal Makine` alpbahOS çalışma hedefi değildir.

## 5. Builder Ubuntu

- VM: `alpbah-builder`
- Hostname: `yrsk`
- Kullanıcı: `sa`
- 23 Eylül güncel DHCP: `172.28.162.172` — değişebilir.
- Windows'tan anahtarlı bağlantı:

```powershell
ssh -i C:\Users\thewo\.ssh\claude_alpbahos_m2 sa@172.28.162.172
```

- Anahtar parolasızdır. Özel anahtarı repoya veya mesaja koyma.
- Ubuntu 24.04 tabanı, kernel `6.8.0-139-generic`.
- Builder root LV: yaklaşık 98 GiB; güncel `df -h /` çıktısında 25 GiB boştu. Aynı kontrolde `make`, `ninja`, `cmake` veya `chroot` süreci yoktu; `/sys/block/nbd0` mevcut değildi. Büyük derlemeden önce tekrar kontrol et.
- LFS hedef kökü: `/mnt/lfs`.
- Kritik ayrıntı: `/mnt/lfs` ayrı bağlı disk/mount değildir; Builder'ın `/` dosya sistemi içindeki dizindir. `findmnt -T /mnt/lfs` `/` döndürür. Yanlışlıkla mount/format işlemi yapma.
- Kaynak arşivleri: `/mnt/lfs/sources`
- Derleme/test logları: `/mnt/lfs/tmp/alp-logs`
- Aynı anda etkin `make`, `ninja` veya `cmake` olmadığını doğrulamadan yeni ağır derleme başlatma.
- `sudo` gerekebilir; parolayı belgeye yazma. Yetki yoksa sistemi yarım değiştirmek yerine blokajı raporla.

## 6. Korunacak artifact'ler

### M1

- Final: `C:\alpbahOS\artifacts\alpbahOS-m1-final-v2.vhdx`
- Boyut: 5,024,776,192 byte.
- Bu dosya salt korunacak M1 teslimidir; üstüne yazma.
- `CURRENT.md` içinde eski ve yeniden okunan iki farklı SHA-256 kaydı vardır. Hash uyuşmazlığını çözmeden birini kesin doğru diye kopyalama.

### M2

- Release: `F:\alpbahOS-build\artifacts\alpbahOS-m2-ssh-gen1.vhdx`
- Manifest: `F:\alpbahOS-build\artifacts\alpbahOS-m2-ssh-gen1.txt`
- SHA dosyası: `F:\alpbahOS-build\artifacts\alpbahOS-m2-ssh-gen1.vhdx.sha256`
- Doğrulanmış release SHA-256: `fa29d47608a4444e043a3cbfa26753fd32a3c7e0b2078179dbcd852eab322c78`
- Release standalone, dinamik 20 GiB VHDX'tir ve parent'ı yoktur.
- Silinmiş Gen1 VM çalışırken release dosyası yerine `vms\alpbahOS-M2-SSH-Gen1` altındaki ayrı çalışma kopyasını kullanıyordu; VM kaydı silindi, bu iki VHDX dosyası korundu.
- Gen2 rootfs tabanlı test artifact'i: `F:\alpbahOS-build\artifacts\alpbahOS-m2-ssh-gen2-rootfs-kwin-test.vhdx`, SHA-256 `14f22e9074eb3a01267df284317e3191e5f75af4ac56699d005d33f11e78dcd4`. Güncel çalışan test VM `alpbahOS-M2-SSH-Gen2` bu imajın v3 çalışma diskini kullanır.

## 7. Gen1 guest erişimi — VM silindi

- `alpbahOS-M2-SSH-Gen1` Hyper-V VM kaydı güncel inventory'de yok; bu guest'e artık SSH/VMConnect ile bağlanma.
- İlişkili Gen1 artifact ve çalışma VHDX dosyaları hâlâ disk üzerinde duruyor; salt okunur `Test-Path` ikisine de `True` verdi. Bunları silme veya yeni VM'ye bağlama için kullanıcı isteği yok.
- Bu bölümdeki Gen1 test geçmişi yalnız arşiv bilgisi olarak kalsın; güncel M2 erişim hedefi Gen2'dir (bölüm 13).

## 8. Teknik olarak gerçekten tamamlananlar

- LFS 12.4-systemd x86_64 temel sistem ve Linux `6.16.1-alpbahOS` açılıyor.
- Hyper-V Gen1 ve Gen2 boot-to-login kanıtları var; M2 Gen1 DHCP/reboot/SSH kayıtları tarihsel test kanıtıdır. Gen1 VM kaydı silindi; güncel M2 test VM'i Gen2'dir.
- BLFS TLS/CA, D-Bus, PAM/logind düzeltmeleri, polkit test yolu, ALSA/PipeWire sanal testleri, Mesa softpipe EGL/GLES smoke testi tamamlandı.
- Qt 6.9.2, KF6/Plasma 6.4.4 bileşenlerinin önemli kısmı, KWin Wayland ve Plasma Workspace derlenip kuruldu.
- Türkçe Q keymap derlemesi geçti.
- `alp` ile gerçek LFS chroot'ta htop kur/list/çalıştır/kaldır döngüsü geçti.
- M2 çalışma imajına OpenSSH ve kullanıcı D-Bus desteği eklendi.

Bu maddeler gerçek grafik masaüstünün açıldığını göstermez.

## 9. Şu anki asıl açık kapı

M07 hâlâ açık: çalışan Gen2 test VM'inde VMConnect `tty1` üzerinden `admin/admin` ile gerçek konsol girişi yapılmalı; SSH'den `loginctl` ile `seat0`, `Type=tty`, aktif PAM/systemd oturumu doğrulanmalı; bundan sonra gerçek KWin/Plasma Wayland başlatılıp görüntü alınmalıdır. `sa` SSH oturumu DRM master/aktif seat sağlamaz; SSH üzerinden `startplasma-wayland` denemesi geçerli değildir. Kullanıcıdan yalnız konsolda giriş yapması istendi, komut çalıştırması istenmedi. Bu giriş henüz doğrulanmadı.

İlk sonraki akış:

1. Test VM'i: çalışan `alpbahOS-M2-SSH-Gen2`; Gen1 VM silinmiştir.
2. Kullanıcı VMConnect `tty1` ekranında `admin/admin` ile giriş yapsın.
3. Guest SSH'sinden `loginctl` ile admin'in `seat0`, `Type=tty`, `Active=yes` PAM/systemd oturumunu doğrula.
4. Yalnız bu kanıttan sonra konsol oturumunda Plasma Wayland başlat; siyah ekran/çökme varsa journal ve KWin logundan kök nedeni araştır.
5. Görüntü oluşmadan M07 tamamlandı yazma.

## 10. Paket yöneticisi için Claude sınırı

- Kanonik motor `alp`; aynı rootfs'ye apt/pacman gibi ikinci native paket veritabanı ekleme.
- Builder `/mnt/lfs/usr/lib/alp/alp.py` son kontrolde `e8b0376` kaynağının beklenen SHA-256 `7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132` değeriyle eşleşti. Paket işlemlerinden önce hash'i tekrar doğrula.
- Bu hash eşleşmeden gerçek rootfs'de `alp remove` veya `alp upgrade` çalıştırma.
- Htop dışındaki katalog, `alp update`, bağımlılık çözümü, transaction lock, rollback/config protection ve PackageKit yolu ayrı ayrı test edilmeden hazır sayılmaz.
- Claude değişikliği ayrı dosya/branch sınırında teslim etmeli; rootfs'ye kurulum tek entegratör tarafından yapılmalı.

## 11. Mevcut commitlenmemiş çalışma

23 Eylül kontrolünde `AGENTS.md`, `CLAUDE.md`, `CURRENT.md`, `docs/BACKLOG.md`, `docs/DECISIONS.md`, `docs/HYPERV_PLAN.md`, `docs/MASTER_PLAN.md`, `docs/WORKLOG.md` ve bazı patch'lerde önceden var olan değişiklikler bulunuyordu. Ayrıca `configs/`, `scripts/`, `docs/IMAGE_PROVISIONING.md` ve `docs/verification/` untracked idi.

Özellikle:

- `scripts/provision-m2-test-user.sh`
- `scripts/build-m2-gen2-test-image.sh`
- `configs/systemd/user/plasma-kwin_wayland.service.d/10-wayland-only.conf`
- `docs/verification/p0-p2-audit-2026-09-23.log`

Bunları otomatik olarak doğru, tamamlanmış veya commitlenmeye hazır varsayma. Önce diff ve test kanıtını incele. Başka ajanın değişikliklerini silme.

## 12. Yeni ajanın ilk raporu

İlk rapor yalnız şu beş satırı netleştirsin:

1. Okunan commit ve çalışma ağacı durumu.
2. Builder erişimi, boş alanı ve etkin derleme olup olmadığı.
3. Hedef VM, disk kopyası ve power state.
4. Üstlenilen tek görev ve değiştireceği dosya/rootfs sınırı.
5. Başarı ölçütü ve log/artifact yolu.

Uzun yeniden keşif, tekrar tekrar aynı hash kontrolü veya kanıtsız “M2 tamam” raporu üretme.

## 13. Güncel Gen2 rootfs ve test durumu — 23 Eylül 2026

- Builder `/mnt/lfs` rootfs'ine getty@tty1, systemd-resolved ve `/etc/resolv.conf` bağları uygulandı; `/usr/lib/alp/alp.py` e8b0376 blob'u, SHA-256 `7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132` ile kuruldu. `/mnt/lfs` gerçek Builder rootfs'sidir, ayrı mount değildir.
- KWin unit kaynağı KWin 6.4.4 paketidir: `/opt/kf6/lib/systemd/user/plasma-kwin_wayland.service`. Rootfs `/usr/lib/systemd/user/` altına symlink ile görünür yapıldı; live guest `systemctl --user cat/show` etkin drop-in'in `--xwayland` argümanını kaldırdığını doğruladı.
- Yeni Gen2 test artifact'i `F:\alpbahOS-build\artifacts\alpbahOS-m2-ssh-gen2-rootfs-kwin-test.vhdx`, SHA-256 `14f22e9074eb3a01267df284317e3191e5f75af4ac56699d005d33f11e78dcd4`. Hyper-V test VM `alpbahOS-M2-SSH-Gen2` şu anda v3 çalışma diskini kullanıyor (`F:\alpbahOS-build\vms\alpbahOS-M2-SSH-Gen2\alpbahOS-M2-SSH-Gen2-v3-rootfs-kwin.vhdx`); önceki v2 diski korunuyor. Test imajındaki konsol hesabı `admin/admin`; parola release imajına yazılmamalı.
- Canlı guest SSH adresi DHCP ile değişir; en son reboot sonrası `sa@172.28.164.164`, MAC `00-15-5D-00-02-09`. Reboot sonrası boot ID `6df39e0d-a48d-4e8f-a138-6ec5c4e4a663`, kernel `root=PARTUUID=84b8b2c9-9a5c-46b9-b9a0-0a22834278fe rootwait`, root `/dev/sda2`; DHCP/gateway/DNS, host ping 4/4, key-only SSH, DNS resolve, boş failed-unit listesi, getty/resolved/sshd enabled+active doğrulandı. KWin user unit tabanı ve drop-in `systemctl --user cat/show` ile görüldü; etkin ExecStart `kwin_wayland_wrapper`, `--xwayland` olmadan.
- VMConnect penceresinde tty1 için `admin/admin` girişi kullanıcıdan istendi. Gerçek tty/PAM/logind session kanıtı henüz alınmadı; SSH ile `loginctl` sorgusu girişten sonra yapılacak. KWin gate geçmeden önce Plasma başlatılmadı; gerçek Plasma/seat0 testi hâlâ açık.

- M04 sahiplik çıkış koşulu açık: `/mnt/lfs/var/lib/alp/db.json` boş `packages`; daha derin taramada bulunan install manifests BLFS/desktop'a ait, LFS base'i kapsamıyor. Kontrollü base reinstall veya tam tarihsel manifest gerekli; dosya uid/gid'sinden tahmin etme. Değerlendirme: `docs/verification/m04-base-ownership-assessment-2026-09-23.md`.
- Artifact ve komut kanıtları: `docs/verification/p0-p2-audit-2026-09-23.log`. Bu bölümdeki durumlar `CURRENT.md` ile birlikte okunmalı.

## 14. M06 D-Bus user bus ve ayrı Gen2 test VM — 24 Eylül 2026

- Eski Gen2 v3 guest'te PipeWire başlatması `Unit dbus.service not found` dedi; Builder `/mnt/lfs/usr/lib/systemd/user` da dbus user unit içermiyordu. `scripts/apply-m2-rootfs-fixes.sh` artık checksum'ı sabitlenmiş D-Bus 1.16.2 arşivinden `dbus.service`/`dbus.socket` upstream template'lerini kuruyor; image script bu dosyaları ve içeriklerini zorunlu doğruluyor.
- Yeni test artifact: `F:\alpbahOS-build\artifacts\alpbahOS-m2-ssh-gen2-dbus-test.vhdx`, SHA-256 `c877ff26fc488b1e917c77d14e1f519d279b5440a5f236eb626fa260733c070b`; ayrı working copy SHA eşleşiyor. Eski `alpbahOS-M2-SSH-Gen2` diski/VM'i değiştirilmedi.
- Yeni VM `alpbahOS-M2-SSH-Gen2-DBus`, IP en son `172.28.171.33`, MAC `00-15-5D-00-02-0A`, kernel `6.16.1-alpbahOS`, boot ID `67e367ff-b6a0-4f6f-9e55-0e2202675d84`. DNS, HTTPS/TLS, SSH, host ping, getty/resolved/sshd ve KWin Wayland-only kontrolü geçti.
- SSH user session'ında `systemctl --user start pipewire.service wireplumber.service pipewire-pulse.socket` başarılı. Geçici null sink 440 Hz playback/monitor capture denemesinde 577536 byte kaydedildi ancak peak/RMS sıfır; bu bir audio roundtrip başarısı değildir. Test config/dosyaları temizlendi. Guest `/dev/snd`'de soundcard yok.
- `loginctl seat-status seat0` DRM `card0`/`Virtual-1` ve keyboard gösteriyor; `loginctl list-sessions` yalnız SSH session ve manager içeriyor. VMConnect'te yeni `alpbahOS-M2-SSH-Gen2-DBus` VM'inin tty1'inde admin/admin login hâlâ gerekli. Sonra `loginctl` ile `seat0`, `Type=tty`, PAM/systemd oturumu ve gerçek Plasma testi değerlendirilecek; komut çalıştırma kullanıcıdan istenmeyecek.
