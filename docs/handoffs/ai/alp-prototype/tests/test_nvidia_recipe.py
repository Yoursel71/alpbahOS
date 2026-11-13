"""D165 (NVIDIA-PKG-01): the pieces of the `nvidia` recipe.

- helpers/nvidia-stage.py: places NVIDIA's files by its .manifest, fail-closed on an unknown type, never setuid,
  never NVIDIA's own libglvnd copies, no 32-bit files, plus the modules and the alpbahOS config files.
- alp recipes: "unpack": false keeps the downloaded file as it is (a self-extracting .run); @KERNEL_RELEASE@ and
  @KERNEL_BUILD@ come from ROOT/usr/lib/modules, never from the running kernel.
A real recipe install runs with the sandbox off here (test_trust_sandbox.py covers the sandbox itself).
"""

from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path

import pytest

import alp

HELPER = Path(__file__).resolve().parent.parent / "helpers" / "nvidia-stage.py"
spec = importlib.util.spec_from_file_location("nvidia_stage", HELPER)
ns = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ns)

HEADER = "NVIDIA Accelerated Graphics Driver for Linux-x86_64\n620.70.06\n \nnvidia nvidia-drm\n \n \n \n \n"
LINES = [
    "libGLX_nvidia.so.620.70.06 0755 OPENGL_LIB NATIVE MODULE:opengl",
    "libGLX_nvidia.so.0 0000 OPENGL_SYMLINK NATIVE libGLX_nvidia.so.620.70.06 MODULE:opengl",
    "./32/libGLX_nvidia.so.620.70.06 0755 OPENGL_LIB COMPAT32 MODULE:opengl",
    "libGL.so.1.7.0 0755 GLX_CLIENT_LIB NATIVE MODULE:opengl",
    "libEGL.so.1.1.0 0755 EGL_CLIENT_LIB NATIVE MODULE:opengl",
    "libGLdispatch.so.0 0755 GLVND_LIB NATIVE MODULE:opengl",
    "10_nvidia.json 0644 GLVND_EGL_ICD_JSON MODULE:opengl",
    "15_nvidia_gbm.json 0644 EGL_EXTERNAL_PLATFORM_JSON MODULE:egl",
    "libnvidia-allocator.so.620.70.06 0755 UTILITY_LIB NATIVE MODULE:nvalloc",
    "libnvidia-allocator.so.1 0000 UTILITY_LIB_SYMLINK NATIVE libnvidia-allocator.so.620.70.06 MODULE:nvalloc",
    "nvidia-drm_gbm.so 0000 GBM_BACKEND_LIB_SYMLINK NATIVE libnvidia-allocator.so.1 MODULE:nvalloc",
    "libnvidia-gtk2.so.620.70.06 0755 UTILITY_LIB NATIVE MODULE:xutils",
    "libvdpau_nvidia.so.620.70.06 0755 VDPAU_LIB NATIVE vdpau/ MODULE:vdpau",
    "libvdpau_nvidia.so 0000 VDPAU_SYMLINK NATIVE / vdpau/libvdpau_nvidia.so.620.70.06 MODULE:vdpau",
    "nvidia_icd.json 0644 VULKAN_ICD_JSON icd.d/ MODULE:opengl",
    "firmware/gsp_ga10x.bin 0444 FIRMWARE INHERIT_PATH_DEPTH:1 MODULE:gsp",
    "nvidia-smi 0755 UTILITY_BINARY MODULE:nvml",
    "nvidia-xconfig 0755 UTILITY_BINARY MODULE:xutils",
    "nvidia-modprobe 04755 NVIDIA_MODPROBE /usr/bin/ MODULE:installer",
    "systemd/system/nvidia-suspend.service 0444 SYSTEMD_UNIT INHERIT_PATH_DEPTH:2 MODULE:installer",
    "nvidia-suspend.service 0000 SYSTEMD_UNIT_SYMLINK systemd-suspend.service.wants MODULE:installer",
    "systemd/system-sleep/nvidia 0755 SYSTEMD_SLEEP_SCRIPT MODULE:installer",
    "nvoptix.bin 0444 OPENGL_DATA /usr/share/nvidia MODULE:optix",
    "nvidia-settings.desktop 0444 DOT_DESKTOP NVIDIA_GLX-1.0/ MODULE:xutils",
    "kernel-open/nvidia/nv.c 0644 KERNEL_MODULE_SRC INHERIT_PATH_DEPTH:1 MODULE:resman",
    "nvidia_drv.so 0755 XMODULE_SHARED_LIB MODULE:xdriver",
]


def _tree(tmp_path: Path, lines=LINES) -> Path:
    ext = tmp_path / "nv"
    ext.mkdir()
    (ext / ".manifest").write_text(HEADER + "\n".join(lines) + "\n")
    for l in lines:
        path, kind = l.split()[0], l.split()[2]
        if kind.endswith("SYMLINK"):
            continue
        p = ext / path
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("Exec=__UTILS_PATH__/nvidia-settings\n" if kind == "DOT_DESKTOP" else path)
    (ext / "kernel-open").mkdir(exist_ok=True)
    for ko in ("nvidia.ko", "nvidia-drm.ko"):
        (ext / "kernel-open" / ko).write_text("ko")
    return ext


def test_stage_places_the_files(tmp_path):
    dest = tmp_path / "dest"
    ns.stage(_tree(tmp_path), dest, "7.1.8-alpbahos")
    lib = dest / "usr/lib"
    assert (lib / "libGLX_nvidia.so.620.70.06").is_file()
    assert os.readlink(lib / "libGLX_nvidia.so.0") == "libGLX_nvidia.so.620.70.06"
    assert os.readlink(lib / "gbm/nvidia-drm_gbm.so") == "../libnvidia-allocator.so.1"
    assert (lib / "vdpau/libvdpau_nvidia.so.620.70.06").is_file()
    assert os.readlink(lib / "libvdpau_nvidia.so") == "vdpau/libvdpau_nvidia.so.620.70.06"
    assert (dest / "usr/share/glvnd/egl_vendor.d/10_nvidia.json").is_file()
    assert (dest / "usr/share/egl/egl_external_platform.d/15_nvidia_gbm.json").is_file()
    assert (dest / "usr/share/vulkan/icd.d/nvidia_icd.json").is_file()
    assert (dest / "usr/lib/firmware/nvidia/620.70.06/gsp_ga10x.bin").is_file()
    assert (dest / "usr/lib/systemd/system/nvidia-suspend.service").stat().st_mode & 0o777 == 0o644
    assert os.readlink(dest / "usr/lib/systemd/system/systemd-suspend.service.wants/nvidia-suspend.service") \
        == "../nvidia-suspend.service"
    assert (dest / "usr/lib/systemd/system-sleep/nvidia").is_file()
    assert (dest / "usr/share/nvidia/nvoptix.bin").is_file()
    assert (dest / "usr/share/applications/nvidia-settings.desktop").read_text() == "Exec=/usr/bin/nvidia-settings\n"
    for ko in ("nvidia.ko", "nvidia-drm.ko"):
        assert (dest / "usr/lib/modules/7.1.8-alpbahos/extra/nvidia" / ko).is_file()
    assert "blacklist nouveau" in (dest / "usr/lib/modprobe.d/nvidia-alpbahos.conf").read_text()
    assert "nvidia-drm" in (dest / "usr/lib/modules-load.d/nvidia-alpbahos.conf").read_text()
    assert "nvidia-modprobe" in (dest / "usr/lib/udev/rules.d/60-nvidia-alpbahos.rules").read_text()
    tmp = (dest / "usr/lib/tmpfiles.d/alpbahos-nvidia.conf").read_text()
    for node in ("nvidiactl 0666 root root - 195:255", "nvidia0 0666 root root - 195:0", "nvidia-modeset 0666 root root - 195:254"):
        assert f"c! /dev/{node}" in tmp


def test_stage_skips_glvnd_32bit_xorg_and_sources(tmp_path):
    dest = tmp_path / "dest"
    ns.stage(_tree(tmp_path), dest, "7.1.8-alpbahos")
    names = {p.name for p in dest.rglob("*")}
    for gone in ("libGL.so.1.7.0", "libEGL.so.1.1.0", "libGLdispatch.so.0", "nvidia_drv.so", "nv.c",
                 "nvidia-xconfig", "libnvidia-gtk2.so.620.70.06"):
        assert gone not in names
    assert not (dest / "usr/lib32").exists() and not any("32" == p.name for p in dest.rglob("*"))


def test_stage_never_setuid(tmp_path):
    dest = tmp_path / "dest"
    ns.stage(_tree(tmp_path), dest, "7.1.8-alpbahos")
    mode = (dest / "usr/bin/nvidia-modprobe").stat().st_mode
    assert mode & 0o7000 == 0 and mode & 0o777 == 0o755


def test_stage_refuses_an_unknown_type(tmp_path):
    with pytest.raises(ns.StageError, match="unknown manifest type NEW_THING"):
        ns.stage(_tree(tmp_path, LINES + ["libnew.so 0755 NEW_THING NATIVE MODULE:x"]), tmp_path / "d", "7.1.8")


def test_stage_needs_built_modules(tmp_path):
    ext = _tree(tmp_path)
    for ko in (ext / "kernel-open").glob("*.ko"):
        ko.unlink()
    with pytest.raises(ns.StageError, match="no kernel modules"):
        ns.stage(ext, tmp_path / "d", "7.1.8")


def test_every_type_is_installed_or_skipped_once():
    assert not set(ns.INSTALL) & set(ns.SKIP)


# ---- alp: unpack false and the kernel tokens ----

@pytest.fixture
def paths(tmp_path: Path) -> alp.Paths:
    p = alp.Paths.resolve(str(tmp_path / "root"))
    p.ensure()
    p.sandbox = "off"
    return p


def _kernel(paths, kv="7.1.8-alpbahos", build=True):
    d = Path(paths.root, "usr/lib/modules", kv)
    d.mkdir(parents=True)
    if build:
        (d / "build").mkdir()
    return d


def test_kernel_tokens_come_from_the_root(paths):
    _kernel(paths)
    _kernel(paths, "6.0.0-old", build=False)  # no build tree: not a candidate
    recipe = {"name": "m", "build": {"configure": ["true"], "make": ["make", "SYSSRC=@KERNEL_BUILD@"],
                                     "make_install": ["stage", "@DESTDIR@", "@KERNEL_RELEASE@"]}}
    steps = alp._recipe_steps(recipe, paths, "/d")
    assert steps[1] == ["make", f"SYSSRC={paths.root}/usr/lib/modules/7.1.8-alpbahos/build"]
    assert steps[2] == ["stage", "/d", "7.1.8-alpbahos"]


@pytest.mark.parametrize("kernels", [[], ["7.1.8-a", "7.2.0-b"]])
def test_kernel_tokens_need_exactly_one_kernel(paths, kernels):
    for kv in kernels:
        _kernel(paths, kv)
    recipe = {"name": "m", "build": {"configure": ["true"], "make": ["make", "-C", "@KERNEL_BUILD@"],
                                     "make_install": ["true"]}}
    with pytest.raises(alp.AlpError, match="çekirdek"):
        alp._recipe_steps(recipe, paths, "/d")


def test_unpack_false_keeps_the_download(paths, tmp_path):
    archive = tmp_path / "x.src"
    archive.write_bytes(b"#!/bin/sh\necho self-extracting\n")
    src = alp._unpack_source({"name": "nvidia", "unpack": False,
                              "source_url": "https://download.nvidia.com/X/NVIDIA-Linux-x86_64-620.70.06.run"},
                             archive, tmp_path / "build")
    assert src == tmp_path / "build/src"
    assert (src / "NVIDIA-Linux-x86_64-620.70.06.run").read_bytes() == archive.read_bytes()


def test_unpack_false_recipe_installs_end_to_end(paths, tmp_path):
    """A recipe shaped like the nvidia one, with a tiny self-extracting script as its source."""
    _kernel(paths)
    catalog = tmp_path / "catalog"
    catalog.mkdir()
    run = catalog / "fake-1.0.run"
    run.write_text('#!/bin/sh\n[ "$1" = --extract-only ] || exit 9\nmkdir -p "$3/kernel-open"\necho ko > "$3/kernel-open/fake.ko"\n')
    recipe = {
        "name": "fake", "version": "1.0", "source_url": "fake-1.0.run", "sha256": alp.sha256_of(run), "unpack": False,
        "build": {
            "configure": ["sh", "fake-1.0.run", "--extract-only", "--target", "nv"],
            "make": ["test", "-d", "@KERNEL_BUILD@"],
            "make_install": ["sh", "-c", 'mkdir -p "$1/usr/lib/modules/$2/extra" && cp nv/kernel-open/fake.ko "$1/usr/lib/modules/$2/extra/"',
                             "sh", "@DESTDIR@", "@KERNEL_RELEASE@"],
        },
    }
    (catalog / "fake.recipe.json").write_text(json.dumps(recipe))
    rec = alp.install_recipe(paths, {"recipe": "fake.recipe.json"}, catalog, dry_run=False)
    assert "/usr/lib/modules/7.1.8-alpbahos/extra/fake.ko" in rec["files"]
    assert (Path(paths.root) / "usr/lib/modules/7.1.8-alpbahos/extra/fake.ko").read_text() == "ko\n"
