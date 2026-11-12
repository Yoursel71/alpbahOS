#!/usr/bin/env python3
"""NVIDIA-PKG-01 (D165): stage an extracted NVIDIA driver package for alp's `nvidia` recipe.

Runs as the recipe's make_install step inside alp's build sandbox (unprivileged build user, no network):
    nvidia-stage.py <extracted-dir> <destdir> <kernel-release>
It reads <extracted-dir>/.manifest (the file list of NVIDIA's own installer) and copies the 64-bit files the
alpbahOS desktop needs into <destdir>, plus the kernel modules built from kernel-open/ and the alpbahOS config files.

Fail closed: every manifest type is either in INSTALL (with its destination) or in SKIP (with the reason); a type in
neither stops the build, so a new driver cannot silently drop a file it needs. 32-bit (COMPAT32) entries are skipped
as a whole: the image has no 32-bit libglvnd yet (STEAM-01).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

LIB = "usr/lib"
# type -> how to place it. "lib": /usr/lib[/<subdir>]; "dir:<path>": a fixed directory; special handlers by name.
INSTALL = {
    "OPENGL_LIB": "lib", "OPENGL_SYMLINK": "lib", "TLS_LIB": "lib",
    "UTILITY_LIB": "lib", "UTILITY_LIB_SYMLINK": "lib",
    "CUDA_LIB": "lib", "CUDA_SYMLINK": "lib",
    "NVCUVID_LIB": "lib", "NVCUVID_LIB_SYMLINK": "lib",
    "ENCODEAPI_LIB": "lib", "ENCODEAPI_LIB_SYMLINK": "lib",
    "OPENCL_LIB": "lib", "OPENCL_LIB_SYMLINK": "lib",
    "VDPAU_LIB": "lib", "VDPAU_SYMLINK": "lib",
    "GLVND_EGL_ICD_JSON": "dir:usr/share/glvnd/egl_vendor.d",
    "EGL_EXTERNAL_PLATFORM_JSON": "dir:usr/share/egl/egl_external_platform.d",
    "CUDA_ICD": "dir:etc/OpenCL/vendors",
    "APPLICATION_PROFILE": "dir:usr/share/nvidia",
    "SANDBOXUTILS_FILELIST_JSON": "dir:usr/share/nvidia/files.d",
    "WINE_LIB": "dir:usr/lib/nvidia/wine",
    "SYSTEMD_UNIT": "dir:usr/lib/systemd/system",
    "SYSTEMD_SLEEP_SCRIPT": "dir:usr/lib/systemd/system-sleep",
    "UTILITY_BINARY": "dir:usr/bin",
    "NVIDIA_MODPROBE": "dir:usr/bin",
    "GBM_BACKEND_LIB_SYMLINK": "gbm",
    "VULKAN_ICD_JSON": "vulkan",
    "FIRMWARE": "firmware",
    "SYSTEMD_UNIT_SYMLINK": "wants",
    "OPENGL_DATA": "explicit", "EXPLICIT_PATH": "explicit",
    "DOT_DESKTOP": "desktop", "ICON": "icon",
}
SKIP = {
    "KERNEL_MODULE_SRC": "built here from kernel-open/, the sources are not installed",
    "DOCUMENTATION": "documentation", "MANPAGE": "man pages", "NVIDIA_MODPROBE_MANPAGE": "man page",
    "GLVND_LIB": "libglvnd is its own alpbahOS record (MESA-01)", "GLVND_SYMLINK": "libglvnd record",
    "GLX_CLIENT_LIB": "libglvnd record", "GLX_CLIENT_SYMLINK": "libglvnd record",
    "EGL_CLIENT_LIB": "libglvnd record", "EGL_CLIENT_SYMLINK": "libglvnd record",
    "OPENCL_WRAPPER_LIB": "no OpenCL ICD loader packaged yet", "OPENCL_WRAPPER_SYMLINK": "no OpenCL ICD loader",
    "XMODULE_SHARED_LIB": "Xorg driver: the session is Wayland", "GLX_MODULE_SHARED_LIB": "Xorg GLX module",
    "GLX_MODULE_SYMLINK": "Xorg GLX module", "XORG_OUTPUTCLASS_CONFIG": "Xorg configuration",
    "INSTALLER_BINARY": "nvidia-installer is not used", "UTILITY_BIN_SYMLINK": "nvidia-uninstall -> installer",
    "INTERNAL_UTILITY_BINARY": "installer internals", "INTERNAL_UTILITY_LIB": "installer internals",
    "INTERNAL_UTILITY_DATA": "installer internals", "DKMS_CONF": "no DKMS (alp rebuilds the recipe)",
    "VULKANSC_ICD_JSON": "Vulkan SC (safety-critical) is not used",
}
SKIP_FILES = {"nvidia-xconfig": "Xorg configuration tool", "libnvidia-gtk2.so": "GTK 2 is not in the image"}
MODPROBE = """# alpbahOS NVIDIA package (alp recipe nvidia, D165): nouveau stays off while this package is installed;
# 'alp remove nvidia' removes this file and nouveau comes back after a reboot.
blacklist nouveau
options nouveau modeset=0
options nvidia-drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
"""
MODULES_LOAD = "# alpbahOS NVIDIA package: KMS driver early for the Wayland session\nnvidia-drm\n"
UDEV = """# alpbahOS NVIDIA package: the /dev/nvidia* nodes (nvidia-modprobe runs as root from udev; it is not setuid).
ACTION=="add|bind", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", DRIVER=="nvidia", \\
    TEST!="/dev/nvidia-uvm", RUN+="/usr/bin/nvidia-modprobe", RUN+="/usr/bin/nvidia-modprobe -c0 -u"
"""


class StageError(RuntimeError):
    pass


def parse_manifest(text: str) -> tuple[str, list[list[str]]]:
    lines = text.splitlines()
    if len(lines) < 9:
        raise StageError("manifest too short")
    version = lines[1].strip()
    entries = [l.split() for l in lines[8:] if l.strip()]
    return version, entries


def _args(entry: list[str]) -> list[str]:
    return [a for a in entry[3:] if not a.startswith(("MODULE:", "INHERIT_PATH_DEPTH:")) and a not in ("NATIVE",)]


def _put_file(src: Path, dst: Path, mode: int) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    os.chmod(dst, mode)


def _put_link(dst: Path, target: str) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.is_symlink() or dst.exists():
        dst.unlink()
    os.symlink(target, dst)


def stage(ext: Path, dest: Path, kver: str) -> list[str]:
    version, entries = parse_manifest((ext / ".manifest").read_text())
    log: list[str] = []
    for e in entries:
        path, perm, kind = e[0], e[1], e[2]
        if "COMPAT32" in e[3:]:
            continue
        if kind in SKIP:
            continue
        if kind not in INSTALL:
            raise StageError(f"unknown manifest type {kind} for {path}: refusing to guess (update nvidia-stage.py)")
        name = os.path.basename(path)
        if name in SKIP_FILES or any(name.startswith(k) for k in SKIP_FILES if k.endswith(".so")):
            continue
        how = INSTALL[kind]
        args = _args(e)
        mode = int(perm, 8) & 0o755  # never setuid/setgid (nvidia-modprobe is 04755 upstream)
        is_link = kind.endswith("SYMLINK")
        if how == "lib":
            sub = ""
            if args and args[0].endswith("/"):
                sub = "" if args[0] == "/" else args[0].strip("/")
                args = args[1:]
            dst = dest / LIB / sub / name
            if is_link:
                if not args:
                    raise StageError(f"symlink without target: {path}")
                _put_link(dst, args[-1])
            else:
                _put_file(ext / path, dst, mode)
        elif how.startswith("dir:"):
            dst = dest / how[4:] / name
            if kind == "SYSTEMD_UNIT" or kind == "SYSTEMD_SLEEP_SCRIPT":
                mode = 0o644 if kind == "SYSTEMD_UNIT" else 0o755
            _put_file(ext / path, dst, mode)
        elif how == "gbm":
            _put_link(dest / LIB / "gbm" / name, "../" + args[-1])
        elif how == "vulkan":
            sub = args[0].strip("/") if args else "icd.d"
            _put_file(ext / path, dest / "usr/share/vulkan" / sub / name, 0o644)
        elif how == "firmware":
            _put_file(ext / path, dest / "usr/lib/firmware/nvidia" / version / name, 0o644)
        elif how == "wants":
            _put_link(dest / "usr/lib/systemd/system" / args[0] / name, "../" + name)
        elif how == "explicit":
            if not args or not args[0].startswith("/"):
                raise StageError(f"{kind} without an absolute directory: {path}")
            _put_file(ext / path, dest / args[0].lstrip("/") / name, 0o644)
        elif how == "desktop":
            text = (ext / path).read_text().replace("__UTILS_PATH__", "/usr/bin").replace("__PIXMAP_PATH__", "/usr/share/pixmaps")
            dst = dest / "usr/share/applications" / name
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_text(text)
            os.chmod(dst, 0o644)
        elif how == "icon":
            sub = args[0].strip("/") if args else "128x128/apps"
            _put_file(ext / path, dest / "usr/share/icons/hicolor" / sub / name, 0o644)
        log.append(f"{kind} {path}")
    # kernel modules built from kernel-open/
    kos = sorted((ext / "kernel-open").glob("*.ko"))
    if not kos:
        raise StageError("no kernel modules in kernel-open/ (did the make step run?)")
    strip = shutil.which("strip")
    for ko in kos:
        dst = dest / "usr/lib/modules" / kver / "extra/nvidia" / ko.name
        _put_file(ko, dst, 0o644)
        if strip:
            subprocess.run([strip, "--strip-debug", str(dst)], check=False)  # an unstripped module still loads
        log.append(f"MODULE {ko.name}")
    for rel, text in (("usr/lib/modprobe.d/nvidia-alpbahos.conf", MODPROBE),
                      ("usr/lib/modules-load.d/nvidia-alpbahos.conf", MODULES_LOAD),
                      ("usr/lib/udev/rules.d/60-nvidia-alpbahos.rules", UDEV)):
        p = dest / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        os.chmod(p, 0o644)
    return log


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: nvidia-stage.py <extracted-dir> <destdir> <kernel-release>", file=sys.stderr)
        return 2
    try:
        log = stage(Path(argv[0]), Path(argv[1]), argv[2])
    except (StageError, OSError) as exc:
        print(f"nvidia-stage: {exc}", file=sys.stderr)
        return 1
    print(f"nvidia-stage: {len(log)} entries staged")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
