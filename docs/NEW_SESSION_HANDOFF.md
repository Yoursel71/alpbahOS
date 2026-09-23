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

23 Eylül canlı sorgusu:

| VM | Durum | Nesil | Kaynak | Disk | MAC |
|---|---|---:|---|---|---|
| `alpbah-builder` | Running | Gen2 | 4 vCPU, dinamik RAM 3–6 GiB | `F:\alpbahOS-build\vhdx\alpbah-builder.vhdx` | `00-15-5D-00-02-04` |
| `alpbahOS-M2-SSH-Gen1` | Off | Gen1 | 2 vCPU, sabit 2 GiB | `F:\alpbahOS-build\vms\alpbahOS-M2-SSH-Gen1\alpbahOS-M2-SSH-Gen1.vhdx` | `00-15-5D-00-02-08` |
| `Yeni Sanal Makine` | Off | Gen1 | Eski/alakasız VM; kullanma | `C:\ProgramData\Microsoft\Windows\Virtual Hard Disks\Yeni Sanal Makine.vhdx` | `00-15-5D-00-02-03` |

Builder ve M2 VM'lerinde otomatik checkpoint kapalıdır. `Yeni Sanal Makine` alpbahOS çalışma hedefi değildir.

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
- Builder root LV: yaklaşık 98 GiB; son kontrolde yaklaşık 21 GiB boştu. Büyük derlemeden önce `df -h / /mnt/lfs` kontrol et.
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
- Hyper-V VM doğrudan release dosyasını değil, `vms\alpbahOS-M2-SSH-Gen1` altındaki ayrı çalışma kopyasını kullanır.

## 7. M2 guest erişimi

- VM: `alpbahOS-M2-SSH-Gen1`, şu an kapalı.
- Guest kullanıcı: `sa`.
- SSH yalnız public key ile açıktır; root SSH ve parola SSH kapalıdır.
- Windows anahtarı: `C:\Users\thewo\.ssh\claude_alpbahos_m2`.
- VM açıldıktan sonra DHCP adresini eski IP'den varsayma. MAC `00-15-5D-00-02-08` ile komşu tablosu/Hyper-V bilgisi üzerinden yeni adresi bul ve önce ping, sonra SSH doğrula.
- `sshd.service` enable/active olarak paketlendi; host key'ler ilk açılışta üretilir.
- Önceki canlı Gen1 testinde DHCP, ping, public-key SSH ve kontrollü reboot geçti.

## 8. Teknik olarak gerçekten tamamlananlar

- LFS 12.4-systemd x86_64 temel sistem ve Linux `6.16.1-alpbahOS` açılıyor.
- Hyper-V Gen1 ve Gen2 boot-to-login kanıtları var; güncel M2 Gen1 DHCP/reboot/SSH geçti.
- BLFS TLS/CA, D-Bus, PAM/logind düzeltmeleri, polkit test yolu, ALSA/PipeWire sanal testleri, Mesa softpipe EGL/GLES smoke testi tamamlandı.
- Qt 6.9.2, KF6/Plasma 6.4.4 bileşenlerinin önemli kısmı, KWin Wayland ve Plasma Workspace derlenip kuruldu.
- Türkçe Q keymap derlemesi geçti.
- `alp` ile gerçek LFS chroot'ta htop kur/list/çalıştır/kaldır döngüsü geçti.
- M2 çalışma imajına OpenSSH ve kullanıcı D-Bus desteği eklendi.

Bu maddeler gerçek grafik masaüstünün açıldığını göstermez.

## 9. Şu anki asıl açık kapı

M07 hâlâ açık: Hyper-V VMConnect konsolundaki gerçek `tty1/seat0` oturumundan KWin/Plasma Wayland başlatılmalı ve görüntü alınmalıdır. SSH oturumu DRM master/aktif seat sağlamadığı için SSH üzerinden `startplasma-wayland` denemesi gerçek masaüstü doğrulaması değildir.

İlk sonraki akış:

1. Repo ve VM envanterini salt okunur doğrula.
2. `alpbahOS-M2-SSH-Gen1` VM'ini başlat.
3. Yeni DHCP adresini MAC ile bul; ping ve SSH'yi doğrula.
4. VMConnect `tty1` üzerinde `sa` oturumunun logind tarafından `seat0`, `Type=tty`, aktif session olarak görüldüğünü doğrula.
5. `/dev/dri`, `/run/user/1000`, user D-Bus ve journal durumunu kontrol et.
6. Gerçek konsoldan Plasma Wayland başlat; siyah ekran/çökme varsa journal ve KWin logundan tek kök nedene ilerle.
7. Görüntü oluşmadan M07 tamamlandı yazma.

## 10. Paket yöneticisi için Claude sınırı

- Kanonik motor `alp`; aynı rootfs'ye apt/pacman gibi ikinci native paket veritabanı ekleme.
- Ana repodaki merge edilmiş `alp.py` ile Builder rootfs'deki eski kopyanın hash'leri geçmiş kontrolde eşleşmiyordu. Önce hash ve sürüm karşılaştır.
- Eski rootfs motorunda güvenli olduğu kanıtlanmadan `alp remove` veya `alp upgrade` çalıştırma.
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
- Canlı guest SSH `sa@172.28.171.21`, MAC `00-15-5D-00-02-09`. Gettty/resolved active, failed units yok, alp hash doğru. KWin user unit tabanı ve drop-in `systemctl --user cat/show` ile görüldü; etkin ExecStart `kwin_wayland_wrapper`, `--xwayland` olmadan.
- VMConnect penceresinde tty1 için `admin/admin` girişi kullanıcıdan istendi. Gerçek tty/PAM/logind session kanıtı henüz alınmadı; SSH ile `loginctl` sorgusu girişten sonra yapılacak. KWin gate geçmeden önce Plasma başlatılmadı; gerçek Plasma/seat0 testi hâlâ açık.
- Artifact ve komut kanıtları: `docs/verification/p0-p2-audit-2026-09-23.log`. Bu bölümdeki durumlar `CURRENT.md` ile birlikte okunmalı.
