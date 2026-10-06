# Base run 95e09834: preserved failure and recipe correction

Run `95e09834a6a310402d00451954c2d409` stopped before acceptance. Its outcome is
`FAIL` (SHA-256 `a59ff99fa2ed6b251f677b86e55de6bf8dbdc1b7a6f5b1d9323e738d4dc5dcea`).
The guest journal records `make -j4 tooldir=/usr` failing in Binutils BFD because
`bfd/compress.c` could not include `zlib.h`. The LFS zlib package was installed
and `/srv/lfs/usr/include/zlib.h` was present. Builds run outside the target LFS
root, so the host compiler did not search that target include directory.

The Binutils recipe now passes `CPPFLAGS=-I/srv/lfs/usr/include` through its
allowlisted recipe environment. This keeps the pinned `--with-system-zlib`
configuration while making its installed LFS dependency visible during the
isolated host-side compile. Recipe JSON validation and the 79-package inventory
and recipe-coverage check pass. A new Base run is required because the runner
preserves an interrupted `build-started` package and refuses to replay it.

The failed run’s VM was powered off; partial guest artifacts were captured at
`/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/95e09834a6a310402d00451954c2d409/guest-base-partial`.
Seventeen package install receipts are present there, including the passing
glibc package and all packages preceding Binutils in the canonical sequence.
The run has no Base acceptance or post-stage host audit; the next run will start
from the accepted Toolchain checkpoint and perform fresh host audits. The
failed run’s state, guest disks, and logs remain preserved for review.
