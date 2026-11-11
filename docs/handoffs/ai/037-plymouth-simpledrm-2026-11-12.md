# 037 — Plymouth crash at boot (PLY-CRASH-01): cause, the UseSimpledrm=0 test, proposed patch, 2026-11-12

For the session that builds the ISO. Nothing in the build or the ISO was changed by this work. Records:
[r39x-followup-2026-11-11.md](../../verification/r39x-followup-2026-11-11.md) (sections 1 and 4).

## What happens

`plymouthd` (started in the initramfs) crashes with SIGSEGV when the boot splash is hidden: 3 of 20 boots of the r39
BIOS install in QEMU. The cores give this stack:
`ply_keyboard_remove_input_handler ← stop_script_animation ← hide_splash_screen (script.so) ← on_boot_splash_idle`.

What follows in the same boot:

- plymouth-quit times out after 20 s;
- SDDM starts about 20 s late;
- the next power-off does not finish within 60 s.

It happens when plymouth-quit arrives just after the kernel switches from simpledrm to the real DRM driver
(virtio_gpu in QEMU).

## Cause (plymouth 26.134.222 source, `r10/dl/plymouth-26.134.222.tar.xz`)

`src/libply-splash-core/ply-device-manager.c`, `free_keyboards_for_renderer()` (line 153; the free is at line 169).
When a DRM device arrives, `create_devices_for_terminal_and_renderer_type` first frees the simpledrm renderer
(`free_simpledrm_renderer` → `free_devices_from_device_path` → `free_keyboards_for_renderer`). That function calls
`ply_keyboard_free (keyboard)` without calling `manager->keyboard_removed_handler`. That handler is stored (lines
83, 1288) but never called anywhere. The display path does call its handler (`free_displays_for_renderer`, line
142).

As a result, `main.c` `on_keyboard_removed()` → `ply_boot_splash_unset_keyboard()` never runs. The script plugin
keeps `plugin->keyboard` pointing at the freed keyboard; its own `unset_keyboard` would have set it to NULL. When the
splash is hidden, `stop_script_animation()` calls `ply_keyboard_remove_input_handler()` on that freed object:
use-after-free. Two cores fault on a NULL list, one on a freed list node.

## Option A: UseSimpledrm=0 (tested, not recommended)

Tested on a reflink copy of the r39 BIOS install:

- `/etc/plymouth/plymouthd.conf`: `UseSimpledrm=1` → `0`. `plymouthd.defaults` was unchanged, so dracut keeps the
  same module list and the initramfs stays at 57.7 MB.
- The initramfs was rebuilt with `target-initramfs.sh`. The initramfs copy of the file then reads `UseSimpledrm=0`.

Result: **0/20 crashes** (r21 S1/r39x conditions; `r39y/PLYFIX/`, `run-PLYFIX.out`). But **the splash is no
longer seen**:

- Without the change, screenshots once a second show the alpbahOS logo with the bar and "Başlatılıyor" from about
  7 s to 11 s after QEMU start (`PLYFIX/FIX-setup/boot-08s.png`).
- With the change, the GRUB frame stays until the screen goes black and the greeter appears
  (`PLYFIX/FIX-c01/boot-10s.png`; same in FIX-c02).
- Plymouth can draw only once the real DRM driver is there (about 3.2 to 4.5 s kernel time, after the switch to the
  real root). plymouth-quit follows 0.05 to 0.4 s later.

The comment in `scripts/rebuild/r23/plymouth-r23.sh` (line 6) already explains this: the GPU drivers are modules
outside the initramfs (D150). Putting `UseSimpledrm=0` into `plymouthd.defaults` too would make dracut pull every
GPU driver and its firmware into the initramfs (about 221 MB, seen 2026-11-10). So option A trades the splash, or a
much larger initramfs, for the fix.

## Option B: patch plymouth (proposed, not built, not tested)

Patch file: [patches/037-plymouth-keyboard-removed.patch](patches/037-plymouth-keyboard-removed.patch). It applies
to 26.134.222 (`patch -Np1 --dry-run`: OK).

```diff
--- a/src/libply-splash-core/ply-device-manager.c
+++ b/src/libply-splash-core/ply-device-manager.c
@@ -166,6 +166,8 @@
                 keyboard_renderer = ply_keyboard_get_renderer (keyboard);
 
                 if (keyboard_renderer == renderer) {
+                        if (manager->keyboard_removed_handler != NULL)
+                                manager->keyboard_removed_handler (manager->event_handler_data, keyboard);
                         ply_keyboard_free (keyboard);
                         ply_list_remove_node (manager->keyboards, node);
                 }
```

How to apply: rebuild the plymouth record with the existing hook,
`PRE_PATCH=docs/handoffs/claude/patches/037-plymouth-keyboard-removed.patch` in
`scripts/rebuild/r10/build-pkg-r10.sh` (lines 27-28, 48, autogen path), the same way as the itstool and Calamares
patches. Keep `UseSimpledrm=1` (`scripts/rebuild/r23/plymouth-r23.sh` lines 30 and 52). Then rebuild the
initramfs: the plymouthd in the initramfs is the one that crashes.

Before relying on it:

- Upstream main was not checked: gitlab.freedesktop.org refused the automated fetch (bot protection). Check whether
  upstream already calls the handler there; if yes, take the upstream commit instead.
- After the change, `on_keyboard_removed` runs for the simpledrm keyboard. It removes the daemon's own key
  handlers and calls `ply_boot_splash_unset_keyboard`. The DRM renderer's keyboard then arrives through
  `keyboard_added_handler` (`on_keyboard_added` → `set_keyboard`), so the splash should get the new keyboard.
  Not run.
- Test: the same 20-boot loop (`scripts/rebuild/r39y/ply-loop-r39y.sh`, cores counted from files) on an install
  from the new ISO, and the LUKS prompt if LUKS is used (keyboard input during the device switch).

## Recommendation

Option B, with the 20-boot loop as the check. Option A only if the splash may be dropped.
