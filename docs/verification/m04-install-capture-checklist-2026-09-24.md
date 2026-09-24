# M04 install-capture planning checklist — 24 September 2026

## Status and scope

This is a **planning checklist only**. It does not change `/mnt/lfs`, capture an
installation, or close M04. The current coverage matrix has stage manifests
for 40 of the 79 LFS 12.4-systemd Chapter 8 entries; those manifests describe
isolated `DESTDIR` trees, not observed installs into the final rootfs. The
other 39 entries have no stage manifest. See the [package coverage matrix](m04-lfs-12.4-package-coverage-2026-09-24.md).

LFS §8.2 says most packages support `DESTDIR`, while some do not. Therefore,
support must be verified for each recipe and every install-time write; the
presence of `DESTDIR` on a main `make install` command is not enough.
[LFS §8.2, Package Management](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/pkgmgt.html)

## Package-specific capture actions

Keep the Chapter 8 order from the [coverage matrix](m04-lfs-12.4-package-coverage-2026-09-24.md).
The following recipes need an explicit adapter or post-install capture in
addition to the main install target:

| LFS package(s) | Capture action and evidence to retain |
|---|---|
| Iana-Etc | Capture the generated `/etc/services` and `/etc/protocols` files and their metadata. Do not assign the shared `/etc` parent directory to the package. [§8.4](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/iana-etc.html) |
| Glibc | Capture the `make install` payload, the later edit to `/usr/bin/ldd`, and any separately run `localedef` outputs. Classify `/etc/ld.so.conf`, locale archive and other manually generated configuration/data separately from the ordinary payload. [§8.5.1–2](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/glibc.html) |
| Bzip2 | Its recipe uses package-specific install commands for the library, links, binaries and documentation. Stage each command and removal explicitly; verify the recipe's actual writes instead of assuming a generic `DESTDIR` target. [§8.7](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/bzip2.html) |
| Flex; Tcl; Expect; Pkgconf; Bash; Bison; Ncurses | Record compatibility links and auxiliary install steps (`lex`, `tclsh`, Expect library link, `pkg-config`, `/usr/bin/sh`, `yacc`, and Ncurses compatibility links/header edits) as package paths. [Flex §8.15](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/flex.html), [Tcl §8.16](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/tcl.html), [Expect §8.17](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/expect.html), [Pkgconf §8.19](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/pkgconf.html), [Bash §8.36](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/bash.html). |
| DejaGNU; Sed; Expat; GMP; MPFR; MPC | Include documentation installed by separate `install`/`install-html` commands. Exclude or centrally model updates to the shared Info index rather than attributing it independently to every package. [DejaGNU §8.18](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/dejagnu.html), [Sed §8.31](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/sed.html), [Expat §8.40](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/expat.html), [GMP §8.21](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/gmp.html), [MPFR §8.22](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/mpfr.html), [MPC §8.23](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/mpc.html). |
| Shadow | Keep executable/library payload separate from the later `pwconv`, `grpconv`, `useradd -D`, root-password, and account/configuration changes. Those mutate system state such as `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`, and `/etc/default/useradd`; do not silently claim them as static package files. [§8.28](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/shadow.html) |
| GCC | Include the explicit include-directory ownership correction, `/usr/lib/cpp`, `cc.1`, LTO plugin link and later `*gdb.py` move. Capture their final paths and metadata. [§8.29](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/gcc.html) |
| Coreutils | Apply the post-install `chroot` move, man-page move/section edit inside the stage or transaction. [§8.59](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/coreutils.html) |
| Ninja | The book installs the binary and shell completion files with individual `install` commands, rather than a conventional `make install`; stage each destination explicitly. [§8.56](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/ninja.html) |
| Perl; XML::Parser; Intltool; Python; Flit-Core; Packaging; Wheel; Setuptools; Meson; MarkupSafe; Jinja2 | These use Perl/Python module installation semantics. Capture the exact module tree, prefix, links and generated files; validate pip/MakeMaker staging options and prevent writes to the Builder's host Python/Perl tree. Site/module directories are shared namespaces. [Perl §8.43](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/perl.html), [Python §8.51](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/python.html), [Ninja §8.56](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/ninja.html), [Meson §8.57](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/meson.html). |
| GRUB | Capture the package programs and the separate Bash-completion move. Treat a later `grub-install` to a disk/EFI system partition or firmware NVRAM as deployment state, outside the generic package payload. [§8.64](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/grub.html) |
| Vim | Record the `vi` binary/man links and documentation link separately; `/etc/vimrc` is an authored configuration step and needs an explicit config ownership policy. [§8.73](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/vim.html) |
| Systemd | Stage `ninja install` and the separate man-page archive extraction. Treat `systemd-machine-id-setup` output as machine-specific state. Capture `systemctl preset-all` symlink changes separately because they depend on presets and the target's existing state. [§8.76](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/systemd.html) |
| D-Bus | Stage `ninja install` and separately capture `/var/lib/dbus` as the link to `/etc/machine-id`. [§8.77](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/dbus.html) |
| Man-DB; IPRoute2; Kbd; Procps-ng; Util-linux; E2fsprogs | Verify each package's configured paths, ownership/modes and auxiliary install commands. Keep caches, runtime files, `/var/lib` state and shared aliases distinct from immutable package payload unless the exact recipe proves their ownership. For Util-linux specifically, retain the `/run`/FHS path configuration and `/var/lib/hwclock` result. [Man-DB §8.78](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/man-db.html), [Util-linux §8.80](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/util-linux.html). |

The remaining recipes still require a traced/verified install event even when
the book shows a conventional install target. This table is not a certification
that any package's current script safely honors `DESTDIR`.

## Shared and generated paths

Apply one consistent policy to these cases across all 79 packages:

- Shared parent directories such as `/usr/share/doc`, `/usr/share/info`,
  `/usr/share/man`, `/usr/lib`, and `/etc`: record directory metadata once or
  mark the directory shared; do not make each package an exclusive owner.
- `/usr/share/info/dir`: a shared index modified by multiple Info installs;
  track it centrally or classify it as generated index data.
- Locale archive and other generated caches/databases: record the generating
  action and inputs, not an invented single-package file owner.
- Configuration and account data under `/etc`, runtime/cache data under
  `/var`, `/run` contents, machine ID, and bootloader/EFI state: classify as
  configuration, generated state, or deployment output under an explicit
  policy.
- Aliases and compatibility links (`sh`, `vi`, `lex`, `yacc`, `pkg-config`,
  GCC links, etc.): record link target and the selected owning package; detect
  replacement by later packages.
- Replaced files: preserve before/after hashes and the ordered install events;
  final ownership alone loses evidence of earlier package collisions.

The existing matrix already shows shared-path differences in staged
comparisons—for example `/usr/share/doc`, `/usr/share/info`, and
`/usr/share/info/dir`—so these need explicit treatment, not a blanket
directory-ownership assumption.

## M04 evidence rule

To close M04 for the full 79-package Chapter 8 scope tracked in the coverage
matrix, preserve an observed install event for every package. This is the
project's completeness scope; §10.1 itself does not state a package count. For
each event, preserve the pinned source/patch and recipe
identities, exact install command/environment, all paths written (including
manual post-install steps), path type, mode, owner/group, link target or file
hash, before/after state for replacements, test result, and log/artifact hash.
Verify that no writes escaped the intended stage/rootfs transaction. Then
reconcile the final rootfs against the ordered ownership ledger and explicitly
classify every non-package path.

A stage manifest, even with a complete rootfs content comparison, is not an
observed historical install and cannot establish ownership for files already
present in `/mnt/lfs`. If the existing rootfs cannot safely be replayed under
capture, the evidence-preserving option is a clean final-rootfs build with
capture enabled. Until all 79 install events and the final reconciliation pass,
M04 remains open.
