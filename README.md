# alpbahOS

![alpbahOS logo](docs/assets/alpbahOS-logo.png)

alpbahOS is a desktop Linux system built from Linux From Scratch (LFS) for x86_64 PCs with 32-bit multilib user space. It is for schools and for people moving from Windows. The default language is Turkish. The desktop is KDE Plasma with a Windows-style bottom taskbar and Start menu. Software comes from the `alp` package manager, KDE Discover, and Flathub.

## Status

- In development. There is no usable release yet, and no release ISO has been published.
- Test base: LFS 12.4 system with BLFS KDE Plasma 6.4.4 (Wayland session), tested in QEMU/KVM.
- Live ISO boots with BIOS in the test. The installer has been run on a virtual BIOS disk only. UEFI is not tested yet.
- The first alpha is not released. The planned rebuild on the newest stable LFS with multilib is not started (D140).
- Current state and evidence: [CURRENT.md](CURRENT.md). Open work: [docs/BACKLOG.md](docs/BACKLOG.md).

## Documents

- [CLAUDE.md](CLAUDE.md): working rules for the agent (rules)
- [CURRENT.md](CURRENT.md): current state
- [docs/DECISIONS.md](docs/DECISIONS.md): decisions with IDs
- [docs/MASTER_PLAN.md](docs/MASTER_PLAN.md): plan and milestones
- [docs/BACKLOG.md](docs/BACKLOG.md): tasks, acceptance criteria, status
- [docs/WORKLOG.md](docs/WORKLOG.md): history (not rewritten)
- [docs/handoffs/claude/](docs/handoffs/claude/): session notes
- [docs/verification/](docs/verification/): test evidence and logs
- [docs/archive/](docs/archive/): old versions of the documents above

## Build and release

- Builds run locally. Release ISOs will be published on GitHub Releases (D107).
- The repository stays private until the first alpha ISO is ready, then it becomes public (D108). Each release needs the user's approval.

## License

- Project code: GPL-3.0, see [LICENSE](LICENSE) (D109).
- Third-party components keep their own licenses (D109).
