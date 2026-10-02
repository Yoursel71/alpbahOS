# alpbahOS altyapı incelemesi — 30 Eylül 2026

Faz 0; salt okunur inceleme. Bu dosya bu fazdaki tek yazma hedefidir.
Ana repo veya Claude ağacı değiştirilmiyor. Kaynak görev metninde kesilmiş satırlar var; eksik ölçütler tahminle tamamlanmadı.

## Kimlik

Komut: `date --iso-8601=seconds; id; uname -r; cat /etc/os-release`

```text
2026-09-30T22:40:12+03:00
uid=1000(yrslf) gid=1000(yrslf) groups=1000(yrslf),10(wheel) context=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
7.2.7-200.fc44.x86_64
NAME="Fedora Linux"
VERSION="44 (KDE Plasma Desktop Edition)"
RELEASE_TYPE=stable
ID=fedora
VERSION_ID=44
VERSION_CODENAME=""
PRETTY_NAME="Fedora Linux 44 (KDE Plasma Desktop Edition)"
ANSI_COLOR="0;38;2;60;110;180"
LOGO=fedora-logo-icon
CPE_NAME="cpe:/o:fedoraproject:fedora:44"
DEFAULT_HOSTNAME="fedora"
HOME_URL="https://fedoraproject.org/"
DOCUMENTATION_URL="https://docs.fedoraproject.org/en-US/fedora/f44/"
SUPPORT_URL="https://ask.fedoraproject.org/"
BUG_REPORT_URL="https://bugzilla.redhat.com/"
REDHAT_BUGZILLA_PRODUCT="Fedora"
REDHAT_BUGZILLA_PRODUCT_VERSION=44
REDHAT_SUPPORT_PRODUCT="Fedora"
REDHAT_SUPPORT_PRODUCT_VERSION=44
SUPPORT_END=2027-05-19
VARIANT="KDE Plasma Desktop Edition"
VARIANT_ID=kde

exit=0
```

## Disk ve RAM

Komut: `df -B1 / /mnt/alpbahOS-ssd /mnt/alpbahOS-data; free -b; findmnt -R /mnt/lfs; findmnt -R /mnt/alpbahOS-data; findmnt -R /mnt/alpbahOS-ssd`

```text
Filesystem        1B-blocks         Used    Available Use% Mounted on
/dev/nvme0n1p3 509332160512 377419710464 116673363968  77% /
/dev/sda1      120032591872  44656906240  74163269632  38% /mnt/alpbahOS-ssd
/dev/sdb1      491106512896 349525286912 136563384320  72% /mnt/alpbahOS-data
               total        used        free      shared  buff/cache   available
Mem:     25046814720  6250721280  7511224320   415174656 12068851712 18796093440
Swap:    25769795584           0 25769795584
TARGET                         SOURCE                                               FSTYPE OPTIONS
/mnt/lfs                       /dev/sda1[/alpbahos-builds/active/lfs-rootfs]        btrfs  rw,noatime,seclabel,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/
├─/mnt/lfs/sources             /dev/sda1[/alpbahos-builds/active/lfs-source-cache]  btrfs  rw,noatime,seclabel,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/
└─/mnt/lfs/mnt/alpbahos-builds /dev/nvme0n1p3[/home/yrslf/alpbahOS-nvme/builds/m07] btrfs  rw,relatime,seclabel,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=257,subvol=/home
TARGET                                         SOURCE                                             FSTYPE OPTIONS
/mnt/alpbahOS-data                             /dev/sdb1                                          ext4   rw,noatime,seclabel
├─/mnt/alpbahOS-data/alpbahOS-build/downloads  /dev/sda1[/alpbahos-builds/active/work/downloads]  btrfs  rw,noatime,seclabel,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/
├─/mnt/alpbahOS-data/alpbahOS-build/host-tools /dev/sda1[/alpbahos-builds/active/work/host-tools] btrfs  rw,noatime,seclabel,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/
├─/mnt/alpbahOS-data/alpbahOS-build/locks      /dev/sda1[/alpbahos-builds/active/work/locks]      btrfs  rw,noatime,seclabel,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/
├─/mnt/alpbahOS-data/alpbahOS-build/logs       /dev/sda1[/alpbahos-builds/active/work/logs]       btrfs  rw,noatime,seclabel,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/
├─/mnt/alpbahOS-data/alpbahOS-build/sources    /dev/sda1[/alpbahos-builds/active/work/sources]    btrfs  rw,noatime,seclabel,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/
├─/mnt/alpbahOS-data/alpbahOS-build/staging    /dev/sda1[/alpbahos-builds/active/work/staging]    btrfs  rw,noatime,seclabel,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/
└─/mnt/alpbahOS-data/alpbahOS-build/tmp        /dev/sda1[/alpbahos-builds/active/work/tmp]        btrfs  rw,noatime,seclabel,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/
TARGET                                                                    SOURCE                                               FSTYPE OPTIONS
/mnt/alpbahOS-ssd                                                         /dev/sda1                                            btrfs  rw,noatime,seclabel,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/
├─/mnt/alpbahOS-ssd/alpbahos-builds/active/lfs-rootfs/sources             /dev/sda1[/alpbahos-builds/active/lfs-source-cache]  btrfs  rw,noatime,seclabel,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/
└─/mnt/alpbahOS-ssd/alpbahos-builds/active/lfs-rootfs/mnt/alpbahos-builds /dev/nvme0n1p3[/home/yrslf/alpbahOS-nvme/builds/m07] btrfs  rw,relatime,seclabel,compress=zstd:1,ssd,discard=async,space_cache=v2,subvolid=257,subvol=/home

exit=0
```

## Git

Komut: `git -C /home/yrslf/alpbahOS status --short --branch; git -C /home/yrslf/alpbahOS rev-parse HEAD; git -C /home/yrslf/alpbahOS worktree list --porcelain; git -C /home/yrslf/alpbahOS-claude status --short --branch; git -C /home/yrslf/alpbahOS-claude rev-parse HEAD`

```text
## main...origin/main [behind 12]
 M AGENTS.md
 M CLAUDE.md
 M CURRENT.md
 M docs/AGENT_STANDING_RULES.md
 M docs/AI_ENVIRONMENT_GUIDE.md
 M docs/BACKLOG.md
 M docs/CLAUDE_START.md
 M docs/DECISIONS.md
 M docs/HYPERV_PLAN.md
 M docs/M2_BLFS_MANIFEST.md
 M docs/MASTER_PLAN.md
 M docs/NEW_SESSION_HANDOFF.md
 M docs/WORKLOG.md
 M docs/patches/plasma-workspace-6.4.4-wayland-no-x11.patch
 M scripts/build-m2-gen2-test-image.sh
 M scripts/capture-m04-install-event.py
 M tests/test_m04_install_event_capture.py
 M tests/test_m04_linux_seccomp_integration.py
?? configs/polkit/
?? docs/patches/kwin-6.4.4-wayland-only-killer.patch
?? docs/patches/libkscreen-6.4.4-wayland-only.patch
?? docs/patches/plasma-desktop-6.4.4-wayland-no-ksmserver-dbus.patch
?? docs/verification/d34-blfs-alsa-lib-replay-2026-09-30.md
?? docs/verification/d34-blfs-audio-stack-replay-2026-09-30.md
?? docs/verification/d34-blfs-ca-trust-stack-2026-09-30.md
?? docs/verification/d34-blfs-hwdata-replay-2026-09-30.md
?? docs/verification/d34-blfs-libdisplay-info-replay-2026-09-30.md
?? docs/verification/d34-blfs-libdrm-replay-2026-09-30.md
?? docs/verification/d34-blfs-libnl-replay-2026-09-30.md
?? docs/verification/d34-blfs-libpciaccess-replay-2026-09-30.md
?? docs/verification/d34-blfs-libsndfile-replay-2026-09-30.md
?? docs/verification/d34-blfs-libyaml-replay-2026-09-30.md
?? docs/verification/d34-blfs-mesa-python-tools-2026-09-30.md
?? docs/verification/d34-blfs-network-stack-replay-2026-09-30.md
?? docs/verification/d34-blfs-networkmanager-stack-2026-09-30.md
?? docs/verification/d34-blfs-nss-trust-replay-2026-09-30.md
?? docs/verification/d34-blfs-polkit-replay-2026-09-30.md
?? docs/verification/d34-blfs-qt-wayland-2026-09-30.md
?? docs/verification/d34-blfs-wayland-protocols-replay-2026-09-30.md
?? docs/verification/d34-blfs-wayland-replay-2026-09-30.md
?? docs/verification/d34-blfs-wpa-supplicant-replay-2026-09-30.md
?? docs/verification/d34-kf6-framework-replay-2026-09-30.md
?? docs/verification/d34-ownership-ledger-recheck-2026-09-30.md
?? docs/verification/d34-plasma-replay-sprint-2026-09-30.md
?? docs/verification/d34-replay-runner-host-integration-audit-2026-09-29.md
?? docs/verification/glibc-ch8-check-review-2026-09-26.md
?? docs/verification/m04-btrfs-send-delta-probe-2026-09-29.md
?? docs/verification/m04-btrfs-send-ledger-parser-2026-09-29.md
?? docs/verification/m04-linux-fixture-probe-2026-09-29.md
?? docs/verification/m08-htop-prefix-root-cause-2026-09-30.md
?? docs/verification/m08-live-packagekit-auth-runtime-2026-09-30.md
?? docs/verification/m08-package-store-transaction-failure-2026-09-29.md
?? docs/verification/m08-packagekit-path-and-auth-retest-2026-09-30.md
?? docs/verification/m09-clean-lfs-desktop-integration-audit-2026-09-30.md
?? docs/verification/m10-alpha-test-matrix-2026-09-29.md
?? docs/verification/m10-alpha-user-guide-draft-2026-09-29.md
?? docs/verification/m10-known-issues-draft-2026-09-29.md
?? scripts/bootstrap-fedora-host-binutils.sh
?? scripts/btrfs_send_ledger.py
?? scripts/build-blfs-alsa-lib.sh
?? scripts/build-blfs-aspell-d34.sh
?? scripts/build-blfs-aspell.sh
?? scripts/build-blfs-boost-headers-d34.sh
?? scripts/build-blfs-boost.sh
?? scripts/build-blfs-cmake-d34.sh
?? scripts/build-blfs-cmake.sh
?? scripts/build-blfs-cracklib.sh
?? scripts/build-blfs-curl.sh
?? scripts/build-blfs-cython-d34.sh
?? scripts/build-blfs-dejavu-fonts-d34.sh
?? scripts/build-blfs-docbook-d34.sh
?? scripts/build-blfs-docbook-stack.sh
?? scripts/build-blfs-docutils.sh
?? scripts/build-blfs-duktape.sh
?? scripts/build-blfs-ecm-d34.sh
?? scripts/build-blfs-ecm.sh
?? scripts/build-blfs-font-stack.sh
?? scripts/build-blfs-fontconfig-d34.sh
?? scripts/build-blfs-freetype-bootstrap-d34.sh
?? scripts/build-blfs-gcrypt-d34.sh
?? scripts/build-blfs-gcrypt-stack.sh
?? scripts/build-blfs-glib.sh
?? scripts/build-blfs-harfbuzz-d34.sh
?? scripts/build-blfs-hwdata.sh
?? scripts/build-blfs-icu-d34.sh
?? scripts/build-blfs-icu.sh
?? scripts/build-blfs-kf6-dependencies.sh
?? scripts/build-blfs-kf6-frameworks.sh
?? scripts/build-blfs-kf6-package-d34.sh
?? scripts/build-blfs-kirigami-addons.sh
?? scripts/build-blfs-knotification-audio-d34.sh
?? scripts/build-blfs-kwin-deps-d34.sh
?? scripts/build-blfs-kwindowsystem-x11-d34.sh
?? scripts/build-blfs-libX11-d34.sh
?? scripts/build-blfs-libXcursor-d34.sh
?? scripts/build-blfs-libXfixes-d34.sh
?? scripts/build-blfs-libXrender-d34.sh
?? scripts/build-blfs-libdisplay-info.sh
?? scripts/build-blfs-libdrm-d34.sh
?? scripts/build-blfs-libgcrypt-d34.sh
?? scripts/build-blfs-libgpg-error-d34.sh
?? scripts/build-blfs-libgudev-d34.sh
?? scripts/build-blfs-libical-d34.sh
?? scripts/build-blfs-libidn2.sh
?? scripts/build-blfs-libndp.sh
?? scripts/build-blfs-libnl.sh
?? scripts/build-blfs-libpciaccess-d34.sh
?? scripts/build-blfs-libpng-d34.sh
?? scripts/build-blfs-libpsl.sh
?? scripts/build-blfs-libpwquality.sh
?? scripts/build-blfs-libqalculate.sh
?? scripts/build-blfs-libsecret-d34.sh
?? scripts/build-blfs-libsecret.sh
?? scripts/build-blfs-libsndfile.sh
?? scripts/build-blfs-libunistring.sh
?? scripts/build-blfs-libwacom-d34.sh
?? scripts/build-blfs-libxkbfile-d34.sh
?? scripts/build-blfs-libxml2-d34.sh
?? scripts/build-blfs-libxslt-d34.sh
?? scripts/build-blfs-libxslt.sh
?? scripts/build-blfs-libyaml-d34.sh
?? scripts/build-blfs-linux-pam.sh
?? scripts/build-blfs-lm-sensors-d34.sh
?? scripts/build-blfs-lmdb-d34.sh
?? scripts/build-blfs-lmdb.sh
?? scripts/build-blfs-lua.sh
?? scripts/build-blfs-mako-d34.sh
?? scripts/build-blfs-mesa-d34.sh
?? scripts/build-blfs-mesa-prereqs.sh
?? scripts/build-blfs-mesa-softpipe.sh
?? scripts/build-blfs-networkmanager.sh
?? scripts/build-blfs-nspr.sh
?? scripts/build-blfs-nss.sh
?? scripts/build-blfs-pcre2.sh
?? scripts/build-blfs-perl-uri-d34.sh
?? scripts/build-blfs-phonon-d34.sh
?? scripts/build-blfs-phonon.sh
?? scripts/build-blfs-pipewire.sh
?? scripts/build-blfs-plasma-core-d34.sh
?? scripts/build-blfs-plasma-wayland-protocols-d34.sh
?? scripts/build-blfs-plasma-wayland-protocols.sh
?? scripts/build-blfs-polkit-qt-d34.sh
?? scripts/build-blfs-polkit-qt.sh
?? scripts/build-blfs-polkit.sh
?? scripts/build-blfs-pyyaml-d34.sh
?? scripts/build-blfs-qca-d34.sh
?? scripts/build-blfs-qca-prereqs.sh
?? scripts/build-blfs-qca.sh
?? scripts/build-blfs-qcoro-d34.sh
?? scripts/build-blfs-qcoro.sh
?? scripts/build-blfs-qrencode-d34.sh
?? scripts/build-blfs-qt-core-prereqs.sh
?? scripts/build-blfs-qt-module-d34-common.sh
?? scripts/build-blfs-qt-multimedia-speech.sh
?? scripts/build-blfs-qt-svg-tools.sh
?? scripts/build-blfs-qt-wayland-modules.sh
?? scripts/build-blfs-qt-websockets.sh
?? scripts/build-blfs-qt5compat-d34.sh
?? scripts/build-blfs-qt5compat.sh
?? scripts/build-blfs-qtbase-d34.sh
?? scripts/build-blfs-qtbase-wayland.sh
?? scripts/build-blfs-qtbase-xcb-d34.sh
?? scripts/build-blfs-qtbase-xkbcommon-d34.sh
?? scripts/build-blfs-qtdeclarative-d34.sh
?? scripts/build-blfs-qtlocation-d34.sh
?? scripts/build-blfs-qtmultimedia-d34.sh
?? scripts/build-blfs-qtpositioning-d34.sh
?? scripts/build-blfs-qtsensors-d34.sh
?? scripts/build-blfs-qtshadertools-d34.sh
?? scripts/build-blfs-qtspeech-d34.sh
?? scripts/build-blfs-qtsvg-d34.sh
?? scripts/build-blfs-qttools-d34.sh
?? scripts/build-blfs-qtwayland-d34.sh
?? scripts/build-blfs-qtwebsockets-d34.sh
?? scripts/build-blfs-sassc.sh
?? scripts/build-blfs-shared-mime-info.sh
?? scripts/build-blfs-sqlite-d34.sh
?? scripts/build-blfs-taglib.sh
?? scripts/build-blfs-uri-qr-deps.sh
?? scripts/build-blfs-utfcpp.sh
?? scripts/build-blfs-wayland-base.sh
?? scripts/build-blfs-wayland-d34.sh
?? scripts/build-blfs-wayland-protocols-d34.sh
?? scripts/build-blfs-wireplumber.sh
?? scripts/build-blfs-wpa-supplicant.sh
?? scripts/build-blfs-x11-d34.sh
?? scripts/build-blfs-xcb-util-cursor-d34.sh
?? scripts/build-blfs-xcb-util-d34.sh
?? scripts/build-blfs-xcb-util-image-d34.sh
?? scripts/build-blfs-xcb-util-keysyms-d34.sh
?? scripts/build-blfs-xcb-util-renderutil-d34.sh
?? scripts/build-blfs-xcb-util-wm-d34.sh
?? scripts/build-blfs-xkb-d34.sh
?? scripts/build-blfs-xkb-runtime.sh
?? scripts/build-blfs-xtrans-d34.sh
?? scripts/build-lfs-acl-ch8.sh
?? scripts/build-lfs-attr-ch8.sh
?? scripts/build-lfs-attr-resume-ch8.sh
?? scripts/build-lfs-autoconf-ch8.sh
?? scripts/build-lfs-automake-ch8.sh
?? scripts/build-lfs-bash-ch6.sh
?? scripts/build-lfs-bash-ch8.sh
?? scripts/build-lfs-bc-ch8.sh
?? scripts/build-lfs-binutils-ch8.sh
?? scripts/build-lfs-binutils-pass1.sh
?? scripts/build-lfs-binutils-pass2.sh
?? scripts/build-lfs-bison-ch7.sh
?? scripts/build-lfs-bison-ch8.sh
?? scripts/build-lfs-bzip2-ch8.sh
?? scripts/build-lfs-coreutils-ch6.sh
?? scripts/build-lfs-coreutils-ch8.sh
?? scripts/build-lfs-dbus-ch8.sh
?? scripts/build-lfs-dejagnu-ch8.sh
?? scripts/build-lfs-diffutils-ch6.sh
?? scripts/build-lfs-diffutils-ch8.sh
?? scripts/build-lfs-e2fsprogs-ch8.sh
?? scripts/build-lfs-expat-ch8.sh
?? scripts/build-lfs-expect-ch8.sh
?? scripts/build-lfs-file-ch6.sh
?? scripts/build-lfs-file-ch8.sh
?? scripts/build-lfs-findutils-ch6.sh
?? scripts/build-lfs-findutils-ch8.sh
?? scripts/build-lfs-flex-ch8.sh
?? scripts/build-lfs-flit-core-ch8.sh
?? scripts/build-lfs-gawk-ch6.sh
?? scripts/build-lfs-gawk-ch8.sh
?? scripts/build-lfs-gcc-ch8.sh
?? scripts/build-lfs-gcc-install-ch8.sh
?? scripts/build-lfs-gcc-pass1.sh
?? scripts/build-lfs-gcc-pass2.sh
?? scripts/build-lfs-gdbm-ch8.sh
?? scripts/build-lfs-gettext-ch7.sh
?? scripts/build-lfs-gettext-ch8.sh
?? scripts/build-lfs-glibc-ch8.sh
?? scripts/build-lfs-glibc-install-ch8.sh
?? scripts/build-lfs-glibc-pass1.sh
?? scripts/build-lfs-gmp-ch8.sh
?? scripts/build-lfs-gmp-resume-ch8.sh
?? scripts/build-lfs-gperf-ch8.sh
?? scripts/build-lfs-grep-ch6.sh
?? scripts/build-lfs-grep-ch8.sh
?? scripts/build-lfs-groff-ch8.sh
?? scripts/build-lfs-grub-ch8.sh
?? scripts/build-lfs-gzip-ch6.sh
?? scripts/build-lfs-gzip-ch8.sh
?? scripts/build-lfs-iana-etc-ch8.sh
?? scripts/build-lfs-inetutils-ch8.sh
?? scripts/build-lfs-intltool-ch8.sh
?? scripts/build-lfs-iproute2-ch8.sh
?? scripts/build-lfs-jinja2-ch8.sh
?? scripts/build-lfs-kbd-ch8.sh
?? scripts/build-lfs-kernel-ch10.sh
?? scripts/build-lfs-kmod-ch8.sh
?? scripts/build-lfs-less-ch8.sh
?? scripts/build-lfs-libcap-ch8.sh
?? scripts/build-lfs-libcap-verify-ch8.sh
?? scripts/build-lfs-libelf-ch8.sh
?? scripts/build-lfs-libffi-ch8.sh
?? scripts/build-lfs-libpipeline-ch8.sh
?? scripts/build-lfs-libstdcxx-pass1.sh
?? scripts/build-lfs-libtool-ch8.sh
?? scripts/build-lfs-libxcrypt-ch8.sh
?? scripts/build-lfs-linux-headers.sh
?? scripts/build-lfs-linux-pam-ch8.sh
?? scripts/build-lfs-lz4-ch8.sh
?? scripts/build-lfs-m4-ch6.sh
?? scripts/build-lfs-m4-ch8.sh
?? scripts/build-lfs-make-ch6.sh
?? scripts/build-lfs-make-ch8.sh
?? scripts/build-lfs-man-db-ch8.sh
?? scripts/build-lfs-man-pages-ch8.sh
?? scripts/build-lfs-markupsafe-ch8.sh
?? scripts/build-lfs-meson-ch8.sh
?? scripts/build-lfs-mpc-ch8.sh
?? scripts/build-lfs-mpfr-ch8.sh
?? scripts/build-lfs-ncurses-ch6.sh
?? scripts/build-lfs-ncurses-ch8.sh
?? scripts/build-lfs-ninja-ch8.sh
?? scripts/build-lfs-openssl-ch8.sh
?? scripts/build-lfs-packaging-ch8.sh
?? scripts/build-lfs-patch-ch6.sh
?? scripts/build-lfs-patch-ch8.sh
?? scripts/build-lfs-perl-ch7.sh
?? scripts/build-lfs-perl-ch8.sh
?? scripts/build-lfs-pkgconf-ch8.sh
?? scripts/build-lfs-procps-ng-ch8.sh
?? scripts/build-lfs-psmisc-ch8.sh
?? scripts/build-lfs-python3-ch7.sh
?? scripts/build-lfs-python3-ch8.sh
?? scripts/build-lfs-readline-ch8.sh
?? scripts/build-lfs-readline-verify-ch8.sh
?? scripts/build-lfs-sed-ch6.sh
?? scripts/build-lfs-sed-ch8.sh
?? scripts/build-lfs-setuptools-ch8.sh
?? scripts/build-lfs-shadow-ch8.sh
?? scripts/build-lfs-systemd-ch8.sh
?? scripts/build-lfs-tar-ch6.sh
?? scripts/build-lfs-tar-ch8.sh
?? scripts/build-lfs-tcl-ch8.sh
?? scripts/build-lfs-texinfo-ch7.sh
?? scripts/build-lfs-texinfo-ch8.sh
?? scripts/build-lfs-util-linux-ch7.sh
?? scripts/build-lfs-util-linux-ch8.sh
?? scripts/build-lfs-vim-ch8.sh
?? scripts/build-lfs-wheel-ch8.sh
?? scripts/build-lfs-xml-parser-ch8.sh
?? scripts/build-lfs-xz-ch6.sh
?? scripts/build-lfs-xz-ch8.sh
?? scripts/build-lfs-zlib-ch8.sh
?? scripts/build-lfs-zstd-ch8.sh
?? scripts/configure-blfs-kf6-prefix.sh
?? scripts/configure-blfs-nss-trust-d34.sh
?? scripts/configure-blfs-pam-stack-d34.sh
?? scripts/configure-blfs-pam-stack.sh
?? scripts/configure-lfs-shadow-ch8-resume.sh
?? scripts/configure-lfs-system-ch9.sh
?? scripts/configure-live-packagekit-polkit.sh
?? scripts/d34_reconcile_package_deltas.py
?? scripts/install-lfs-attr-ch8-resume.sh
?? scripts/install-lfs-gcc-ch8-resume.sh
?? scripts/install-lfs-glibc-ch8.sh
?? scripts/install-lfs-sed-ch8-resume.sh
?? scripts/install-packagekit-alp-helper.sh
?? scripts/kf6-d34-package-order.json
?? scripts/lfs-build-guard.sh
?? scripts/lfs-chapter7-base-in-chroot.sh
?? scripts/packagekit/
?? scripts/plasma-d34-package-order.json
?? scripts/preflight-d34-candidate-root.py
?? scripts/prepare-lfs-chroot.sh
?? scripts/rebuild-blfs-shadow-pam.sh
?? scripts/resume-d34-package-replay.py
?? scripts/resume-lfs-gcc-pass1.sh
?? scripts/resume-lfs-glibc-ch8-check.sh
?? scripts/run-d34-package-replay.py
?? tests/test_d34_blfs_audio_wiring.py
?? tests/test_d34_btrfs_send_ledger.py
?? tests/test_d34_builder_wiring.py
?? tests/test_d34_candidate_preflight.py
?? tests/test_d34_supplemental_reconcile.py
?? tests/test_m04_btrfs_send_delta.py
?? tests/test_m08_alp_packagekit_backend.py
a9bac38544955c30c146c175760195ff193a0b76
worktree /home/yrslf/alpbahOS
HEAD a9bac38544955c30c146c175760195ff193a0b76
branch refs/heads/main

## claude/m08-live-fixes
c6d98d4bc54ed33a4afca22e30e00ac6b1744714

exit=0
```

## Host bütünlüğü ilk baseline

Komut: `rpm -Va`

```text
.......T.  c /etc/environment
missing     /boot/efi/EFI (Permission denied)
missing     /boot/efi/EFI/BOOT (Permission denied)
missing     /boot/efi/EFI/fedora (Permission denied)
..?......  c /etc/iscsi/iscsid.conf
missing   c /etc/nftables/main.nft (Permission denied)
missing   c /etc/nftables/nat.nft (Permission denied)
missing   n /etc/nftables/osf (Permission denied)
missing   c /etc/nftables/osf/pf.os (Permission denied)
missing   c /etc/nftables/router.nft (Permission denied)
..?....T.  c /etc/sysconfig/nftables.conf
.......T.  c /etc/sysconfig/kernel
..?......    /usr/lib/efi/shim/16.1-5/EFI/BOOT/BOOTX64.EFI
..?......    /usr/lib/efi/shim/16.1-5/EFI/BOOT/fbx64.efi
..?......    /usr/lib/efi/shim/16.1-5/EFI/fedora/BOOTX64.CSV
..?......    /usr/lib/efi/shim/16.1-5/EFI/fedora/mmx64.efi
..?......    /usr/lib/efi/shim/16.1-5/EFI/fedora/shim.efi
..?......    /usr/lib/efi/shim/16.1-5/EFI/fedora/shimx64.efi
..?......    /usr/lib/efi/shim/16.1-5/EFI/BOOT/BOOTIA32.EFI
..?......    /usr/lib/efi/shim/16.1-5/EFI/BOOT/fbia32.efi
..?......    /usr/lib/efi/shim/16.1-5/EFI/fedora/BOOTIA32.CSV
..?......    /usr/lib/efi/shim/16.1-5/EFI/fedora/mmia32.efi
..?......    /usr/lib/efi/shim/16.1-5/EFI/fedora/shimia32.efi
.......T.  c /etc/sysconfig/raid-check
missing     /etc/polkit-1/localauthority/10-vendor.d (Permission denied)
missing     /etc/polkit-1/localauthority/20-org.d (Permission denied)
missing     /etc/polkit-1/localauthority/30-site.d (Permission denied)
missing     /etc/polkit-1/localauthority/50-local.d (Permission denied)
missing     /etc/polkit-1/localauthority/90-mandatory.d (Permission denied)
missing   c /etc/polkit-1/rules.d/49-polkit-pkla-compat.rules (Permission denied)
missing     /var/lib/polkit-1/localauthority (Permission denied)
missing     /var/lib/polkit-1/localauthority/10-vendor.d (Permission denied)
missing     /var/lib/polkit-1/localauthority/20-org.d (Permission denied)
missing     /var/lib/polkit-1/localauthority/30-site.d (Permission denied)
missing     /var/lib/polkit-1/localauthority/50-local.d (Permission denied)
missing     /var/lib/polkit-1/localauthority/90-mandatory.d (Permission denied)
missing     /boot/efi/System (Permission denied)
missing     /boot/efi/System/Library (Permission denied)
missing     /boot/efi/System/Library/CoreServices (Permission denied)
missing     /boot/efi/System/Library/CoreServices/SystemVersion.plist (Permission denied)
missing     /boot/efi/mach_kernel (Permission denied)
..?......    /usr/libexec/dbus-1/dbus-daemon-launch-helper
.....UG..  g /var/run/pcscd
..?......    /usr/libexec/utempter/utempter
.......T.  c /etc/sysconfig/run-parts
.......T.  c /etc/sysconfig/crond
..?......    /usr/bin/lockdev
..?......    /usr/share/ModemManager/connection.available.d/99-log-event
..?......    /usr/share/ModemManager/fcc-unlock.available.d/105b
..?......    /usr/share/ModemManager/fcc-unlock.available.d/1199
..?......    /usr/share/ModemManager/fcc-unlock.available.d/14c3
..?......    /usr/share/ModemManager/fcc-unlock.available.d/2c7c
..?......    /usr/share/ModemManager/modem-setup.available.d/0000:0000
..?......    /usr/bin/userhelper
..?......  c /etc/vpnc/default.conf
missing   c /etc/audit/plugins.d/sedispatch.conf (Permission denied)
..?......  c /etc/gssproxy/99-network-fs-clients.conf
..?......  c /etc/gssproxy/gssproxy.conf
..?......  c /etc/ppp/chap-secrets
..?......  c /etc/ppp/eaptls-client
..?......  c /etc/ppp/eaptls-server
..?......  c /etc/ppp/pap-secrets
..5....T.  c /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:phracek:PyCharm.repo
..5....T.  c /etc/yum.repos.d/google-chrome.repo
..5....T.  c /etc/yum.repos.d/rpmfusion-nonfree-nvidia-driver.repo
..5....T.  c /etc/yum.repos.d/rpmfusion-nonfree-steam.repo
.......T.  c /etc/sysconfig/wpa_supplicant
..?......  c /etc/wpa_supplicant/wpa_supplicant.conf
..?......    /usr/lib/cups/backend/gutenprint53+usb
.......T.  c /etc/sysconfig/o2cb
.......T.  c /etc/sysconfig/man-db
.......T.  c /etc/sysconfig/qemu-ga
..?......    /usr/libexec/fwupd/efi/fwupdx64.efi.signed
.......T.  c /etc/sysconfig/atd
missing     /var/spool/at/spool (Permission denied)
S.5....T.  c /etc/sysconfig/livesys
.M....G..    /var/cache/apt/archives/partial
.....UG..    /var/lib/apt/lists
.M....G..    /var/lib/apt/lists/partial
..?......  c /etc/pki/akmods/cacert.config.in
missing   c /etc/libvirt/libvirt-admin.conf (Permission denied)
missing   c /etc/libvirt/libvirt.conf (Permission denied)
missing     /etc/libvirt/storage (Permission denied)
missing     /etc/libvirt/storage/autostart (Permission denied)
missing   c /etc/libvirt/virtstoraged.conf (Permission denied)
missing   c /etc/libvirt/virtlockd.conf (Permission denied)
missing   c /etc/libvirt/virtlogd.conf (Permission denied)
missing   c /etc/libvirt/network.conf (Permission denied)
missing     /etc/libvirt/qemu (Permission denied)
missing     /etc/libvirt/qemu/networks (Permission denied)
missing     /etc/libvirt/qemu/networks/autostart (Permission denied)
missing   c /etc/libvirt/virtnetworkd.conf (Permission denied)
missing   c /etc/libvirt/virtproxyd.conf (Permission denied)
missing   c /etc/libvirt/virtinterfaced.conf (Permission denied)
missing   c /etc/libvirt/virtnodedevd.conf (Permission denied)
missing     /etc/libvirt/nwfilter (Permission denied)
missing   c /etc/libvirt/virtnwfilterd.conf (Permission denied)
missing     /etc/libvirt/secrets (Permission denied)
missing   c /etc/libvirt/virtsecretd.conf (Permission denied)
missing     /etc/libvirt/qemu (Permission denied)
missing   c /etc/libvirt/qemu-lockd.conf (Permission denied)
missing   c /etc/libvirt/qemu.conf (Permission denied)
missing     /etc/libvirt/qemu/autostart (Permission denied)
missing   c /etc/libvirt/virtqemud.conf (Permission denied)
missing     /var/log/libvirt/qemu (Permission denied)
missing   c /etc/libvirt/libvirtd.conf (Permission denied)
.M.......    /usr/lib/tlauncher/tlauncher.sh
.......T.    /usr/share/nvim/runtime/doc/tags
.M.......    /var/cache/tailscale
..?......  c /etc/libaudit.conf
missing     /var/lib/samba/private/certs (Permission denied)
missing     /var/log/samba/old (Permission denied)
missing     /var/lib/bluetooth/mesh (Permission denied)
missing   c /etc/firewalld/firewalld-server.conf (Permission denied)
missing   c /etc/firewalld/firewalld-standard.conf (Permission denied)
missing   c /etc/firewalld/firewalld-workstation.conf (Permission denied)
missing     /etc/firewalld/helpers (Permission denied)
missing     /etc/firewalld/icmptypes (Permission denied)
missing     /etc/firewalld/ipsets (Permission denied)
missing     /etc/firewalld/policies (Permission denied)
missing     /etc/firewalld/services (Permission denied)
missing     /etc/firewalld/zones (Permission denied)
..?......  c /etc/fwupd/fwupd.conf
missing   c /etc/grub.d/35_fwupd (Permission denied)
.M.......    /var/lib/fwupd
..?......  c /etc/security/opasswd
..?......    /usr/bin/unix_update
..?......    /usr/bin/chfn
..?......    /usr/bin/chsh
S.5....T.  c /etc/selinux/targeted/contexts/files/file_contexts.local
missing     /var/lib/selinux/targeted/active/commit_num (Permission denied)
missing     /var/lib/selinux/targeted/active/file_contexts (Permission denied)
missing     /var/lib/selinux/targeted/active/file_contexts.homedirs (Permission denied)
missing     /var/lib/selinux/targeted/active/homedir_template (Permission denied)
missing     /var/lib/selinux/targeted/active/modules (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/abrt (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/abrt/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/abrt/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/abrt/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/accountsd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/accountsd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/accountsd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/accountsd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/acct (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/acct/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/acct/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/acct/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/afs (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/afs/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/afs/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/afs/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/afterburn (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/afterburn/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/afterburn/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/afterburn/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/aide (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/aide/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/aide/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/aide/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/alsa (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/alsa/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/alsa/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/alsa/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/amanda (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/amanda/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/amanda/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/amanda/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/anaconda (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/anaconda/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/anaconda/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/anaconda/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/antivirus (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/antivirus/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/antivirus/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/antivirus/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/apache (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/apache/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/apache/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/apache/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/apcupsd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/apcupsd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/apcupsd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/apcupsd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/apm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/apm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/apm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/apm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/application (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/application/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/application/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/application/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/arpwatch (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/arpwatch/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/arpwatch/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/arpwatch/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/asterisk (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/asterisk/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/asterisk/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/asterisk/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/auditadm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/auditadm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/auditadm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/auditadm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/authlogin (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/authlogin/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/authlogin/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/authlogin/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/automount (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/automount/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/automount/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/automount/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/avahi (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/avahi/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/avahi/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/avahi/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/awstats (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/awstats/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/awstats/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/awstats/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bacula (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bacula/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bacula/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bacula/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/base (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/base/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/base/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/base/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bind (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bind/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bind/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bind/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bitlbee (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bitlbee/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bitlbee/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bitlbee/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/blkmapd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/blkmapd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/blkmapd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/blkmapd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/blueman (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/blueman/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/blueman/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/blueman/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bluetooth (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bluetooth/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bluetooth/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bluetooth/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/boinc (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/boinc/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/boinc/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/boinc/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/boltd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/boltd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/boltd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/boltd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/boothd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/boothd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/boothd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/boothd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bootloader (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bootloader/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bootloader/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bootloader/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bootupd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bootupd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bootupd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bootupd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/brctl (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/brctl/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/brctl/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/brctl/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/brltty (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/brltty/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/brltty/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/brltty/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bugzilla (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bugzilla/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bugzilla/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/bugzilla/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cachefilesd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cachefilesd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cachefilesd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cachefilesd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/calamaris (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/calamaris/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/calamaris/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/calamaris/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/callweaver (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/callweaver/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/callweaver/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/callweaver/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/canna (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/canna/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/canna/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/canna/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ccs (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ccs/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ccs/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ccs/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cdrecord (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cdrecord/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cdrecord/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cdrecord/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/certmaster (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/certmaster/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/certmaster/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/certmaster/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/certmonger (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/certmonger/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/certmonger/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/certmonger/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/certwatch (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/certwatch/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/certwatch/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/certwatch/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cfengine (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cfengine/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cfengine/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cfengine/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cgroup (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cgroup/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cgroup/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cgroup/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/chrome (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/chrome/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/chrome/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/chrome/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/chronyd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/chronyd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/chronyd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/chronyd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cifsutils (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cifsutils/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cifsutils/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cifsutils/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cinder (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cinder/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cinder/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cinder/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cipe (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cipe/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cipe/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cipe/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/clock (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/clock/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/clock/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/clock/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/clogd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/clogd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/clogd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/clogd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cloudform (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cloudform/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cloudform/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cloudform/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cmirrord (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cmirrord/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cmirrord/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cmirrord/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cobbler (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cobbler/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cobbler/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cobbler/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/collectd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/collectd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/collectd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/collectd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/colord (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/colord/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/colord/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/colord/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/comsat (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/comsat/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/comsat/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/comsat/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/condor (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/condor/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/condor/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/condor/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/conman (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/conman/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/conman/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/conman/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/conntrackd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/conntrackd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/conntrackd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/conntrackd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/consolekit (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/consolekit/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/consolekit/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/consolekit/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/coreos_installer (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/coreos_installer/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/coreos_installer/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/coreos_installer/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/couchdb (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/couchdb/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/couchdb/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/couchdb/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/courier (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/courier/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/courier/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/courier/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cpucontrol (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cpucontrol/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cpucontrol/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cpucontrol/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cpufreqselector (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cpufreqselector/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cpufreqselector/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cpufreqselector/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cpuplug (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cpuplug/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cpuplug/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cpuplug/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cron (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cron/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cron/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cron/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ctdb (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ctdb/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ctdb/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ctdb/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cups (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cups/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cups/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cups/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cvs (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cvs/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cvs/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cvs/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cyphesis (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cyphesis/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cyphesis/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cyphesis/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cyrus (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cyrus/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cyrus/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/cyrus/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/daemontools (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/daemontools/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/daemontools/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/daemontools/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dbadm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dbadm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dbadm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dbadm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dbskk (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dbskk/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dbskk/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dbskk/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dbus (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dbus/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dbus/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dbus/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dcc (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dcc/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dcc/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dcc/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ddclient (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ddclient/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ddclient/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ddclient/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/denyhosts (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/denyhosts/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/denyhosts/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/denyhosts/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/devicekit (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/devicekit/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/devicekit/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/devicekit/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dhcp (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dhcp/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dhcp/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dhcp/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dictd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dictd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dictd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dictd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dirsrv (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dirsrv/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dirsrv/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dirsrv/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/distcc (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/distcc/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/distcc/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/distcc/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dmesg (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dmesg/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dmesg/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dmesg/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dmidecode (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dmidecode/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dmidecode/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dmidecode/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dnsmasq (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dnsmasq/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dnsmasq/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dnsmasq/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dnssec (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dnssec/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dnssec/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dnssec/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dovecot (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dovecot/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dovecot/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dovecot/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/drbd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/drbd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/drbd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/drbd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dspam (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dspam/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dspam/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/dspam/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/entropyd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/entropyd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/entropyd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/entropyd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/exim (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/exim/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/exim/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/exim/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fcoe (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fcoe/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fcoe/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fcoe/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fdo (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fdo/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fdo/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fdo/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fedoratp (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fedoratp/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fedoratp/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fedoratp/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fetchmail (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fetchmail/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fetchmail/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fetchmail/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/finger (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/finger/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/finger/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/finger/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/firewalld (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/firewalld/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/firewalld/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/firewalld/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/firewallgui (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/firewallgui/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/firewallgui/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/firewallgui/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/firstboot (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/firstboot/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/firstboot/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/firstboot/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fprintd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fprintd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fprintd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fprintd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/freeipmi (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/freeipmi/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/freeipmi/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/freeipmi/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/freqset (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/freqset/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/freqset/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/freqset/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fstools (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fstools/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fstools/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fstools/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ftp (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ftp/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ftp/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ftp/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fwupd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fwupd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fwupd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/fwupd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/games (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/games/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/games/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/games/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gdomap (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gdomap/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gdomap/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gdomap/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/geoclue (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/geoclue/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/geoclue/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/geoclue/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/getty (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/getty/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/getty/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/getty/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/git (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/git/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/git/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/git/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gitosis (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gitosis/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gitosis/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gitosis/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/glance (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/glance/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/glance/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/glance/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/glusterd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/glusterd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/glusterd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/glusterd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gnome (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gnome/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gnome/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gnome/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gnome_remote_desktop (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gnome_remote_desktop/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gnome_remote_desktop/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gnome_remote_desktop/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gpg (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gpg/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gpg/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gpg/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gpm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gpm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gpm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gpm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gpsd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gpsd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gpsd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gpsd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gssproxy (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gssproxy/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gssproxy/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/gssproxy/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/guest (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/guest/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/guest/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/guest/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hddtemp (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hddtemp/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hddtemp/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hddtemp/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hostapd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hostapd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hostapd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hostapd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hostname (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hostname/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hostname/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hostname/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hsqldb (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hsqldb/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hsqldb/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hsqldb/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hwloc (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hwloc/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hwloc/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hwloc/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hypervkvp (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hypervkvp/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hypervkvp/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/hypervkvp/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ibacm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ibacm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ibacm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ibacm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ica (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ica/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ica/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ica/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/icecast (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/icecast/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/icecast/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/icecast/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iiosensorproxy (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iiosensorproxy/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iiosensorproxy/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iiosensorproxy/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/inetd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/inetd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/inetd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/inetd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/init (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/init/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/init/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/init/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/inn (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/inn/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/inn/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/inn/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/insights_client (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/insights_client/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/insights_client/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/insights_client/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/insights_core (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/insights_core/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/insights_core/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/insights_core/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iodine (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iodine/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iodine/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iodine/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iotop (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iotop/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iotop/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iotop/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ipmievd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ipmievd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ipmievd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ipmievd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ipsec (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ipsec/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ipsec/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ipsec/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iptables (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iptables/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iptables/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iptables/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/irc (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/irc/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/irc/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/irc/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/irqbalance (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/irqbalance/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/irqbalance/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/irqbalance/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iscsi (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iscsi/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iscsi/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/iscsi/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/isns (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/isns/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/isns/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/isns/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/jabber (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/jabber/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/jabber/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/jabber/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/jetty (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/jetty/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/jetty/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/jetty/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/jockey (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/jockey/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/jockey/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/jockey/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/journalctl (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/journalctl/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/journalctl/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/journalctl/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kafs (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kafs/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kafs/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kafs/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kdump (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kdump/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kdump/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kdump/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kdumpgui (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kdumpgui/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kdumpgui/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kdumpgui/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keepalived (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keepalived/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keepalived/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keepalived/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kerberos (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kerberos/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kerberos/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kerberos/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keyboardd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keyboardd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keyboardd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keyboardd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keystone (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keystone/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keystone/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keystone/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keyutils (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keyutils/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keyutils/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/keyutils/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kismet (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kismet/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kismet/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kismet/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kmscon (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kmscon/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kmscon/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kmscon/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kpatch (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kpatch/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kpatch/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/kpatch/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ksmtuned (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ksmtuned/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ksmtuned/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ksmtuned/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ktalk (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ktalk/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ktalk/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ktalk/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ktls (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ktls/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ktls/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ktls/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/l2tp (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/l2tp/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/l2tp/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/l2tp/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ldap (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ldap/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ldap/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ldap/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/libraries (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/libraries/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/libraries/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/libraries/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/likewise (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/likewise/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/likewise/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/likewise/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lircd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lircd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lircd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lircd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/livecd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/livecd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/livecd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/livecd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lldpad (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lldpad/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lldpad/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lldpad/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/loadkeys (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/loadkeys/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/loadkeys/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/loadkeys/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/locallogin (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/locallogin/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/locallogin/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/locallogin/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lockdev (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lockdev/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lockdev/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lockdev/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logadm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logadm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logadm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logadm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logging (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logging/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logging/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logging/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logrotate (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logrotate/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logrotate/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logrotate/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logwatch (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logwatch/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logwatch/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/logwatch/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lpd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lpd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lpd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lpd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lsm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lsm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lsm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lsm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lttng-tools (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lttng-tools/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lttng-tools/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lttng-tools/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lvm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lvm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lvm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/lvm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mailman (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mailman/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mailman/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mailman/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mailscanner (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mailscanner/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mailscanner/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mailscanner/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/man2html (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/man2html/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/man2html/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/man2html/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mandb (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mandb/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mandb/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mandb/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mcelog (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mcelog/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mcelog/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mcelog/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mediawiki (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mediawiki/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mediawiki/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mediawiki/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/memcached (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/memcached/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/memcached/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/memcached/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/milter (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/milter/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/milter/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/milter/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/minidlna (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/minidlna/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/minidlna/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/minidlna/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/minissdpd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/minissdpd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/minissdpd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/minissdpd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/miscfiles (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/miscfiles/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/miscfiles/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/miscfiles/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mock (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mock/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mock/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mock/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/modemmanager (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/modemmanager/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/modemmanager/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/modemmanager/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/modutils (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/modutils/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/modutils/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/modutils/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mojomojo (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mojomojo/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mojomojo/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mojomojo/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mon_statd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mon_statd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mon_statd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mon_statd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mongodb (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mongodb/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mongodb/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mongodb/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/motion (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/motion/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/motion/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/motion/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mount (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mount/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mount/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mount/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mozilla (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mozilla/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mozilla/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mozilla/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mpd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mpd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mpd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mpd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mplayer (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mplayer/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mplayer/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mplayer/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mptcpd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mptcpd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mptcpd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mptcpd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mrtg (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mrtg/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mrtg/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mrtg/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mta (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mta/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mta/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mta/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/munin (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/munin/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/munin/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/munin/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mythtv (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mythtv/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mythtv/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/mythtv/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nagios (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nagios/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nagios/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nagios/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/namespace (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/namespace/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/namespace/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/namespace/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ncftool (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ncftool/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ncftool/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ncftool/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/netlabel (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/netlabel/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/netlabel/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/netlabel/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/netutils (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/netutils/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/netutils/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/netutils/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/networkmanager (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/networkmanager/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/networkmanager/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/networkmanager/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ninfod (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ninfod/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ninfod/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ninfod/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nis (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nis/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nis/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nis/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nova (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nova/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nova/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nova/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nscd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nscd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nscd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nscd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nsd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nsd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nsd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nsd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nslcd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nslcd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nslcd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nslcd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ntop (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ntop/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ntop/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ntop/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ntp (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ntp/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ntp/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ntp/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/numad (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/numad/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/numad/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/numad/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nut (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nut/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nut/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nut/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nvme_stas (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nvme_stas/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nvme_stas/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nvme_stas/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nx (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nx/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nx/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/nx/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/obex (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/obex/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/obex/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/obex/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/oddjob (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/oddjob/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/oddjob/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/oddjob/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/opafm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/opafm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/opafm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/opafm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/opendnssec (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/opendnssec/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/opendnssec/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/opendnssec/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openfortivpn (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openfortivpn/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openfortivpn/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openfortivpn/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openhpid (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openhpid/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openhpid/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openhpid/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openshift (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openshift-origin (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openshift-origin/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openshift-origin/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openshift-origin/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openshift/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openshift/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openshift/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/opensm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/opensm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/opensm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/opensm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openvpn (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openvpn/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openvpn/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openvpn/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openvswitch (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openvswitch/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openvswitch/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openvswitch/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openwsman (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openwsman/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openwsman/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/openwsman/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/oracleasm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/oracleasm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/oracleasm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/oracleasm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/osad (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/osad/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/osad/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/osad/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pads (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pads/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pads/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pads/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/passenger (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/passenger/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/passenger/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/passenger/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pcm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pcm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pcm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pcm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pcmcia (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pcmcia/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pcmcia/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pcmcia/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pcscd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pcscd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pcscd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pcscd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pdns (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pdns/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pdns/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pdns/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pegasus (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pegasus/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pegasus/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pegasus/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/permissivedomains (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/permissivedomains/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/permissivedomains/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pesign (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pesign/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pesign/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pesign/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pingd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pingd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pingd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pingd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pkcs (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pkcs/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pkcs/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pkcs/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pki (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pki/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pki/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pki/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/plymouthd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/plymouthd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/plymouthd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/plymouthd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/podsleuth (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/podsleuth/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/podsleuth/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/podsleuth/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/policykit (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/policykit/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/policykit/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/policykit/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/polipo (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/polipo/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/polipo/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/polipo/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/portmap (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/portmap/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/portmap/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/portmap/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/portreserve (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/portreserve/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/portreserve/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/portreserve/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/postfix (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/postfix/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/postfix/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/postfix/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/postgresql (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/postgresql/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/postgresql/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/postgresql/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/postgrey (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/postgrey/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/postgrey/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/postgrey/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/powerprofiles (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/powerprofiles/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/powerprofiles/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/powerprofiles/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ppp (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ppp/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ppp/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ppp/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/prelink (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/prelink/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/prelink/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/prelink/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/prelude (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/prelude/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/prelude/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/prelude/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/privoxy (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/privoxy/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/privoxy/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/privoxy/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/procmail (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/procmail/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/procmail/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/procmail/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/prosody (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/prosody/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/prosody/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/prosody/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/psad (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/psad/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/psad/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/psad/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ptchown (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ptchown/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ptchown/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ptchown/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pulseaudio (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pulseaudio/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pulseaudio/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pulseaudio/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/puppet (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/puppet/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/puppet/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/puppet/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pwauth (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pwauth/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pwauth/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/pwauth/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qatlib (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qatlib/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qatlib/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qatlib/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qgs (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qgs/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qgs/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qgs/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qmail (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qmail/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qmail/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qmail/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qpid (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qpid/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qpid/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/qpid/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/quantum (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/quantum/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/quantum/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/quantum/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/quota (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/quota/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/quota/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/quota/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rabbitmq (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rabbitmq/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rabbitmq/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rabbitmq/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/radius (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/radius/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/radius/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/radius/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/radvd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/radvd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/radvd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/radvd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/raid (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/raid/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/raid/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/raid/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rasdaemon (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rasdaemon/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rasdaemon/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rasdaemon/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rdisc (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rdisc/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rdisc/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rdisc/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/readahead (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/readahead/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/readahead/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/readahead/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/realmd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/realmd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/realmd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/realmd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/redfish-finder (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/redfish-finder/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/redfish-finder/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/redfish-finder/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/redis (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/redis/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/redis/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/redis/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/remotelogin (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/remotelogin/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/remotelogin/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/remotelogin/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhcd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhcd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhcd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhcd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhcs (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhcs/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhcs/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhcs/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhgb (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhgb/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhgb/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhgb/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhnsd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhnsd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhnsd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhnsd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhsmcertd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhsmcertd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhsmcertd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rhsmcertd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ricci (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ricci/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ricci/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ricci/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rkhunter (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rkhunter/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rkhunter/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rkhunter/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rlogin (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rlogin/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rlogin/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rlogin/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rngd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rngd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rngd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rngd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/roundup (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/roundup/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/roundup/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/roundup/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rpc (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rpc/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rpc/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rpc/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rpcbind (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rpcbind/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rpcbind/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rpcbind/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rpm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rpm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rpm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rpm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rrdcached (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rrdcached/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rrdcached/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rrdcached/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rshd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rshd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rshd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rshd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rshim (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rshim/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rshim/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rshim/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rssh (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rssh/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rssh/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rssh/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rsync (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rsync/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rsync/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rsync/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rtas (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rtas/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rtas/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rtas/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rtkit (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rtkit/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rtkit/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rtkit/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rwho (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rwho/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rwho/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/rwho/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/samba (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/samba/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/samba/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/samba/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sambagui (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sambagui/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sambagui/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sambagui/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sandboxX (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sandboxX/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sandboxX/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sandboxX/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sanlock (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sanlock/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sanlock/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sanlock/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sap (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sap/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sap/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sap/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sasl (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sasl/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sasl/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sasl/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sbd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sbd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sbd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sbd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sblim (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sblim/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sblim/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sblim/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/screen (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/screen/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/screen/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/screen/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/secadm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/secadm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/secadm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/secadm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sectoolm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sectoolm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sectoolm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sectoolm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/selinuxutil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/selinuxutil/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/selinuxutil/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/selinuxutil/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sendmail (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sendmail/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sendmail/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sendmail/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sensord (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sensord/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sensord/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sensord/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/setrans (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/setrans/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/setrans/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/setrans/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/setroubleshoot (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/setroubleshoot/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/setroubleshoot/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/setroubleshoot/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/seunshare (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/seunshare/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/seunshare/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/seunshare/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/shorewall (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/shorewall/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/shorewall/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/shorewall/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/slocate (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/slocate/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/slocate/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/slocate/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/slpd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/slpd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/slpd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/slpd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/slrnpull (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/slrnpull/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/slrnpull/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/slrnpull/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/smartmon (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/smartmon/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/smartmon/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/smartmon/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/smokeping (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/smokeping/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/smokeping/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/smokeping/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/smoltclient (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/smoltclient/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/smoltclient/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/smoltclient/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/snapper (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/snapper/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/snapper/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/snapper/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/snmp (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/snmp/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/snmp/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/snmp/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/snort (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/snort/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/snort/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/snort/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sosreport (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sosreport/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sosreport/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sosreport/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/soundserver (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/soundserver/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/soundserver/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/soundserver/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/spamassassin (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/spamassassin/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/spamassassin/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/spamassassin/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/speech-dispatcher (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/speech-dispatcher/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/speech-dispatcher/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/speech-dispatcher/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/squid (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/squid/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/squid/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/squid/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ssh (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ssh/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ssh/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ssh/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sslh (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sslh/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sslh/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sslh/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sssd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sssd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sssd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sssd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/staff (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/staff/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/staff/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/staff/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stalld (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stalld/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stalld/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stalld/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stapserver (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stapserver/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stapserver/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stapserver/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stratisd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stratisd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stratisd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stratisd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stunnel (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stunnel/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stunnel/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/stunnel/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/su (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/su/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/su/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/su/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sudo (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sudo/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sudo/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sudo/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/svnserve (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/svnserve/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/svnserve/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/svnserve/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/swift (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/swift/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/swift/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/swift/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/switcheroo (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/switcheroo/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/switcheroo/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/switcheroo/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysadm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysadm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysadm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysadm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysadm_secadm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysadm_secadm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysadm_secadm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysadm_secadm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysnetwork (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysnetwork/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysnetwork/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysnetwork/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysstat (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysstat/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysstat/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/sysstat/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/systemd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/systemd-homed (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/systemd-homed/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/systemd-homed/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/systemd-homed/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/systemd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/systemd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/systemd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tangd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tangd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tangd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tangd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/targetd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/targetd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/targetd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/targetd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tcpd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tcpd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tcpd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tcpd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tcsd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tcsd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tcsd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tcsd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/telepathy (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/telepathy/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/telepathy/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/telepathy/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/telnet (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/telnet/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/telnet/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/telnet/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tftp (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tftp/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tftp/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tftp/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tgtd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tgtd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tgtd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tgtd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/thin (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/thin/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/thin/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/thin/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/thumb (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/thumb/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/thumb/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/thumb/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tlp (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tlp/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tlp/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tlp/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tmpreaper (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tmpreaper/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tmpreaper/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tmpreaper/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tomcat (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tomcat/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tomcat/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tomcat/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tor (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tor/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tor/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tor/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tuned (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tuned/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tuned/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tuned/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tvtime (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tvtime/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tvtime/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/tvtime/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/udev (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/udev/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/udev/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/udev/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ulogd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ulogd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ulogd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/ulogd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/uml (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/uml/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/uml/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/uml/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unconfined (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unconfined/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unconfined/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unconfined/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unconfineduser (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unconfineduser/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unconfineduser/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unconfineduser/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unlabelednet (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unlabelednet/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unlabelednet/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unlabelednet/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unprivuser (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unprivuser/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unprivuser/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/unprivuser/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/updfstab (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/updfstab/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/updfstab/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/updfstab/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usbmodules (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usbmodules/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usbmodules/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usbmodules/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usbmuxd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usbmuxd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usbmuxd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usbmuxd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/userdomain (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/userdomain/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/userdomain/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/userdomain/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/userhelper (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/userhelper/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/userhelper/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/userhelper/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usermanage (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usermanage/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usermanage/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usermanage/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usernetctl (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usernetctl/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usernetctl/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/usernetctl/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/uucp (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/uucp/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/uucp/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/uucp/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/uuidd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/uuidd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/uuidd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/uuidd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/varnishd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/varnishd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/varnishd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/varnishd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vdagent (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vdagent/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vdagent/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vdagent/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vhostmd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vhostmd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vhostmd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vhostmd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/virt (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/virt/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/virt/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/virt/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/virt_supplementary (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/virt_supplementary/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/virt_supplementary/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/virt_supplementary/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vlock (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vlock/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vlock/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vlock/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vmtools (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vmtools/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vmtools/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vmtools/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vmware (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vmware/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vmware/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vmware/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vnstatd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vnstatd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vnstatd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vnstatd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vpn (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vpn/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vpn/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/vpn/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/w3c (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/w3c/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/w3c/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/w3c/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/watchdog (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/watchdog/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/watchdog/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/watchdog/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wdmd (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wdmd/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wdmd/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wdmd/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/webadm (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/webadm/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/webadm/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/webadm/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/webalizer (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/webalizer/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/webalizer/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/webalizer/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wine (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wine/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wine/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wine/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wireguard (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wireguard/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wireguard/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wireguard/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wireshark (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wireshark/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wireshark/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/wireshark/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/xen (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/xen/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/xen/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/xen/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/xguest (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/xguest/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/xguest/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/xguest/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/xserver (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/xserver/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/xserver/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/xserver/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zabbix (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zabbix/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zabbix/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zabbix/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zarafa (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zarafa/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zarafa/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zarafa/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zebra (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zebra/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zebra/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zebra/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zoneminder (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zoneminder/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zoneminder/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zoneminder/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zosremote (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zosremote/cil (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zosremote/hll (Permission denied)
missing     /var/lib/selinux/targeted/active/modules/100/zosremote/lang_ext (Permission denied)
missing     /var/lib/selinux/targeted/active/modules_checksum (Permission denied)
missing     /var/lib/selinux/targeted/active/policy.kern (Permission denied)
missing     /var/lib/selinux/targeted/active/seusers (Permission denied)
missing     /var/lib/selinux/targeted/active/users_extra (Permission denied)
missing   c /etc/grub.d/00_header (Permission denied)
missing   c /etc/grub.d/01_users (Permission denied)
missing   c /etc/grub.d/08_fallback_counting (Permission denied)
missing   c /etc/grub.d/10_linux (Permission denied)
missing   c /etc/grub.d/10_reset_boot_success (Permission denied)
missing   c /etc/grub.d/12_menu_auto_hide (Permission denied)
missing   c /etc/grub.d/14_menu_show_once (Permission denied)
missing   c /etc/grub.d/20_linux_xen (Permission denied)
missing   c /etc/grub.d/20_ppc_terminfo (Permission denied)
missing   c /etc/grub.d/25_bli (Permission denied)
missing   c /etc/grub.d/30_os-prober (Permission denied)
missing   c /etc/grub.d/30_uefi-firmware (Permission denied)
missing   c /etc/grub.d/40_custom (Permission denied)
missing   c /etc/grub.d/41_custom (Permission denied)
missing     /etc/grub.d/README (Permission denied)
missing     /usr/lib/containers/storage/overlay-images/images.lock (Permission denied)
missing     /usr/lib/containers/storage/overlay-layers/layers.lock (Permission denied)
..?......  c /etc/sudo.conf
..?......  c /etc/sudoers
..?......    /usr/bin/sudo
..?......    /usr/bin/sudoreplay
missing     /var/db/sudo/lectured (Permission denied)
missing     /var/lib/nfs/statd/sm (Permission denied)
missing     /var/lib/nfs/statd/sm.bak (Permission denied)
......G..    /run/plasmalogin
.M.......    /var/lib/plasmalogin
..?......    /etc/cups/cups-files.conf.default
..?......    /etc/cups/cupsd.conf.default
..?......    /etc/cups/snmp.conf.default
missing     /var/spool/cups/tmp (Permission denied)
missing   c /etc/audit/audit-stop.rules (Permission denied)
missing     /etc/audit/rules.d (Permission denied)
missing     /etc/ipsec.d/policies (Permission denied)
missing   c /etc/ipsec.d/policies/block (Permission denied)
missing   c /etc/ipsec.d/policies/clear (Permission denied)
missing   c /etc/ipsec.d/policies/clear-or-private (Permission denied)
missing   c /etc/ipsec.d/policies/portexcludes.conf (Permission denied)
missing   c /etc/ipsec.d/policies/private (Permission denied)
missing   c /etc/ipsec.d/policies/private-or-clear (Permission denied)
..?......  c /etc/ipsec.secrets
missing     /var/lib/ipsec/nss (Permission denied)
missing     /etc/sssd/conf.d (Permission denied)
missing     /etc/sssd/pki (Permission denied)
..?......    /usr/libexec/sssd/sssd_pam
..?......    /usr/libexec/sssd/krb5_child
..?......    /usr/libexec/sssd/ldap_child
..?......    /usr/libexec/sssd/proxy_child
missing   c /etc/audit/auditd.conf (Permission denied)
missing     /etc/audit/plugins.d (Permission denied)
..?......    /usr/lib/tmpfiles.d/audit.conf
missing     /usr/libexec/initscripts/legacy-actions/auditd/condrestart (Permission denied)
missing     /usr/libexec/initscripts/legacy-actions/auditd/reload (Permission denied)
missing     /usr/libexec/initscripts/legacy-actions/auditd/restart (Permission denied)
missing     /usr/libexec/initscripts/legacy-actions/auditd/resume (Permission denied)
missing     /usr/libexec/initscripts/legacy-actions/auditd/rotate (Permission denied)
missing     /usr/libexec/initscripts/legacy-actions/auditd/state (Permission denied)
missing     /usr/libexec/initscripts/legacy-actions/auditd/stop (Permission denied)
..?......    /usr/lib/cups/backend/hp
..?......    /usr/lib/cups/backend/hpfax
..?......  c /etc/gssproxy/24-nfs-server.conf
..?......  c /etc/ssh/sshd_config
missing   c /etc/ssh/sshd_config.d/40-redhat-crypto-policies.conf (Permission denied)
missing   c /etc/ssh/sshd_config.d/50-redhat.conf (Permission denied)
..?......  c /etc/sysconfig/sshd
missing     /boot/grub2/fonts (Permission denied)
missing     /boot/grub2/fonts/unicode.pf2 (Permission denied)
missing   c /boot/grub2/grubenv (Permission denied)
..?......    /usr/bin/gen_grub_cfgstub
missing     /usr/lib/efi/grub2/1:2.12-64.fc44/EFI/fedora/grubx64.efi (Permission denied)
missing     /boot/grub2/fonts (Permission denied)
missing     /boot/grub2/fonts/unicode.pf2 (Permission denied)
missing   c /boot/grub2/grubenv (Permission denied)
..?......    /usr/bin/gen_grub_cfgstub
missing     /usr/lib/efi/grub2/1:2.12-64.fc44/EFI/fedora/grubia32.efi (Permission denied)
.M.......  g /run/thermald/thermald.pid
missing     /boot/grub2/fonts (Permission denied)
missing     /boot/grub2/fonts/unicode.pf2 (Permission denied)
missing     /usr/lib/efi/grub2/1:2.12-64.fc44/EFI/fedora/gcdx64.efi (Permission denied)
missing     /boot/grub2/fonts (Permission denied)
missing     /boot/grub2/fonts/unicode.pf2 (Permission denied)
missing     /usr/lib/efi/grub2/1:2.12-64.fc44/EFI/fedora/gcdia32.efi (Permission denied)
..?......  c /etc/libaudit.conf
..?......    /usr/bin/staprun

exit=1
```

## KWin

Komut: `rpm -q kwin; rpm -V kwin; stat /usr/lib/systemd/user/plasma-kwin_wayland.service; sha256sum /usr/lib/systemd/user/plasma-kwin_wayland.service`

```text
kwin-6.7.5-1.fc44.x86_64
  File: /usr/lib/systemd/user/plasma-kwin_wayland.service
  Size: 184       	Blocks: 8          IO Block: 4096   regular file
Device: 0,37	Inode: 1008019     Links: 1
Access: (0644/-rw-r--r--)  Uid: (    0/    root)   Gid: (    0/    root)
Context: system_u:object_r:xdm_unit_file_t:s0
Access: 2026-09-30 20:31:10.628056671 +0300
Modify: 2026-09-08 03:00:00.000000000 +0300
Change: 2026-09-30 20:31:10.088050992 +0300
 Birth: 2026-09-30 20:31:10.071547824 +0300
7b9e88ff3ef0649e503f74fc984c126f7ede0929283d224e9b5e547b798d5458  /usr/lib/systemd/user/plasma-kwin_wayland.service

exit=0
```

## İzleme

Komut: `sensors -j; dmesg --level=err,crit,alert,emerg; journalctl -k -b --no-pager -p err; cat /proc/loadavg`

```text
{
   "k10temp-pci-00c3":{
      "Adapter": "PCI adapter",
      "Tctl":{
         "temp1_input": 50.625
      }
   },
   "nvme-pci-0900":{
      "Adapter": "PCI adapter",
      "Composite":{
         "temp1_input": 39.850,
         "temp1_max": 82.850,
         "temp1_min": -0.150,
         "temp1_crit": 86.850,
         "temp1_alarm": 0.000
      }
   },
   "nct6793-isa-0290":{
      "Adapter": "ISA adapter",
      "in0":{
         "in0_input": 0.720,
         "in0_min": 0.000,
         "in0_max": 1.744,
         "in0_alarm": 0.000,
         "in0_beep": 0.000
      },
      "in1":{
         "in1_input": 1.824,
         "in1_min": 0.000,
         "in1_max": 0.000,
         "in1_alarm": 1.000,
         "in1_beep": 0.000
      },
      "in2":{
         "in2_input": 3.440,
         "in2_min": 0.000,
         "in2_max": 0.000,
         "in2_alarm": 1.000,
         "in2_beep": 0.000
      },
      "in3":{
         "in3_input": 3.328,
         "in3_min": 0.000,
         "in3_max": 0.000,
         "in3_alarm": 1.000,
         "in3_beep": 0.000
      },
      "in4":{
         "in4_input": 0.240,
         "in4_min": 0.000,
         "in4_max": 0.000,
         "in4_alarm": 1.000,
         "in4_beep": 0.000
      },
      "in5":{
         "in5_input": 0.120,
         "in5_min": 0.000,
         "in5_max": 0.000,
         "in5_alarm": 1.000,
         "in5_beep": 0.000
      },
      "in6":{
         "in6_input": 0.912,
         "in6_min": 0.000,
         "in6_max": 0.000,
         "in6_alarm": 1.000,
         "in6_beep": 0.000
      },
      "in7":{
         "in7_input": 3.440,
         "in7_min": 0.000,
         "in7_max": 0.000,
         "in7_alarm": 1.000,
         "in7_beep": 0.000
      },
      "in8":{
         "in8_input": 3.264,
         "in8_min": 0.000,
         "in8_max": 0.000,
         "in8_alarm": 1.000,
         "in8_beep": 0.000
      },
      "in9":{
         "in9_input": 1.784,
         "in9_min": 0.000,
         "in9_max": 0.000,
         "in9_alarm": 1.000,
         "in9_beep": 0.000
      },
      "in10":{
         "in10_input": 0.168,
         "in10_min": 0.000,
         "in10_max": 0.000,
         "in10_alarm": 1.000,
         "in10_beep": 0.000
      },
      "in11":{
         "in11_input": 0.120,
         "in11_min": 0.000,
         "in11_max": 0.000,
         "in11_alarm": 1.000,
         "in11_beep": 0.000
      },
      "in12":{
         "in12_input": 1.824,
         "in12_min": 0.000,
         "in12_max": 0.000,
         "in12_alarm": 1.000,
         "in12_beep": 0.000
      },
      "in13":{
         "in13_input": 1.712,
         "in13_min": 0.000,
         "in13_max": 0.000,
         "in13_alarm": 1.000,
         "in13_beep": 0.000
      },
      "in14":{
         "in14_input": 0.184,
         "in14_min": 0.000,
         "in14_max": 0.000,
         "in14_alarm": 1.000,
         "in14_beep": 0.000
      },
      "fan1":{
         "fan1_input": 1638.000,
         "fan1_min": 0.000,
         "fan1_alarm": 0.000,
         "fan1_beep": 0.000,
         "fan1_pulses": 2.000
      },
      "fan2":{
         "fan2_input": 2743.000,
         "fan2_min": 0.000,
         "fan2_alarm": 0.000,
         "fan2_beep": 0.000,
         "fan2_pulses": 2.000
      },
      "fan3":{
         "fan3_input": 0.000,
         "fan3_min": 0.000,
         "fan3_alarm": 0.000,
         "fan3_beep": 0.000,
         "fan3_pulses": 2.000
      },
      "fan4":{
         "fan4_input": 0.000,
         "fan4_min": 0.000,
         "fan4_alarm": 0.000,
         "fan4_beep": 0.000,
         "fan4_pulses": 2.000
      },
      "fan5":{
         "fan5_input": 0.000,
         "fan5_min": 0.000,
         "fan5_alarm": 0.000,
         "fan5_beep": 0.000,
         "fan5_pulses": 2.000
      },
      "SYSTIN":{
         "temp1_input": 119.000,
         "temp1_max": 0.000,
         "temp1_max_hyst": 0.000,
         "temp1_type": 4.000,
         "temp1_offset": 0.000
      },
      "CPUTIN":{
         "temp2_input": 32.500,
         "temp2_max": 80.000,
         "temp2_max_hyst": 75.000,
         "temp2_alarm": 0.000,
         "temp2_type": 4.000,
         "temp2_offset": 0.000,
         "temp2_beep": 0.000
      },
      "AUXTIN0":{
         "temp3_input": 31.000,
         "temp3_max": 0.000,
         "temp3_max_hyst": 0.000,
         "temp3_alarm": 1.000,
         "temp3_type": 4.000,
         "temp3_offset": 0.000,
         "temp3_beep": 0.000
      },
      "AUXTIN1":{
         "temp4_input": 111.000,
         "temp4_type": 4.000,
         "temp4_offset": 0.000
      },
      "AUXTIN2":{
         "temp5_input": 111.000,
         "temp5_type": 4.000,
         "temp5_offset": 0.000
      },
      "AUXTIN3":{
         "temp6_input": 111.000,
         "temp6_type": 4.000,
         "temp6_offset": 0.000
      },
      "SMBUSMASTER 0":{
         "temp7_input": 50.500
      },
      "PCH_CHIP_CPU_MAX_TEMP":{
         "temp8_input": 0.000
      },
      "PCH_CHIP_TEMP":{
         "temp9_input": 0.000
      },
      "PCH_CPU_TEMP":{
         "temp10_input": 0.000
      },
      "PCH_MCH_TEMP":{
         "temp11_input": 0.000
      },
      "Agent0 Dimm0 ":{
         "temp12_input": 0.000
      },
      "TSI0_TEMP":{
         "temp13_input": 50.625
      },
      "TSI2_TEMP":{
         "temp15_input": 3892313.987
      },
      "TSI3_TEMP":{
         "temp16_input": 3892313.987
      },
      "TSI4_TEMP":{
         "temp17_input": 3892313.987
      },
      "TSI5_TEMP":{
         "temp18_input": 3892313.987
      },
      "TSI6_TEMP":{
         "temp19_input": 3892313.987
      },
      "TSI7_TEMP":{
         "temp20_input": 3892313.987
      },
      "intrusion0":{
         "intrusion0_alarm": 0.000,
         "intrusion0_beep": 0.000
      },
      "intrusion1":{
         "intrusion1_alarm": 1.000,
         "intrusion1_beep": 0.000
      },
      "beep_enable":{
         "beep_enable": 0.000
      }
   }
}
dmesg: read kernel buffer failed: Operation not permitted
Oct 01 01:27:18 thewo kernel: virt/tdx: TDX not supported by the host platform
Sep 30 22:27:21 thewo kernel:
1.70 1.63 1.22 2/1333 39559

exit=0
```

## VM envanteri

Komut: `virsh -c qemu:///session list --all; virsh -c qemu:///system list --all; ls -l /dev/kvm`

```text
 Id   Name   State
--------------------

 Id   Name   State
--------------------

crw-rw-rw-. 1 root kvm 10, 232 Sep 30 22:27 /dev/kvm

exit=0
```

## Riskli çağrıların tam statik envanteri

Yorumlar ve heredoc içindeki guest komutları da dahil; bu liste tek başına çalıştırılabilirlik/host etkisi kanıtı değildir. Eski host runner’ları yeni akışta çalıştırılmayacak.

```text
/home/yrslf/alpbahOS/scripts/apply-m2-rootfs-fixes.sh:42: rm -f -- "$tmp_service" "$tmp_socket"
/home/yrslf/alpbahOS/scripts/build-blfs-alsa-lib.sh:34: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/libasound.so.2 ]]' || fail 'make is missing or ALSA-lib is already installed.'
/home/yrslf/alpbahOS/scripts/build-blfs-alsa-lib.sh:51: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-alsa-lib.sh:101: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-aspell-d34.sh:36: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-aspell-d34.sh:70: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-aspell.sh:18: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not the expected HDD bind mount.'
/home/yrslf/alpbahOS/scripts/build-blfs-aspell.sh:19: [[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot pseudo-filesystems are not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-aspell.sh:73:     installed="$(sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX aspell --version | head -n1)"
/home/yrslf/alpbahOS/scripts/build-blfs-aspell.sh:84:   sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- "$archive" "$work" "$source" "$stage" "$pkglog" <<'ASPELL_BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-aspell.sh:108:   sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$source" "$pkglog" <<'ASPELL_INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-aspell.sh:134:   if sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX aspell dump dicts 2>/dev/null | grep -Fxq "$lang"; then
/home/yrslf/alpbahOS/scripts/build-blfs-aspell.sh:140:   sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- "$archive" "$work" "$stage" "$pkglog" <<'DICT_BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-aspell.sh:161:   source="$(sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX find "$work" -mindepth 2 -maxdepth 2 -type f -name configure -printf '%h\n' | head -n1)"
/home/yrslf/alpbahOS/scripts/build-blfs-aspell.sh:163:   sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$source" "$pkglog" <<'DICT_INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-aspell.sh:173:   if ! sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX aspell dump dicts | grep -Fxq "$lang"; then
/home/yrslf/alpbahOS/scripts/build-blfs-aspell.sh:183: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '
/home/yrslf/alpbahOS/scripts/build-blfs-boost-headers-d34.sh:32: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-boost-headers-d34.sh:64: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-boost.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '
/home/yrslf/alpbahOS/scripts/build-blfs-boost.sh:54: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-boost.sh:106: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-cmake-d34.sh:17: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c 'command -v make >/dev/null && test ! -x /usr/bin/cmake'
/home/yrslf/alpbahOS/scripts/build-blfs-cmake-d34.sh:28: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-cmake-d34.sh:45: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$WORK/cmake-$VERSION" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-cmake.sh:29: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-cmake.sh:30: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-cmake.sh:31: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-cmake.sh:32: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-cmake.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-cmake.sh:59:     rm -f "$TEMP_DOWNLOAD"
/home/yrslf/alpbahOS/scripts/build-blfs-cmake.sh:66: if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-cmake.sh:129: if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-cracklib.sh:34: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '
/home/yrslf/alpbahOS/scripts/build-blfs-cracklib.sh:57: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-cracklib.sh:127: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-curl.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/libcurl.so ]]' || fail 'make is missing or libcurl already exists in the target.'
/home/yrslf/alpbahOS/scripts/build-blfs-curl.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ "$(pkg-config --modversion libpsl)" == 0.21.5 && "$(openssl version)" == "OpenSSL 3.5.2"* ]]' || fail 'cURL dependencies libpsl 0.21.5 and OpenSSL 3.5.2 are missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-curl.sh:48: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-curl.sh:101: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-cython-d34.sh:24: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-cython-d34.sh:46:         rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"
/home/yrslf/alpbahOS/scripts/build-blfs-cython-d34.sh:50: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-cython-d34.sh:77: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-dejavu-fonts-d34.sh:18: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c 'command -v fc-cache >/dev/null && command -v fc-match >/dev/null && test -r /etc/fonts/fonts.conf && ! -d /usr/share/fonts/dejavu'
/home/yrslf/alpbahOS/scripts/build-blfs-dejavu-fonts-d34.sh:26:   else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"; fi
/home/yrslf/alpbahOS/scripts/build-blfs-dejavu-fonts-d34.sh:28: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /usr/bin/python3 - "$ARCHIVE" "$WORK" <<'STAGE'
/home/yrslf/alpbahOS/scripts/build-blfs-dejavu-fonts-d34.sh:46: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$STAGE/usr/share/fonts/dejavu" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-docbook-d34.sh:62: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-docbook-d34.sh:135: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-docbook-stack.sh:19: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-docbook-stack.sh:46:     rm -f "$tmp"
/home/yrslf/alpbahOS/scripts/build-blfs-docbook-stack.sh:61: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-docutils.sh:39:   rm -f "$tmp"
/home/yrslf/alpbahOS/scripts/build-blfs-docutils.sh:41: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-docutils.sh:76: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -s -- "$WORK" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-duktape.sh:49: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-duktape.sh:106: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-ecm-d34.sh:22: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-ecm-d34.sh:48: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-ecm-d34.sh:87: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-ecm.sh:30: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-ecm.sh:31: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-ecm.sh:32: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-ecm.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-ecm.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-ecm.sh:71: if ! sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-blfs-ecm.sh:139: if ! sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-blfs-font-stack.sh:16: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-font-stack.sh:17: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-font-stack.sh:18: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-font-stack.sh:19: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-font-stack.sh:20: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-font-stack.sh:64:         rm -f "$temp_download"
/home/yrslf/alpbahOS/scripts/build-blfs-font-stack.sh:71:     if ! sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-blfs-font-stack.sh:174:     if ! sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-blfs-font-stack.sh:217: if sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin /bin/bash -ec \
/home/yrslf/alpbahOS/scripts/build-blfs-fontconfig-d34.sh:17: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c 'command -v make >/dev/null && pkg-config --exists freetype2 harfbuzz && ! -x /usr/bin/fc-cache'
/home/yrslf/alpbahOS/scripts/build-blfs-fontconfig-d34.sh:26:   else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"; fi
/home/yrslf/alpbahOS/scripts/build-blfs-fontconfig-d34.sh:28: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j6 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-fontconfig-d34.sh:45: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$WORK/fontconfig-$VERSION" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-freetype-bootstrap-d34.sh:17: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c 'command -v make >/dev/null && command -v gcc >/dev/null && ! -e /usr/lib/libfreetype.so'
/home/yrslf/alpbahOS/scripts/build-blfs-freetype-bootstrap-d34.sh:26:   else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"; fi
/home/yrslf/alpbahOS/scripts/build-blfs-freetype-bootstrap-d34.sh:28: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j6 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-freetype-bootstrap-d34.sh:46: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$WORK/freetype-2.13.3" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-gcrypt-d34.sh:27: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 \
/home/yrslf/alpbahOS/scripts/build-blfs-gcrypt-d34.sh:69: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX PKG_CONFIG_PATH=/usr/lib/pkgconfig LD_LIBRARY_PATH=/usr/lib \
/home/yrslf/alpbahOS/scripts/build-blfs-gcrypt-stack.sh:38:   if [[ "$recipe" == libgcrypt ]] && sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -ec '
/home/yrslf/alpbahOS/scripts/build-blfs-gcrypt-stack.sh:48:   if [[ "$recipe" == libgpg-error ]] && sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -ec '
/home/yrslf/alpbahOS/scripts/build-blfs-gcrypt-stack.sh:64:     rm -f "$temp"
/home/yrslf/alpbahOS/scripts/build-blfs-gcrypt-stack.sh:67:   if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-gcrypt-stack.sh:134:   if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-glib.sh:29: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -ec '
/home/yrslf/alpbahOS/scripts/build-blfs-glib.sh:43:   rm -f "$tmp"
/home/yrslf/alpbahOS/scripts/build-blfs-glib.sh:45: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-glib.sh:88: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-harfbuzz-d34.sh:17: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c 'command -v meson >/dev/null && command -v ninja >/dev/null && pkg-config --exists freetype2 && ! -e /usr/lib/libharfbuzz.so'
/home/yrslf/alpbahOS/scripts/build-blfs-harfbuzz-d34.sh:26:   else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"; fi
/home/yrslf/alpbahOS/scripts/build-blfs-harfbuzz-d34.sh:28: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j6 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-harfbuzz-d34.sh:45: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$WORK/build" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-hwdata.sh:28: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/share/hwdata/pnp.ids ]]' || fail 'make is missing or hwdata is already installed.'
/home/yrslf/alpbahOS/scripts/build-blfs-hwdata.sh:39: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-hwdata.sh:83: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-icu-d34.sh:23: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 \
/home/yrslf/alpbahOS/scripts/build-blfs-icu-d34.sh:56: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$WORK/stage" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-icu.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/libicuuc.so ]]' || fail 'make is missing or ICU already exists.'
/home/yrslf/alpbahOS/scripts/build-blfs-icu.sh:44: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-icu.sh:91: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-dependencies.sh:10: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not the expected HDD bind mount.'
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-dependencies.sh:11: [[ -c "$LFS/dev/null" && "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot pseudo-filesystems are not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-dependencies.sh:69:   sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- "$archive" "$work" "$source" "$stage" "$pkglog" "$options" "$patchfile" "$installopts" "$docs" <<'AUTOTOOLS'
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-dependencies.sh:90:   sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$source" "$pkglog" "$pc" "$ver" "$installopts" "$docs" <<'AUTOTOOLS_INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-dependencies.sh:118:   sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- "$archive" "$work" "$source" "$build" "$stage" "$pkglog" "$args" <<'CMAKE_BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-dependencies.sh:131:   sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$build" "$pkglog" "$pc" "$ver" "$marker" <<'CMAKE_INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-dependencies.sh:157: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-frameworks.sh:13: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-frameworks.sh:59:  if [[ "$n" == networkmanager-qt ]] && ! sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX pkg-config --exists libnm; then
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-frameworks.sh:64:  if [[ "$n" == modemmanager-qt ]] && ! sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX pkg-config --exists mm-glib; then
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-frameworks.sh:80:  if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr ECM_DIR=/usr/share/ECM/cmake Qt6_DIR=/opt/qt6/lib/cmake/Qt6 Qt6LinguistTools_DIR=/opt/qt6/lib/cmake/Qt6LinguistTools Qt6Svg_DIR=/opt/qt6/lib/cmake/Qt6Svg PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:/opt/kf6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib MAKEFLAGS=-j4 /bin/bash -s -- "$a" "$w" "$s" "$b" "$st" "$pl" "$opts" <<'BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-frameworks.sh:99:  if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr Qt6_DIR=/opt/qt6/lib/cmake/Qt6 PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:/opt/kf6/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib /bin/bash -s -- "$b" "$pl" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-package-d34.sh:28: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-package-d34.sh:35: if [[ "$PACKAGE" == networkmanager-qt ]] && ! sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX pkg-config --exists libnm; then
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-package-d34.sh:68: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-kf6-package-d34.sh:129: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-kirigami-addons.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/cmake && -f /opt/qt6/lib/cmake/Qt6/Qt6Config.cmake && -d /opt/kf6/lib/cmake/KF6CoreAddons && ! -e /opt/kf6/lib/cmake/KF6KirigamiAddons/KF6KirigamiAddonsConfig.cmake ]]' || fail 'CMake/Qt6/KF6 dependency is missing or Kirigami Addons already exists.'
/home/yrslf/alpbahOS/scripts/build-blfs-kirigami-addons.sh:45: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6 LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-kirigami-addons.sh:98: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6 LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-knotification-audio-d34.sh:35: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-knotification-audio-d34.sh:71: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-kwin-deps-d34.sh:46: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-kwin-deps-d34.sh:112: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-libdisplay-info.sh:29: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -s /usr/share/hwdata/pnp.ids && -x /usr/bin/meson && -x /usr/bin/ninja && ! -e /usr/lib/libdisplay-info.so ]]' || fail 'hwdata, Meson, Ninja are missing or libdisplay-info is already installed.'
/home/yrslf/alpbahOS/scripts/build-blfs-libdisplay-info.sh:40: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libdisplay-info.sh:83: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libdrm-d34.sh:23: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-libdrm-d34.sh:46:         rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"
/home/yrslf/alpbahOS/scripts/build-blfs-libdrm-d34.sh:50: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-libdrm-d34.sh:77: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-libical-d34.sh:26: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 \
/home/yrslf/alpbahOS/scripts/build-blfs-libical-d34.sh:65: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-libidn2.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/libidn2.so ]]' || fail 'make is missing or libidn2 already exists in the target.'
/home/yrslf/alpbahOS/scripts/build-blfs-libidn2.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -f /usr/include/unistr.h && -e /usr/lib/libunistring.so ]] && grep -Fq "#define _LIBUNISTRING_VERSION 0x010300" /usr/include/unistring/version.h' || fail 'libidn2 dependency libunistring 1.3 is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-libidn2.sh:48: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libidn2.sh:99: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-libndp.sh:28: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/libndp.so ]]' || fail 'make is missing or libndp already exists in the target.'
/home/yrslf/alpbahOS/scripts/build-blfs-libndp.sh:46: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libnl.sh:28: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -f /usr/lib/pkgconfig/libnl-3.0.pc ]]' || fail 'make is missing or libnl is already installed.'
/home/yrslf/alpbahOS/scripts/build-blfs-libnl.sh:39: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libnl.sh:83: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libpciaccess-d34.sh:23: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-libpciaccess-d34.sh:43:     rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"
/home/yrslf/alpbahOS/scripts/build-blfs-libpciaccess-d34.sh:46: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-libpciaccess-d34.sh:72: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-libpng-d34.sh:17: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c 'command -v make >/dev/null && pkg-config --exists zlib && ! -e /usr/lib/libpng16.so'
/home/yrslf/alpbahOS/scripts/build-blfs-libpng-d34.sh:26:   else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"; fi
/home/yrslf/alpbahOS/scripts/build-blfs-libpng-d34.sh:28: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j6 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-libpng-d34.sh:45: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$WORK/libpng-$VERSION" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-libpsl.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/libpsl.so ]]' || fail 'make is missing or libpsl already exists in the target.'
/home/yrslf/alpbahOS/scripts/build-blfs-libpsl.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ "$(pkg-config --modversion libidn2)" == 2.3.8 ]]' || fail 'libpsl dependency libidn2 2.3.8 is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-libpsl.sh:48: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libpsl.sh:99: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-libpwquality.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '
/home/yrslf/alpbahOS/scripts/build-blfs-libpwquality.sh:51: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libpwquality.sh:111: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libqalculate.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/libqalculate.so ]]' || fail 'make is missing or libqalculate already exists in the target.'
/home/yrslf/alpbahOS/scripts/build-blfs-libqalculate.sh:48: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libqalculate.sh:99: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-libsecret-d34.sh:19: [credential-adjacent line redacted; calls=chroot]
/home/yrslf/alpbahOS/scripts/build-blfs-libsecret-d34.sh:39: [credential-adjacent line redacted; calls=chroot]
/home/yrslf/alpbahOS/scripts/build-blfs-libsecret.sh:10: [credential-adjacent line redacted; calls=mount]
/home/yrslf/alpbahOS/scripts/build-blfs-libsecret.sh:14: [credential-adjacent line redacted; calls=chroot]
/home/yrslf/alpbahOS/scripts/build-blfs-libsecret.sh:31: [credential-adjacent line redacted; calls=chroot]
/home/yrslf/alpbahOS/scripts/build-blfs-libsecret.sh:66: [credential-adjacent line redacted; calls=chroot]
/home/yrslf/alpbahOS/scripts/build-blfs-libsndfile.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && -e /usr/lib/libasound.so.2 && ! -e /usr/lib/libsndfile.so.1 ]]' || fail 'make/ALSA dependency is missing or libsndfile is already installed.'
/home/yrslf/alpbahOS/scripts/build-blfs-libsndfile.sh:43: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libsndfile.sh:92: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-libunistring.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/libunistring.so ]]' || fail 'make is missing or libunistring already exists in the target.'
/home/yrslf/alpbahOS/scripts/build-blfs-libunistring.sh:47: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libunistring.sh:98: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-libxml2-d34.sh:20: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c \
/home/yrslf/alpbahOS/scripts/build-blfs-libxml2-d34.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libxml2-d34.sh:47: rm -f /usr/lib/libxml2.la
/home/yrslf/alpbahOS/scripts/build-blfs-libxslt-d34.sh:20: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c \
/home/yrslf/alpbahOS/scripts/build-blfs-libxslt-d34.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libxslt.sh:28: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-libxslt.sh:29: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-libxslt.sh:30: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-libxslt.sh:31: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-libxslt.sh:32: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-libxslt.sh:59:     rm -f "$TEMP_DOWNLOAD"
/home/yrslf/alpbahOS/scripts/build-blfs-libxslt.sh:66: if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libxslt.sh:119: if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-libyaml-d34.sh:23: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-libyaml-d34.sh:45:         rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"
/home/yrslf/alpbahOS/scripts/build-blfs-libyaml-d34.sh:49: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-libyaml-d34.sh:76: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-linux-pam.sh:51: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-linux-pam.sh:115: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-lm-sensors-d34.sh:21: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 \
/home/yrslf/alpbahOS/scripts/build-blfs-lm-sensors-d34.sh:53: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash -s -- "$WORK/stage" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-lmdb-d34.sh:27: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 \
/home/yrslf/alpbahOS/scripts/build-blfs-lmdb-d34.sh:66: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-lmdb.sh:41:   rm -f "$tmp"
/home/yrslf/alpbahOS/scripts/build-blfs-lmdb.sh:43: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-lmdb.sh:82: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-lua.sh:34: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/liblua.so.5.4 ]]' || fail 'make is missing or Lua is already installed.'
/home/yrslf/alpbahOS/scripts/build-blfs-lua.sh:51: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-lua.sh:127: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-mako-d34.sh:18: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/python3 && -x /usr/bin/pip3 && -d /usr/lib/python3.13/site-packages/Cython && ! -d /usr/lib/python3.13/site-packages/mako ]]'
/home/yrslf/alpbahOS/scripts/build-blfs-mako-d34.sh:27:   else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"; fi
/home/yrslf/alpbahOS/scripts/build-blfs-mako-d34.sh:29: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-mako-d34.sh:45: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$SOURCE" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-d34.sh:19: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c 'command -v meson >/dev/null && command -v ninja >/dev/null && pkg-config --exists wayland-egl wayland-client libdrm yaml-0.1 && python3 -m pip --version >/dev/null && ! -e /usr/lib/libgallium-25.1.8.so'
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-d34.sh:28:   else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"; fi
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-d34.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-d34.sh:48: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$SOURCE" "$BUILD" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-prereqs.sh:16: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-prereqs.sh:17: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-prereqs.sh:18: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-prereqs.sh:19: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-prereqs.sh:20: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-prereqs.sh:64:         rm -f "$temp_download"
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-prereqs.sh:71:     if ! sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-prereqs.sh:138:     if ! sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-softpipe.sh:29: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-softpipe.sh:30: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-softpipe.sh:31: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-softpipe.sh:32: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-softpipe.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-softpipe.sh:61:     rm -f "$TEMP_DOWNLOAD"
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-softpipe.sh:68: if ! sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-blfs-mesa-softpipe.sh:135: if ! sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-blfs-networkmanager.sh:20: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c \
/home/yrslf/alpbahOS/scripts/build-blfs-networkmanager.sh:23: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c \
/home/yrslf/alpbahOS/scripts/build-blfs-networkmanager.sh:33: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-nspr.sh:28: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -e /usr/lib/libnspr4.so ]]' || fail 'make is missing or NSPR already exists in the target.'
/home/yrslf/alpbahOS/scripts/build-blfs-nspr.sh:46: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-nss.sh:33: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && -x /usr/bin/patch && -e /usr/lib/libnspr4.so && ! -e /usr/lib/libnss3.so ]]' || fail 'make/patch/NSPR prerequisites are missing or NSS is already installed.'
/home/yrslf/alpbahOS/scripts/build-blfs-nss.sh:55: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-pcre2.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/make && ! -f /usr/lib/pkgconfig/libpcre2-8.pc ]]' || fail 'make is missing or PCRE2 is already installed.'
/home/yrslf/alpbahOS/scripts/build-blfs-pcre2.sh:43: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-pcre2.sh:93: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-perl-uri-d34.sh:27: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-perl-uri-d34.sh:52: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-phonon-d34.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-phonon-d34.sh:81: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib \
/home/yrslf/alpbahOS/scripts/build-blfs-phonon.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6:/opt/kf6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kf6/lib:/usr/lib LC_ALL=POSIX /bin/bash -s <<'PHONON_PREFLIGHT'
/home/yrslf/alpbahOS/scripts/build-blfs-phonon.sh:55: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-phonon.sh:113: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-pipewire.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/meson && -x /usr/bin/ninja && -e /usr/lib/libasound.so.2 && -e /usr/lib/libsndfile.so.1 && ! -e /usr/lib/libpipewire-0.3.so ]]' || fail 'Meson/Ninja/ALSA/libsndfile prerequisite is missing or PipeWire already exists.'
/home/yrslf/alpbahOS/scripts/build-blfs-pipewire.sh:44: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-pipewire.sh:104: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-plasma-core-d34.sh:46: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-plasma-core-d34.sh:115: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/opt/kf6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-plasma-wayland-protocols-d34.sh:22: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-plasma-wayland-protocols-d34.sh:42: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-plasma-wayland-protocols-d34.sh:70: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/usr:/usr/share/ECM \
/home/yrslf/alpbahOS/scripts/build-blfs-plasma-wayland-protocols.sh:29: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -ec '
/home/yrslf/alpbahOS/scripts/build-blfs-plasma-wayland-protocols.sh:46:   rm -f "$tmp"
/home/yrslf/alpbahOS/scripts/build-blfs-plasma-wayland-protocols.sh:48: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-plasma-wayland-protocols.sh:91: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-polkit-qt-d34.sh:23: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-polkit-qt-d34.sh:55: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib /bin/bash -s -- "$WORK/stage" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-polkit-qt.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX /bin/bash -s <<'POLKIT_QT_PREFLIGHT'
/home/yrslf/alpbahOS/scripts/build-blfs-polkit-qt.sh:56: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-polkit-qt.sh:114: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-polkit.sh:32: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -s <<'POLKIT_PREFLIGHT'
/home/yrslf/alpbahOS/scripts/build-blfs-polkit.sh:69: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-polkit.sh:139: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-polkit.sh:153: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-pyyaml-d34.sh:18: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/python3 && -x /usr/bin/pip3 && -d /usr/lib/python3.13/site-packages/Cython && -e /usr/lib/libyaml.so && ! -d /usr/lib/python3.13/site-packages/yaml ]]'
/home/yrslf/alpbahOS/scripts/build-blfs-pyyaml-d34.sh:27:   else curl --fail --location --retry 3 --output "$DATA/downloads/$ARCHIVE.part-$STAMP" "$URL"; sudo -n install -o 0 -g 0 -m 0644 "$DATA/downloads/$ARCHIVE.part-$STAMP" "$ARCHIVE_PATH"; rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"; fi
/home/yrslf/alpbahOS/scripts/build-blfs-pyyaml-d34.sh:29: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-pyyaml-d34.sh:45: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$SOURCE" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-qca-d34.sh:19: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 CMAKE_PREFIX_PATH='/opt/qt6;/usr' LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qca-d34.sh:46: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH='/opt/qt6;/usr' LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-qca-prereqs.sh:18: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-qca-prereqs.sh:19: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-qca-prereqs.sh:20: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-qca-prereqs.sh:21: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-qca-prereqs.sh:107: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qca-prereqs.sh:124: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-qca-prereqs.sh:144: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qca-prereqs.sh:161: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-qca-prereqs.sh:178: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qca-prereqs.sh:192: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-qca-prereqs.sh:211: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qca-prereqs.sh:238: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-qca-prereqs.sh:257: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-qca.sh:26: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-qca.sh:27: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-qca.sh:28: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot pseudo-filesystems are not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-qca.sh:32: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-qca.sh:61: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qca.sh:122: if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qcoro-d34.sh:29: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb \
/home/yrslf/alpbahOS/scripts/build-blfs-qcoro-d34.sh:57: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb \
/home/yrslf/alpbahOS/scripts/build-blfs-qcoro.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6 LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX /bin/bash -c '
/home/yrslf/alpbahOS/scripts/build-blfs-qcoro.sh:55: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6 LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qcoro.sh:110: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6 LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-qrencode-d34.sh:26: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 \
/home/yrslf/alpbahOS/scripts/build-blfs-qrencode-d34.sh:62: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-qt-core-prereqs.sh:16: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-qt-core-prereqs.sh:17: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-core-prereqs.sh:18: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-core-prereqs.sh:19: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-core-prereqs.sh:20: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-core-prereqs.sh:62:         rm -f "$temp_download"
/home/yrslf/alpbahOS/scripts/build-blfs-qt-core-prereqs.sh:69:     if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qt-core-prereqs.sh:138:     if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qt-module-d34-common.sh:35: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig CMAKE_PREFIX_PATH=/opt/qt6 LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX /bin/bash -c "$preflight" || fail "Qt $module preflight failed."
/home/yrslf/alpbahOS/scripts/build-blfs-qt-module-d34-common.sh:47: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig CMAKE_PREFIX_PATH=/opt/qt6 LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j6 /bin/bash -s -- "$ARCHIVE" "$WORK" "$module" <<'BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-module-d34-common.sh:94: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 CMAKE_PREFIX_PATH=/opt/qt6 LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX /bin/bash -s -- "$WORK/build" "$module" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-multimedia-speech.sh:9: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail 'LFS is not the expected HDD bind mount.'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-multimedia-speech.sh:13: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '[[ -f /opt/qt6/lib/cmake/Qt6/Qt6Config.cmake && -f /opt/qt6/lib/cmake/Qt6ShaderTools/Qt6ShaderToolsConfig.cmake ]]'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-multimedia-speech.sh:54:   sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX CMAKE_PREFIX_PATH=/opt/qt6:/usr MAKEFLAGS=-j4 /bin/bash -s -- "$archive" "$work" "$source" "$build" "$stage" "$pkglog" "$marker" "$module" <<'BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-multimedia-speech.sh:73:   if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX CMAKE_PREFIX_PATH=/opt/qt6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib /bin/bash -s -- "$build" "$pkglog" "$marker" "$module" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-multimedia-speech.sh:92: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '[[ -f /opt/qt6/lib/cmake/Qt6Multimedia/Qt6MultimediaConfig.cmake && -f /opt/qt6/lib/cmake/Qt6TextToSpeech/Qt6TextToSpeechConfig.cmake && -e /opt/qt6/lib/libQt6Multimedia.so && -e /opt/qt6/lib/libQt6TextToSpeech.so ]]'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-svg-tools.sh:14: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '
/home/yrslf/alpbahOS/scripts/build-blfs-qt-svg-tools.sh:47:   sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX CMAKE_PREFIX_PATH=/opt/qt6:/usr MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qt-svg-tools.sh:90:   if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX CMAKE_PREFIX_PATH=/opt/qt6:/usr LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib \
/home/yrslf/alpbahOS/scripts/build-blfs-qt-wayland-modules.sh:17: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-qt-wayland-modules.sh:18: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-wayland-modules.sh:19: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-wayland-modules.sh:20: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-wayland-modules.sh:21: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-qt-wayland-modules.sh:65:         rm -f "$temp_download"
/home/yrslf/alpbahOS/scripts/build-blfs-qt-wayland-modules.sh:72:     if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-qt-wayland-modules.sh:140:     if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-qt-websockets.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin CMAKE_PREFIX_PATH=/opt/qt6 LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX /bin/bash -c '
/home/yrslf/alpbahOS/scripts/build-blfs-qt-websockets.sh:51: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 CMAKE_PREFIX_PATH=/opt/qt6 PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qt-websockets.sh:99: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin QT6DIR=/opt/qt6 CMAKE_PREFIX_PATH=/opt/qt6 LD_LIBRARY_PATH=/opt/qt6/lib:/usr/lib LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-qt5compat.sh:26: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-qt5compat.sh:27: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-qt5compat.sh:28: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts && "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc && "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot pseudo-filesystems are not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-qt5compat.sh:32: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -ec '
/home/yrslf/alpbahOS/scripts/build-blfs-qt5compat.sh:53: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qt5compat.sh:101: if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-d34.sh:19: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c 'command -v cmake >/dev/null && command -v ninja >/dev/null && pkg-config --exists freetype2 harfbuzz fontconfig libpng16 dbus-1 openssl sqlite3 && test ! -e /opt/qt6/lib/libQt6Core.so.6'
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-d34.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j8 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-d34.sh:59: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$STAGE" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-wayland.sh:31: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-wayland.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-wayland.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-wayland.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-wayland.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-wayland.sh:62:     rm -f "$TEMP_DOWNLOAD"
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-wayland.sh:69: if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-wayland.sh:147: if ! sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-xcb-d34.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-xcb-d34.sh:87: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-xkbcommon-d34.sh:30: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-qtbase-xkbcommon-d34.sh:80: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/opt/qt6/bin:/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-sassc.sh:38: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '
/home/yrslf/alpbahOS/scripts/build-blfs-sassc.sh:64: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-sassc.sh:93: if ! sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -s /usr/lib/libsass.so && -f /usr/lib/pkgconfig/libsass.pc ]]'; then
/home/yrslf/alpbahOS/scripts/build-blfs-sassc.sh:114:     sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-sassc.sh:129: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-sassc.sh:171: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-shared-mime-info.sh:29: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -ec '
/home/yrslf/alpbahOS/scripts/build-blfs-shared-mime-info.sh:45:   rm -f "$tmp"
/home/yrslf/alpbahOS/scripts/build-blfs-shared-mime-info.sh:47: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-shared-mime-info.sh:90: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-sqlite-d34.sh:17: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c 'command -v make >/dev/null && command -v cmake >/dev/null && test -e /usr/lib/libsqlite3.so && test ! -e /usr/lib/pkgconfig/sqlite3.pc'
/home/yrslf/alpbahOS/scripts/build-blfs-sqlite-d34.sh:28: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j6 /bin/bash -s -- "$ARCHIVE" "$WORK" <<'BUILD'
/home/yrslf/alpbahOS/scripts/build-blfs-sqlite-d34.sh:53: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$WORK/sqlite-autoconf-3500400" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-taglib.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/cmake && -f /usr/include/utf8cpp/utf8.h && ! -e /usr/lib/libtag.so ]]' || fail 'CMake/utfcpp dependency is missing or TagLib already exists.'
/home/yrslf/alpbahOS/scripts/build-blfs-taglib.sh:45: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-taglib.sh:96: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-uri-qr-deps.sh:14: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -ec '
/home/yrslf/alpbahOS/scripts/build-blfs-uri-qr-deps.sh:42:   sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- "$archive" "$work" "$source" "$stage" "$pkglog" "$module" "$ver" <<'PERL'
/home/yrslf/alpbahOS/scripts/build-blfs-uri-qr-deps.sh:74:   sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$source" "$pkglog" "$module" "$ver" <<'INSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-uri-qr-deps.sh:90: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 /bin/bash -s -- libqrencode-4.1.1.tar.gz "$QR_WORK" "$QR_SOURCE" "$QR_STAGE" "$QR_LOG" <<'QR'
/home/yrslf/alpbahOS/scripts/build-blfs-uri-qr-deps.sh:125: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -s -- "$QR_SOURCE" "$QR_LOG" <<'QRINSTALL'
/home/yrslf/alpbahOS/scripts/build-blfs-utfcpp.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/cmake && ! -d /usr/include/utf8cpp ]]' || fail 'CMake is missing or utfcpp is already installed.'
/home/yrslf/alpbahOS/scripts/build-blfs-utfcpp.sh:45: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-utfcpp.sh:93: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-base.sh:21: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-base.sh:22: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-base.sh:23: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-base.sh:24: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-base.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-base.sh:73:         rm -f "$temp_download"
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-base.sh:80:     if ! sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-base.sh:208:     if ! sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-base.sh:221:         rm -f /usr/lib/libxml2.la
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-d34.sh:23: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-d34.sh:46:         rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-d34.sh:50: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-d34.sh:76: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-protocols-d34.sh:23: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-protocols-d34.sh:46:         rm -f "$DATA/downloads/$ARCHIVE.part-$STAMP"
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-protocols-d34.sh:50: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-wayland-protocols-d34.sh:76: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-wireplumber.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX /bin/bash -c '[[ -x /usr/bin/meson && -x /usr/bin/ninja && -e /usr/lib/libpipewire-0.3.so && -e /usr/lib/liblua.so.5.4.8 && -e /usr/lib/libglib-2.0.so && ! -e /usr/lib/libwireplumber-0.5.so ]]' || fail 'Meson/PipeWire/Lua/GLib prerequisites are missing or WirePlumber already exists.'
/home/yrslf/alpbahOS/scripts/build-blfs-wireplumber.sh:44: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-wireplumber.sh:105: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-wpa-supplicant.sh:21: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c \
/home/yrslf/alpbahOS/scripts/build-blfs-wpa-supplicant.sh:31: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
/home/yrslf/alpbahOS/scripts/build-blfs-x11-d34.sh:48: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-x11-d34.sh:143: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH=/usr/lib LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-xkb-d34.sh:57: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-blfs-xkb-d34.sh:99: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-blfs-xkb-runtime.sh:16: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-blfs-xkb-runtime.sh:17: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-blfs-xkb-runtime.sh:18: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-xkb-runtime.sh:19: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-xkb-runtime.sh:20: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-blfs-xkb-runtime.sh:64:         rm -f "$temp_download"
/home/yrslf/alpbahOS/scripts/build-blfs-xkb-runtime.sh:71:     if ! sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-blfs-xkb-runtime.sh:139:     if ! sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-acl-ch8.sh:26: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-acl-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-acl-ch8.sh:28: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-acl-ch8.sh:29: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-acl-ch8.sh:72: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-attr-ch8.sh:30: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-attr-ch8.sh:31: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-attr-ch8.sh:32: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-attr-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-attr-ch8.sh:85: sudo -n chroot "$LFS" /usr/bin/ld --version | head -n 1 | grep -F 'GNU Binutils) 2.45' >/dev/null || fail 'The Chapter 8 Binutils linker is not installed.'
/home/yrslf/alpbahOS/scripts/build-lfs-attr-ch8.sh:86: sudo -n chroot "$LFS" /usr/bin/gcc --version | head -n 1 | grep -F '15.2.0' >/dev/null || fail 'The LFS GCC toolchain is not installed.'
/home/yrslf/alpbahOS/scripts/build-lfs-attr-ch8.sh:105: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-autoconf-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-autoconf-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-autoconf-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-autoconf-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-autoconf-ch8.sh:77: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-automake-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-automake-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-automake-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-automake-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-automake-ch8.sh:77: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-bash-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-bash-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-bash-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-bash-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-bash-ch8.sh:78: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-bc-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-bc-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-bc-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-bc-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-bc-ch8.sh:44: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-binutils-ch8.sh:25: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-binutils-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-binutils-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-binutils-ch8.sh:28: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-binutils-ch8.sh:43: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-binutils-pass2.sh:58: rm -fv "$LFS/usr/lib"/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
/home/yrslf/alpbahOS/scripts/build-lfs-bison-ch7.sh:13: [[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
/home/yrslf/alpbahOS/scripts/build-lfs-bison-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-bison-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-bison-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-bison-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-bison-ch8.sh:77: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-bzip2-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-bzip2-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-bzip2-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-bzip2-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-bzip2-ch8.sh:47: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-bzip2-ch8.sh:74:         rm -fv /usr/lib/libbz2.a
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch6.sh:24: [[ ! -e "$SOURCE_DIR" && ! -e "$LFS/usr/bin/ls" && ! -e "$LFS/usr/bin/chroot" && ! -e "$LFS/usr/sbin/chroot" ]] || fail 'Refusing to reuse an extracted Coreutils tree or overwrite existing target outputs.'
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch6.sh:51: mv -v "$LFS/usr/bin/chroot" "$LFS/usr/sbin"
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch6.sh:53: mv -v "$LFS/usr/share/man/man1/chroot.1" "$LFS/usr/share/man/man8/chroot.8"
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch6.sh:54: sed -i 's/"1"/"8"/' "$LFS/usr/share/man/man8/chroot.8"
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch6.sh:56: printf 'Installed LFS Chapter 6 Coreutils and relocated chroot into %s/usr\n' "$LFS"
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:57:         '[' b2sum base32 base64 basename basenc cat chcon chgrp chmod chown chroot cksum comm cp csplit cut
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:60:         pathchk pinky pr printenv printf ptx pwd readlink realpath rm rmdir runcon seq sha1sum sha224sum sha256sum
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:69:     for path in usr/bin/chroot usr/sbin/chroot usr/share/man/man8/chroot.8 usr/share/info/coreutils.info \
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:88: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:111: mv -v /usr/bin/chroot /usr/sbin
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:113: mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:114: sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:117: [[ "$(/usr/sbin/chroot --version | sed -n '1p')" == 'chroot (GNU coreutils) 9.7' ]]
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:118: for command in cat chmod chown cp date df du env install ln ls mkdir mv rm sort stat test; do
/home/yrslf/alpbahOS/scripts/build-lfs-coreutils-ch8.sh:122: [[ -f /usr/share/info/coreutils.info && -f /usr/share/man/man8/chroot.8 ]]
/home/yrslf/alpbahOS/scripts/build-lfs-dbus-ch8.sh:36: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-dbus-ch8.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-dbus-ch8.sh:38: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-dbus-ch8.sh:39: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-dbus-ch8.sh:65: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-dbus-ch8.sh:131: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-dejagnu-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-dejagnu-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-dejagnu-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-dejagnu-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-dejagnu-ch8.sh:43: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-diffutils-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-diffutils-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-diffutils-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-diffutils-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-diffutils-ch8.sh:77: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-e2fsprogs-ch8.sh:37: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-e2fsprogs-ch8.sh:38: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-e2fsprogs-ch8.sh:39: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-e2fsprogs-ch8.sh:40: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-e2fsprogs-ch8.sh:66: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-e2fsprogs-ch8.sh:147: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-expat-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-expat-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-expat-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-expat-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-expat-ch8.sh:77: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-expect-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-expect-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-expect-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-expect-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-expect-ch8.sh:45: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-file-ch6.sh:59: rm -v "$LFS/usr/lib/libmagic.la"
/home/yrslf/alpbahOS/scripts/build-lfs-file-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-file-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-file-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-file-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-file-ch8.sh:43: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-findutils-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-findutils-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-findutils-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-findutils-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-findutils-ch8.sh:78: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-flex-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-flex-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-flex-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-flex-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-flex-ch8.sh:44: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-flit-core-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-flit-core-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-flit-core-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-flit-core-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-flit-core-ch8.sh:71: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-gawk-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-gawk-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gawk-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gawk-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gawk-ch8.sh:75: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-gawk-ch8.sh:93: rm -f /usr/bin/gawk-5.3.2
/home/yrslf/alpbahOS/scripts/build-lfs-gcc-ch8.sh:35: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-gcc-ch8.sh:36: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gcc-ch8.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gcc-ch8.sh:38: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gcc-ch8.sh:69: sudo -n chroot "$LFS" /usr/bin/gcc --version | head -n 1 | grep -F '15.2.0' >/dev/null || fail 'GCC Pass 2 version check failed.'
/home/yrslf/alpbahOS/scripts/build-lfs-gcc-ch8.sh:70: sudo -n chroot "$LFS" /usr/bin/ld --version | head -n 1 | grep -F 'GNU Binutils) 2.45' >/dev/null || fail 'Chapter 8 Binutils is not active.'
/home/yrslf/alpbahOS/scripts/build-lfs-gcc-ch8.sh:87: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-gdbm-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-gdbm-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gdbm-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gdbm-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gdbm-ch8.sh:80: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-gettext-ch7.sh:13: [[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
/home/yrslf/alpbahOS/scripts/build-lfs-gettext-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-gettext-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gettext-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gettext-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gettext-ch8.sh:83: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-glibc-ch8.sh:14: [[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
/home/yrslf/alpbahOS/scripts/build-lfs-glibc-install-ch8.sh:11: [[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
/home/yrslf/alpbahOS/scripts/build-lfs-gmp-ch8.sh:29: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-gmp-ch8.sh:30: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gmp-ch8.sh:31: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gmp-ch8.sh:32: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gmp-ch8.sh:41: sudo -n chroot "$LFS" /usr/bin/ld --version | head -n 1 | grep -F 'GNU Binutils) 2.45' >/dev/null || fail 'The Chapter 8 Binutils linker is not installed.'
/home/yrslf/alpbahOS/scripts/build-lfs-gmp-ch8.sh:57: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-gperf-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-gperf-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gperf-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gperf-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gperf-ch8.sh:77: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-grep-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-grep-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-grep-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-grep-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-grep-ch8.sh:76: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-groff-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-groff-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-groff-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-groff-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-groff-ch8.sh:87: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-grub-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-grub-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-grub-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-grub-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-grub-ch8.sh:96: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-gzip-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-gzip-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gzip-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gzip-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-gzip-ch8.sh:84: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-iana-etc-ch8.sh:13: [[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
/home/yrslf/alpbahOS/scripts/build-lfs-inetutils-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-inetutils-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-inetutils-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-inetutils-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-inetutils-ch8.sh:80: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-intltool-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-intltool-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-intltool-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-intltool-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-intltool-ch8.sh:73: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-iproute2-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-iproute2-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-iproute2-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-iproute2-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-iproute2-ch8.sh:87: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-jinja2-ch8.sh:34: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-jinja2-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-jinja2-ch8.sh:36: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-jinja2-ch8.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-jinja2-ch8.sh:86: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-kbd-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-kbd-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-kbd-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-kbd-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-kbd-ch8.sh:51: printf 'Kbd tests require valgrind and are documented to fail in the chroot; they are skipped.\n'
/home/yrslf/alpbahOS/scripts/build-lfs-kbd-ch8.sh:95: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-kernel-ch10.sh:33: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/build-lfs-kernel-ch10.sh:34: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-kernel-ch10.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-kernel-ch10.sh:36: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-kernel-ch10.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-kernel-ch10.sh:71: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-lfs-kernel-ch10.sh:79: sudo -n chroot --userspec="$BUILD_UID:$BUILD_GID" "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-kernel-ch10.sh:164: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-kernel-ch10.sh:189: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-lfs-kmod-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-kmod-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-kmod-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-kmod-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-kmod-ch8.sh:86: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-less-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-less-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-less-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-less-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-less-ch8.sh:76: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-libcap-ch8.sh:26: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-libcap-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libcap-ch8.sh:28: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libcap-ch8.sh:29: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libcap-ch8.sh:76: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-libelf-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-libelf-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libelf-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libelf-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libelf-ch8.sh:51: printf 'The LFS rm /usr/lib/libelf.a cleanup is omitted to preserve the static archive.\n'
/home/yrslf/alpbahOS/scripts/build-lfs-libelf-ch8.sh:77: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-libffi-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-libffi-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libffi-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libffi-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libffi-ch8.sh:77: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-libpipeline-ch8.sh:34: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-libpipeline-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libpipeline-ch8.sh:36: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libpipeline-ch8.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libpipeline-ch8.sh:99: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-libstdcxx-pass1.sh:56:     [[ ! -e "$LFS/usr/lib/$archive" ]] || rm -v "$LFS/usr/lib/$archive"
/home/yrslf/alpbahOS/scripts/build-lfs-libtool-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-libtool-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libtool-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libtool-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libtool-ch8.sh:50: printf 'The LFS page lists make check as a test-suite command; it is not being run. The cleanup rm for libltdl.a is also skipped to preserve the installed file.\n'
/home/yrslf/alpbahOS/scripts/build-lfs-libtool-ch8.sh:80: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-libxcrypt-ch8.sh:26: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-libxcrypt-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libxcrypt-ch8.sh:28: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libxcrypt-ch8.sh:29: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-libxcrypt-ch8.sh:72: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-linux-pam-ch8.sh:51: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-lfs-linux-pam-ch8.sh:115: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/build-lfs-lz4-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-lz4-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-lz4-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-lz4-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-lz4-ch8.sh:44: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-m4-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-m4-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-m4-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-m4-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-m4-ch8.sh:42: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-make-ch8.sh:34: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-make-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-make-ch8.sh:36: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-make-ch8.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-make-ch8.sh:89: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-man-db-ch8.sh:36: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-man-db-ch8.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-man-db-ch8.sh:38: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-man-db-ch8.sh:39: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-man-db-ch8.sh:65: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-man-db-ch8.sh:144: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-man-pages-ch8.sh:13: [[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
/home/yrslf/alpbahOS/scripts/build-lfs-man-pages-ch8.sh:32: rm -v man3/crypt*
/home/yrslf/alpbahOS/scripts/build-lfs-markupsafe-ch8.sh:34: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-markupsafe-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-markupsafe-ch8.sh:36: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-markupsafe-ch8.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-markupsafe-ch8.sh:88: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-meson-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-meson-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-meson-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-meson-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-meson-ch8.sh:75: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-mpc-ch8.sh:29: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-mpc-ch8.sh:30: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-mpc-ch8.sh:31: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-mpc-ch8.sh:32: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-mpc-ch8.sh:80: sudo -n chroot "$LFS" /usr/bin/ld --version | head -n 1 | grep -F 'GNU Binutils) 2.45' >/dev/null || fail 'The Chapter 8 Binutils linker is not installed.'
/home/yrslf/alpbahOS/scripts/build-lfs-mpc-ch8.sh:81: sudo -n chroot "$LFS" /usr/bin/gcc --version | head -n 1 | grep -F '15.2.0' >/dev/null || fail 'The LFS GCC toolchain is not installed.'
/home/yrslf/alpbahOS/scripts/build-lfs-mpc-ch8.sh:100: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-mpfr-ch8.sh:29: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-mpfr-ch8.sh:30: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-mpfr-ch8.sh:31: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-mpfr-ch8.sh:32: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-mpfr-ch8.sh:83: sudo -n chroot "$LFS" /usr/bin/ld --version | head -n 1 | grep -F 'GNU Binutils) 2.45' >/dev/null || fail 'The Chapter 8 Binutils linker is not installed.'
/home/yrslf/alpbahOS/scripts/build-lfs-mpfr-ch8.sh:84: sudo -n chroot "$LFS" /usr/bin/gcc --version | head -n 1 | grep -F '15.2.0' >/dev/null || fail 'The LFS GCC toolchain is not installed.'
/home/yrslf/alpbahOS/scripts/build-lfs-mpfr-ch8.sh:103: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-ncurses-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-ncurses-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-ncurses-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-ncurses-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-ncurses-ch8.sh:86: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-ninja-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-ninja-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-ninja-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-ninja-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-ninja-ch8.sh:73: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-openssl-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-openssl-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-openssl-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-openssl-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-openssl-ch8.sh:81: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-packaging-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-packaging-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-packaging-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-packaging-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-packaging-ch8.sh:71: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-patch-ch8.sh:34: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-patch-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-patch-ch8.sh:36: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-patch-ch8.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-patch-ch8.sh:84: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-perl-ch7.sh:13: [[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
/home/yrslf/alpbahOS/scripts/build-lfs-perl-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-perl-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-perl-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-perl-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-perl-ch8.sh:78: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-pkgconf-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-pkgconf-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-pkgconf-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-pkgconf-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-pkgconf-ch8.sh:44: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-procps-ng-ch8.sh:36: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-procps-ng-ch8.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-procps-ng-ch8.sh:38: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-procps-ng-ch8.sh:39: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-procps-ng-ch8.sh:63: printf 'Using the existing source archive without checksum work. The test suite is skipped per user preference and has known host/chroot-sensitive cases.\n'
/home/yrslf/alpbahOS/scripts/build-lfs-procps-ng-ch8.sh:65: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-procps-ng-ch8.sh:136: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-psmisc-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-psmisc-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-psmisc-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-psmisc-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-psmisc-ch8.sh:75: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-python3-ch7.sh:13: [[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
/home/yrslf/alpbahOS/scripts/build-lfs-python3-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-python3-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-python3-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-python3-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-python3-ch8.sh:83: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-readline-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-readline-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-readline-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-readline-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-readline-ch8.sh:44: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-sed-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-sed-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-sed-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-sed-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-sed-ch8.sh:71: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-setuptools-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-setuptools-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-setuptools-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-setuptools-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-setuptools-ch8.sh:73: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-shadow-ch8.sh:31: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-shadow-ch8.sh:32: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-shadow-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-shadow-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-shadow-ch8.sh:82: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-systemd-ch8.sh:37: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-systemd-ch8.sh:38: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-systemd-ch8.sh:39: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-systemd-ch8.sh:40: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-systemd-ch8.sh:43: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c '
/home/yrslf/alpbahOS/scripts/build-lfs-systemd-ch8.sh:68: printf 'Using existing source archives without checksum work. Systemd package tests are skipped per user preference and the LFS page notes known chroot/kernel failures.\n'
/home/yrslf/alpbahOS/scripts/build-lfs-systemd-ch8.sh:70: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-systemd-ch8.sh:189: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-tar-ch8.sh:34: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-tar-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-tar-ch8.sh:36: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-tar-ch8.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-tar-ch8.sh:87: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-tcl-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-tcl-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-tcl-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-tcl-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-tcl-ch8.sh:45: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-texinfo-ch7.sh:13: [[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
/home/yrslf/alpbahOS/scripts/build-lfs-texinfo-ch8.sh:34: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-texinfo-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-texinfo-ch8.sh:36: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-texinfo-ch8.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-texinfo-ch8.sh:98: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-util-linux-ch7.sh:13: [[ "$(id -u)" == 0 ]] || fail 'Run as root inside the LFS chroot.'
/home/yrslf/alpbahOS/scripts/build-lfs-util-linux-ch7.sh:16: [[ ! -e /usr/bin/mount ]] || fail 'Refusing to overwrite an existing /usr/bin/mount.'
/home/yrslf/alpbahOS/scripts/build-lfs-util-linux-ch8.sh:36: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-util-linux-ch8.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-util-linux-ch8.sh:38: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-util-linux-ch8.sh:39: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-util-linux-ch8.sh:65: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-util-linux-ch8.sh:150: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-util-linux-ch8.sh:160: for command in mount umount lsblk blkid fdisk sfdisk hwclock findmnt \
/home/yrslf/alpbahOS/scripts/build-lfs-util-linux-ch8.sh:164: [[ "$(mount --version | sed -n '1p')" == *'2.41.1'* ]]
/home/yrslf/alpbahOS/scripts/build-lfs-util-linux-ch8.sh:173: readelf -h /usr/bin/mount | grep -F 'Advanced Micro Devices X86-64'
/home/yrslf/alpbahOS/scripts/build-lfs-util-linux-ch8.sh:174: ldd /usr/bin/mount | grep -E 'libc[.]so[.]6.*[/]usr/lib/'
/home/yrslf/alpbahOS/scripts/build-lfs-vim-ch8.sh:34: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-vim-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-vim-ch8.sh:36: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-vim-ch8.sh:37: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-vim-ch8.sh:100: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-wheel-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-wheel-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-wheel-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-wheel-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-wheel-ch8.sh:71: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-xml-parser-ch8.sh:32: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-xml-parser-ch8.sh:33: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-xml-parser-ch8.sh:34: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-xml-parser-ch8.sh:35: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-xml-parser-ch8.sh:77: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-xz-ch6.sh:51: rm -v "$LFS/usr/lib/liblzma.la"
/home/yrslf/alpbahOS/scripts/build-lfs-xz-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-xz-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-xz-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-xz-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-xz-ch8.sh:31: [[ "$(sudo -n chroot "$LFS" /usr/bin/xz --version | head -1)" == 'xz (XZ Utils) 5.8.1' ]] || fail 'The existing bootstrap Xz is not version 5.8.1.'
/home/yrslf/alpbahOS/scripts/build-lfs-xz-ch8.sh:44: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-zlib-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-zlib-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-zlib-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-zlib-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-zlib-ch8.sh:44: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-zlib-ch8.sh:59:         rm -fv /usr/lib/libz.a
/home/yrslf/alpbahOS/scripts/build-lfs-zstd-ch8.sh:24: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/build-lfs-zstd-ch8.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-zstd-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-zstd-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/build-lfs-zstd-ch8.sh:44: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-lfs-zstd-ch8.sh:58:         rm -fv /usr/lib/libzstd.a
/home/yrslf/alpbahOS/scripts/build-m04-acl-stage.sh:39:   for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
/home/yrslf/alpbahOS/scripts/build-m04-acl-stage.sh:130: if setfacl -m u:1001:r-- "$acl_probe" && getfacl -ncp "$acl_probe" | grep -Fq 'user:1001:r--'; then :; else rm -f "$acl_probe"; echo 'filesystem ACL probe failed' >&2; exit 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-acl-stage.sh:131: rm -f "$acl_probe"
/home/yrslf/alpbahOS/scripts/build-m04-acl-stage.sh:141: bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
/home/yrslf/alpbahOS/scripts/build-m04-acl-stage.sh:145: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 TMPDIR="$BUILD_CHROOT/tmp" BUILD_CHROOT="$BUILD_CHROOT" ACL_TEST_PARSER_CHROOT="$ACL_TEST_PARSER_CHROOT" CPPFLAGS="-I$ATTR_STAGE_CHROOT/usr/include" LDFLAGS="-L$ATTR_STAGE_CHROOT/usr/lib" LD_LIBRARY_PATH="$ATTR_STAGE_CHROOT/usr/lib" /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS/scripts/build-m04-acl-stage.sh:154: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c "cd '$BUILD_CHROOT' && make DESTDIR='$STAGE_CHROOT' install"
/home/yrslf/alpbahOS/scripts/build-m04-acl-stage.sh:160: if chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" /usr/bin/ldd "$STAGE_CHROOT/usr/lib/libacl.so.1" > "$DEPENDENCY_RESOLUTION" 2>&1; then :; else cat "$DEPENDENCY_RESOLUTION" >&2; exit 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-acl-stage.sh:163: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" LD_DEBUG=libs /bin/bash --noprofile --norc -c "
/home/yrslf/alpbahOS/scripts/build-m04-acl-stage.sh:168: rm -f "$smoke"
/home/yrslf/alpbahOS/scripts/build-m04-attr-stage.sh:30:   for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
/home/yrslf/alpbahOS/scripts/build-m04-attr-stage.sh:77: if setfacl -m u:1001:r-- "$acl_probe" && getfacl -cpn "$acl_probe" | grep -Fq 'user:1001:r--'; then :; else rm -f "$acl_probe"; echo 'filesystem ACL probe failed' >&2; exit 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-attr-stage.sh:78: rm -f "$acl_probe"
/home/yrslf/alpbahOS/scripts/build-m04-attr-stage.sh:84: bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
/home/yrslf/alpbahOS/scripts/build-m04-attr-stage.sh:87: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 TMPDIR="$BUILD_CHROOT/tmp" /bin/bash --noprofile --norc -c "
/home/yrslf/alpbahOS/scripts/build-m04-attr-stage.sh:94: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c "cd '$BUILD_CHROOT' && make DESTDIR='$STAGE_CHROOT' install"
/home/yrslf/alpbahOS/scripts/build-m04-attr-stage.sh:99: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" /bin/bash --noprofile --norc -c "
/home/yrslf/alpbahOS/scripts/build-m04-attr-stage.sh:103: rm -f "$probe"
/home/yrslf/alpbahOS/scripts/build-m04-bash-stage.sh:5: # /mnt/lfs chroot, then install it into an isolated DESTDIR for comparison.
/home/yrslf/alpbahOS/scripts/build-m04-bash-stage.sh:26:         umount "${MOUNTS[$i]}"
/home/yrslf/alpbahOS/scripts/build-m04-bash-stage.sh:81:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m04-bash-stage.sh:84:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-bash-stage.sh:93: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-bash-stage.sh:104: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-bash-stage.sh:108: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-bash-stage.sh:114: rm -f "$STAGE_HOST/usr/share/info/dir"
/home/yrslf/alpbahOS/scripts/build-m04-bash-stage.sh:118: [[ $(chroot "$LFS" "$STAGE_CHROOT/usr/bin/bash" --noprofile --norc -c 'printf "%s\n" "$((20 + 22))"') == 42 ]]
/home/yrslf/alpbahOS/scripts/build-m04-bash-stage.sh:119: chroot "$LFS" "$STAGE_CHROOT/usr/bin/bash" --version | head -n 1
/home/yrslf/alpbahOS/scripts/build-m04-bc-stage.sh:54:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS/scripts/build-m04-bc-stage.sh:93:     bc_output=$(printf '2+2\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/bc")
/home/yrslf/alpbahOS/scripts/build-m04-bc-stage.sh:95:     dc_output=$(printf '5 2 + p\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/dc")
/home/yrslf/alpbahOS/scripts/build-m04-bc-stage.sh:120:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m04-bc-stage.sh:123:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-bc-stage.sh:132: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-bc-stage.sh:141: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-bc-stage.sh:144: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS/scripts/build-m04-bc-stage.sh:148: bc_output=$(printf '2+2\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/bc")
/home/yrslf/alpbahOS/scripts/build-m04-bc-stage.sh:150: dc_output=$(printf '5 2 + p\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/dc")
/home/yrslf/alpbahOS/scripts/build-m04-binutils-stage.sh:37:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS/scripts/build-m04-binutils-stage.sh:103:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m04-binutils-stage.sh:106:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-binutils-stage.sh:118: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-binutils-stage.sh:138: chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-binutils-stage.sh:174: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-binutils-stage.sh:178:         rm -rfv /tmp/alp-m04-binutils-stage-r1/usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
/home/yrslf/alpbahOS/scripts/build-m04-binutils-stage.sh:185:     tool_output=$(chroot "$LFS" /usr/bin/env LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" \
/home/yrslf/alpbahOS/scripts/build-m04-dejagnu-stage.sh:44:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS/scripts/build-m04-dejagnu-stage.sh:102:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m04-dejagnu-stage.sh:105:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-dejagnu-stage.sh:114: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-dejagnu-stage.sh:127: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-dejagnu-stage.sh:131: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS/scripts/build-m04-dejagnu-stage.sh:144: DEJAGNU_VERSION=$(chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-expat-stage.sh:23:     rm -f "$FIXTURE"
/home/yrslf/alpbahOS/scripts/build-m04-expat-stage.sh:24:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS/scripts/build-m04-expat-stage.sh:60:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-expat-stage.sh:61:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-expat-stage.sh:70: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-expat-stage.sh:78: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-expat-stage.sh:81: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-expat-stage.sh:89: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-expect-stage.sh:34:         umount "${MOUNTS[$i]}"
/home/yrslf/alpbahOS/scripts/build-m04-expect-stage.sh:100:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m04-expect-stage.sh:103:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-expect-stage.sh:114: PTY_OUTPUT=$(chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-expect-stage.sh:121: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-expect-stage.sh:136: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-expect-stage.sh:140: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-expect-stage.sh:151: EXPECT_VERSION=$(chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-flex-stage.sh:50:     version=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/flex" --version)
/home/yrslf/alpbahOS/scripts/build-m04-flex-stage.sh:52:     chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-flex-stage.sh:70:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS/scripts/build-m04-flex-stage.sh:139:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m04-flex-stage.sh:142:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-flex-stage.sh:151: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-flex-stage.sh:160: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-flex-stage.sh:163: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS/scripts/build-m04-flex-stage.sh:165: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-gcc-stage.sh:71:     case "$status" in 0|1) ;; *) echo "findmnt failed during NBD mount check: $output" >&2; return 1 ;; esac
/home/yrslf/alpbahOS/scripts/build-m04-gcc-stage.sh:100:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
/home/yrslf/alpbahOS/scripts/build-m04-gcc-stage.sh:216: bind_mount() { local src=$1 dst=$2; mountpoint -q "$dst" && { echo "pre-existing mount: $dst" >&2; return 1; }; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
/home/yrslf/alpbahOS/scripts/build-m04-gcc-stage.sh:221: chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-gcc-stage.sh:247:       chroot --userspec=101:101 --groups=101 / /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-gcc-stage.sh:269: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-gcc-stage.sh:297: chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-gdbm-stage.sh:22:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS/scripts/build-m04-gdbm-stage.sh:55:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-gdbm-stage.sh:56:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-gdbm-stage.sh:65: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-gdbm-stage.sh:73: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-gdbm-stage.sh:76: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-gdbm-stage.sh:81: chroot "$LFS" "$STAGE_CHROOT/usr/bin/gdbm_dump" --version | head -n 1
/home/yrslf/alpbahOS/scripts/build-m04-gdbm-stage.sh:82: chroot "$LFS" "$STAGE_CHROOT/usr/bin/gdbm_load" --version | head -n 1
/home/yrslf/alpbahOS/scripts/build-m04-gmp-stage.sh:39:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS/scripts/build-m04-gmp-stage.sh:105:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m04-gmp-stage.sh:108:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-gmp-stage.sh:120: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-gmp-stage.sh:143: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-gmp-stage.sh:165: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-gperf-stage.sh:22:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS/scripts/build-m04-gperf-stage.sh:55:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-gperf-stage.sh:56:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-gperf-stage.sh:65: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-gperf-stage.sh:73: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-gperf-stage.sh:76: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-gperf-stage.sh:81: rm -f "$STAGE_HOST/usr/share/info/dir"
/home/yrslf/alpbahOS/scripts/build-m04-gperf-stage.sh:82: chroot "$LFS" "$STAGE_CHROOT/usr/bin/gperf" --version | head -n 1
/home/yrslf/alpbahOS/scripts/build-m04-iana-etc-stage.sh:40:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS/scripts/build-m04-iana-etc-stage.sh:119:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m04-iana-etc-stage.sh:122:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-iana-etc-stage.sh:131: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS/scripts/build-m04-inetutils-stage.sh:22:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS/scripts/build-m04-inetutils-stage.sh:58:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-inetutils-stage.sh:59:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-inetutils-stage.sh:68: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-inetutils-stage.sh:79: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-inetutils-stage.sh:82: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-inetutils-stage.sh:88: chroot "$LFS" "$STAGE_CHROOT/usr/bin/ftp" --version | head -n 1
/home/yrslf/alpbahOS/scripts/build-m04-less-stage.sh:22:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS/scripts/build-m04-less-stage.sh:58:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-less-stage.sh:59:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-less-stage.sh:68: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-less-stage.sh:76: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-less-stage.sh:79: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-less-stage.sh:85: chroot "$LFS" "$STAGE_CHROOT/usr/bin/less" --version | head -n 1
/home/yrslf/alpbahOS/scripts/build-m04-libcap-stage.sh:28:   for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
/home/yrslf/alpbahOS/scripts/build-m04-libcap-stage.sh:73:     [[ $findmnt_status -eq 1 ]] || { echo "Cannot verify nbd0 mount source (findmnt status $findmnt_status)" >&2; return 1; }
/home/yrslf/alpbahOS/scripts/build-m04-libcap-stage.sh:103: bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
/home/yrslf/alpbahOS/scripts/build-m04-libcap-stage.sh:106: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 TMPDIR=/build/libcap-2.76-m04-r1/tmp /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS/scripts/build-m04-libcap-stage.sh:112: # target as root inside the chroot after the unprivileged build.
/home/yrslf/alpbahOS/scripts/build-m04-libcap-stage.sh:113: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c 'cd /build/libcap-2.76-m04-r1 && make test'
/home/yrslf/alpbahOS/scripts/build-m04-libcap-stage.sh:114: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c 'cd /build/libcap-2.76-m04-r1 && make DESTDIR=/tmp/alp-m04-libcap-stage-r1 prefix=/usr lib=lib install'
/home/yrslf/alpbahOS/scripts/build-m04-libcap-stage.sh:123: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS/scripts/build-m04-libtool-stage.sh:22:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS/scripts/build-m04-libtool-stage.sh:55:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-libtool-stage.sh:56:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-libtool-stage.sh:65: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-libtool-stage.sh:73: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-libtool-stage.sh:76: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-libtool-stage.sh:81: rm -f "$STAGE_HOST/usr/lib/libltdl.a"
/home/yrslf/alpbahOS/scripts/build-m04-libtool-stage.sh:82: chroot "$LFS" "$STAGE_CHROOT/usr/bin/libtool" --version | head -n 1
/home/yrslf/alpbahOS/scripts/build-m04-libtool-stage.sh:83: chroot "$LFS" "$STAGE_CHROOT/usr/bin/libtoolize" --version | head -n 1
/home/yrslf/alpbahOS/scripts/build-m04-libxcrypt-stage.sh:68:     [[ $status -eq 1 ]] || { echo "Cannot verify nbd0 mount source (findmnt status $status)" >&2; return 1; }
/home/yrslf/alpbahOS/scripts/build-m04-libxcrypt-stage.sh:84:     umount "${MOUNTS[$i]}" || { echo "CLEANUP_FAILED: cannot unmount ${MOUNTS[$i]}" >&2; status=1; }
/home/yrslf/alpbahOS/scripts/build-m04-libxcrypt-stage.sh:134:   if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-libxcrypt-stage.sh:135:   mount --bind "$src" "$dst"
/home/yrslf/alpbahOS/scripts/build-m04-libxcrypt-stage.sh:145: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 TMPDIR=/build/libxcrypt-4.4.38-m04-r1/tmp /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS/scripts/build-m04-libxcrypt-stage.sh:159: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c 'set -Eeuo pipefail; cd /build/libxcrypt-4.4.38-m04-r1; make DESTDIR=/tmp/alp-m04-libxcrypt-stage-r1 install'
/home/yrslf/alpbahOS/scripts/build-m04-libxcrypt-stage.sh:173: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS/scripts/build-m04-libxcrypt-stage.sh:183: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS/scripts/build-m04-man-pages-stage.sh:40:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS/scripts/build-m04-man-pages-stage.sh:86:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m04-man-pages-stage.sh:89:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-man-pages-stage.sh:98: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS/scripts/build-m04-man-pages-stage.sh:102:         rm -v man3/crypt*
/home/yrslf/alpbahOS/scripts/build-m04-mpc-stage.sh:43:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
/home/yrslf/alpbahOS/scripts/build-m04-mpc-stage.sh:114: bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
/home/yrslf/alpbahOS/scripts/build-m04-mpc-stage.sh:118: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-mpc-stage.sh:135: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS/scripts/build-m04-mpc-stage.sh:145: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS/scripts/build-m04-mpfr-stage.sh:40:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS/scripts/build-m04-mpfr-stage.sh:138:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m04-mpfr-stage.sh:141:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-mpfr-stage.sh:155: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-mpfr-stage.sh:185: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-mpfr-stage.sh:210: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-ncurses-stage.sh:94:     umount "${MOUNTS[$i]}" || { echo "CLEANUP_FAILED: cannot unmount ${MOUNTS[$i]}" >&2; status=1; }
/home/yrslf/alpbahOS/scripts/build-m04-ncurses-stage.sh:150:   if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-ncurses-stage.sh:151:   mount --bind "$src" "$dst"
/home/yrslf/alpbahOS/scripts/build-m04-ncurses-stage.sh:161: # chroot. The active-root library replacement and cp into / from the book are
/home/yrslf/alpbahOS/scripts/build-m04-ncurses-stage.sh:163: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-ncurses-stage.sh:186: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-ncurses-stage.sh:198: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-ncurses-stage.sh:235: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-ncurses-stage.sh:247: chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-perl-stage.sh:22:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS/scripts/build-m04-perl-stage.sh:49:     chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-perl-stage.sh:78:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-perl-stage.sh:79:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-perl-stage.sh:88: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-perl-stage.sh:110: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-perl-stage.sh:113: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-perl-stage.sh:119: chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-pkgconf-stage.sh:35:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS/scripts/build-m04-pkgconf-stage.sh:97:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m04-pkgconf-stage.sh:100:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-pkgconf-stage.sh:111: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-pkgconf-stage.sh:118: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-pkgconf-stage.sh:132: STAGED_VERSION=$(chroot "$LFS" /usr/bin/env \
/home/yrslf/alpbahOS/scripts/build-m04-pkgconf-stage.sh:136: [[ $(chroot "$LFS" /usr/bin/env LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" \
/home/yrslf/alpbahOS/scripts/build-m04-pkgconf-stage.sh:138: chroot "$LFS" /usr/bin/env LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" \
/home/yrslf/alpbahOS/scripts/build-m04-psmisc-stage.sh:73:       [[ $status -eq 1 ]] || { echo "Cannot check mount for $device (findmnt status $status)" >&2; return 1; }
/home/yrslf/alpbahOS/scripts/build-m04-psmisc-stage.sh:174:     umount "${MOUNTS[$i]}" || { echo "CLEANUP_FAILED: cannot unmount ${MOUNTS[$i]}" >&2; status=1; }
/home/yrslf/alpbahOS/scripts/build-m04-psmisc-stage.sh:219:   if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-psmisc-stage.sh:220:   mount --bind "$src" "$dst"
/home/yrslf/alpbahOS/scripts/build-m04-psmisc-stage.sh:229: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-psmisc-stage.sh:237: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS/scripts/build-m04-psmisc-stage.sh:243: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS/scripts/build-m04-psmisc-stage.sh:252: pstree_version=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/pstree" --version 2>&1 | head -n 1)
/home/yrslf/alpbahOS/scripts/build-m04-psmisc-stage.sh:254: pstree_smoke=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/pstree" -p 1)
/home/yrslf/alpbahOS/scripts/build-m04-psmisc-stage.sh:256: fuser_version=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/fuser" --version 2>&1 | head -n 1)
/home/yrslf/alpbahOS/scripts/build-m04-sed-stage.sh:5: # inside /mnt/lfs chroot. Do not run until the M04 GCC stage is complete.
/home/yrslf/alpbahOS/scripts/build-m04-sed-stage.sh:159:     umount "${MOUNTS[$i]}" || { echo "CLEANUP_FAILED: cannot unmount ${MOUNTS[$i]}" >&2; status=1; }
/home/yrslf/alpbahOS/scripts/build-m04-sed-stage.sh:210:   if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-sed-stage.sh:211:   mount --bind "$src" "$dst"
/home/yrslf/alpbahOS/scripts/build-m04-sed-stage.sh:222: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-sed-stage.sh:232: chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-sed-stage.sh:239: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS/scripts/build-m04-sed-stage.sh:249: smoke_output=$(printf 'alp staging smoke\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/sed" 's/staging/stage/; s/smoke/ok/')
/home/yrslf/alpbahOS/scripts/build-m04-sed-stage.sh:251: version_output=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/sed" --version | head -n 1)
/home/yrslf/alpbahOS/scripts/build-m04-shadow-stage.sh:74:     [[ $status -eq 1 ]] || { echo "Cannot verify nbd0 mount source (findmnt status $status)" >&2; return 1; }
/home/yrslf/alpbahOS/scripts/build-m04-shadow-stage.sh:116:     umount "${MOUNTS[$i]}" || { echo "CLEANUP_FAILED: cannot unmount ${MOUNTS[$i]}" >&2; status=1; }
/home/yrslf/alpbahOS/scripts/build-m04-shadow-stage.sh:203:   if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi
/home/yrslf/alpbahOS/scripts/build-m04-shadow-stage.sh:204:   mount --bind "$src" "$dst"
/home/yrslf/alpbahOS/scripts/build-m04-shadow-stage.sh:215: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-shadow-stage.sh:238: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-shadow-stage.sh:266: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS/scripts/build-m04-tcl-stage.sh:54:     output=$(printf 'puts [expr {20 + 22}]\n' | chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-tcl-stage.sh:71:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS/scripts/build-m04-tcl-stage.sh:140:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m04-tcl-stage.sh:143:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m04-tcl-stage.sh:152: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-tcl-stage.sh:174: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m04-tcl-stage.sh:178: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS/scripts/build-m07-vgem-kernel.sh:6: # build inside the /mnt/lfs chroot, and install only after a successful build.
/home/yrslf/alpbahOS/scripts/build-m07-vgem-kernel.sh:22:         if ! umount -R -- "${MOUNTED[$i]}"; then
/home/yrslf/alpbahOS/scripts/build-m07-vgem-kernel.sh:43: if pgrep -x make >/dev/null || pgrep -x ninja >/dev/null || pgrep -x chroot >/dev/null; then
/home/yrslf/alpbahOS/scripts/build-m07-vgem-kernel.sh:44:     echo 'Another build/chroot process is active; refusing to proceed.' >&2
/home/yrslf/alpbahOS/scripts/build-m07-vgem-kernel.sh:52:     echo 'An existing mount is present below /mnt/lfs; refusing to alter it.' >&2
/home/yrslf/alpbahOS/scripts/build-m07-vgem-kernel.sh:67:         echo "Unexpected pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m07-vgem-kernel.sh:70:     mount --rbind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m07-vgem-kernel.sh:71:     mount --make-rslave "$target"
/home/yrslf/alpbahOS/scripts/build-m07-vgem-kernel.sh:81:     chroot --userspec=1001:1001 "$ROOTFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m07-vgem-kernel.sh:93: chroot "$ROOTFS" /usr/bin/make -C /sources/linux-6.16.1 modules_install >>"$BUILD_LOG" 2>&1
/home/yrslf/alpbahOS/scripts/build-m07-vgem-kernel.sh:97: chroot "$ROOTFS" /sbin/depmod -a "$KERNEL_RELEASE"
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:30:     if (( EFI_MOUNTED )); then umount "$MOUNT/boot/efi" || cleanup_ok=0; fi
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:31:     if (( ROOT_MOUNTED )); then umount "$MOUNT" || cleanup_ok=0; fi
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:36:     if (( CREATED && ! SUCCESS && cleanup_ok )); then rm -f -- "$OUT"; fi
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:37:     if (( RAW_CREATED && ! LOOP_ATTACHED && cleanup_ok )); then rm -f -- "$RAW"; fi
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:43:     rm -rf -- "$WORK"
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:97: mount "$PART2" "$MOUNT"
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:100: mount "$PART1" "$MOUNT/boot/efi"
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:168: chroot "$MOUNT" /usr/sbin/useradd -m -u 1001 -g users -G wheel -s /bin/bash admin
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:169: chroot "$MOUNT" /usr/sbin/usermod -aG audio sa
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:170: chroot "$MOUNT" /usr/sbin/usermod -aG audio admin
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:172: [credential-adjacent line redacted; calls=chroot]
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:177: chroot "$MOUNT" /usr/bin/id -nG sa | tr ' ' '\n' | grep -qx audio
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:178: chroot "$MOUNT" /usr/bin/id -nG admin | tr ' ' '\n' | grep -qx audio
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:225: umount "$MOUNT/boot/efi"
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:227: umount "$MOUNT"
/home/yrslf/alpbahOS/scripts/build-m2-gen2-test-image.sh:236: rm -f -- "$RAW"
/home/yrslf/alpbahOS/scripts/build-m2-test-snd-aloop-module.sh:6: # Builder rootfs. Compilation runs as LFS (UID 1001) inside /mnt/lfs chroot;
/home/yrslf/alpbahOS/scripts/build-m2-test-snd-aloop-module.sh:7: # installation and depmod run as root inside that same chroot.
/home/yrslf/alpbahOS/scripts/build-m2-test-snd-aloop-module.sh:23:         umount -R -- "${MOUNTED[$i]}"
/home/yrslf/alpbahOS/scripts/build-m2-test-snd-aloop-module.sh:37: if ps -eo comm= | grep -Eq '^(make|ninja|cmake|chroot)$'; then
/home/yrslf/alpbahOS/scripts/build-m2-test-snd-aloop-module.sh:38:     echo 'Another build/chroot process is active; refusing to proceed.' >&2
/home/yrslf/alpbahOS/scripts/build-m2-test-snd-aloop-module.sh:46:     echo 'An existing mount is present below /mnt/lfs; refusing to alter it.' >&2
/home/yrslf/alpbahOS/scripts/build-m2-test-snd-aloop-module.sh:58:         echo "Unexpected pre-existing mount: $target" >&2
/home/yrslf/alpbahOS/scripts/build-m2-test-snd-aloop-module.sh:61:     mount --rbind "$source" "$target"
/home/yrslf/alpbahOS/scripts/build-m2-test-snd-aloop-module.sh:62:     mount --make-rslave "$target"
/home/yrslf/alpbahOS/scripts/build-m2-test-snd-aloop-module.sh:72:     chroot --userspec=1001:1001 "$ROOTFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/build-m2-test-snd-aloop-module.sh:86: chroot "$ROOTFS" /sbin/depmod -a "$KERNEL_RELEASE"
/home/yrslf/alpbahOS/scripts/build-m2-test-snd-aloop-module.sh:90: chroot "$ROOTFS" /sbin/modinfo "/lib/modules/$KERNEL_RELEASE/$MODULE_REL" \
/home/yrslf/alpbahOS/scripts/capture-m04-install-event.py:48:     "splice", "mmap", "mount", "umount2",
/home/yrslf/alpbahOS/scripts/capture-m04-install-event.py:82:     "mount", "umount", "umount2", "pivot_root", "move_mount", "open_tree",
/home/yrslf/alpbahOS/scripts/capture-m04-install-event.py:454:                 f"line {line_no}: {match.group(1)} observed; fixture event invalid because mount topology changes are not captured"
/home/yrslf/alpbahOS/scripts/configure-blfs-kf6-prefix.sh:16: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/configure-blfs-kf6-prefix.sh:39: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -e <<'CHROOT'
/home/yrslf/alpbahOS/scripts/configure-blfs-nss-trust-d34.sh:15: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c \
/home/yrslf/alpbahOS/scripts/configure-blfs-nss-trust-d34.sh:19: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -s <<'NSS_TRUST'
/home/yrslf/alpbahOS/scripts/configure-blfs-pam-stack-d34.sh:18: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -s <<'PAM_PREFLIGHT'
/home/yrslf/alpbahOS/scripts/configure-blfs-pam-stack-d34.sh:26: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -s <<'PAM_CONFIG'
/home/yrslf/alpbahOS/scripts/configure-blfs-pam-stack.sh:19: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c '
/home/yrslf/alpbahOS/scripts/configure-blfs-pam-stack.sh:38: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c '
/home/yrslf/alpbahOS/scripts/configure-blfs-pam-stack.sh:56: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/configure-lfs-shadow-ch8-resume.sh:21: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/configure-lfs-shadow-ch8-resume.sh:22: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/configure-lfs-shadow-ch8-resume.sh:23: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/configure-lfs-shadow-ch8-resume.sh:24: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/configure-lfs-shadow-ch8-resume.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/configure-lfs-shadow-ch8-resume.sh:53: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/configure-lfs-system-ch9.sh:24: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/configure-lfs-system-ch9.sh:25: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/configure-lfs-system-ch9.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/configure-lfs-system-ch9.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/configure-lfs-system-ch9.sh:28: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/configure-lfs-system-ch9.sh:168: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/install-lfs-attr-ch8-resume.sh:21: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/install-lfs-attr-ch8-resume.sh:22: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/install-lfs-attr-ch8-resume.sh:23: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/install-lfs-attr-ch8-resume.sh:24: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/install-lfs-attr-ch8-resume.sh:25: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/install-lfs-attr-ch8-resume.sh:46: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/install-lfs-gcc-ch8-resume.sh:47:     [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/install-lfs-gcc-ch8-resume.sh:49: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/install-lfs-gcc-ch8-resume.sh:50: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/install-lfs-gcc-ch8-resume.sh:51: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/install-lfs-gcc-ch8-resume.sh:52: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/install-lfs-gcc-ch8-resume.sh:125: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/install-lfs-glibc-ch8.sh:24: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/install-lfs-glibc-ch8.sh:25: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/install-lfs-glibc-ch8.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/install-lfs-glibc-ch8.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/install-lfs-glibc-ch8.sh:28: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/install-lfs-glibc-ch8.sh:82: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/install-lfs-sed-ch8-resume.sh:24: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$DATA/lfs")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/install-lfs-sed-ch8-resume.sh:25: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/install-lfs-sed-ch8-resume.sh:26: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/install-lfs-sed-ch8-resume.sh:27: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/install-lfs-sed-ch8-resume.sh:28: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/install-lfs-sed-ch8-resume.sh:45: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/lfs-build-guard.sh:5: # the exact Btrfs mount/subvolume identity prepared by the transaction runner.
/home/yrslf/alpbahOS/scripts/lfs-build-guard.sh:34:     [[ "$mount_id" == "${ALPBAHOS_D34_MOUNT_ID:-}" ]] || lfs_guard_die 'D34 target mount ID mismatch.'
/home/yrslf/alpbahOS/scripts/lfs-build-guard.sh:52:     [[ "$(stat -c '%d:%i' -- "$root")" == "$(stat -c '%d:%i' -- "$data_root/lfs")" ]] || lfs_guard_die "$root is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/lfs-chapter7-base-in-chroot.sh:10: [[ "$(id -u)" == 0 ]] || fail 'Chapter 7 setup must run as root inside chroot.'
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-autoseat.sh:12: cleanup() { set +e; ((MOUNTED)) && umount "$MOUNT"; ((ATTACHED)) && qemu-nbd --disconnect "$NBD" >/dev/null 2>&1; rm -rf -- "$WORK"; }
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-autoseat.sh:19: mkdir -p "$MOUNT"; mount "${NBD}p2" "$MOUNT"; MOUNTED=1
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-autoseat.sh:42: sync; umount "$MOUNT"; MOUNTED=0; qemu-nbd --disconnect "$NBD"; ATTACHED=0
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-dbus-and-dri.sh:25:     if (( ROOT_MOUNTED )); then umount "$MOUNT"; fi
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-dbus-and-dri.sh:27:     rm -rf -- "$WORK"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-dbus-and-dri.sh:43: mount "${NBD}p2" "$MOUNT"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-dbus-and-dri.sh:88: umount "$MOUNT"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-dns-and-admin.sh:21:     if (( ROOT_MOUNTED )); then umount "$MOUNT"; fi
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-dns-and-admin.sh:23:     rm -rf -- "$WORK"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-dns-and-admin.sh:37: mount "${NBD}p2" "$MOUNT"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-dns-and-admin.sh:57:     chroot "$MOUNT" /usr/sbin/useradd -m -u 1001 -g users -G wheel -s /bin/bash admin
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-dns-and-admin.sh:59: [credential-adjacent line redacted; calls=chroot]
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-dns-and-admin.sh:69: umount "$MOUNT"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-efi.sh:17:     if (( EFI_MOUNTED )); then umount "$MOUNT/boot/efi"; fi
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-efi.sh:18:     if (( ROOT_MOUNTED )); then umount "$MOUNT"; fi
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-efi.sh:20:     rm -rf -- "$WORK"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-efi.sh:37: mount "${NBD}p2" "$MOUNT"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-efi.sh:39: mount "${NBD}p1" "$MOUNT/boot/efi"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-efi.sh:55: umount "$MOUNT/boot/efi"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-efi.sh:57: umount "$MOUNT"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-login-and-alp.sh:19:     if (( ROOT_MOUNTED )); then umount "$MOUNT"; fi
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-login-and-alp.sh:21:     rm -rf -- "$WORK"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-login-and-alp.sh:40: mount "${NBD}p2" "$MOUNT"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-login-and-alp.sh:61: umount "$MOUNT"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-root-partuuid.sh:20:     if (( EFI_MOUNTED )); then umount "$MOUNT/boot/efi"; fi
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-root-partuuid.sh:21:     if (( ROOT_MOUNTED )); then umount "$MOUNT"; fi
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-root-partuuid.sh:23:     rm -rf -- "$WORK"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-root-partuuid.sh:46: mount "${NBD}p2" "$MOUNT"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-root-partuuid.sh:48: mount "${NBD}p1" "$MOUNT/boot/efi"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-root-partuuid.sh:72: umount "$MOUNT/boot/efi"
/home/yrslf/alpbahOS/scripts/patch-m2-gen2-root-partuuid.sh:74: umount "$MOUNT"
/home/yrslf/alpbahOS/scripts/preflight-d34-candidate-root.py:2: """Read-only identity and mount-boundary preflight for a D34 candidate root.
/home/yrslf/alpbahOS/scripts/preflight-d34-candidate-root.py:66:         raise CandidatePreflightError(f"cannot read mount table: {exc}") from exc
/home/yrslf/alpbahOS/scripts/preflight-d34-candidate-root.py:95:         raise CandidatePreflightError("findmnt did not return exactly one containing mount")
/home/yrslf/alpbahOS/scripts/preflight-d34-candidate-root.py:96:     mount = filesystems[0]
/home/yrslf/alpbahOS/scripts/preflight-d34-candidate-root.py:97:     if mount.get("fstype") != "btrfs":
/home/yrslf/alpbahOS/scripts/preflight-d34-candidate-root.py:98:         raise CandidatePreflightError(f"candidate filesystem is {mount.get('fstype')!r}, not btrfs")
/home/yrslf/alpbahOS/scripts/preflight-d34-candidate-root.py:99:     if mount.get("uuid") != expected_fs_uuid:
/home/yrslf/alpbahOS/scripts/preflight-d34-candidate-root.py:101:             f"candidate filesystem UUID mismatch: expected {expected_fs_uuid}, got {mount.get('uuid')}"
/home/yrslf/alpbahOS/scripts/preflight-d34-candidate-root.py:125:             "type": mount["fstype"], "uuid": mount["uuid"],
/home/yrslf/alpbahOS/scripts/preflight-d34-candidate-root.py:126:             "source": mount["source"], "mount_id": mount["id"],
/home/yrslf/alpbahOS/scripts/preflight-d34-candidate-root.py:127:             "mountpoint": mount["target"], "fsroot": mount["fsroot"],
/home/yrslf/alpbahOS/scripts/prepare-lfs-chroot.sh:41:         printf 'Keeping existing %s mount at %s.\n' "$fstype" "$target"
/home/yrslf/alpbahOS/scripts/prepare-lfs-chroot.sh:45:         mount -v -t "$fstype" -o "$options" "$source" "$target"
/home/yrslf/alpbahOS/scripts/prepare-lfs-chroot.sh:47:         mount -v -t "$fstype" "$source" "$target"
/home/yrslf/alpbahOS/scripts/prepare-lfs-chroot.sh:52:     mount -v --bind /dev "$LFS/dev"
/home/yrslf/alpbahOS/scripts/prepare-lfs-chroot.sh:54:     [[ "$(findmnt -n -o MAJ:MIN -M "$LFS/dev")" == "$(findmnt -n -o MAJ:MIN -M /dev)" ]] || fail "Unexpected existing mount at $LFS/dev"
/home/yrslf/alpbahOS/scripts/prepare-lfs-chroot.sh:55:     printf 'Keeping existing /dev bind mount.\n'
/home/yrslf/alpbahOS/scripts/prepare-lfs-chroot.sh:72: printf '\nPreparing essential Chapter 7 files inside chroot.\n'
/home/yrslf/alpbahOS/scripts/prepare-lfs-chroot.sh:73: chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/prepare-lfs-chroot.sh:76:     PS1='(lfs chroot) \u:\w\$ ' \
/home/yrslf/alpbahOS/scripts/prepare-lfs-chroot.sh:80:     /bin/bash --login -s < "$SCRIPT_DIR/lfs-chapter7-base-in-chroot.sh"
/home/yrslf/alpbahOS/scripts/provision-m2-test-user.sh:53:     chroot "$ROOTFS" /usr/sbin/usermod -aG wheel sa
/home/yrslf/alpbahOS/scripts/provision-m2-test-user.sh:63:     chroot "$ROOTFS" /usr/sbin/useradd -m -u "$SA_UID" -g users -G wheel -s /bin/bash sa
/home/yrslf/alpbahOS/scripts/provision-m2-test-user.sh:66: [credential-adjacent line redacted; calls=chroot]
/home/yrslf/alpbahOS/scripts/rebuild-blfs-shadow-pam.sh:28: sudo -n chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin LC_ALL=POSIX /bin/bash -c '
/home/yrslf/alpbahOS/scripts/rebuild-blfs-shadow-pam.sh:51: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/rebuild-blfs-shadow-pam.sh:132: sudo -n chroot "$LFS" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
/home/yrslf/alpbahOS/scripts/resume-d34-package-replay.py:54: [credential-adjacent line redacted; calls=mount]
/home/yrslf/alpbahOS/scripts/resume-d34-package-replay.py:68:     unmount = subprocess.run(["umount", "-R", str(replay.LFS_MOUNT)],
/home/yrslf/alpbahOS/scripts/resume-d34-package-replay.py:87:     parser.add_argument("--script-kind", choices=("host", "chroot"))
/home/yrslf/alpbahOS/scripts/resume-d34-package-replay.py:109:     parser.add_argument("--script-kind", choices=("host", "chroot"), default="chroot")
/home/yrslf/alpbahOS/scripts/resume-d34-package-replay.py:211: [credential-adjacent line redacted; calls=mount]
/home/yrslf/alpbahOS/scripts/resume-lfs-glibc-ch8-check.sh:42: [[ "$(stat -c '%d:%i' "$LFS")" == "$(stat -c '%d:%i' "$LFS_DATA")" ]] || fail "$LFS is not the expected HDD bind mount."
/home/yrslf/alpbahOS/scripts/resume-lfs-glibc-ch8-check.sh:43: [[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
/home/yrslf/alpbahOS/scripts/resume-lfs-glibc-ch8-check.sh:44: [[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
/home/yrslf/alpbahOS/scripts/resume-lfs-glibc-ch8-check.sh:45: [[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
/home/yrslf/alpbahOS/scripts/resume-lfs-glibc-ch8-check.sh:46: [[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
/home/yrslf/alpbahOS/scripts/resume-lfs-glibc-ch8-check.sh:81: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/resume-lfs-glibc-ch8-check.sh:97: sudo -n chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS/scripts/resume-m04-acl-stage.sh:49:   for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
/home/yrslf/alpbahOS/scripts/resume-m04-acl-stage.sh:148: bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
/home/yrslf/alpbahOS/scripts/resume-m04-acl-stage.sh:150: chroot "$LFS" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 BUILD_CHROOT="$BUILD_CHROOT" /bin/bash --noprofile --norc -c 'cd "$BUILD_CHROOT" && make DESTDIR="/tmp/alp-m04-acl-stage-20260924-r2" install' 2>&1 | tee -a "$LOG"
/home/yrslf/alpbahOS/scripts/resume-m04-acl-stage.sh:155: if chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" /usr/bin/ldd "$STAGE_CHROOT/usr/lib/libacl.so.1" > "$DEPENDENCY_RESOLUTION" 2>&1; then :; else cat "$DEPENDENCY_RESOLUTION" >&2; exit 1; fi
/home/yrslf/alpbahOS/scripts/resume-m04-acl-stage.sh:158: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" LD_DEBUG=libs /bin/bash --noprofile --norc -c "'$STAGE_CHROOT/usr/bin/setfacl' -m u:1001:r-- '/tmp/alp-m04-acl-smoke-file-20260924-r2' && '$STAGE_CHROOT/usr/bin/getfacl' -ncp '/tmp/alp-m04-acl-smoke-file-20260924-r2' | grep -Fqx 'user:1001:r--'" 2> "$SMOKE_TRACE"
/home/yrslf/alpbahOS/scripts/resume-m04-acl-stage.sh:161: rm -f "$SMOKE_FILE"
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:5: [credential-adjacent line redacted; calls=mount]
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:7: host mount namespace.
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:177:     mount = filesystems[0]
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:178:     if mount.get("fstype") != "btrfs":
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:179:         raise ReplayError(f"expected Btrfs filesystem, got {mount.get('fstype')!r}")
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:180:     return {"uuid": mount["uuid"], "mount_id": str(mount["id"]), "target": mount["target"]}
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:259: [credential-adjacent line redacted; calls=mount]
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:260:     _mount_command(["umount", "-R", str(LFS_MOUNT)])
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:261:     _mount_command(["mount", "--bind", str(work), str(LFS_MOUNT)])
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:265:     _mount_command(["mount", "--bind", "/dev", str(root / "dev")])
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:266:     _mount_command(["mount", "-t", "devpts", "-o", "gid=5,mode=0620", "devpts", str(root / "dev/pts")])
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:267:     _mount_command(["mount", "-t", "tmpfs", "-o", "nosuid,nodev", "tmpfs", str(root / "dev/shm")])
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:268:     _mount_command(["mount", "-t", "proc", "proc", str(root / "proc")])
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:269:     _mount_command(["mount", "-t", "sysfs", "sysfs", str(root / "sys")])
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:270:     _mount_command(["mount", "-t", "tmpfs", "-o", "mode=0755,nosuid,nodev", "tmpfs", str(root / "run")])
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:274:         raise ReplayError(f"expected one exact /mnt/lfs root mount, got {len(mount_lines)}")
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:277:         raise ReplayError(f"unexpected D34 root mount record: {mount_lines[0]}")
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:299:                 "sudo", "-n", "chroot", str(LFS_MOUNT), "/usr/bin/env", "-i",
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:332:     unmount = subprocess.run(["umount", "-R", str(LFS_MOUNT)],
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:374:     parser.add_argument("--script-kind", choices=("host", "chroot"))
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:400:     parser.add_argument("--script-kind", choices=("host", "chroot"), default="chroot")
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:425:             parser.error("chroot replay script must be one of this repo's build-lfs-*-ch8.sh files")
/home/yrslf/alpbahOS/scripts/run-d34-package-replay.py:460: [credential-adjacent line redacted; calls=mount]
/home/yrslf/alpbahOS/scripts/validate-m04-acl-stage.sh:69:   if (( SMOKE_CREATED )); then rm -f "$SMOKE_FILE" || status=1; fi
/home/yrslf/alpbahOS/scripts/validate-m04-acl-stage.sh:104:   mount_sources=$(findmnt -rn -o SOURCE) || { echo 'Cannot read mount sources' >&2; return 1; }
/home/yrslf/alpbahOS/scripts/validate-m04-acl-stage.sh:174: if chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" /lib64/ld-linux-x86-64.so.2 --list "$STAGE_CHROOT/usr/bin/setfacl" > "$DEPENDENCY_RESOLUTION" 2>&1; then :; else cat "$DEPENDENCY_RESOLUTION" >&2; exit 1; fi
/home/yrslf/alpbahOS/scripts/validate-m04-acl-stage.sh:179: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" LD_DEBUG=libs /bin/bash --noprofile --norc -c "'$STAGE_CHROOT/usr/bin/setfacl' -m u:1001:r-- '/tmp/alp-m04-acl-smoke-file-validation-$RUN_ID' && '$STAGE_CHROOT/usr/bin/getfacl' -ncp '/tmp/alp-m04-acl-smoke-file-validation-$RUN_ID' | grep -Fqx 'user:1001:r--'" 2> "$SMOKE_TRACE"
/home/yrslf/alpbahOS-claude/scripts/apply-m2-rootfs-fixes.sh:49: rm -f -- "$tmp_service" "$tmp_socket"
/home/yrslf/alpbahOS-claude/scripts/build-m04-acl-stage.sh:39:   for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
/home/yrslf/alpbahOS-claude/scripts/build-m04-acl-stage.sh:130: if setfacl -m u:1001:r-- "$acl_probe" && getfacl -ncp "$acl_probe" | grep -Fq 'user:1001:r--'; then :; else rm -f "$acl_probe"; echo 'filesystem ACL probe failed' >&2; exit 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-acl-stage.sh:131: rm -f "$acl_probe"
/home/yrslf/alpbahOS-claude/scripts/build-m04-acl-stage.sh:141: bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
/home/yrslf/alpbahOS-claude/scripts/build-m04-acl-stage.sh:145: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 TMPDIR="$BUILD_CHROOT/tmp" BUILD_CHROOT="$BUILD_CHROOT" ACL_TEST_PARSER_CHROOT="$ACL_TEST_PARSER_CHROOT" CPPFLAGS="-I$ATTR_STAGE_CHROOT/usr/include" LDFLAGS="-L$ATTR_STAGE_CHROOT/usr/lib" LD_LIBRARY_PATH="$ATTR_STAGE_CHROOT/usr/lib" /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS-claude/scripts/build-m04-acl-stage.sh:154: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c "cd '$BUILD_CHROOT' && make DESTDIR='$STAGE_CHROOT' install"
/home/yrslf/alpbahOS-claude/scripts/build-m04-acl-stage.sh:160: if chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" /usr/bin/ldd "$STAGE_CHROOT/usr/lib/libacl.so.1" > "$DEPENDENCY_RESOLUTION" 2>&1; then :; else cat "$DEPENDENCY_RESOLUTION" >&2; exit 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-acl-stage.sh:163: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" LD_DEBUG=libs /bin/bash --noprofile --norc -c "
/home/yrslf/alpbahOS-claude/scripts/build-m04-acl-stage.sh:168: rm -f "$smoke"
/home/yrslf/alpbahOS-claude/scripts/build-m04-attr-stage.sh:30:   for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
/home/yrslf/alpbahOS-claude/scripts/build-m04-attr-stage.sh:77: if setfacl -m u:1001:r-- "$acl_probe" && getfacl -cpn "$acl_probe" | grep -Fq 'user:1001:r--'; then :; else rm -f "$acl_probe"; echo 'filesystem ACL probe failed' >&2; exit 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-attr-stage.sh:78: rm -f "$acl_probe"
/home/yrslf/alpbahOS-claude/scripts/build-m04-attr-stage.sh:84: bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
/home/yrslf/alpbahOS-claude/scripts/build-m04-attr-stage.sh:87: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 TMPDIR="$BUILD_CHROOT/tmp" /bin/bash --noprofile --norc -c "
/home/yrslf/alpbahOS-claude/scripts/build-m04-attr-stage.sh:94: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c "cd '$BUILD_CHROOT' && make DESTDIR='$STAGE_CHROOT' install"
/home/yrslf/alpbahOS-claude/scripts/build-m04-attr-stage.sh:99: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" /bin/bash --noprofile --norc -c "
/home/yrslf/alpbahOS-claude/scripts/build-m04-attr-stage.sh:103: rm -f "$probe"
/home/yrslf/alpbahOS-claude/scripts/build-m04-bash-stage.sh:5: # /mnt/lfs chroot, then install it into an isolated DESTDIR for comparison.
/home/yrslf/alpbahOS-claude/scripts/build-m04-bash-stage.sh:26:         umount "${MOUNTS[$i]}"
/home/yrslf/alpbahOS-claude/scripts/build-m04-bash-stage.sh:81:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-bash-stage.sh:84:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-bash-stage.sh:93: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-bash-stage.sh:104: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-bash-stage.sh:108: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-bash-stage.sh:114: rm -f "$STAGE_HOST/usr/share/info/dir"
/home/yrslf/alpbahOS-claude/scripts/build-m04-bash-stage.sh:118: [[ $(chroot "$LFS" "$STAGE_CHROOT/usr/bin/bash" --noprofile --norc -c 'printf "%s\n" "$((20 + 22))"') == 42 ]]
/home/yrslf/alpbahOS-claude/scripts/build-m04-bash-stage.sh:119: chroot "$LFS" "$STAGE_CHROOT/usr/bin/bash" --version | head -n 1
/home/yrslf/alpbahOS-claude/scripts/build-m04-bc-stage.sh:54:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS-claude/scripts/build-m04-bc-stage.sh:85:         echo "önceden bağlı: $target -- başka bir chroot oturumu açık olabilir" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-bc-stage.sh:96:     bc_output=$(printf '2+2\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/bc")
/home/yrslf/alpbahOS-claude/scripts/build-m04-bc-stage.sh:98:     dc_output=$(printf '5 2 + p\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/dc")
/home/yrslf/alpbahOS-claude/scripts/build-m04-bc-stage.sh:123:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-bc-stage.sh:126:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-bc-stage.sh:135: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-bc-stage.sh:144: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-bc-stage.sh:147: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS-claude/scripts/build-m04-bc-stage.sh:151: bc_output=$(printf '2+2\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/bc")
/home/yrslf/alpbahOS-claude/scripts/build-m04-bc-stage.sh:153: dc_output=$(printf '5 2 + p\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/dc")
/home/yrslf/alpbahOS-claude/scripts/build-m04-binutils-stage.sh:37:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS-claude/scripts/build-m04-binutils-stage.sh:103:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-binutils-stage.sh:106:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-binutils-stage.sh:118: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-binutils-stage.sh:138: chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-binutils-stage.sh:174: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-binutils-stage.sh:178:         rm -rfv /tmp/alp-m04-binutils-stage-r1/usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
/home/yrslf/alpbahOS-claude/scripts/build-m04-binutils-stage.sh:185:     tool_output=$(chroot "$LFS" /usr/bin/env LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" \
/home/yrslf/alpbahOS-claude/scripts/build-m04-dejagnu-stage.sh:44:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS-claude/scripts/build-m04-dejagnu-stage.sh:87:         echo "önceden bağlı: $target -- başka bir chroot oturumu açık olabilir" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-dejagnu-stage.sh:105:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-dejagnu-stage.sh:108:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-dejagnu-stage.sh:117: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-dejagnu-stage.sh:130: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-dejagnu-stage.sh:134: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS-claude/scripts/build-m04-dejagnu-stage.sh:147: DEJAGNU_VERSION=$(chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-expat-stage.sh:23:     rm -f "$FIXTURE"
/home/yrslf/alpbahOS-claude/scripts/build-m04-expat-stage.sh:24:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS-claude/scripts/build-m04-expat-stage.sh:60:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-expat-stage.sh:61:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-expat-stage.sh:70: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-expat-stage.sh:78: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-expat-stage.sh:81: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-expat-stage.sh:89: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-expect-stage.sh:34:         umount "${MOUNTS[$i]}"
/home/yrslf/alpbahOS-claude/scripts/build-m04-expect-stage.sh:100:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-expect-stage.sh:103:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-expect-stage.sh:114: PTY_OUTPUT=$(chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-expect-stage.sh:121: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-expect-stage.sh:136: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-expect-stage.sh:140: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-expect-stage.sh:151: EXPECT_VERSION=$(chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-flex-stage.sh:50:     version=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/flex" --version)
/home/yrslf/alpbahOS-claude/scripts/build-m04-flex-stage.sh:52:     chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-flex-stage.sh:70:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS-claude/scripts/build-m04-flex-stage.sh:101:         echo "önceden bağlı: $target -- başka bir chroot oturumu açık olabilir" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-flex-stage.sh:142:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-flex-stage.sh:145:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-flex-stage.sh:154: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-flex-stage.sh:163: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-flex-stage.sh:166: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS-claude/scripts/build-m04-flex-stage.sh:168: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gcc-stage.sh:71:     case "$status" in 0|1) ;; *) echo "findmnt failed during NBD mount check: $output" >&2; return 1 ;; esac
/home/yrslf/alpbahOS-claude/scripts/build-m04-gcc-stage.sh:100:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
/home/yrslf/alpbahOS-claude/scripts/build-m04-gcc-stage.sh:216: bind_mount() { local src=$1 dst=$2; mountpoint -q "$dst" && { echo "pre-existing mount: $dst" >&2; return 1; }; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
/home/yrslf/alpbahOS-claude/scripts/build-m04-gcc-stage.sh:221: chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gcc-stage.sh:247:       chroot --userspec=101:101 --groups=101 / /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gcc-stage.sh:269: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gcc-stage.sh:297: chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gdbm-stage.sh:22:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS-claude/scripts/build-m04-gdbm-stage.sh:55:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-gdbm-stage.sh:56:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-gdbm-stage.sh:65: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gdbm-stage.sh:73: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gdbm-stage.sh:76: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gdbm-stage.sh:81: chroot "$LFS" "$STAGE_CHROOT/usr/bin/gdbm_dump" --version | head -n 1
/home/yrslf/alpbahOS-claude/scripts/build-m04-gdbm-stage.sh:82: chroot "$LFS" "$STAGE_CHROOT/usr/bin/gdbm_load" --version | head -n 1
/home/yrslf/alpbahOS-claude/scripts/build-m04-gmp-stage.sh:39:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS-claude/scripts/build-m04-gmp-stage.sh:105:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-gmp-stage.sh:108:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-gmp-stage.sh:120: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gmp-stage.sh:143: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gmp-stage.sh:165: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gperf-stage.sh:22:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS-claude/scripts/build-m04-gperf-stage.sh:55:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-gperf-stage.sh:56:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-gperf-stage.sh:65: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gperf-stage.sh:73: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gperf-stage.sh:76: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-gperf-stage.sh:81: rm -f "$STAGE_HOST/usr/share/info/dir"
/home/yrslf/alpbahOS-claude/scripts/build-m04-gperf-stage.sh:82: chroot "$LFS" "$STAGE_CHROOT/usr/bin/gperf" --version | head -n 1
/home/yrslf/alpbahOS-claude/scripts/build-m04-iana-etc-stage.sh:40:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS-claude/scripts/build-m04-iana-etc-stage.sh:70:         echo "önceden bağlı: $target -- başka bir chroot oturumu açık olabilir" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-iana-etc-stage.sh:122:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-iana-etc-stage.sh:125:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-iana-etc-stage.sh:134: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS-claude/scripts/build-m04-inetutils-stage.sh:22:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS-claude/scripts/build-m04-inetutils-stage.sh:58:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-inetutils-stage.sh:59:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-inetutils-stage.sh:68: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-inetutils-stage.sh:79: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-inetutils-stage.sh:82: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-inetutils-stage.sh:88: chroot "$LFS" "$STAGE_CHROOT/usr/bin/ftp" --version | head -n 1
/home/yrslf/alpbahOS-claude/scripts/build-m04-less-stage.sh:22:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS-claude/scripts/build-m04-less-stage.sh:58:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-less-stage.sh:59:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-less-stage.sh:68: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-less-stage.sh:76: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-less-stage.sh:79: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-less-stage.sh:85: chroot "$LFS" "$STAGE_CHROOT/usr/bin/less" --version | head -n 1
/home/yrslf/alpbahOS-claude/scripts/build-m04-libcap-stage.sh:28:   for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
/home/yrslf/alpbahOS-claude/scripts/build-m04-libcap-stage.sh:73:     [[ $findmnt_status -eq 1 ]] || { echo "Cannot verify nbd0 mount source (findmnt status $findmnt_status)" >&2; return 1; }
/home/yrslf/alpbahOS-claude/scripts/build-m04-libcap-stage.sh:103: bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
/home/yrslf/alpbahOS-claude/scripts/build-m04-libcap-stage.sh:106: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 TMPDIR=/build/libcap-2.76-m04-r1/tmp /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS-claude/scripts/build-m04-libcap-stage.sh:112: # target as root inside the chroot after the unprivileged build.
/home/yrslf/alpbahOS-claude/scripts/build-m04-libcap-stage.sh:113: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c 'cd /build/libcap-2.76-m04-r1 && make test'
/home/yrslf/alpbahOS-claude/scripts/build-m04-libcap-stage.sh:114: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c 'cd /build/libcap-2.76-m04-r1 && make DESTDIR=/tmp/alp-m04-libcap-stage-r1 prefix=/usr lib=lib install'
/home/yrslf/alpbahOS-claude/scripts/build-m04-libcap-stage.sh:123: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS-claude/scripts/build-m04-libtool-stage.sh:22:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS-claude/scripts/build-m04-libtool-stage.sh:55:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-libtool-stage.sh:56:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-libtool-stage.sh:65: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-libtool-stage.sh:73: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-libtool-stage.sh:76: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-libtool-stage.sh:81: rm -f "$STAGE_HOST/usr/lib/libltdl.a"
/home/yrslf/alpbahOS-claude/scripts/build-m04-libtool-stage.sh:82: chroot "$LFS" "$STAGE_CHROOT/usr/bin/libtool" --version | head -n 1
/home/yrslf/alpbahOS-claude/scripts/build-m04-libtool-stage.sh:83: chroot "$LFS" "$STAGE_CHROOT/usr/bin/libtoolize" --version | head -n 1
/home/yrslf/alpbahOS-claude/scripts/build-m04-libxcrypt-stage.sh:68:     [[ $status -eq 1 ]] || { echo "Cannot verify nbd0 mount source (findmnt status $status)" >&2; return 1; }
/home/yrslf/alpbahOS-claude/scripts/build-m04-libxcrypt-stage.sh:84:     umount "${MOUNTS[$i]}" || { echo "CLEANUP_FAILED: cannot unmount ${MOUNTS[$i]}" >&2; status=1; }
/home/yrslf/alpbahOS-claude/scripts/build-m04-libxcrypt-stage.sh:134:   if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-libxcrypt-stage.sh:135:   mount --bind "$src" "$dst"
/home/yrslf/alpbahOS-claude/scripts/build-m04-libxcrypt-stage.sh:145: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i HOME=/home/lfs TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 TMPDIR=/build/libxcrypt-4.4.38-m04-r1/tmp /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS-claude/scripts/build-m04-libxcrypt-stage.sh:159: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c 'set -Eeuo pipefail; cd /build/libxcrypt-4.4.38-m04-r1; make DESTDIR=/tmp/alp-m04-libxcrypt-stage-r1 install'
/home/yrslf/alpbahOS-claude/scripts/build-m04-libxcrypt-stage.sh:173: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS-claude/scripts/build-m04-libxcrypt-stage.sh:183: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS-claude/scripts/build-m04-man-pages-stage.sh:40:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS-claude/scripts/build-m04-man-pages-stage.sh:72:         echo "önceden bağlı: $target -- başka bir chroot oturumu açık olabilir" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-man-pages-stage.sh:89:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-man-pages-stage.sh:92:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-man-pages-stage.sh:101: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS-claude/scripts/build-m04-man-pages-stage.sh:105:         rm -v man3/crypt*
/home/yrslf/alpbahOS-claude/scripts/build-m04-mpc-stage.sh:43:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
/home/yrslf/alpbahOS-claude/scripts/build-m04-mpc-stage.sh:114: bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
/home/yrslf/alpbahOS-claude/scripts/build-m04-mpc-stage.sh:118: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-mpc-stage.sh:135: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS-claude/scripts/build-m04-mpc-stage.sh:145: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash --noprofile --norc -c '
/home/yrslf/alpbahOS-claude/scripts/build-m04-mpfr-stage.sh:40:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS-claude/scripts/build-m04-mpfr-stage.sh:138:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-mpfr-stage.sh:141:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-mpfr-stage.sh:155: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-mpfr-stage.sh:185: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-mpfr-stage.sh:210: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-ncurses-stage.sh:94:     umount "${MOUNTS[$i]}" || { echo "CLEANUP_FAILED: cannot unmount ${MOUNTS[$i]}" >&2; status=1; }
/home/yrslf/alpbahOS-claude/scripts/build-m04-ncurses-stage.sh:150:   if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-ncurses-stage.sh:151:   mount --bind "$src" "$dst"
/home/yrslf/alpbahOS-claude/scripts/build-m04-ncurses-stage.sh:161: # chroot. The active-root library replacement and cp into / from the book are
/home/yrslf/alpbahOS-claude/scripts/build-m04-ncurses-stage.sh:163: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-ncurses-stage.sh:186: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-ncurses-stage.sh:198: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-ncurses-stage.sh:235: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-ncurses-stage.sh:247: chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-perl-stage.sh:22:     for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}"; done
/home/yrslf/alpbahOS-claude/scripts/build-m04-perl-stage.sh:49:     chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-perl-stage.sh:78:     if /usr/bin/mountpoint -q "$target"; then echo "Refusing pre-existing mount: $target" >&2; return 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-perl-stage.sh:79:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-perl-stage.sh:88: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-perl-stage.sh:110: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-perl-stage.sh:113: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-perl-stage.sh:119: chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-pkgconf-stage.sh:35:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS-claude/scripts/build-m04-pkgconf-stage.sh:97:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-pkgconf-stage.sh:100:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-pkgconf-stage.sh:111: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-pkgconf-stage.sh:118: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-pkgconf-stage.sh:132: STAGED_VERSION=$(chroot "$LFS" /usr/bin/env \
/home/yrslf/alpbahOS-claude/scripts/build-m04-pkgconf-stage.sh:136: [[ $(chroot "$LFS" /usr/bin/env LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" \
/home/yrslf/alpbahOS-claude/scripts/build-m04-pkgconf-stage.sh:138: chroot "$LFS" /usr/bin/env LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib" \
/home/yrslf/alpbahOS-claude/scripts/build-m04-psmisc-stage.sh:73:       [[ $status -eq 1 ]] || { echo "Cannot check mount for $device (findmnt status $status)" >&2; return 1; }
/home/yrslf/alpbahOS-claude/scripts/build-m04-psmisc-stage.sh:174:     umount "${MOUNTS[$i]}" || { echo "CLEANUP_FAILED: cannot unmount ${MOUNTS[$i]}" >&2; status=1; }
/home/yrslf/alpbahOS-claude/scripts/build-m04-psmisc-stage.sh:219:   if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-psmisc-stage.sh:220:   mount --bind "$src" "$dst"
/home/yrslf/alpbahOS-claude/scripts/build-m04-psmisc-stage.sh:229: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-psmisc-stage.sh:237: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS-claude/scripts/build-m04-psmisc-stage.sh:243: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS-claude/scripts/build-m04-psmisc-stage.sh:252: pstree_version=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/pstree" --version 2>&1 | head -n 1)
/home/yrslf/alpbahOS-claude/scripts/build-m04-psmisc-stage.sh:254: pstree_smoke=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/pstree" -p 1)
/home/yrslf/alpbahOS-claude/scripts/build-m04-psmisc-stage.sh:256: fuser_version=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/fuser" --version 2>&1 | head -n 1)
/home/yrslf/alpbahOS-claude/scripts/build-m04-sed-stage.sh:5: # inside /mnt/lfs chroot. Do not run until the M04 GCC stage is complete.
/home/yrslf/alpbahOS-claude/scripts/build-m04-sed-stage.sh:159:     umount "${MOUNTS[$i]}" || { echo "CLEANUP_FAILED: cannot unmount ${MOUNTS[$i]}" >&2; status=1; }
/home/yrslf/alpbahOS-claude/scripts/build-m04-sed-stage.sh:188:       echo "önceden bağlı: $target -- başka bir chroot oturumu açık olabilir" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-sed-stage.sh:213:   if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-sed-stage.sh:214:   mount --bind "$src" "$dst"
/home/yrslf/alpbahOS-claude/scripts/build-m04-sed-stage.sh:225: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-sed-stage.sh:235: chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-sed-stage.sh:242: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS-claude/scripts/build-m04-sed-stage.sh:252: smoke_output=$(printf 'alp staging smoke\n' | chroot "$LFS" "$STAGE_CHROOT/usr/bin/sed" 's/staging/stage/; s/smoke/ok/')
/home/yrslf/alpbahOS-claude/scripts/build-m04-sed-stage.sh:254: version_output=$(chroot "$LFS" "$STAGE_CHROOT/usr/bin/sed" --version | head -n 1)
/home/yrslf/alpbahOS-claude/scripts/build-m04-shadow-stage.sh:74:     [[ $status -eq 1 ]] || { echo "Cannot verify nbd0 mount source (findmnt status $status)" >&2; return 1; }
/home/yrslf/alpbahOS-claude/scripts/build-m04-shadow-stage.sh:116:     umount "${MOUNTS[$i]}" || { echo "CLEANUP_FAILED: cannot unmount ${MOUNTS[$i]}" >&2; status=1; }
/home/yrslf/alpbahOS-claude/scripts/build-m04-shadow-stage.sh:203:   if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi
/home/yrslf/alpbahOS-claude/scripts/build-m04-shadow-stage.sh:204:   mount --bind "$src" "$dst"
/home/yrslf/alpbahOS-claude/scripts/build-m04-shadow-stage.sh:215: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-shadow-stage.sh:238: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-shadow-stage.sh:266: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin \
/home/yrslf/alpbahOS-claude/scripts/build-m04-tcl-stage.sh:54:     output=$(printf 'puts [expr {20 + 22}]\n' | chroot "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-tcl-stage.sh:71:         umount "${MOUNTS[$i]}" || status=1
/home/yrslf/alpbahOS-claude/scripts/build-m04-tcl-stage.sh:104:         echo "önceden bağlı: $target -- başka bir chroot oturumu açık olabilir" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-tcl-stage.sh:143:         echo "Refusing pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m04-tcl-stage.sh:146:     mount --bind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m04-tcl-stage.sh:155: chroot --userspec=1001:1001 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-tcl-stage.sh:177: chroot --userspec=101:101 "$LFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m04-tcl-stage.sh:181: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 \
/home/yrslf/alpbahOS-claude/scripts/build-m07-vgem-kernel.sh:6: # build inside the /mnt/lfs chroot, and install only after a successful build.
/home/yrslf/alpbahOS-claude/scripts/build-m07-vgem-kernel.sh:22:         if ! umount -R -- "${MOUNTED[$i]}"; then
/home/yrslf/alpbahOS-claude/scripts/build-m07-vgem-kernel.sh:43: if pgrep -x make >/dev/null || pgrep -x ninja >/dev/null || pgrep -x chroot >/dev/null; then
/home/yrslf/alpbahOS-claude/scripts/build-m07-vgem-kernel.sh:44:     echo 'Another build/chroot process is active; refusing to proceed.' >&2
/home/yrslf/alpbahOS-claude/scripts/build-m07-vgem-kernel.sh:52:     echo 'An existing mount is present below /mnt/lfs; refusing to alter it.' >&2
/home/yrslf/alpbahOS-claude/scripts/build-m07-vgem-kernel.sh:67:         echo "Unexpected pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m07-vgem-kernel.sh:70:     mount --rbind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m07-vgem-kernel.sh:71:     mount --make-rslave "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m07-vgem-kernel.sh:81:     chroot --userspec=1001:1001 "$ROOTFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m07-vgem-kernel.sh:93: chroot "$ROOTFS" /usr/bin/make -C /sources/linux-6.16.1 modules_install >>"$BUILD_LOG" 2>&1
/home/yrslf/alpbahOS-claude/scripts/build-m07-vgem-kernel.sh:97: chroot "$ROOTFS" /sbin/depmod -a "$KERNEL_RELEASE"
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:30:     if (( EFI_MOUNTED )); then umount "$MOUNT/boot/efi" || cleanup_ok=0; fi
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:31:     if (( ROOT_MOUNTED )); then umount "$MOUNT" || cleanup_ok=0; fi
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:36:     if (( CREATED && ! SUCCESS && cleanup_ok )); then rm -f -- "$OUT"; fi
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:37:     if (( RAW_CREATED && ! LOOP_ATTACHED && cleanup_ok )); then rm -f -- "$RAW"; fi
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:43:     rm -rf -- "$WORK"
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:97: mount "$PART2" "$MOUNT"
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:100: mount "$PART1" "$MOUNT/boot/efi"
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:168: chroot "$MOUNT" /usr/sbin/useradd -m -u 1001 -g users -G wheel -s /bin/bash admin
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:169: chroot "$MOUNT" /usr/sbin/usermod -aG audio sa
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:170: chroot "$MOUNT" /usr/sbin/usermod -aG audio admin
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:172: [credential-adjacent line redacted; calls=chroot]
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:177: chroot "$MOUNT" /usr/bin/id -nG sa | tr ' ' '\n' | grep -qx audio
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:178: chroot "$MOUNT" /usr/bin/id -nG admin | tr ' ' '\n' | grep -qx audio
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:225: umount "$MOUNT/boot/efi"
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:227: umount "$MOUNT"
/home/yrslf/alpbahOS-claude/scripts/build-m2-gen2-test-image.sh:236: rm -f -- "$RAW"
/home/yrslf/alpbahOS-claude/scripts/build-m2-test-snd-aloop-module.sh:6: # Builder rootfs. Compilation runs as LFS (UID 1001) inside /mnt/lfs chroot;
/home/yrslf/alpbahOS-claude/scripts/build-m2-test-snd-aloop-module.sh:7: # installation and depmod run as root inside that same chroot.
/home/yrslf/alpbahOS-claude/scripts/build-m2-test-snd-aloop-module.sh:23:         umount -R -- "${MOUNTED[$i]}"
/home/yrslf/alpbahOS-claude/scripts/build-m2-test-snd-aloop-module.sh:37: if ps -eo comm= | grep -Eq '^(make|ninja|cmake|chroot)$'; then
/home/yrslf/alpbahOS-claude/scripts/build-m2-test-snd-aloop-module.sh:38:     echo 'Another build/chroot process is active; refusing to proceed.' >&2
/home/yrslf/alpbahOS-claude/scripts/build-m2-test-snd-aloop-module.sh:46:     echo 'An existing mount is present below /mnt/lfs; refusing to alter it.' >&2
/home/yrslf/alpbahOS-claude/scripts/build-m2-test-snd-aloop-module.sh:58:         echo "Unexpected pre-existing mount: $target" >&2
/home/yrslf/alpbahOS-claude/scripts/build-m2-test-snd-aloop-module.sh:61:     mount --rbind "$source" "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m2-test-snd-aloop-module.sh:62:     mount --make-rslave "$target"
/home/yrslf/alpbahOS-claude/scripts/build-m2-test-snd-aloop-module.sh:72:     chroot --userspec=1001:1001 "$ROOTFS" /usr/bin/env -i \
/home/yrslf/alpbahOS-claude/scripts/build-m2-test-snd-aloop-module.sh:86: chroot "$ROOTFS" /sbin/depmod -a "$KERNEL_RELEASE"
/home/yrslf/alpbahOS-claude/scripts/build-m2-test-snd-aloop-module.sh:90: chroot "$ROOTFS" /sbin/modinfo "/lib/modules/$KERNEL_RELEASE/$MODULE_REL" \
/home/yrslf/alpbahOS-claude/scripts/capture-m04-install-event.py:7: integration must still verify those mount restrictions and trace coverage before
/home/yrslf/alpbahOS-claude/scripts/capture-m04-install-event.py:47:     "splice", "mmap", "mount", "umount2",
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-autoseat.sh:13: cleanup() { set +e; ((MOUNTED)) && umount "$MOUNT"; ((ATTACHED)) && qemu-nbd --disconnect "$NBD" >/dev/null 2>&1; rm -rf -- "$WORK"; }
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-autoseat.sh:23: mkdir -p "$MOUNT"; mount "${NBD}p2" "$MOUNT"; MOUNTED=1
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-autoseat.sh:46: sync; umount "$MOUNT"; MOUNTED=0; qemu-nbd --disconnect "$NBD"; ATTACHED=0
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-dbus-and-dri.sh:25:     if (( ROOT_MOUNTED )); then umount "$MOUNT"; fi
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-dbus-and-dri.sh:27:     rm -rf -- "$WORK"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-dbus-and-dri.sh:43: mount "${NBD}p2" "$MOUNT"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-dbus-and-dri.sh:88: umount "$MOUNT"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-dns-and-admin.sh:21:     if (( ROOT_MOUNTED )); then umount "$MOUNT"; fi
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-dns-and-admin.sh:23:     rm -rf -- "$WORK"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-dns-and-admin.sh:37: mount "${NBD}p2" "$MOUNT"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-dns-and-admin.sh:57:     chroot "$MOUNT" /usr/sbin/useradd -m -u 1001 -g users -G wheel -s /bin/bash admin
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-dns-and-admin.sh:59: [credential-adjacent line redacted; calls=chroot]
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-dns-and-admin.sh:69: umount "$MOUNT"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-efi.sh:17:     if (( EFI_MOUNTED )); then umount "$MOUNT/boot/efi"; fi
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-efi.sh:18:     if (( ROOT_MOUNTED )); then umount "$MOUNT"; fi
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-efi.sh:20:     rm -rf -- "$WORK"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-efi.sh:37: mount "${NBD}p2" "$MOUNT"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-efi.sh:39: mount "${NBD}p1" "$MOUNT/boot/efi"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-efi.sh:55: umount "$MOUNT/boot/efi"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-efi.sh:57: umount "$MOUNT"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-login-and-alp.sh:19:     if (( ROOT_MOUNTED )); then umount "$MOUNT"; fi
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-login-and-alp.sh:21:     rm -rf -- "$WORK"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-login-and-alp.sh:40: mount "${NBD}p2" "$MOUNT"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-login-and-alp.sh:61: umount "$MOUNT"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-root-partuuid.sh:20:     if (( EFI_MOUNTED )); then umount "$MOUNT/boot/efi"; fi
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-root-partuuid.sh:21:     if (( ROOT_MOUNTED )); then umount "$MOUNT"; fi
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-root-partuuid.sh:23:     rm -rf -- "$WORK"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-root-partuuid.sh:46: mount "${NBD}p2" "$MOUNT"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-root-partuuid.sh:48: mount "${NBD}p1" "$MOUNT/boot/efi"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-root-partuuid.sh:72: umount "$MOUNT/boot/efi"
/home/yrslf/alpbahOS-claude/scripts/patch-m2-gen2-root-partuuid.sh:74: umount "$MOUNT"
/home/yrslf/alpbahOS-claude/scripts/provision-m2-test-user.sh:53:     chroot "$ROOTFS" /usr/sbin/usermod -aG wheel sa
/home/yrslf/alpbahOS-claude/scripts/provision-m2-test-user.sh:63:     chroot "$ROOTFS" /usr/sbin/useradd -m -u "$SA_UID" -g users -G wheel -s /bin/bash sa
/home/yrslf/alpbahOS-claude/scripts/provision-m2-test-user.sh:66: [credential-adjacent line redacted; calls=chroot]
/home/yrslf/alpbahOS-claude/scripts/resume-m04-acl-stage.sh:49:   for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do umount "${MOUNTS[$i]}" || status=1; done
/home/yrslf/alpbahOS-claude/scripts/resume-m04-acl-stage.sh:148: bind_mount() { local src=$1 dst=$2; if mountpoint -q "$dst"; then echo "Refusing pre-existing mount: $dst" >&2; return 1; fi; mount --bind "$src" "$dst"; MOUNTS+=("$dst"); }
/home/yrslf/alpbahOS-claude/scripts/resume-m04-acl-stage.sh:150: chroot "$LFS" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=C.UTF-8 BUILD_CHROOT="$BUILD_CHROOT" /bin/bash --noprofile --norc -c 'cd "$BUILD_CHROOT" && make DESTDIR="/tmp/alp-m04-acl-stage-20260924-r2" install' 2>&1 | tee -a "$LOG"
/home/yrslf/alpbahOS-claude/scripts/resume-m04-acl-stage.sh:155: if chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" /usr/bin/ldd "$STAGE_CHROOT/usr/lib/libacl.so.1" > "$DEPENDENCY_RESOLUTION" 2>&1; then :; else cat "$DEPENDENCY_RESOLUTION" >&2; exit 1; fi
/home/yrslf/alpbahOS-claude/scripts/resume-m04-acl-stage.sh:158: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" LD_DEBUG=libs /bin/bash --noprofile --norc -c "'$STAGE_CHROOT/usr/bin/setfacl' -m u:1001:r-- '/tmp/alp-m04-acl-smoke-file-20260924-r2' && '$STAGE_CHROOT/usr/bin/getfacl' -ncp '/tmp/alp-m04-acl-smoke-file-20260924-r2' | grep -Fqx 'user:1001:r--'" 2> "$SMOKE_TRACE"
/home/yrslf/alpbahOS-claude/scripts/resume-m04-acl-stage.sh:161: rm -f "$SMOKE_FILE"
/home/yrslf/alpbahOS-claude/scripts/validate-m04-acl-stage.sh:69:   if (( SMOKE_CREATED )); then rm -f "$SMOKE_FILE" || status=1; fi
/home/yrslf/alpbahOS-claude/scripts/validate-m04-acl-stage.sh:104:   mount_sources=$(findmnt -rn -o SOURCE) || { echo 'Cannot read mount sources' >&2; return 1; }
/home/yrslf/alpbahOS-claude/scripts/validate-m04-acl-stage.sh:174: if chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" /lib64/ld-linux-x86-64.so.2 --list "$STAGE_CHROOT/usr/bin/setfacl" > "$DEPENDENCY_RESOLUTION" 2>&1; then :; else cat "$DEPENDENCY_RESOLUTION" >&2; exit 1; fi
/home/yrslf/alpbahOS-claude/scripts/validate-m04-acl-stage.sh:179: chroot "$LFS" /usr/bin/env -i PATH=/usr/bin:/usr/sbin:/bin:/sbin LD_LIBRARY_PATH="$STAGE_CHROOT/usr/lib:$ATTR_STAGE_CHROOT/usr/lib" LD_DEBUG=libs /bin/bash --noprofile --norc -c "'$STAGE_CHROOT/usr/bin/setfacl' -m u:1001:r-- '/tmp/alp-m04-acl-smoke-file-validation-$RUN_ID' && '$STAGE_CHROOT/usr/bin/getfacl' -ncp '/tmp/alp-m04-acl-smoke-file-validation-$RUN_ID' | grep -Fqx 'user:1001:r--'" 2> "$SMOKE_TRACE"
```

## Dokümanların okuma kimliği

- `/home/yrslf/alpbahOS/AGENTS.md`: 9507 byte; sha256 `cca03405244a06df9d5e7c881224f0b3047507b729ca03f2c2e65614200ff760`
- `/home/yrslf/alpbahOS/docs/AGENT_STANDING_RULES.md`: 5587 byte; sha256 `9bd3c885264f0db9c0308ba4ecd92eb2359b338805815520e630f964f32bbbd3`
- `/home/yrslf/alpbahOS/docs/DECISIONS.md`: 16504 byte; sha256 `fae0356cbf4204e555ee281083b46c189f04936201bc1db568d424e45e0ec168`
- `/home/yrslf/alpbahOS/docs/MASTER_PLAN.md`: 48247 byte; sha256 `c4a1929e0159158c7df841e84150121c0ae58bbd3e4d21f36520e9d86f59e839`
- `/home/yrslf/alpbahOS/CURRENT.md`: 100528 byte; sha256 `928a0c38a0eb73769cf70490618b444a2856520329a6988b1073b122072ff918`
- `/home/yrslf/alpbahOS/docs/WORKLOG.md`: 496631 byte; sha256 `16ae72891aed952bc5d37a71170fda0e7a7fe9ffa2195b5772336c751d44ebba`
- `/home/yrslf/alpbahOS/docs/NEW_SESSION_HANDOFF.md`: 47627 byte; sha256 `93045d120e0d375908b316cbfd83b59492e00ac1f0693067fa113d8008a9eb6d`
- `/home/yrslf/alpbahOS/docs/AI_ENVIRONMENT_GUIDE.md`: 7567 byte; sha256 `84fa94099ec420bca95b2f5c9702bfd8fd85b7a8a8e762e638f3c285a838913e`
- `/home/yrslf/alpbahOS-claude/AGENTS.md`: 8952 byte; sha256 `d2e39d1fc2b96265dc55105774dfe924a6cf9d309b3254011ebf7638109b7e59`
- `/home/yrslf/alpbahOS-claude/docs/handoffs/claude/017-codex-betik-incelemesi.md`: 9052 byte; sha256 `3359757a976d90ddded5ae6cb98032ebbabd791090caef15bdd36ddda02d329c`
- `/home/yrslf/alpbahOS-claude/docs/handoffs/claude/018-mantik-hatalari-ve-pkg02.md`: 5556 byte; sha256 `16ff6e5b367c1f3da2caf956fa26f24b99b31e25f1577b770185f6bdd292a501`

## Depo ve süreç özeti

```text
/home/yrslf/alpbahOS dirty entries=342
/home/yrslf/alpbahOS-claude dirty entries=0
4151 claude cwd=/home/yrslf
7717 codex cwd=/home/yrslf
8322 codex cwd=/usr/lib/chatgpt/resources
```
Claude aktif; cwd home olduğundan main ağacını kullanmadığı ispatlanamaz. Kirli snapshot alınmayacak. Git içeriğinde sır olmadığı garanti edilmez; aday adı/boyutu tarandı, içerik veya anahtar basılmadı.

## Mevcut ISO envanteri (hash hesaplanmadı)

```text
/home/yrslf/alpbahOS-nvme/m10-alpha-20260930T/alpbahOS-live-m10-m08-depends.iso 2339700736 bytes
/home/yrslf/alpbahOS-nvme/m10-alpha-20260930T/alpbahOS-live-m10-pk-c-backend.iso 2339700736 bytes
/home/yrslf/alpbahOS-nvme/m10-alpha-20260930T/alpbahOS-live-m10-pk-liveauth.iso 2339700736 bytes
/home/yrslf/alpbahOS-nvme/m10-alpha-20260930T/alpbahOS-live-m10-pk-safe-path.iso 2339700736 bytes
/home/yrslf/alpbahOS-nvme/m10-alpha-20260930T/alpbahOS-live-m10-pk-sim-helper.iso 2339700736 bytes
/home/yrslf/alpbahOS-nvme/m10-alpha-20260930T/alpbahOS-live-m10-pk-sim-safe.iso 2339704832 bytes
/home/yrslf/alpbahOS-nvme/m10-alpha-20260930T/alpbahOS-live-m10.iso 2339655680 bytes
```

## Aktif ve aday Alp DB/ledger salt okunur kontrolü

```text
/mnt/lfs/var/lib/alp/db.json: [Errno 2] No such file or directory: '/mnt/lfs/var/lib/alp/db.json'
/home/yrslf/alpbahOS-nvme/m10-alpha-20260930T/rootfs/var/lib/alp/db.json: [Errno 2] No such file or directory: '/home/yrslf/alpbahOS-nvme/m10-alpha-20260930T/rootfs/var/lib/alp/db.json'
```

MLFS keşif URL: https://www.linuxfromscratch.org/mlfs/view/
```text
HTTP 200

```

## Faz 0 değerlendirme

- Fedora 44 KDE, Ryzen 7 5700, 8C/16T, ~23 GiB RAM ve /dev/kvm erişimi doğrulandı. Başlangıçta RAM available ~17 GiB; masaüstü 9 GiB iddiası bu örnekte doğrulanmadı. CPU Tctl 38.2°C; yük ölçümü değil.
- SSD /dev/sda1 Btrfs: 70 GiB boş; HDD /dev/sdb1 ext4: 128 GiB boş; host NVMe: 109 GiB boş. Veri alt yollarının bir kısmı SSD’den bind edilmiş: yeni cache/artifact yolu ayrı olacak. Eski /mnt/lfs SSD Btrfs köküdür; tarihsel ext4 varsayımı güncel değil.
- ~/cl-ssd yok; ~/alpbahOS-vm-tests boş. ~/alpbahOS-nvme altında builds/m07, d34-candidates ve m10-alpha-20260930T var. ISO adayları mevcut; sıfırdan tekrar üretilebilirlik veya checksum kabulü verilmedi.
- main HEAD a9bac38544955c30c146c175760195ff193a0b76; 342 kirli kayıt. Çalışan Claude PID 4151 cwd /home/yrslf: main’i kullanmadığı ispatlanamaz, kirli snapshot yok. HEAD/dal değiştirilmeyecek; worktree temiz committen ayrılacak.
- CURRENT çalışma kopyası 30 Eylül güncellemelerini içeriyor; 26 Eylül’de kalmış iddiası çalışma kopyası için yanlış. Commitlenmiş main ile kirli dosyalar birbirine karıştırılmamalı.
- D34 79/79 kapandığına dair 30 Eylül raporları var. Eski aktif Alp DB, D34 ledger, ISO sahipliği ve kaynak→build tekrar üretimi ayrı ölçütlerdir; biri diğerini kanıtlamaz.
- KWin servis dosyası mevcut, rpm -V kwin çıktı boş. Geçmiş silinme/host root runner nedeni kanıtlanmadı.
- rpm -Va exit 1, 1921 satır. Permission denied olmayan gerçek missing satırı yok. Repo/config mtime/hash ve runtime dizin metadata farkları var. Bu yetkisiz tarama temiz host kabulü değildir; privileged baseline kullanıcı tarafından sağlanmalı.
- dmesg yetkisiz erişime kapalı; journalctl -k okunabilen kapsam ve ham hata çıktısı yukarıda. MCE temizliği tam olarak kabul edilmedi. stress-ng ve rasdaemon PATH’te yok; host paketi kurulmadı.
- Yeni kullanıcı talimatı VM’de root build şartını getiriyor; AGENTS/standing/AI guide’ın host chroot/bind maddeleri bu görev için geçersiz. Windows/Hyper-V bağlantısı denenmedi.
- 017/018 incelemesi okundu: sessiz Alp downgrade, etkisiz ! guard, writer lock, build path ve imajda yerinde değişiklik riskleri. Eski betikler yeni VM entrypoint’ten çağrılmayacak. alp.py ve Claude profilleri değiştirilmeyecek.
- Temizlik önerisi: birden çok M09/M10 ISO ve eski kaynak/build/snapshot kopyası önce inode/backing/mount bağlarıyla envantere alınmalı; ancak kullanıcı onayından sonra arşiv planı uygulanmalı. Hiçbir mevcut imaj/dizin silinmedi veya taşınmadı.
