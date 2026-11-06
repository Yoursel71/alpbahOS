# D34 BLFS libnl replay — 30 September 2026

## Result

BLFS `libnl 3.11.0` completed in a private D34 replay after the display-library supplemental candidate.

- Input: `libdisplay-info-20260930T065609Z-4b4b07e5/after-ro`, filesystem UUID `663b4a21-0364-4ee2-91cd-67d5994e9fe4`, subvolume UUID `96e46878-e26e-0743-9d67-ad7ae1f833b6`, ID 594.
- Replay `libnl-20260930T065833Z-8cdbaa35`: PASS; 14,484 Btrfs events and 31,598,622-byte incremental send.
- Output snapshot UUID `f654f282-283a-bd42-9850-2f1842cdfa99`, ID 597.
- Durable ledger: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/libnl-20260930T065833Z-8cdbaa35/d34-ownership-ledger.json`; COMPLETE, 79/79 official LFS entries, four supplemental packages (Linux-PAM, hwdata, libdisplay-info, libnl), and 51,865 final path owners.
- All 267 final paths attributed to libnl were found in the output snapshot. The installed `nl-link-list` command exists. The builder's pkg-config, version, header, shared-library and command checks passed.
- Package test suite and checksum calculations were skipped per the builder scope and user instruction. Existing `/mnt/lfs` and ISO artifacts were not replay targets.

The host builder now uses the shared D34 identity/lock guard. The runner approves only the matching `libnl` host script, and reconciliation accepts libnl as a post-LFS supplemental only after hwdata. Before replay, 14 targeted D34 tests passed, along with Python compilation, shell syntax and `git diff --check`. This is M06 network-library progress; it does not prove a complete NetworkManager stack or desktop release.
