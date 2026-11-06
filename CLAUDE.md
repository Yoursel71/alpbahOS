# alpbahOS — Claude working rules

Claude is the only agent on this project (D100). The user decides and approves; Claude proposes, tests and reports.
Replies to the user are short Turkish. Live docs are English (D102); historical records (handoffs, verification, WORKLOG, archive) are not rewritten. This is the single rule file (D101); the v1 rule files are kept in [docs/archive/AGENTS-v1.md](docs/archive/AGENTS-v1.md), [docs/archive/CLAUDE-v1.md](docs/archive/CLAUDE-v1.md) and [docs/archive/AGENT_STANDING_RULES.md](docs/archive/AGENT_STANDING_RULES.md) for reference only.

## 1. Start of every session

Read in this order:

1. `CLAUDE.md` (this file)
2. `CURRENT.md`
3. `docs/DECISIONS.md`
4. `docs/MASTER_PLAN.md`
5. `docs/BACKLOG.md`
6. The newest file in `docs/handoffs/claude/`

Then:

- Run `git status`. Keep every uncommitted change you did not make. Never discard it.
- Do not re-ask anything these files already answer. If you must ask, write the answer into `docs/DECISIONS.md` (or here) so it is not asked again.
- If two of these files disagree, `docs/DECISIONS.md` wins. Report the conflict to the user instead of picking silently.
- Before any push, check `git remote -v` and `git worktree list` (section 9).

## 2. Product principles

Each item cites the decision it comes from. Changing one needs a new user decision in `docs/DECISIONS.md`.

- Name is exactly `alpbahOS` (D110). Architecture is x86_64 with a 32-bit multilib (lib32) user space (D111).
- Target users: schools/education and people moving from Windows (D112).
- Brand is unchanged: mountain/terminal logo, dark navy + cyan + orange (D113). Keep the logo and colours; record the source and licence of every asset.
- Atatürk theme is a selectable theme in the Welcome app and Settings. The default wallpaper and lock screen use the alpbahOS brand (D114).
- Layout: Windows-style single bottom taskbar with a Start menu (D115).
- Appearance: Solid by default, Glass as an option. Liquid glass is out of the first release (D116). Glass is claimed only with a measured performance result.
- Animations are smooth, fast and customisable (D117). Shortcuts follow a Windows-familiar profile (Alt+Tab, Win+D, Win+E, ...) generated from one source (D118).
- Terminal: Konsole + Zsh + zsh-autosuggestions + zsh-syntax-highlighting (D119, technical choice).
- Turkish UI, Turkish Q keyboard, Europe/Istanbul default time zone, changeable (D120).
- Settings: KDE System Settings plus an alpbah Welcome app on first boot (D121).
- Package engine is `alp` (D122). Commands `alp install`, `alp remove`, `alp update`; Turkish help and errors; typing `apt install ...` prints a hint that points to alp (D123).
- GUI store: KDE Discover with an alp PackageKit backend (D124). Flathub is on by default (D125). Stable channel; the user starts updates (D126).
- Preinstalled: Dolphin, Konsole, Kate/KWrite, Okular, Gwenview, Ark, LibreOffice, VLC, Firefox (D127). KDE Edu is not preinstalled.
- GPU: open-source Mesa drivers preinstalled; NVIDIA proprietary driver as a separate one-click package (D128). Mesa real drivers (Intel/AMD/NVIDIA open) plus llvmpipe (D134).
- Steam is supported natively through multilib (D129). Wine comes through Bottles (Flatpak), not a system Wine (D130).
- Microsoft Office is not a target; LibreOffice handles Word files (D131). Never promise Word compatibility without tests.
- Xwayland runs X11 apps inside the Wayland session (D132). KScreenLocker is the screen locker (D133).
- Target hardware: old x86_64 PC with 4 GiB RAM; idle at or below 1 GiB is a design target, measured before it is published as a requirement (D135).
- Boot: Legacy BIOS and UEFI (D136). First release = live USB + disk installer (D137). Installer is Calamares, graphical, offline, can install alongside Windows (D138). LUKS is an installer option; Secure Boot comes later (D139).
- Base: rebuild once on the newest stable LFS with multilib (D140), pinned to LFS 13.1-systemd, Multilib LFS 13.1 and BLFS 13.1-systemd (D145). Every base package is installed through `alp` so the file ownership ledger is automatic (D141). Test-image deviations are closed in the rebuild (D142).
- Kept from v1 (D143 and the v1 rules): build the LFS base from source and customise existing open-source projects. Do not write a kernel, compositor, browser or dependency solver from scratch. Do not promise driver or hardware support without tests.
- Terminal suggestions never run by themselves: accepting a suggestion is not running it.
- Spelling help never silently rewrites arguments or file names. Interactive shell settings do not leak into build scripts.
- Do not change `/bin/sh`. Scripts choose their interpreter explicitly.
- Shortcuts are defined in one place. No two system actions on one key; terminal Ctrl+C and similar context rules are kept.
- Accessibility: effect-off, contrast and reduced-motion behaviour must stay usable.

## 3. Environment

Facts below come from the handoff files and the repo as read on 2026-11-06. Items marked "not verified" were not checked in this session.

| Item | Fact |
|---|---|
| Host | Fedora (Linux). Test VMs run under QEMU/KVM (D106). |
| LFS chroot | `/mnt/lfs`. Bind mounts: `sudo bash scripts/lfs-blfs/mount_lfs.sh` (dev, pts, proc, sys, run, shm). Unmount: `scripts/lfs-blfs/umount_lfs.sh`. |
| Build scripts | `scripts/lfs-blfs/` (for example `build_image7.sh`, `run_blfs.sh`, `calamares/`, `live-iso/`). Source tarballs and images are not in Git. |
| Installer runner | `scripts/lfs-blfs/calamares/runner/m11-run.sh <new-target.img> <log-dir>` (root). Refuses an existing target file. |
| Scratch/work dir | `/home/yrslf/alpbahOS/scratch-lfs-bench`: `alp-iso/`, `alp-iso-out/`, `m11-runner/` (logs and target images), `test-secrets/` (test passwords, outside the repo). Its contents are not re-verified here beyond the directory listing. |
| Worktrees | `/home/yrslf/alpbahOS/alpbahOS-claude` (branch `claude/pkg-backlog-sync`); `/home/yrslf/alpbahOS/wt-t2-kisayol` (this tree, branch `claude/t2-kisayol-2026-11-05`). |
| Push target | remote `yoursel` = `https://github.com/Yoursel71/alpbahOS.git`. This is the only push target (D103). |
| Other remote | remote `origin` = `https://github.com/alperenyardim30-hash/alpbahOS.git`. Never push there. Open PR #5 is left untouched (D103). |
| Legacy | `scripts/legacy/`, `tests/legacy/` and `docs/archive/` hold old tools, tests and Windows-host notes (D104). Do not run or extend them without a reason written in the handoff. |
| Test base | LFS 12.4 system plus BLFS KDE Plasma 6.4.4 is the working base until the rebuild boots (D140, handoff 023). Kernel 6.16.1 (handoff 023). |
| Installed root device | `root=PARTUUID=…`, no initramfs (D144). Set by `scripts/lfs-blfs/calamares/modules/grubcfg.conf`. Needs GPT and `CONFIG_EFI_PARTITION=y`. |

## 4. Safety rules

- Never write a real or physical disk, partition, bootloader or Windows boot entry without the user's explicit permission for that exact action (D138).
- Installer and disk tests run only on new disk-image files. Never reuse or overwrite an existing target image.
- Never shut down or reboot the host without explicit approval (handoffs 023, 024).
- Never put passwords, keys or tokens in the repo, logs or chat. Test passwords stay in `scratch-lfs-bench/test-secrets/` (outside the repo). Release images must not contain test accounts, embedded keys or test fonts.
- One writer at a time on `/mnt/lfs` and on any image or nbd device. Check `/sys/block/nbd0/pid` (or the loop device in use) before you start.
- Every script that mounts an image or a chroot uses `trap ... ERR` (and EXIT) cleanup, so a failed run does not leave mounts, loop devices or changed images behind.
- Clean up big temp files (images, tarballs, squashfs) when the task ends. Do not leave them in `/tmp` or in the repo.
- Never use `git reset --hard`, `git clean`, `git stash` (bare) or force push. Never delete files of unknown origin; list them and ask.
- D105 removed the one-hour test limit and the per-session time box; long builds and tests may run in the background. The older VM rule from handoffs 021/024 (few VM boots per session, report each extra boot) stays until the user changes it.

## 5. Build rules

- Verify every source (checksum or signature) before building. Never pipe a downloaded script into a shell.
- No host-specific CPU flags: never build with `-march=native` or host-detected CPU names. Follow D146 (generic x86-64 baseline, newer instructions only with runtime dispatch), run `scripts/lfs-blfs/cpu-baseline/audit-isa.sh` after every build, and use the default `qemu64` CPU model as the QEMU gate.
- Record per package: book version, URL, checksum, patches, configuration, dependencies, log path and status.
- Separate clean build/staging directory, log and status file for each package.
- Resume from verified inputs and outputs, not from stamp files.
- Do not hide critical toolchain test failures. Known exceptions go into the handoff or the verification record with the log and the reason.
- Set parallelism from RAM and measurements, and record the value used (handoff 024 ran the module build with `-j16`; treat that as a measurement to repeat, not a rule).
- State for every command whether it runs on the host, in the chroot, in the temporary toolchain or in the target system.
- Check `$LFS` before use: it must be non-empty, resolved, and the expected mount must be present. Never install into the host root.
- Keep LFS user and permission order. Limit root operations to the steps that need them.
- All fixes go into the rootfs/build scripts first. Images are produced from the rootfs. No manual fixes inside a test VM.
- Long builds and tests may run in the background for hours, overnight included (D105). Report a summary afterwards.

## 6. Package rules

- One package database and one transaction lock. The CLI and Discover call the same `alp` engine (D122, D124).
- No second native package manager in the same rootfs.
- No partial updates. Packages come from our own recipes and our own manifest.
- `apt`-like command names do not mean Debian or Ubuntu binary compatibility. Do not mix in an external distribution's base repositories.
- For each system package, check the source and repository trust. Flatpak apps (Flathub) show their source to the user.
- Dependency resolution and graphical store integration count as working only after tests on the target.

## 7. Evidence and honesty

- These are different states and must be named as such: "script ready", "build passed", "booted", "works on real hardware". Do not merge them.
- Never report untested work as done. Write "not run" for every test that was not run.
- Every result gives: environment (host, chroot, QEMU VM, target), command, result and log/artifact path.
- Failed attempts are recorded with the log and the cause, then fixed and retried. Do not hide them.
- Screenshots and logs go into the verification folder or the handoff, and are linked from there.
- A milestone is done only when its exit criteria in `docs/MASTER_PLAN.md` are proven. Otherwise write "partial" and list the remaining debt.
- Claude review is a check, not proof. Say whether a review was done.
- Mockup names, kernel versions, package counts or desktop names in designs are not evidence of a running system.

## 8. Working with the user

- Do not ask the user to run terminal commands. Do everything you can yourself.
- Exception: physical or administrator steps only. Ask once, with the exact commands.
- Short Turkish reports: what was done, where the evidence is, what is next. Long logs stay in files.
- A user decision goes into `docs/DECISIONS.md`. Update every affected doc in the same commit, then run `python3 docs/handoffs/claude/tools/check_docs.py`.
- Do not re-ask a documented decision. If the user has not decided, keep the item open and say what it blocks. No user decisions are open as of 2026-11-06.
- External actions need the user's go-ahead unless they were already given: push, release, making the repo public, GitHub changes (D103, D108). Every release needs approval; M12 release is a separate approval (handoff 023).
- Subagents only when the user asks. Give each one a disjoint set of files. Keep git operations in the main session.

## 9. Git

- Work on a branch or worktree, then deliver by fast-forwarding `main` on `yoursel` (D103). No pull request is needed unless the user asks for one.
- Run `git fetch` before any push.
- Push to `yoursel` `main` with fast-forward only (D103). Never force push. Never rewrite pushed history.
- Do not reset, stash or overwrite other people's uncommitted changes. If you must set work aside, commit a temporary WIP commit on your branch.
- Commit only when the task asks for it. Keep commits scoped to the task's files.

## 10. Handoff note

At the end of each work session, write `docs/handoffs/claude/NNN-<topic>-<yyyy-mm-dd>.md`. Use the next free number (025 is the newest as of 2026-11-06). Template:

```text
Task / status:
Host, branch and commit:
Changed files:
Behaviour (what works now):
Checks run and results (environment, command, result):
Logs / screenshots / artifacts (paths):
Known issues and open decisions:
Next single action:
```

Mark each check that was not run as "not run". Keep the note short; put long output in a log file and link it.
