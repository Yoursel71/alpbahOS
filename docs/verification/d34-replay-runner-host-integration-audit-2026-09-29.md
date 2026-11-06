# D34 replay-runner host integration audit — 29 September 2026

## Evidence gathered

- The clean candidate is a Btrfs subvolume on the NVMe filesystem (`/home`), while `/mnt/lfs` is a separate active Btrfs directory view on the HDD. Both identities were rechecked read-only. No candidate or active-root writes were performed.
- All **79** Chapter 8 scripts target paths inside `/mnt/lfs`. **76** host orchestrators require ext4 and inode identity with HDD `$DATA/lfs`, then acquire the common lock inside each script. Three special scripts are excluded from those exact guard counts: `build-lfs-glibc-ch8.sh` and `build-lfs-man-pages-ch8.sh` run inside the chroot; `build-lfs-iana-etc-ch8.sh` has a distinct host-side install path. (An earlier note said 78; the exact 76/79 grep count supersedes it.)
- A disposable root mount-namespace probe bind-mounted the NVMe candidate over `/mnt/lfs`, remounted that view read-only, confirmed the candidate tree was visible, and exited. The host `/mnt/lfs` view returned to its original HDD source and mount ID 907 afterward. This validates the isolation mechanism only; it did not run a builder or change the candidate.
- A Linux `flock` probe confirmed a child can re-lock the exact inherited open file descriptor (`flock -n FD` succeeded), while a new independent open of the same lock path was blocked. This is a viable mechanism for a wrapper to retain the LFS writer lock across a builder process without a second lock acquisition.

## Consequence / next implementation

The package scripts could not safely use the NVMe candidate as-is. On 30 September, the 76 host orchestrators were wired to [`lfs-build-guard.sh`](../../scripts/lfs-build-guard.sh): default HDD/ext4/inode checks and per-script lock acquisition remain; D34 mode validates the inherited lock FD and the exact filesystem UUID, mount ID, root device/inode, and subvolume UUID/ID. A **read-only** candidate bind mount passed this guard in a private namespace; the host `/mnt/lfs` mount remained unchanged. Static wiring tests cover all 76 adapted scripts and enumerate the three inner-chroot scripts.

Still required: implement the transaction runner that owns the lock before snapshot creation, creates disposable working snapshots, removes the old `/mnt/lfs` mount tree inside the private namespace, exposes the working subvolume there, mounts only required chroot pseudo-filesystems, unmounts them before snapshot/send, and rejects identity/mount drift. The three inner-chroot scripts need to be run only through that runner's locked parent transaction.

Validation: `bash -n` passed for all 79 Chapter 8 scripts and the common helper; builder wiring tests 3/3, send parser tests 9/9, candidate preflight tests 5/5, and documentation check 0 findings. These probes establish neither a real Chapter 8 install nor transaction rollback, per-package ownership reconciliation, or performance at full-root scale. The production ledger remains **0/79**; no package replay was attempted.
