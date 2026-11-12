# 038: Debian box (ALP-KUTU-01) fails because netavark is missing (2026-11-12)

For: the session that owns DISTROBOX-01 / ALP-KUTU-01 and the r4-root build.

## Finding (rc01, ISO sha256 `fe439bb9...131b`)

- `distrobox create` as testuser (debian:13) exits 125:
  `Error: could not find "netavark" in one of [/usr/local/libexec/podman /usr/local/lib/podman /usr/libexec/podman /usr/lib/podman]`.
- `/usr/libexec/podman` has conmon, quadlet and rootlessport, no netavark. The alp database has no netavark record.
- Podman 5.x supports only the netavark network backend (CNI was removed), so this can't be fixed with a
  `containers.conf` setting; the binary has to ship.
- Effect on users: `alp install <name>` for a name that is not in the alp catalog and not on Flathub goes
  to the Debian box and ends with `alt işlem başarısız (çıkış 125): distrobox create`.
- Evidence: `scratch-lfs-bench/lfs13-logs/iso-beta-0.9/rc01/matrix/run-APPS.out`, `ALP-testuser-install.txt`,
  row KUTU in `results-rc01.tsv`; record `docs/verification/beta-rc01-2026-11-12.md`.

## Suggested fix

1. Build netavark (Rust, `make` / `cargo build --release`, install to `/usr/libexec/podman/netavark`) and
   aardvark-dns (DNS for container networks) with a stage record, so `alp check` stays clean. The versions
   should match what podman 5.8 expects (netavark 1.x).
2. Rerun the KUTU row: testuser `distrobox create -i debian:13`, `distrobox enter -- true`, then
   `alp install -y htop` through the box.
3. Until it ships: either keep KUTU out of the beta claim, or make alp say in Turkish that the Debian box
   is not available yet, instead of the raw podman error.

## rc01 status

rc01 contains the plymouth fix (handoff 037) and ALP-LOCK-MSG-01. All requested matrix rows pass on it; KUTU
is the only failing row. rc01 was built from a snapshot of r4-root; the live r4-root does not have the
plymouth patch yet (037 has the build steps).
