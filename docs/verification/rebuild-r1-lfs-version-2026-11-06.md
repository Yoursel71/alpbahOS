# REBUILD-R1: newest stable LFS, multilib edition, and version gap

Date: 2026-11-06. Scope: decision D140 (rebuild the base on the newest stable LFS with multilib) and D111 (x86_64 with lib32). Sources were fetched on 2026-11-06. "Verified" means read from the URL shown. "Inferred" means my reasoning, not stated by a source.

## 1. Newest stable LFS book (verified)

| Item | Value | Source |
|---|---|---|
| Stable systemd book | LFS 13.1-systemd | https://www.linuxfromscratch.org/lfs/download.html (lists "Current Stable (systemd)" at /lfs/downloads/stable-systemd/) |
| Book URL | https://www.linuxfromscratch.org/lfs/view/13.1-systemd/ | fetched; title "Version 13.1-systemd" |
| Release date | 2026-09-01 ("Published September 1st, 2026") | book page above; https://www.linuxfromscratch.org/lfs/news.html ("LFS-13.1 Release", 2026/09/01, Bruce Dubbs) |
| Changelog entry | "2026-09-01 bdubbs: LFS-13.1 released." | https://www.linuxfromscratch.org/lfs/view/13.1-systemd/chapter01/changelog.html |
| Matching BLFS | BLFS 13.1-systemd, published 2026-09-03 | https://www.linuxfromscratch.org/blfs/view/13.1-systemd/ ; https://www.linuxfromscratch.org/blfs/download.html (Current Stable Systemd 13.1); https://www.linuxfromscratch.org/blfs/news.html ("BLFS 13.1 has been released!", 2026/09/03) |

LFS 13.1 is the newest stable book on the site. The 13.1-rc2 news item (2026/08/16) is a preliminary release and is not used.

Key package versions from the LFS 13.1-systemd package list (https://www.linuxfromscratch.org/lfs/view/13.1-systemd/chapter03/packages.html):

| Package | 13.1 | 12.4 (alpbahOS base) | Source for 12.4 |
|---|---|---|---|
| glibc | 2.44 | 2.42 | https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter03/packages.html |
| gcc | 16.2.0 | 15.2.0 | same |
| binutils | 2.47 | 2.45 | same |
| Linux kernel | 7.1.8 | 6.16.1 | same |
| systemd | 261.2 | 257.8 | same |
| Python 3 | 3.14.7 | 3.13.7 | same |

## 2. Multilib edition (verified)

- Multilib LFS (MLFS) stable book: "Multilib Linux From Scratch - Version 13.1", "Published August 31st, 2026". URL: https://linuxfromscratch.org/mlfs/view/stable/ (fetched).
- The MLFS stable page is linked from https://linuxfromscratch.org/mlfs/ ("This is the stable release of MLFS that is known to work with BLFS, GLFS, and SLFS with identical instructions to LFS"). That page gives no version number. Its dev branch is https://linuxfromscratch.org/mlfs/view/dev/.
- MLFS 13.1 package list (https://linuxfromscratch.org/mlfs/view/stable/chapter03/packages.html) matches LFS 13.1 exactly: glibc 2.44, gcc 16.2.0, binutils 2.47, kernel 7.1.8, systemd 261.2, Python 3.14.7. Its lib32 mention is absent from that page.
- MLFS scope, from https://linuxfromscratch.org/mlfs/view/stable/prologue/multilib.html: it "provides 32-bit (i?86) dependencies and toolchains intended for 64-bit x86 (x86_64/AMD64) systems". It "installs a completely new LFS system". Adding multilib to an existing system "is not yet recommended", and it is recommended to have installed LFS first.
- Inferred: MLFS 13.1 tracks LFS 13.1, since the package versions are identical. The book pages do not state the base version. Open item: confirm with the MLFS editors or the book's multilib prologue before pinning.
- A search snippet (not fetched, so not verified) said the MLFS stable release tracks LFS 13.0. The fetched MLFS homepage does not contain "13.0". Treat the 13.0 claim as unverified.

## 3. Gap from the current base (verified unless marked)

- Current base: LFS 12.4-systemd, per docs/archive/DECISIONS-v1.md D33 (line 43 of that file). Its release date is 2025-09-01 (https://www.linuxfromscratch.org/lfs/news.html, "LFS-12.4 Release").
- Gap: one major step, 12.4 to 13.1 (13.0 released 2026-03-05, https://www.linuxfromscratch.org/lfs/view/13.1-systemd/chapter01/changelog.html).
- Changes listed by the book: the LFS 13.1 news item says "46 packages were updated or added", and "Major changes include toolchain updates to binutils-2.47, gcc-16.2.0, and glibc-2.44", plus the kernel update to 7.1.8 (https://www.linuxfromscratch.org/lfs/news.html).
- The book changelog does not compare with 12.4. Its 140 entries run from LFS-13.0 (2026-03-05) to LFS-13.1 (2026-09-01) and do not mention 12.4 or multilib (changelog URL above).
- Not verified: a complete 12.4 to 13.1 diff. The package-list table in section 1 covers the six packages asked for, not the full set.

## 4. Recommendation (inferred unless marked)

- Pin **LFS 13.1-systemd** (https://www.linuxfromscratch.org/lfs/view/13.1-systemd/) as the base book. It is the newest stable book, released 2026-09-01.
- Pin **MLFS 13.1** at its versioned URL https://linuxfromscratch.org/mlfs/view/13.1/ (the `stable/` URL moves to the next release; checked by the supervisor on 2026-11-06: `view/13.1/` returns 200, the view index also lists `13.1-openrc/` and `13.1-rc1*`, and `13.1-systemd/` is 404, so plain `13.1/` is the systemd edition) as the multilib instruction set, since it is the only official multilib edition I found for 13.1 and its package list matches LFS 13.1. Open point: its base version is not stated on the page.
- Pair with **BLFS 13.1-systemd** (https://www.linuxfromscratch.org/blfs/view/13.1-systemd/), the matching stable BLFS. Its page does not name a base LFS version, so the pairing is inferred from the matching release number.
- Keep 12.4 as the working base until the rebuild boots (D140). Build from the pinned book, not from the development branches.
- Before the rebuild starts, check the 13.1 book's build instructions against MLFS 13.1 (chapter 5 onward) for differences in toolchain steps. Not done in this research.
