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
## Current Codex result — desktop and panel visible (25 September 2026)

This entry supersedes the interim “desktop not visible / missing activity daemon” status above. Earlier observations remain historical evidence.

- Builder /mnt/lfs contains the rebuilt Plasma Workspace and Plasma Desktop 6.4.4. Workspace configure used WITH_X11=OFF and KDE_INSTALL_SYSTEMDUSERUNITDIR=/usr/lib/systemd/user. Plasma Desktop used PLASMA_DESKTOP_WITH_X11=OFF with the Wayland-only patches recorded in scripts/build-m07-plasma.sh and docs/patches/.
- kactivitymanagerd 6.4.4 and Milou 6.4.4 source archives were downloaded from the official KDE Attic HTTPS path. Their official .sha256 sidecars passed: kactivitymanagerd SHA-256 38f24d9529810495db1a2d0f102a89885d22813f131fb6453b79d898bfcbe2a4; milou SHA-256 a644e5965b33c20f82ce51660fa3b7c2d41810b068cf21f77658824cb3ea6b1e. Rebuild/install is repeatable with scripts/build-m07-runtime-deps.sh.
- Runtime installs: /opt/kf6/lib/libexec/kactivitymanagerd; D-Bus service /usr/share/dbus-1/services/org.kde.ActivityManager.service; user unit /usr/lib/systemd/user/plasma-kactivitymanagerd.service; Milou QML module /opt/kf6/lib/qml/org/kde/milou.
- Workspace build log SHA-256 bd0db8cb2a535216a70af71041f43d5f0c6ea56ca43c4cdebdb9c93b343a4a84. Desktop build log SHA-256 0440cec2b1ef0c9fb273a5e1452377f611fbbb6672b13fe7fc6a5e252cfc36cf. Runtime dependency build logs: kactivitymanagerd c56ab8bca6809dfa9cb1aac6d0887db4d5ce40eeafed9cccca5c9ddbf8d503cc; Milou ec08e4887f89871c5ed6706484283c7b3a847380c12dc20b04811fcb902ecd0d. plasma_session SHA-256 892c424330f29845c76b6f24cbe98ebe722f768a0dac7ed0f5d8aea93f717b0f; plasmashell 21e7492579ec4a85f63c9e5eedaa3c45a1b38a3c8c75cb5ad7478ce9a47bba0d; kactivitymanagerd 9c63068f73dd673495c0fe37bac1b73503050cd8b0afdcfbbffd03047c716809.
- A fresh 24 GiB test VHDX was built from /mnt/lfs at F:alpbahOS-buildartifactsalpbahOS-m2-ssh-gen2-m07-runtimefix-2026-09-25.vhdx. qemu-img check passed before and after applying the isolated test profile. Builder and Windows SHA-256 match: 39a239092f61c0b264546d7cd193195a2f1f545da99c5fbc5ea9e4c9640196e2. Root PARTUUID: 7b402e6e-47ab-4076-80f1-94afedbf4725. The prior test disk remains at alpbahOS-m2-ssh-gen2-m07-plasma-2026-09-25.vhdx.
- Test-only profile: tty1 autologin admin/admin and passwordless sudo for sa/admin exist only in the separate test VHDX. The once-per-boot marker now uses XDG_RUNTIME_DIR; the profile exports KDE QML/plugin paths. /mnt/lfs itself has no /etc/alp-autostart-plasma and no /etc/sudoers.d/90-alpbah-test.
- Live boot evidence: kernel 6.16.1-alpbahOS; loginctl shows admin, seat0, tty, Remote=no, Active=yes, State=active. Processes include startplasma-wayland, kwin_wayland, plasmashell, and kactivitymanagerd. plasma-workspace-wayland.target, plasma-core.target, plasma-plasmashell.service, plasma-kwin_wayland.service, and plasma-kactivitymanagerd.service are all active. D-Bus successfully activated org.kde.ActivityManager.
- Final screenshot F:alpbahOS-buildartifactsm07-gen2-plasma-runtimefix-2026-09-25-afterstartup.png shows the KDE wallpaper and bottom panel. SHA-256: 16ccEF466c155b23b8b81569b3d7c3a022f266fa66d1fb055e90900e88362d42. The initial screenshot showed KSplash while startup continued; the later capture is the desktop/panel acceptance evidence.
- Remaining visible/runtime gaps: Kickoff fails to load org.kde.kirigamiaddons.components; keyboard layout lacks org.kde.plasma.private.kcm_keyboard; notifications/volume lacks org.kde.plasma.private.volume; Plasma logs report no DRM render node for wl-drm and UDisks2 is not installed. The desktop and panel render despite these missing applet modules; full basic-app profile is not yet complete.
- For M-ISO staging, /mnt/lfs also contains /home/sa/.ssh/authorized_keys. It is a development access key and must be excluded. The test VHDX/profile is never an ISO source.

## Ek (25 Eylül gece): fare, font, ikon — kullanıcı VM'i kullanamıyordu
- **Fare:** kernelde `CONFIG_HID_HYPERV_MOUSE is not set` → VMConnect "Fare girişi yakalanmadı". Test VM'e Builder'da (Codex'in ağacı kopyalanarak, `/mnt/lfs`'e dokunmadan) `hid-hyperv.ko` (vermagic `6.16.1-alpbahOS SMP preempt mod_unload`) derlenip `/lib/modules/6.16.1-alpbahOS/extra/`'ya kondu, `modules-load.d/hid-hyperv.conf` ile açılışta yükleniyor; `/proc/bus/input/devices`'te "Microsoft Vmbus HID-compliant Mouse" görüldü. **Kalıcı çözüm (Codex):** kernel config'e `CONFIG_HID_HYPERV_MOUSE=y`. Derleme notu: kaynak ağacının `.config`'i artık `-miso1` (M09) — modülü `/mnt/lfs/boot/config-6.16.1-alpbahOS` ile derle, aksi halde vermagic uyumsuz.
- **Font:** imajda hiç font yoktu (her şey kare). Builder'dan DejaVu, Liberation2, Noto Core `/usr/share/fonts`'a kopyalandı, `fc-cache` çalıştı. **Kalıcı çözüm (Codex):** BLFS'e font paketleri (Noto, DejaVu, Liberation; Türkçe karakter desteği şart).
- **Açık:** panel/başlatıcıda ikon yok (boş sayfa ikonları) — Breeze ikon teması uygulama ikonları için eksik; Uygulama Başlatıcı `org.kde.kirigamiaddons.components` modülünü bulamıyor (kirigami-addons paketi derlenmemiş).
- Builder RAM üst sınırı 10 GB'a çıkarıldı (dinamik). CPU sayısı (4) Codex'in derlemesi bitince artırılabilir.
