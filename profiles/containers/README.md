# Container configuration (DISTROBOX-01, D163)

Installed to `/etc/containers/` by `scripts/rebuild/r40/dbx-r40.sh` (record `alpbahos-containers-r40`).
`policy.json` accepts any image (the upstream containers-common default); signature policies per registry are a
follow-up. `registries.conf` lets short names such as `debian:13` resolve on Docker Hub, Quay and GHCR.
