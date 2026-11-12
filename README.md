# alpbahOS

![alpbahOS logo](docs/assets/alpbahOS-logo.png)

alpbahOS is a desktop Linux system built from Linux From Scratch (LFS) for x86_64 PCs with a 32-bit multilib user space. It is for schools and for people moving from Windows. The default language is Turkish. The desktop is KDE Plasma with a Windows-style bottom taskbar and Start menu. Software comes from the `alp` package manager, KDE Discover and Flathub.

**Documentation site (Turkish):** https://yoursel71.github.io/alpbahOS/ — source in [`site/`](site/).

## Status

- In development. Beta 0.9 test ISOs are built and tested in QEMU (BIOS and UEFI). None is published and there is no release yet.
- Base: the rebuilt LFS 13.1 / BLFS 13.1 system with a KDE Plasma Wayland session (D145).
- Working in the latest tested rounds: live ISO, Calamares installer (new look, Turkish status text, optional NVIDIA driver page), Zsh as the login shell, network printing (Avahi, CUPS, driverless IPP discovery), the first-login Welcome app (theme, appearance, taskbar position).
- Not tested yet: a real PC (USB boot, real Wi-Fi, NVIDIA). The Beta 0.9 gate is not met.
- Current state and evidence: [CURRENT.md](CURRENT.md). Open work: [docs/BACKLOG.md](docs/BACKLOG.md).

## Documents

- [CURRENT.md](CURRENT.md): current state
- [docs/DECISIONS.md](docs/DECISIONS.md): decisions with IDs
- [docs/MASTER_PLAN.md](docs/MASTER_PLAN.md): plan and milestones
- [docs/BACKLOG.md](docs/BACKLOG.md): tasks, acceptance criteria, status
- [docs/WORKLOG.md](docs/WORKLOG.md): history (not rewritten)
- [docs/handoffs/ai/](docs/handoffs/ai/): session notes
- [docs/verification/](docs/verification/): test evidence and logs
- [docs/archive/](docs/archive/): old versions of the documents above
- [site/](site/): the Turkish documentation site (VitePress, published with GitHub Pages)

## Build and release

- Builds run locally (see [scripts/rebuild/](scripts/rebuild/)). Release ISOs will be published on GitHub Releases (D107).
- Each release needs the owner's approval.
- To work on the docs site: `cd site && npm ci && npm run dev`.

## License

- Project code: GPL-3.0, see [LICENSE](LICENSE) (D109).
- Third-party components keep their own licenses (D109).
