# alpbahOS 0.2-alpha internal tryout guide (draft)

**Status:** Internal test instructions. This is not a release announcement or a promise that every listed feature is complete.

## Image and scope

- Current image: `/mnt/alpbahOS-data/alpbahOS-build/artifacts/m10-packagekit-simfix-20260930/alpbahOS-live-m10-pk-simfix.iso` (x86_64/64-bit BIOS+UEFI tryout image; not release-approved). NVMe build copy: `/home/yrslf/alpbahOS-nvme/m10-alpha-20260930T/alpbahOS-live-m10-pk-sim-helper.iso`.
- Target architecture: x86_64 / 64-bit. The accepted long-term 32-bit x86 application runtime is not included in this first alpha; it is a later M03/M04 task.
- This ISO reached Plasma under BIOS and OVMF/KVM. On the latest OVMF run, Plasma appeared at 1920×1080 with the Atatürk wallpaper and visible pointer. Package tests used a disksless VM; live changes disappear when the VM powers off. Rendering was tested with QEMU's 2D virtio display; this is not a frame-rate or latency benchmark.

## Safe first tryout

1. Use a disposable QEMU/KVM VM and boot the ISO as its optical drive. Do not select a host physical disk as the guest system disk.
2. Allocate 4–6 vCPU and 4–8 GiB RAM; use a `virtio` display at 1920×1080. Do not infer frame rate or latency from the desktop smoke.
3. Test BIOS or UEFI boot. The live session reaches Plasma automatically; Ctrl+Alt+T opens Konsole.
4. Check existing files with Gwenview and Okular. Spectacle can save a full-screen PNG from Konsole with:

   ```sh
   spectacle --background --nonotify --fullscreen --output /tmp/screenshot.png
   file /tmp/screenshot.png
   ```

   `/tmp` belongs to the temporary live session; copy anything needed before shutting down the guest.
5. Shut down the QEMU guest after testing. The tested image does not require installing to a physical disk.

## Features to treat as incomplete

- PackageKit CLI install, launch (`htop --version` → 3.3.0), and remove passed on this live ISO. Discover found and installed htop, then removed it, but displayed a generic `Update Issue` after removal. Its details page also renders unknown size as `16.0 EiB` and license as Unknown. Do not treat Discover's transaction feedback as reliable yet; see the [live PackageKit/Discover report](m08-live-packagekit-auth-runtime-2026-09-30.md).
- Spectacle's command-line and interactive capture/save were verified on a predecessor ISO; the GUI save flow has not been repeated on the current 153622Z image.
- Konsole rendered the Turkish letters `Çç Ğğ İı Öö Şş Üü` without tofu, and `localectl` reports `tr_TR.UTF-8` / `trq` for system locale / virtual console. Active Wayland layout and physical Turkish-Q input still need interactive confirmation.
- The Atatürk wallpaper and pointer were visible in the latest UEFI run. Selected theme, shortcut, and Turkish-Q input flows still need interactive acceptance. Some desktop services emit D-Bus / UDisks2 warnings.
- Physical Wi-Fi, Bluetooth pairing, speakers/microphone, and hardware graphics are not certified by the VM tests.
- The user-facing release is still blocked on open items in `m10-alpha-test-matrix-2026-09-29.md`, including Discover's false failure after a successful removal and the M10 security/release review. The 79-package D34 ownership ledger is complete and independently reproduced; it describes the separate clean LFS candidate and does not certify the desktop rootfs or release ISO. See [ownership recheck](d34-ownership-ledger-recheck-2026-09-30.md).
