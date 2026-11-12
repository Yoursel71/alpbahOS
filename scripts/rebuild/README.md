   ':cccccccccccccccc::;,.
# REBUILD-R2: MLFS 13.1 multilib base rebuild (scripts)

Rebuild of the alpbahOS base on Multilib LFS 13.1 (systemd edition), decisions
D111, D140, D141, D145 and D146 in `docs/DECISIONS.md`. The build root is
`LFS=/mnt/lfs13`, a btrfs subvolume owned by user `yrslf`. `/mnt/lfs` is the
LFS 12.4 test base and is never touched by these scripts.

## Files

| File | Runs as | What it does |
|---|---|---|
| `config.sh` | sourced | Book 4.4 environment (`LFS`, `LFS_TGT`, `LFS_TGT32`, `LC_ALL`, `PATH`, `CONFIG_SITE`, `MAKEFLAGS=-j16`), `set +h`, umask 022, and `lfs_guard`. |
| `ch4-root.sh` | root | Book 4.2 directory layout and symlinks, `$LFS/tools`, `$LFS/sources`, and the 4.3 chown to `yrslf`. |
| `ch4-user.sh` | yrslf | Checks the layout and prints the build environment. No root. |
| `fetch-sources.sh <manifest>` | yrslf | Downloads all 96 book sources into `$LFS/sources`, checks md5 against the book, runs `md5sum -c`, writes the manifest TSV. |
| `version-check.sh` | any user | Book 2.2 host check plus the multilib `gcc -m32` test. Read-only. Prints PASS/FAIL/WARN. |
| `run-chapter.sh <chapter-dir> [first-NN]` | yrslf | Runs `<chapter-dir>/NN-*.sh` in order in a clean env, one log per script, stops at the first failure. |
| `ch5/`, `ch6/` | yrslf | Per-package build scripts (`NN-<package>.sh`). Not described here; see their headers. |
| `run-chroot.sh <chapter-dir> [first-NN]` | root (sudo) | Runs `<chapter-dir>/NN-*.sh` in order, each as `host` or `chroot` context (line 2). Mounts and unmounts the kernel file systems. |
| `ch7/` | root, via `run-chroot.sh` | MLFS 13.1 chapter 7: ownership, kernfs mounts, directories, essential files, gettext, bison, perl, zlib, mpdecimal, Python, texinfo, util-linux (64-bit and 32-bit), cleanup. |

Logs and fetch lists are kept outside the repo in
`/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/` (`<chapter>/NN-<pkg>.log`,
`<chapter>/summary.txt`, `fetch/`).

## Order of operations (supervisor)

1. `ch4-root.sh`, as root (once). Guard: LFS is `/mnt/lfs13`, is a btrfs subvolume, the caller is root.
2. `ch4-user.sh`, as yrslf (optional check of step 1).
3. `fetch-sources.sh <manifest.tsv>`, as yrslf. Downloads and verifies all sources. Exit 1 on any missing or bad file.
4. `version-check.sh`, as yrslf. Read-only host check.
5. `run-chapter.sh ch5 [NN]`, as yrslf.
6. Snapshot (done by the supervisor, outside these scripts).
7. `run-chapter.sh ch6 [NN]`, as yrslf.
8. Snapshot (supervisor).

Resume a chapter after a fix with `run-chapter.sh ch5 <NN>`. Each re-run appends to
the logs and the summary, and each log header records the script's sha256.

Chapter 7 (chroot) runs as root through `run-chroot.sh`, not `run-chapter.sh`:

10. `sudo run-chroot.sh ch7 [NN]`. Runs `ch7/NN-*.sh` in order. Each script declares its context
    in line 2: `# CONTEXT: host` (run on the host, `env -i`, `LFS=/mnt/lfs13`) or
    `# CONTEXT: chroot` (run in `$LFS` with `chroot(8)`; the script text is passed to `bash -c`,
    nothing is copied into the build root). `02-kernfs.sh` mounts dev, pts, proc, sys, run and
    shm; the runner unmounts them on exit (success, failure, INT, TERM, HUP) with plain `umount`,
    never `-R` or `-l`. The runner refuses to start if anything is already mounted under `$LFS`,
    and it runs `02-kernfs.sh` first when a resume starts at a chroot script.
11. Snapshot (supervisor), after the chapter.

Chapter 7 is run in a detached tmux session (`tmux new -d -s ch7 'sudo bash ... run-chroot.sh ch7'`).
Logs and summary follow the same layout as chapters 5 and 6, and are handed back to `yrslf`
when the runner exits.

## Deviations from the book

| Book (MLFS 13.1) | Here | Why |
|---|---|---|
| User `lfs`, `groupadd`/`useradd` | Existing host user `yrslf` | Single developer account; no new login. |
| `.bash_profile` + `.bashrc` (4.4) | `config.sh` values plus `env -i HOME TERM bash --noprofile --norc` per script | Same clean environment without dotfiles. |
| `LFS=/mnt/lfs`, `MAKEFLAGS=-j$(nproc)` | `LFS=/mnt/lfs13`, `MAKEFLAGS=-j16` | Contract value; repeat the parallelism measurement before trusting it (AGENT.md section 5). |
| `chown root:root $LFS/sources/*` after download | `sources` and downloads owned by `yrslf` | Builds run as yrslf. |
| `$LFS` owned by root (2.6) | `$LFS` owned by `yrslf` | Same reason. |
| `mv /etc/bash.bashrc` (4.4 note) | Not done | Only affects interactive bash; the runner uses `--norc`. The host file is not changed. |
| Download with `wget --input-file` | `curl` with resume, retries and UA `alpbahOS-build`; mirror fallback | Contract. Every file is still checked against the book md5. |
| Mirror (none in the book) | `ftp.osuosl.org/pub/lfs/lfs-packages/13.1/` for a file that fails at its book URL | Taken from the book's mirrors page. Its md5sums differ from the book for two entries, so it is used only with the book md5 check. |
| 7.2 `chown --from lfs` | `chown --from yrslf` (`ch7/01-changing-ownership.sh`) | Build user is `yrslf`. The script checks that nothing under those trees stays non-root. |
| 7.6 `exec /usr/bin/bash --login` | Not run (`ch7/04-create-essential-files.sh`) | Scripted, not interactive. The files are complete without it. |
| 7.15.2 backup tarball `$HOME/lfs-temp-tools-13.1.tar.xz` | Not written | The read-only btrfs snapshot `after-ch7-2026-11-06` is the backup, as for ch5 and ch6. |
| 7.15.1 cleanup and 7.4 `chroot` env | Same commands; `MAKEFLAGS=-j16` in the chroot env | Same parallelism as the host chapters (`config.sh`). |

Multilib: the book's 13.1 pages read for this step list no x32 parts, so none were skipped.

## D146: generic x86-64 baseline

- No `-march`, `-mtune` or host-detected CPU flags in anything that ends up in the final system. `config.sh` sets no `CFLAGS`.
- `libffi` is configured with `--with-gcc-arch=x86-64` (chapter 5/6 scripts).
- GMP is built with `--enable-fat` and generic `CFLAGS` when built standalone.
- `scripts/lfs-blfs/cpu-baseline/audit-isa.sh` is the audit after builds (AGENT.md section 5).

## Checking the scripts

```
bash -n scripts/rebuild/*.sh scripts/rebuild/config.sh
bash scripts/rebuild/version-check.sh
```

`shellcheck` is not installed on the build host, so only `bash -n` was run.
