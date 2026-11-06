# D34 BLFS audio/session stack replay — 30 September 2026

## Scope and method

The BLFS audio/session prerequisites were replayed in order on private Btrfs snapshots on the NVMe D34 candidate. The host HDD target `/mnt/lfs`, current live ISO, and prior candidate snapshots were not modified. The package builders used the shared writer-lock guard; the replay runner recorded each package delta and the reconciler extended the existing LFS ownership chain. The user asked to skip checksum calculations, so no package checksum was computed. Upstream package test suites were not run by these builders.

## Successful package sequence

| Package | Version | D34 run | Result |
| --- | --- | --- | --- |
| PipeWire | 1.4.7 | `pipewire-20260930T071124Z-88d33363` | PASS |
| PCRE2 | 10.45 | `pcre2-20260930T072205Z-80d2176d` | PASS |
| GLib | 2.84.4 | `glib-20260930T072525Z-f3747960` | PASS |
| WirePlumber | 0.5.10 | `wireplumber-20260930T072724Z-fc96b11a` | PASS |

Sources were the retained upstream archives: PipeWire from freedesktop.org, PCRE2 from the PCRE2Project GitHub release, GLib from download.gnome.org, and WirePlumber from freedesktop.org. No source archive was replaced during these replays.

PipeWire built with ALSA and libsndfile support, `pw-cat` tools, and without the unavailable optional Flatpak integration. PCRE2 built Unicode, JIT, 8/16/32-bit libraries, and zlib/bzip2/readline integrations. GLib used the newly replayed PCRE2 dependency; optional man-page and introspection generation were disabled to avoid unrelated documentation/tooling dependencies. WirePlumber used GLib, PipeWire, and Lua, and installed its systemd user unit. The user units were not enabled or started.

## Evidence

- Each successful run has `status.json`, `builder.log`, `events.jsonl`, and `incremental-send.bin` under `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/<run-id>/`.
- The final WirePlumber run contains `d34-ownership-ledger.json`: `COMPLETE`, all 79 official LFS Chapter 8 packages, 11 separately recorded BLFS supplemental packages, 4,689,836 path events, and 54,598 final system-path owners.
- A root-level walk of the final read-only candidate found every final-owned path for PipeWire (522), PCRE2 (239), GLib (541), and WirePlumber (215). Critical executable, shared-library, and user-unit paths were also present, including `pipewire`, `pw-cat`, `pw-play`, `pw-record`, `wireplumber`, `wpctl`, `libpipewire-0.3.so`, `libpcre2-8.so`, `libglib-2.0.so`, `libwireplumber-0.5.so`, and both user units.
- D34 regression checks: 22 passed across supplemental reconciliation, candidate preflight, builder wiring, and audio wiring. `bash -n`, Python bytecode compilation, and `git diff --check` passed.

## Failure retained and correction

Two GLib replay attempts stopped before package build because `build-blfs-glib.sh` tried to acquire the shared lock directly even though D34 had passed its already-held lock descriptor. Those failed runs remain preserved (`glib-20260930T072331Z-8ad7263a` and `glib-20260930T072414Z-6a92dd90`). The builder now calls `lfs_acquire_writer_lock`, which validates the inherited D34 lock, and the subsequent GLib replay passed.

## Limits

This proves package installation and ownership accounting in the clean D34 candidate. It does not prove that the active M06/M07 rootfs or current ISO was rebuilt from this candidate. No audio device playback/recording, PipeWire session startup, Plasma session, network behavior, or physical hardware was tested. M06 and M09 release acceptance remain open.
