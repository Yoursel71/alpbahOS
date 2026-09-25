# M07 — Gen2 Plasma oturumu bring-up (25 Eylül 2026, Claude)

Test imajı: `F:\alpbahOS-build\artifacts\alpbahOS-m2-ssh-gen2-vgem-autoseat-claude-2026-09-25.vhdx`
(Codex'in `...vgem-test-final-2026-09-25.vhdx` dosyasının kopyası + `scripts/patch-m2-gen2-autoseat.sh`;
kaynak SHA-256 `89f2517a…`, yamalı `2b85c2b1…`). Kaynak dosya değiştirilmedi.

## Yeni erişim altyapısı (konsola/GUI'ye ihtiyaç yok)
- Test VM'de `sa` ve `admin` için şifresiz sudo; tty1 `admin` otomatik girişi (gerçek seat0 oturumu).
- `admin` oturumu `/etc/alp-autostart-plasma` varsa boot başına bir kez `startplasma-wayland` çalıştırır
  (log: `/var/tmp/alp-plasma-autostart.log`). Yeniden denemek: `sudo rm /run/alp-plasma-tried; sudo systemctl restart getty@tty1`.
- `scripts/vm-screenshot.ps1`: Hyper-V WMI ile VM ekran görüntüsü (SSH'tan, masaüstü gerektirmez).
- `scripts/refresh-ssh-hosts.ps1`: PC yeniden başlayınca değişen VM IP'lerini MAC'ten bulup `~/.ssh/config`'i günceller.
- VM'ler için otomatik başlatma (`AutomaticStartAction=Start`) açıldı.
- COM1 → `\.\pipe\alpbahos-gen2-console` bağlandı (kernel `console=ttyS0` zaten var; okuma denemesi tamamlanmadı).

## KWin/Plasma zinciri — bulgular (canlı doğrulandı)
1. Render node: Codex'in VGEM çekirdeğiyle `/dev/dri/renderD128` var; KWin DRM/EGL açılıyor. **KSplash gerçekten ekrana çizildi.**
2. `plasma_session` ikilisi `kwin_wayland_wrapper --xwayland` çağırıyor; KWin "Unknown option 'xwayland'" ile ölüyor,
   wrapper saniyede bir yeniden deniyor. Yama (`plasma-workspace-6.4.4-wayland-no-xwayland.patch`) ikiliye girmemiş:
   `strings -el plasma_session | grep xwayland` → `--xwayland` (Qt6 QStringLiteral UTF-16 saklar; önceki `strings` (ASCII)
   kontrolleri bu yüzden yanıltıcıydı). Geçici çözüm: `/opt/kf6/bin/kwin_wayland_wrapper` sarmalayıcı script, argümanı süzüp
   `.real`'e devrediyor. **Kalıcı: plasma-workspace yamayla yeniden derlenmeli.**
   Uyarı: `kwin_wayland` ikilisini ASLA yeniden adlandırma/sarma — KWin QPA eklentisi `applicationFilePath` `kwin_wayland` ile bitmiyorsa
   `Could not load the Qt platform plugin "wayland-org.kde.kwin.qpa"` verir (kendi tanı sarmalayıcım bunu bir süre yanılttı).
3. `plasma-workspace` `WITH_X11=OFF` derlenmiş → `ksmserver` derlenmiyor (CMake: `if(WITH_X11) add_subdirectory(ksmserver)`),
   ama `plasma_session` ve `plasma-plasmashell.service` ona bağımlı (`plasma-ksmserver.service`). Geçici çözüm: no-op
   `/etc/systemd/user/plasma-ksmserver.service`. Kalıcı: ksmserver'ı (X11 gerektirmeden) sağlamak ya da bağımlılığı yamalamak.
4. Plasma birimleri `/opt/kf6/lib/systemd/user` altında; systemd kullanıcı arama yolunda değil. Geçici çözüm: `/etc/systemd/user` sembolik bağları.
   Kalıcı: `-DKDE_INSTALL_SYSTEMDUSERUNITDIR=/usr/lib/systemd/user` ile kurmak.
5. Bu üçüyle oturum `plasma-workspace-wayland.target`'a ulaşıyor. **Son engel:** `plasmashell: starting invalid corona
   "org.kde.plasma.desktop"` — `plasma-desktop` (kabuk paketi) kurulu değil (`/opt/kf6/share/plasma/shells` yok).
   Kaynak Builder'da: `/mnt/lfs/sources/kde/plasma-desktop-6.4.4` (derlenmemiş).

## Codex için sıralı iş
1. plasma-workspace'i yamalı yeniden derle (xwayland argümanı), birimleri `/usr/lib/systemd/user`'a kur, ksmserver çözümü (3).
2. plasma-desktop-6.4.4'ü derle/kur (org.kde.plasma.desktop kabuğu) + eksik `org.kde.milou` (KRunner arayüzü, Overview için).
3. Test: `scripts/vm-screenshot.ps1` ile masaüstü/panel ekran görüntüsü.
