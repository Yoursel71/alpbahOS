#!/usr/bin/env python3
"""Reconcile successful, sequential D34 Btrfs package deltas into an ownership ledger.

The ledger is an event-derived record of which package changed each path. It
does not apply streams, inspect file contents, or claim that a rootfs is ready
for release. Failed/incomplete runs are ignored; successful runs must form one
gap-free chain in official LFS Chapter 8 order.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any


REPO = Path(__file__).resolve().parents[1]
EXPECTED_FS_UUID = "663b4a21-0364-4ee2-91cd-67d5994e9fe4"
EXPECTED_INITIAL_SUBVOL_UUID = "c205dbcb-bd1d-4c46-9150-03272bbbf8d6"
SYSTEM_ROOTS = {"bin", "boot", "etc", "home", "lib", "lib64", "opt", "root", "sbin", "usr", "var"}
CREATE_OPS = {"mkfile", "mkdir", "mknod", "mkfifo", "mksock", "symlink"}
DELETE_OPS = {"unlink", "rmdir"}
SUPPLEMENTAL_PACKAGES = {
    "libpciaccess": {
        "version": "0.18.1",
        "reason": "BLFS PCI access library required by the Mesa and Wayland graphics stack",
    },
    "libdrm": {
        "version": "2.4.125",
        "reason": "BLFS Direct Rendering Manager userspace library required by the Mesa graphics stack",
    },
    "wayland": {
        "version": "1.24.0",
        "reason": "BLFS Wayland compositor/client protocol library required by the Plasma session",
    },
    "wayland-protocols": {
        "version": "1.45",
        "reason": "BLFS Wayland protocol XML descriptions required by compositors and clients",
    },
    "libyaml": {
        "version": "0.2.5",
        "reason": "BLFS YAML parser library required by the Mesa build tools profile",
    },
    "Cython": {
        "version": "3.1.3",
        "reason": "BLFS Cython compiler required by the Mesa build-toolchain profile",
    },
    "Mako": {
        "version": "1.3.10",
        "reason": "BLFS Mako template engine required by the Mesa build-toolchain profile",
    },
    "PyYAML": {
        "version": "6.0.2",
        "reason": "BLFS PyYAML parser required by the Mesa build-toolchain profile",
    },
    "Mesa": {
        "version": "25.1.8",
        "reason": "BLFS Gallium softpipe EGL/GLES graphics stack for the alpbahOS Wayland desktop profile",
    },
    "freetype-bootstrap": {
        "version": "2.13.3",
        "reason": "BLFS bootstrap FreeType needed to build HarfBuzz and the font stack",
    },
    "harfbuzz": {
        "version": "11.4.1",
        "reason": "BLFS OpenType text shaping engine required by the alpbahOS font and Qt stacks",
    },
    "fontconfig": {
        "version": "2.17.1",
        "reason": "BLFS font discovery and configuration runtime for the alpbahOS graphical session",
    },
    "dejavu-fonts": {
        "version": "2.37",
        "reason": "DejaVu font family providing broad Latin and Turkish glyph coverage in the live desktop",
    },
    "libpng": {
        "version": "1.6.50",
        "reason": "BLFS PNG image codec required by Qt image formats and the alpbahOS desktop",
    },
    "QtBase": {
        "version": "6.9.2",
        "reason": "BLFS Qt Core/Gui/DBus/SQL base for the alpbahOS Wayland desktop and applications",
    },
    "CMake": {
        "version": "4.1.0",
        "reason": "BLFS CMake build system required for Qt, KDE Frameworks, and Plasma",
    },
    "sqlite-desktop": {
        "version": "3.50.4",
        "reason": "BLFS SQLite development runtime explicitly used by QtBase system-SQLite configuration",
    },
    "qtshadertools": {"version": "6.9.2", "reason": "BLFS Qt ShaderTools compiler support required by QtQuick and QtWayland"},
    "qtdeclarative": {"version": "6.9.2", "reason": "BLFS Qt QML/Quick runtime used by the Plasma Wayland desktop"},
    "qtwayland": {"version": "6.9.2", "reason": "BLFS Qt Wayland client platform plugin for the Plasma session"},
    "extra-cmake-modules": {
        "version": "6.17.0",
        "reason": "KDE Extra CMake Modules required to configure KDE Frameworks and Plasma",
    },
    "qtsvg": {
        "version": "6.9.2",
        "reason": "Qt SVG runtime and image-format plugin required by KDE Frameworks and desktop applications",
    },
    "qttools": {
        "version": "6.9.2",
        "reason": "Qt LinguistTools and translation utilities required by KDE Frameworks package configuration",
    },
    "linux-pam": {
        "version": "1.7.1",
        "reason": "BLFS 12.4 prerequisite required by the alpbahOS Systemd PAM/logind profile",
    },
    "hwdata": {
        "version": "0.398",
        "reason": "BLFS device ID database required by the alpbahOS desktop hardware profile",
    },
    "libdisplay-info": {
        "version": "0.3.0",
        "reason": "BLFS display information library required by the alpbahOS Wayland desktop profile",
    },
    "libnl": {
        "version": "3.11.0",
        "reason": "BLFS Netlink library used by the alpbahOS host/network management profile",
    },
    "alsa-lib": {
        "version": "1.2.14",
        "reason": "BLFS ALSA userspace library and UCM profiles required by the alpbahOS audio profile",
    },
    "libsndfile": {
        "version": "1.2.2",
        "reason": "BLFS audio-file codec library used by the alpbahOS PipeWire profile",
    },
    "lua": {
        "version": "5.4.8",
        "reason": "BLFS embedded Lua runtime required by the alpbahOS WirePlumber profile",
    },
    "pipewire": {
        "version": "1.4.7",
        "reason": "BLFS audio graph and user-session services for the alpbahOS audio profile",
    },
    "wireplumber": {
        "version": "0.5.10",
        "reason": "BLFS PipeWire session manager and user service for the alpbahOS audio profile",
    },
    "pcre2": {
        "version": "10.45",
        "reason": "BLFS PCRE2 runtime and development library required by GLib",
    },
    "glib": {
        "version": "2.84.4",
        "reason": "BLFS GLib/GIO runtime required by the alpbahOS session manager and desktop services",
    },
    "libunistring": {
        "version": "1.3",
        "reason": "BLFS Unicode string library required by libidn2 and the network stack",
    },
    "libidn2": {
        "version": "2.3.8",
        "reason": "BLFS internationalized domain-name library required by libpsl and cURL",
    },
    "libpsl": {
        "version": "0.21.5",
        "reason": "BLFS Public Suffix List library used by cURL and network clients",
    },
    "curl": {
        "version": "8.15.0",
        "reason": "BLFS cURL TLS/PSL-enabled network client for bootstrap and user-space transfers",
    },
    "ca-trust-stack": {
        "version": "libtasn1-4.20.0+which-2.23+make-ca-1.16.1+p11-kit-0.25.5",
        "reason": "BLFS Mozilla root CA store generation and p11-kit trust extraction stack",
    },
    "duktape": {
        "version": "2.7.0",
        "reason": "BLFS embeddable JavaScript runtime required by Polkit",
    },
    "polkit": {
        "version": "126",
        "reason": "BLFS authorization framework required by the desktop and PackageKit profile",
    },
    "pam-stack-config": {
        "version": "alpbahOS-1",
        "reason": "BLFS Linux-PAM service policy required by logind, login, and Polkit",
    },
    "libndp": {
        "version": "1.9",
        "reason": "BLFS Neighbor Discovery library required by NetworkManager IPv6 support",
    },
    "nspr": {
        "version": "4.37",
        "reason": "Mozilla portable runtime required by NSS",
    },
    "nss": {
        "version": "3.115.0",
        "reason": "Mozilla TLS and crypto libraries required by NetworkManager",
    },
    "nss-trust-integration": {
        "version": "alpbahOS-1",
        "reason": "BLFS p11-kit trust module integration for NSS-aware applications",
    },
    "wpa_supplicant": {
        "version": "2.11",
        "reason": "BLFS D-Bus-enabled Wi-Fi supplicant required by NetworkManager",
    },
    "networkmanager": {
        "version": "1.54.0",
        "reason": "BLFS system network manager for wired and wireless connectivity",
    },
    "libxslt": {
        "version": "1.1.43",
        "reason": "BLFS XML/XSLT tools required to generate NetworkManager build metadata",
    },
    "libxml2": {
        "version": "2.14.5",
        "reason": "BLFS XML parser prerequisite for libxslt and NetworkManager",
    },
    "plasma-wayland-protocols": {
        "version": "1.18.0",
        "reason": "Plasma Wayland protocol descriptions required by KF6 GUI integration and the Wayland desktop",
    },
    "xkeyboard-config": {
        "version": "2.45",
        "reason": "XKB keymap and rules data required by the Wayland keyboard runtime",
    },
    "libxkbcommon": {
        "version": "1.11.0",
        "reason": "Wayland keyboard keymap compilation/runtime and KF6 window-system development dependency",
    },
    "aspell": {
        "version": "0.60.8.1",
        "reason": "Spell-checking backend required by the KF6 Sonnet library and text applications",
    },
    "docbook-xml": {
        "version": "4.5",
        "reason": "DocBook XML DTD required by KDE documentation tools and generated manuals",
    },
    "docbook-xsl": {
        "version": "1.79.2",
        "reason": "DocBook XSL stylesheets required by KDocTools and KDE documentation builds",
    },
    "docbook-catalogs": {
        "version": "alpbahOS-1",
        "reason": "XML catalog routing for installed DocBook DTD and XSL resources",
    },
    "perl-uri": {
        "version": "5.32",
        "reason": "Perl URI::Escape module required to configure KDE KDocTools",
    },
    "breeze-icons": {
        "version": "6.17.0",
        "reason": "KF6 Breeze icon CMake package required by KIconThemes and the Plasma desktop icon profile",
    },
    "libogg": {"version": "1.3.6", "reason": "BLFS audio dependency for Vorbis and libcanberra notification sounds"},
    "libvorbis": {"version": "1.3.7", "reason": "BLFS Vorbis audio codec required by libcanberra"},
    "libcanberra": {"version": "0.30", "reason": "Sound event playback library required by KF6 KNotifications"},
    "qtmultimedia": {"version": "6.9.2", "reason": "Qt Multimedia module required to configure Qt TextToSpeech"},
    "qtspeech": {"version": "6.9.2", "reason": "Qt TextToSpeech CMake module required by KF6 KTextWidgets"},
    "libgpg-error": {"version": "1.55", "reason": "BLFS error-code library required by libgcrypt"},
    "libgcrypt": {"version": "1.11.2", "reason": "BLFS cryptography library required by KF6 KWallet"},
    "qca-qt6": {"version": "2.3.10", "reason": "Qt cryptography abstraction required by KF6 KWallet"},
    "qt5compat": {"version": "6.9.2", "reason": "Qt Core5Compat module required by QCA Qt 6"},
    "libsecret": {"version": "0.21.7", "reason": "Secret service API required by KF6 KWallet runtime"},
    "lmdb": {"version": "0.9.33", "reason": "LMDB database backend required by KF6 Baloo file indexing"},
    "libqrencode": {"version": "4.1.1", "reason": "QR encoding library required by KF6 Prison"},
    "libical": {"version": "3.0.20", "reason": "iCalendar protocol library required by KF6 KCalendarCore"},
}
KF6_PACKAGE_ORDER = json.loads((REPO / "scripts/kf6-d34-package-order.json").read_text(encoding="utf-8"))
PLASMA_PACKAGE_ORDER = json.loads((REPO / "scripts/plasma-d34-package-order.json").read_text(encoding="utf-8"))
SUPPLEMENTAL_PACKAGES.update({
    name: {
        "version": "6.17.0",
        "reason": "BLFS KDE Frameworks runtime/build module required by the Plasma desktop profile",
    }
    for name in KF6_PACKAGE_ORDER
})
SUPPLEMENTAL_PACKAGES.update({
    name: {
        "version": "6.4.4",
        "reason": "Wayland-only Plasma desktop component required by the M07 session profile",
    }
    for name in PLASMA_PACKAGE_ORDER
})
SUPPLEMENTAL_PACKAGES.update({
    "xtrans": {"version": "1.6.0", "reason": "X transport headers required to build libX11 for the Wayland screen locker"},
    "libX11": {"version": "1.8.12", "reason": "Xlib shared library required by the KScreenLocker greeter build"},
    "xcb-util-keysyms": {"version": "0.4.1", "reason": "XCB key symbol helper library required by KScreenLocker"},
    "xcb-util-wm": {"version": "0.4.2", "reason": "XCB ICCCM/EWMH libraries required to enable the KDE X11 compatibility module"},
    "kwindowsystem-x11": {"version": "6.17.0", "reason": "Rebuild KWindowSystem with its X11 compatibility module while preserving Wayland support for KScreenLocker"},
    "libXfixes": {"version": "6.0.1", "reason": "X Fixes client library required by KWindowSystem's X11 compatibility module"},
    "libXrender": {"version": "0.9.12", "reason": "X Render client library required by the Qt XCB platform plugin"},
    "xcb-util": {"version": "0.4.1", "reason": "Base XCB utility library required by the Qt XCB platform plugin"},
    "xcb-util-image": {"version": "0.4.1", "reason": "XCB image helpers required by the Qt XCB platform plugin"},
    "xcb-util-renderutil": {"version": "0.3.10", "reason": "XCB Render utility library required by the Qt XCB platform plugin"},
    "xcb-util-cursor": {"version": "0.1.6", "reason": "XCB cursor library required by the Qt XCB platform plugin"},
    "qtbase-xcb": {"version": "6.9.2", "reason": "Rebuild QtBase with its XCB platform plugin so KDE's X11 greeter module can compile alongside Wayland"},
    "libxkbcommon-x11": {"version": "1.11.0", "reason": "XKB X11 client library required by the Qt XCB platform plugin"},
})
SUPPLEMENTAL_PACKAGES["boost-headers"] = {
    "version": "1.89.0",
    "reason": "Boost headers required by Plasma Activities; no compiled Boost components are requested by its CMake configuration",
}
SUPPLEMENTAL_PACKAGES["qtsensors"] = {
    "version": "6.9.2",
    "reason": "Qt Sensors module required by the Wayland KWin compositor build",
}
SUPPLEMENTAL_PACKAGES["qtbase-xkbcommon"] = {
    "version": "6.9.2",
    "reason": "Rebuild existing QtBase with libxkbcommon support required by KWin input-method and keymap code",
}
SUPPLEMENTAL_PACKAGES.update({
    "libepoxy": {"version": "1.5.10", "reason": "OpenGL/EGL dispatch library required by KWin"},
    "libevdev": {"version": "1.13.4", "reason": "Linux evdev device abstraction required by libinput"},
    "mtdev": {"version": "1.1.7", "reason": "Multitouch device protocol library used by libinput"},
    "libinput": {"version": "1.29.1", "reason": "Wayland compositor input-device backend required by KWin"},
    "libxcvt": {"version": "0.1.3", "reason": "RandR-compatible modeline generation library required by KWin DRM output support"},
    "lcms2": {"version": "2.17", "reason": "Little CMS color management library required by KWin"},
    "xcb-proto": {"version": "1.17.0", "reason": "X protocol descriptions required to build libxcb headers used by KWin"},
    "util-macros": {"version": "1.20.2", "reason": "X.Org autoconf macros required by the X protocol development stack"},
    "xorgproto": {"version": "2024.1", "reason": "X protocol headers and xproto metadata required by libXau/libxcb"},
    "libXau": {"version": "1.0.12", "reason": "X authority client library required by libxcb"},
    "libxcb": {"version": "1.17.0", "reason": "XCB client headers required by common KWin sources in Wayland-only builds"},
})


class LedgerError(RuntimeError):
    pass


def _load_expected(path: Path) -> list[dict[str, str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    packages = data.get("packages")
    if not isinstance(packages, list) or not packages:
        raise LedgerError("expected Chapter 8 package manifest has no package list")
    rows = [{"name": entry.get("name"), "version": entry.get("version")} for entry in packages]
    names = [row["name"] for row in rows]
    if any(not isinstance(name, str) or not name for name in names) or len(set(names)) != len(names):
        raise LedgerError("expected Chapter 8 package names are invalid or duplicated")
    return rows


def _successes(run_root: Path) -> list[tuple[Path, dict[str, Any]]]:
    found: list[tuple[Path, dict[str, Any]]] = []
    for path in run_root.glob("*/status.json"):
        try:
            status = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise LedgerError(f"cannot read run status {path}: {exc}") from exc
        if status.get("schema") == "alpbahOS.d34-package-replay/v1" and status.get("result") == "PASS":
            found.append((path.parent, status))
    return sorted(found, key=lambda item: (item[1].get("run_id", ""), item[0].name))


def _select_ancestral_chain(runs: list[tuple[Path, dict[str, Any]]], terminal_run_id: str
                            ) -> tuple[list[tuple[Path, dict[str, Any]]], list[str]]:
    """Select the successful replay ancestry ending at one explicitly named run."""
    by_id = {status.get("run_id"): (path, status) for path, status in runs}
    if terminal_run_id not in by_id:
        raise LedgerError(f"terminal successful run not found: {terminal_run_id}")
    by_after = {
        status.get("after_readonly", {}).get("uuid", "").replace("-", "").lower(): (path, status)
        for path, status in runs
    }
    chain: list[tuple[Path, dict[str, Any]]] = []
    current = by_id[terminal_run_id]
    while True:
        chain.append(current)
        base_uuid = current[1].get("candidate", {}).get("subvolume_uuid", "").replace("-", "").lower()
        if base_uuid == EXPECTED_INITIAL_SUBVOL_UUID.replace("-", "").lower():
            break
        parent = by_after.get(base_uuid)
        if parent is None:
            raise LedgerError(f"cannot trace terminal run ancestry through base subvolume {base_uuid}")
        current = parent
        if len(chain) > len(runs):
            raise LedgerError("cycle detected while tracing terminal run ancestry")
    chain.reverse()
    chosen = {status.get("run_id") for _, status in chain}
    omitted = sorted(status.get("run_id", path.name) for path, status in runs
                     if status.get("run_id") not in chosen)
    return chain, omitted


def _check_chain(runs: list[tuple[Path, dict[str, Any]]], expected: list[dict[str, str]]) -> None:
    previous_path: str | None = None
    previous_uuid = EXPECTED_INITIAL_SUBVOL_UUID
    official_names: list[str] = []
    supplemental_names: list[str] = []
    expected_names = [package["name"] for package in expected]
    for run_dir, status in runs:
        if status.get("candidate", {}).get("filesystem_uuid") != EXPECTED_FS_UUID:
            raise LedgerError(f"wrong candidate filesystem in {run_dir.name}")
        candidate = status.get("candidate", {})
        if candidate.get("subvolume_uuid", "").replace("-", "").lower() != previous_uuid.replace("-", "").lower():
            raise LedgerError(f"candidate subvolume chain breaks at {run_dir.name}")
        if previous_path is not None and candidate.get("path") != previous_path:
            raise LedgerError(f"candidate path chain breaks at {run_dir.name}")
        base = status.get("base_readonly", {})
        after = status.get("after_readonly", {})
        if base.get("uuid") is None or after.get("uuid") is None:
            raise LedgerError(f"run lacks Btrfs snapshot identities: {run_dir.name}")
        package_name = status.get("package", "")
        if len(official_names) < len(expected_names) and package_name == expected_names[len(official_names)]:
            official_names.append(package_name)
        elif package_name in SUPPLEMENTAL_PACKAGES:
            next_package = expected_names[len(official_names)] if len(official_names) < len(expected_names) else None
            allowed_linux_pam = package_name == "linux-pam" and next_package == "systemd" and len(official_names) == 73
            allowed_post_lfs_hwdata = package_name == "hwdata" and len(official_names) == len(expected_names)
            allowed_post_lfs_libpciaccess = (package_name == "libpciaccess"
                                             and len(official_names) == len(expected_names)
                                             and "hwdata" in supplemental_names)
            allowed_post_lfs_libdrm = (package_name == "libdrm"
                                       and len(official_names) == len(expected_names)
                                       and "libpciaccess" in supplemental_names)
            allowed_post_lfs_wayland = (package_name == "wayland"
                                        and len(official_names) == len(expected_names)
                                        and "libdrm" in supplemental_names
                                        and "libxml2" in supplemental_names)
            allowed_post_lfs_wayland_protocols = (package_name == "wayland-protocols"
                                                  and len(official_names) == len(expected_names)
                                                  and "wayland" in supplemental_names)
            allowed_post_lfs_libyaml = (package_name == "libyaml"
                                        and len(official_names) == len(expected_names))
            allowed_post_lfs_cython = (package_name == "Cython"
                                       and len(official_names) == len(expected_names)
                                       and "libyaml" in supplemental_names)
            allowed_post_lfs_mako = (package_name == "Mako"
                                     and len(official_names) == len(expected_names)
                                     and "Cython" in supplemental_names)
            allowed_post_lfs_pyyaml = (package_name == "PyYAML"
                                       and len(official_names) == len(expected_names)
                                       and "libyaml" in supplemental_names
                                       and "Cython" in supplemental_names)
            allowed_post_lfs_mesa = (package_name == "Mesa"
                                     and len(official_names) == len(expected_names)
                                     and all(name in supplemental_names for name in
                                             ("libpciaccess", "libdrm", "wayland", "wayland-protocols",
                                              "libyaml", "Cython", "Mako", "PyYAML")))
            allowed_post_lfs_freetype_bootstrap = (
                package_name == "freetype-bootstrap"
                and len(official_names) == len(expected_names)
                and "Mesa" in supplemental_names
            )
            allowed_post_lfs_harfbuzz = (
                package_name == "harfbuzz"
                and len(official_names) == len(expected_names)
                and "freetype-bootstrap" in supplemental_names
            )
            allowed_post_lfs_fontconfig = (
                package_name == "fontconfig"
                and len(official_names) == len(expected_names)
                and "freetype-bootstrap" in supplemental_names
                and "harfbuzz" in supplemental_names
            )
            allowed_post_lfs_dejavu_fonts = (
                package_name == "dejavu-fonts"
                and len(official_names) == len(expected_names)
                and "fontconfig" in supplemental_names
            )
            allowed_post_lfs_libpng = (
                package_name == "libpng"
                and len(official_names) == len(expected_names)
                and "Mesa" in supplemental_names
            )
            allowed_post_lfs_qtbase = (
                package_name == "QtBase"
                and len(official_names) == len(expected_names)
                and all(name in supplemental_names for name in
                        ("Mesa", "wayland", "wayland-protocols", "freetype-bootstrap", "harfbuzz",
                         "fontconfig", "libpng"))
            )
            allowed_post_lfs_cmake = (
                package_name == "CMake"
                and len(official_names) == len(expected_names)
                and "Mesa" in supplemental_names
                and "libpng" in supplemental_names
            )
            allowed_post_lfs_sqlite = (
                package_name == "sqlite-desktop"
                and len(official_names) == len(expected_names)
                and "CMake" in supplemental_names
            )
            allowed_post_lfs_qtshadertools = (
                package_name == "qtshadertools" and len(official_names) == len(expected_names)
                and "QtBase" in supplemental_names and "CMake" in supplemental_names
            )
            allowed_post_lfs_qtdeclarative = (
                package_name == "qtdeclarative" and len(official_names) == len(expected_names)
                and "QtBase" in supplemental_names and "qtshadertools" in supplemental_names
            )
            allowed_post_lfs_qtwayland = (
                package_name == "qtwayland" and len(official_names) == len(expected_names)
                and "QtBase" in supplemental_names and "qtshadertools" in supplemental_names
                and "qtdeclarative" in supplemental_names and "Mesa" in supplemental_names
                and "wayland" in supplemental_names and "wayland-protocols" in supplemental_names
            )
            allowed_post_lfs_ecm = (
                package_name == "extra-cmake-modules"
                and len(official_names) == len(expected_names)
                and "CMake" in supplemental_names and "QtBase" in supplemental_names
                and "qtwayland" in supplemental_names
            )
            allowed_post_lfs_qtsvg = (
                package_name == "qtsvg"
                and len(official_names) == len(expected_names)
                and "CMake" in supplemental_names and "QtBase" in supplemental_names
                and "qtwayland" in supplemental_names
                and "extra-cmake-modules" in supplemental_names
            )
            allowed_post_lfs_qttools = (
                package_name == "qttools"
                and len(official_names) == len(expected_names)
                and "QtBase" in supplemental_names and "CMake" in supplemental_names
                and "qtsvg" in supplemental_names and "attica" in supplemental_names
            )
            allowed_post_lfs_qtmultimedia = (
                package_name == "qtmultimedia" and len(official_names) == len(expected_names)
                and "QtBase" in supplemental_names
            )
            allowed_post_lfs_qtspeech = (
                package_name == "qtspeech" and len(official_names) == len(expected_names)
                and "QtBase" in supplemental_names and "qtmultimedia" in supplemental_names
            )
            allowed_post_lfs_libgpg_error = (
                package_name == "libgpg-error" and len(official_names) == len(expected_names)
            )
            allowed_post_lfs_libgcrypt = (
                package_name == "libgcrypt" and len(official_names) == len(expected_names)
                and "libgpg-error" in supplemental_names
            )
            allowed_post_lfs_qca = (
                package_name == "qca-qt6" and len(official_names) == len(expected_names)
                and all(name in supplemental_names for name in ("QtBase", "CMake", "ca-trust-stack", "libgcrypt", "qt5compat"))
            )
            allowed_post_lfs_qt5compat = (
                package_name == "qt5compat" and len(official_names) == len(expected_names)
                and "QtBase" in supplemental_names
            )
            allowed_post_lfs_libsecret = (
                package_name == "libsecret" and len(official_names) == len(expected_names)
                and all(name in supplemental_names for name in ("glib", "libgcrypt"))
            )
            completed_kf6 = [name for name in KF6_PACKAGE_ORDER if name in supplemental_names]
            next_kf6 = KF6_PACKAGE_ORDER[len(completed_kf6)] if len(completed_kf6) < len(KF6_PACKAGE_ORDER) else None
            allowed_post_lfs_lmdb = (
                package_name == "lmdb" and len(official_names) == len(expected_names)
                and next_kf6 == "baloo" and "kfilemetadata" in supplemental_names
            )
            allowed_post_lfs_qrencode = (
                package_name == "libqrencode" and len(official_names) == len(expected_names)
                and next_kf6 == "prison" and "krunner" in supplemental_names
            )
            allowed_post_lfs_libical = (
                package_name == "libical" and len(official_names) == len(expected_names)
                and next_kf6 == "kcalendarcore" and "purpose" in supplemental_names
            )
            allowed_post_lfs_kf6 = (
                package_name == next_kf6
                and len(official_names) == len(expected_names)
                and all(name in supplemental_names for name in
                        ("QtBase", "qtwayland", "qtsvg", "extra-cmake-modules"))
                and (package_name == "attica" or "qttools" in supplemental_names)
                and (package_name != "ktextwidgets" or "qtspeech" in supplemental_names)
                and (package_name != "kwallet" or all(name in supplemental_names for name in ("libgpg-error", "libgcrypt", "qca-qt6", "qt5compat", "libsecret")))
                and (package_name != "kguiaddons" or "plasma-wayland-protocols" in supplemental_names)
                and (package_name != "kwindowsystem" or all(name in supplemental_names for name in
                                                             ("xkeyboard-config", "libxkbcommon")))
                and (package_name != "sonnet" or "aspell" in supplemental_names)
                and (package_name != "kdoctools" or all(name in supplemental_names for name in
                                                        ("docbook-xml", "docbook-xsl", "docbook-catalogs", "perl-uri")))
                and (package_name != "kiconthemes" or "breeze-icons" in supplemental_names)
                and (package_name != "knotifications" or all(name in supplemental_names for name in
                                                              ("libogg", "libvorbis", "libcanberra")))
                and (package_name != "baloo" or "lmdb" in supplemental_names)
                and (package_name != "prison" or "libqrencode" in supplemental_names)
                and (package_name != "kcalendarcore" or "libical" in supplemental_names)
            )
            completed_plasma = [name for name in PLASMA_PACKAGE_ORDER if name in supplemental_names]
            next_plasma = (PLASMA_PACKAGE_ORDER[len(completed_plasma)]
                           if len(completed_plasma) < len(PLASMA_PACKAGE_ORDER) else None)
            plasma_base_ready = (
                len(official_names) == len(expected_names)
                and all(name in supplemental_names for name in KF6_PACKAGE_ORDER)
                and all(name in supplemental_names for name in ("Mesa", "QtBase", "qtwayland", "plasma-wayland-protocols"))
            )
            plasma_requires = {
                "breeze": ("kdecoration",),
                "boost-headers": ("breeze",),
                "plasma-activities": ("boost-headers",),
                "kglobalacceld": (),
                "kwayland": (),
                "layer-shell-qt": ("kwayland",),
                "libplasma": ("kwayland",),
                "qtsensors": ("QtBase",),
                "libepoxy": ("qtsensors",),
                "libevdev": ("libepoxy",),
                "mtdev": ("libevdev",),
                "libinput": ("libevdev", "mtdev"),
                "libxcvt": ("libinput",),
                "lcms2": ("libxcvt",),
                "xcb-proto": ("lcms2",),
                "util-macros": ("xcb-proto",),
                "xorgproto": ("util-macros",),
                "libXau": ("xorgproto",),
                "libxcb": ("libXau",),
                "qtbase-xkbcommon": ("QtBase", "libxkbcommon", "libxcb"),
                "qtpositioning": ("QtBase",),
                "qtlocation": ("qtpositioning",),
                "qtwebsockets": ("QtBase",),
                "qcoro": ("QtBase", "qtdeclarative", "qtwebsockets"),
                "libkscreen": ("kwin", "qtwayland"),
                "plasma5support": ("libkscreen",),
                "plasma-activities-stats": ("plasma-activities",),
                "xtrans": ("xorgproto",),
                "libX11": ("xtrans", "libxcb"),
                "xcb-util-keysyms": ("libxcb",),
                "xcb-util-wm": ("libxcb",),
                "xcb-util": ("libxcb",),
                "xcb-util-image": ("xcb-util", "libxcb"),
                "xcb-util-renderutil": ("libxcb",),
                "xcb-util-cursor": ("xcb-util-image", "xcb-util-renderutil"),
                "libXrender": ("libX11",),
                "libXcursor": ("libXrender", "libXfixes"),
                "libxkbfile": ("libX11", "xorgproto"),
                "libgudev": ("libevdev",),
                "libwacom": ("libevdev", "libgudev"),
                "libxkbcommon-x11": ("libxkbcommon", "libxcb"),
                "libXfixes": ("libX11", "xorgproto"),
                "qtbase-xcb": ("QtBase", "qtbase-xkbcommon", "libX11", "libxcb", "xcb-util", "xcb-util-image", "xcb-util-keysyms", "xcb-util-renderutil", "xcb-util-cursor", "libXrender", "libXfixes", "libxkbcommon-x11"),
                "kwindowsystem-x11": ("kwindowsystem", "xcb-util-wm", "xcb-util-keysyms", "libX11", "libXfixes", "qtbase-xcb"),
                "kscreenlocker": ("kwin", "libkscreen", "plasma5support", "plasma-activities-stats", "libX11", "xcb-util-keysyms", "xcb-util-wm", "libXfixes", "kwindowsystem-x11", "qtbase-xcb"),
                "kwin": ("kdecoration", "breeze", "plasma-activities", "kglobalacceld", "kwayland", "layer-shell-qt", "libplasma", "qtsensors", "libepoxy", "libevdev", "mtdev", "libinput", "libxcvt", "lcms2", "xcb-proto", "libXau", "libxcb", "qtbase-xkbcommon"),
                "plasma-workspace": ("kwin", "qtlocation", "qcoro", "plasma5support", "plasma-activities-stats", "kscreenlocker"),
                "kactivitymanagerd": ("plasma-workspace",),
                "milou": ("plasma-workspace",),
                "plasma-integration": ("plasma-workspace", "libXcursor"),
                "plasma-desktop": ("plasma-workspace", "plasma-integration", "kactivitymanagerd", "libxkbfile", "libwacom"),
            }
            allowed_post_lfs_plasma = (
                package_name == next_plasma and plasma_base_ready
                and all(name in supplemental_names for name in plasma_requires.get(package_name, ()))
            )
            allowed_post_lfs_breeze_icons = (
                package_name == "breeze-icons" and len(official_names) == len(expected_names)
                and next_kf6 == "kiconthemes"
                and all(name in supplemental_names for name in ("kpackage", "kdesu"))
                and all(name in supplemental_names for name in ("QtBase", "qtwayland", "qtsvg", "extra-cmake-modules", "qttools"))
            )
            allowed_post_lfs_libogg = (
                package_name == "libogg" and len(official_names) == len(expected_names)
                and next_kf6 == "knotifications" and "kiconthemes" in supplemental_names
            )
            allowed_post_lfs_libvorbis = (
                package_name == "libvorbis" and len(official_names) == len(expected_names)
                and next_kf6 == "knotifications" and "kiconthemes" in supplemental_names
                and "libogg" in supplemental_names
            )
            allowed_post_lfs_libcanberra = (
                package_name == "libcanberra" and len(official_names) == len(expected_names)
                and next_kf6 == "knotifications" and "kiconthemes" in supplemental_names
                and all(name in supplemental_names for name in ("libogg", "libvorbis"))
            )
            allowed_post_lfs_plasma_protocols = (
                package_name == "plasma-wayland-protocols"
                and len(official_names) == len(expected_names)
                and all(name in supplemental_names for name in
                        ("QtBase", "qtwayland", "qtsvg", "extra-cmake-modules", "qttools", "attica"))
            )
            allowed_post_lfs_xkeyboard_config = (
                package_name == "xkeyboard-config" and len(official_names) == len(expected_names)
            )
            allowed_post_lfs_libxkbcommon = (
                package_name == "libxkbcommon" and len(official_names) == len(expected_names)
                and "xkeyboard-config" in supplemental_names
            )
            allowed_post_lfs_aspell = (
                package_name == "aspell" and len(official_names) == len(expected_names)
            )
            allowed_post_lfs_docbook_xml = (
                package_name == "docbook-xml" and len(official_names) == len(expected_names)
            )
            allowed_post_lfs_docbook_xsl = (
                package_name == "docbook-xsl" and len(official_names) == len(expected_names)
                and "docbook-xml" in supplemental_names
            )
            allowed_post_lfs_docbook_catalogs = (
                package_name == "docbook-catalogs" and len(official_names) == len(expected_names)
                and all(name in supplemental_names for name in ("docbook-xml", "docbook-xsl"))
            )
            allowed_post_lfs_perl_uri = (
                package_name == "perl-uri" and len(official_names) == len(expected_names)
                and all(name in supplemental_names for name in ("docbook-xml", "docbook-xsl", "docbook-catalogs"))
            )
            allowed_post_lfs_display = (package_name == "libdisplay-info"
                                        and len(official_names) == len(expected_names)
                                        and "hwdata" in supplemental_names)
            allowed_post_lfs_libnl = (package_name == "libnl"
                                      and len(official_names) == len(expected_names)
                                      and "hwdata" in supplemental_names)
            allowed_post_lfs_libndp = (package_name == "libndp"
                                       and len(official_names) == len(expected_names)
                                       and "libnl" in supplemental_names)
            allowed_post_lfs_nspr = (package_name == "nspr"
                                     and len(official_names) == len(expected_names))
            allowed_post_lfs_nss = (package_name == "nss"
                                    and len(official_names) == len(expected_names)
                                    and "nspr" in supplemental_names)
            allowed_post_lfs_nss_trust = (package_name == "nss-trust-integration"
                                          and len(official_names) == len(expected_names)
                                          and "nss" in supplemental_names
                                          and "ca-trust-stack" in supplemental_names)
            allowed_post_lfs_wpa = (package_name == "wpa_supplicant"
                                    and len(official_names) == len(expected_names)
                                    and "libnl" in supplemental_names
                                    and "nss" in supplemental_names
                                    and "nss-trust-integration" in supplemental_names)
            allowed_post_lfs_networkmanager = (package_name == "networkmanager"
                                               and len(official_names) == len(expected_names)
                                               and "libndp" in supplemental_names
                                               and "polkit" in supplemental_names
                                               and "nss-trust-integration" in supplemental_names
                                               and "wpa_supplicant" in supplemental_names
                                               and "libxslt" in supplemental_names)
            allowed_post_lfs_libxslt = (package_name == "libxslt"
                                        and len(official_names) == len(expected_names)
                                        and "libxml2" in supplemental_names)
            allowed_post_lfs_libxml2 = (package_name == "libxml2"
                                        and len(official_names) == len(expected_names))
            allowed_post_lfs_alsa = (package_name == "alsa-lib"
                                     and len(official_names) == len(expected_names)
                                     and "hwdata" in supplemental_names)
            allowed_post_lfs_sndfile = (package_name == "libsndfile"
                                        and len(official_names) == len(expected_names)
                                        and "alsa-lib" in supplemental_names)
            allowed_post_lfs_lua = (package_name == "lua"
                                    and len(official_names) == len(expected_names))
            allowed_post_lfs_pipewire = (package_name == "pipewire"
                                         and len(official_names) == len(expected_names)
                                         and "alsa-lib" in supplemental_names
                                         and "libsndfile" in supplemental_names)
            allowed_post_lfs_wireplumber = (package_name == "wireplumber"
                                            and len(official_names) == len(expected_names)
                                            and "pipewire" in supplemental_names
                                            and "lua" in supplemental_names
                                            and "glib" in supplemental_names)
            allowed_post_lfs_pcre2 = (package_name == "pcre2"
                                      and len(official_names) == len(expected_names))
            allowed_post_lfs_glib = (package_name == "glib"
                                     and len(official_names) == len(expected_names)
                                     and "pcre2" in supplemental_names)
            allowed_post_lfs_libunistring = (package_name == "libunistring"
                                             and len(official_names) == len(expected_names))
            allowed_post_lfs_libidn2 = (package_name == "libidn2"
                                        and len(official_names) == len(expected_names)
                                        and "libunistring" in supplemental_names)
            allowed_post_lfs_libpsl = (package_name == "libpsl"
                                       and len(official_names) == len(expected_names)
                                       and "libidn2" in supplemental_names)
            allowed_post_lfs_curl = (package_name == "curl"
                                     and len(official_names) == len(expected_names)
                                     and "libpsl" in supplemental_names)
            allowed_post_lfs_ca_trust = (package_name == "ca-trust-stack"
                                         and len(official_names) == len(expected_names)
                                         and "curl" in supplemental_names)
            allowed_post_lfs_duktape = (package_name == "duktape"
                                        and len(official_names) == len(expected_names))
            allowed_post_lfs_pam_config = (package_name == "pam-stack-config"
                                           and len(official_names) == len(expected_names))
            allowed_post_lfs_polkit = (package_name == "polkit"
                                       and len(official_names) == len(expected_names)
                                       and "glib" in supplemental_names
                                       and "duktape" in supplemental_names
                                       and "pam-stack-config" in supplemental_names)
            if not (allowed_linux_pam or allowed_post_lfs_hwdata or allowed_post_lfs_libpciaccess
                    or allowed_post_lfs_libdrm or allowed_post_lfs_wayland
                    or allowed_post_lfs_wayland_protocols or allowed_post_lfs_display
                    or allowed_post_lfs_libyaml or allowed_post_lfs_cython
                    or allowed_post_lfs_mako or allowed_post_lfs_pyyaml or allowed_post_lfs_mesa
                    or allowed_post_lfs_freetype_bootstrap
                    or allowed_post_lfs_harfbuzz
                    or allowed_post_lfs_fontconfig
                    or allowed_post_lfs_dejavu_fonts
                    or allowed_post_lfs_libpng
                    or allowed_post_lfs_qtbase
                    or allowed_post_lfs_cmake
                    or allowed_post_lfs_sqlite
                    or allowed_post_lfs_qtshadertools or allowed_post_lfs_qtdeclarative or allowed_post_lfs_qtwayland
                    or allowed_post_lfs_ecm or allowed_post_lfs_qtsvg or allowed_post_lfs_qttools
                    or allowed_post_lfs_qtmultimedia or allowed_post_lfs_qtspeech
                    or allowed_post_lfs_libgpg_error or allowed_post_lfs_libgcrypt
                    or allowed_post_lfs_qca
                    or allowed_post_lfs_qt5compat
                    or allowed_post_lfs_libsecret
                    or allowed_post_lfs_lmdb
                    or allowed_post_lfs_qrencode
                    or allowed_post_lfs_libical
                    or allowed_post_lfs_kf6
                    or allowed_post_lfs_plasma
                    or allowed_post_lfs_plasma_protocols
                    or allowed_post_lfs_xkeyboard_config or allowed_post_lfs_libxkbcommon
                    or allowed_post_lfs_aspell
                    or allowed_post_lfs_docbook_xml or allowed_post_lfs_docbook_xsl
                    or allowed_post_lfs_docbook_catalogs
                    or allowed_post_lfs_perl_uri
                    or allowed_post_lfs_breeze_icons
                    or allowed_post_lfs_libogg or allowed_post_lfs_libvorbis or allowed_post_lfs_libcanberra
                    or allowed_post_lfs_libnl or allowed_post_lfs_libndp or allowed_post_lfs_nspr
                    or allowed_post_lfs_nss or allowed_post_lfs_nss_trust or allowed_post_lfs_wpa
                    or allowed_post_lfs_networkmanager
                    or allowed_post_lfs_libxslt
                    or allowed_post_lfs_libxml2
                    or allowed_post_lfs_alsa or allowed_post_lfs_sndfile
                    or allowed_post_lfs_lua or allowed_post_lfs_pipewire or allowed_post_lfs_wireplumber
                    or allowed_post_lfs_pcre2 or allowed_post_lfs_glib
                    or allowed_post_lfs_libunistring or allowed_post_lfs_libidn2
                    or allowed_post_lfs_libpsl or allowed_post_lfs_curl or allowed_post_lfs_ca_trust
                    or allowed_post_lfs_duktape or allowed_post_lfs_pam_config
                    or allowed_post_lfs_polkit):
                raise LedgerError(f"supplemental package is not at its declared Chapter 8 prerequisite boundary: {run_dir.name}")
            if package_name in supplemental_names:
                raise LedgerError(f"duplicate supplemental package run: {run_dir.name}")
            supplemental_names.append(package_name)
        else:
            raise LedgerError(f"unexpected or out-of-order package run {package_name!r} in {run_dir.name}")
        previous_uuid = after["uuid"]
        previous_path = after.get("path")
        events_path = run_dir / "events.jsonl"
        if not events_path.is_file():
            raise LedgerError(f"event stream is missing for {run_dir.name}")
    if official_names != expected_names[: len(official_names)]:
        raise LedgerError(f"successful package runs are not a Chapter 8 prefix: {official_names}")
    if not official_names:
        raise LedgerError("no successful sequential package runs were found")


def _is_system_path(path: str) -> bool:
    return path != "." and path.split("/", 1)[0] in SYSTEM_ROOTS


def _event_paths(event: dict[str, Any]) -> list[str]:
    op = event.get("op")
    path = event.get("path")
    if not isinstance(path, str):
        return []
    paths = [path]
    if op == "rename" and isinstance(event.get("path_to"), str):
        paths.append(event["path_to"])
    return paths


def _build_ledger(runs: list[tuple[Path, dict[str, Any]]], expected: list[dict[str, str]]) -> dict[str, Any]:
    package_rows: list[dict[str, Any]] = []
    supplemental_rows: list[dict[str, Any]] = []
    final_owners: dict[str, str] = {}
    all_path_events = 0
    excluded_non_system = 0
    official_index = 0
    for run_dir, status in runs:
        deltas: dict[str, dict[str, Any]] = {}
        event_count = 0
        first_event: dict[str, Any] | None = None
        last_event: dict[str, Any] | None = None
        with (run_dir / "events.jsonl").open(encoding="utf-8") as source:
            for line_number, line in enumerate(source, 1):
                try:
                    record = json.loads(line)
                except json.JSONDecodeError as exc:
                    raise LedgerError(f"invalid event JSON {run_dir.name}:{line_number}: {exc}") from exc
                event_count += 1
                if first_event is None:
                    first_event = record
                last_event = record
                op = record.get("op")
                if op in {"snapshot", "end"}:
                    continue
                for relpath in _event_paths(record):
                    all_path_events += 1
                    if not _is_system_path(relpath):
                        excluded_non_system += 1
                        continue
                    item = deltas.setdefault(relpath, {"operations": Counter(), "first_sequence": record.get("sequence"),
                                                        "last_sequence": record.get("sequence"), "data_bytes": 0})
                    item["operations"][op] += 1
                    item["last_sequence"] = record.get("sequence")
                    item["data_bytes"] += int(record.get("data_bytes", 0))
                    package = status["package"]
                    if op == "rename":
                        prior_owner = final_owners.pop(record["path"], package)
                        final_owners[record["path_to"]] = prior_owner
                    elif op in CREATE_OPS or op in {"write", "encoded_write", "clone", "truncate", "link"}:
                        final_owners[relpath] = package
                    elif op in DELETE_OPS:
                        final_owners.pop(relpath, None)
        if event_count != status.get("event_count"):
            raise LedgerError(f"event count mismatch in {run_dir.name}: {event_count} != {status.get('event_count')}")
        normalize = lambda value: value.replace("-", "").lower() if isinstance(value, str) else value
        if (not first_event or first_event.get("op") != "snapshot"
                or normalize(first_event.get("uuid")) != normalize(status["after_readonly"]["uuid"])
                or normalize(first_event.get("clone_uuid")) != normalize(status["base_readonly"]["uuid"])
                or not last_event or last_event.get("op") != "end"):
            raise LedgerError(f"stream header/end identities mismatch in {run_dir.name}")
        package = status["package"]
        is_supplemental = package in SUPPLEMENTAL_PACKAGES
        row = {
            "package": package,
            "version": SUPPLEMENTAL_PACKAGES[package]["version"] if is_supplemental else expected[official_index]["version"],
            "run_id": status["run_id"], "base_uuid": status["base_readonly"]["uuid"],
            "after_uuid": status["after_readonly"]["uuid"], "btrfs_event_count": event_count,
            "system_path_count": len(deltas),
            "system_paths": [
                {"path": path, "operations": dict(sorted(item["operations"].items())),
                 "first_sequence": item["first_sequence"], "last_sequence": item["last_sequence"],
                 "data_bytes": item["data_bytes"]}
                for path, item in sorted(deltas.items())
            ],
        }
        if is_supplemental:
            row["reason"] = SUPPLEMENTAL_PACKAGES[package]["reason"]
            supplemental_rows.append(row)
        else:
            package_rows.append(row)
            official_index += 1
    return {
        "schema": "alpbahOS.d34-package-ownership-ledger/v1",
        "result": "COMPLETE" if len(package_rows) == len(expected) else "PARTIAL",
        "filesystem_uuid": EXPECTED_FS_UUID,
        "initial_subvolume_uuid": EXPECTED_INITIAL_SUBVOL_UUID,
        "expected_package_count": len(expected), "reconciled_package_count": len(package_rows),
        "remaining_package_count": len(expected) - len(package_rows),
        "supplemental_package_count": len(supplemental_rows),
        "path_event_count": all_path_events, "excluded_non_system_path_event_count": excluded_non_system,
        "final_system_path_owner_count": len(final_owners),
        "final_system_path_owners": dict(sorted(final_owners.items())),
        "packages": package_rows, "supplemental_runs": supplemental_rows,
        "limitations": [
            "Owners are inferred from sequential Btrfs create/write/delete events, not a privileged syscall trace.",
            "Only paths rooted under bin, boot, etc, home, lib, lib64, opt, root, sbin, usr, and var are listed.",
            "This ledger does not prove content equality, dependency correctness, bootability, or release acceptance.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-root", type=Path, default=Path("/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs"))
    parser.add_argument("--expected", type=Path, default=REPO / "docs/verification/manifests/lfs-base/m04-expected-chapter8-packages-12.4.json")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--terminal-run-id", help="reconcile only the successful ancestry ending at this run")
    parser.add_argument("--allow-partial", action="store_true")
    args = parser.parse_args()
    try:
        expected = _load_expected(args.expected)
        all_runs = _successes(args.run_root)
        omitted_runs: list[str] = []
        runs = all_runs
        if args.terminal_run_id:
            runs, omitted_runs = _select_ancestral_chain(all_runs, args.terminal_run_id)
        _check_chain(runs, expected)
        expected_names = {package["name"] for package in expected}
        official_count = sum(status.get("package") in expected_names for _, status in runs)
        if official_count != len(expected) and not args.allow_partial:
            raise LedgerError(f"only {official_count}/{len(expected)} packages reconciled; pass --allow-partial for an explicitly partial ledger")
        ledger = _build_ledger(runs, expected)
        if args.terminal_run_id:
            ledger["branch_selection"] = {"terminal_run_id": args.terminal_run_id,
                                          "omitted_successful_run_ids": omitted_runs}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(json.dumps({"result": ledger["result"], "reconciled": ledger["reconciled_package_count"],
                          "expected": ledger["expected_package_count"], "owned_paths": ledger["final_system_path_owner_count"],
                          "selected_runs": len(runs), "omitted_successful_runs": len(omitted_runs),
                          "output": str(args.output)}, sort_keys=True))
        return 0
    except (OSError, json.JSONDecodeError, LedgerError) as exc:
        print(f"d34-reconcile: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
