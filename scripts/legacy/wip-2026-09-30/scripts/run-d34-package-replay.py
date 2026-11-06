#!/usr/bin/env python3
"""Run one LFS Chapter 8 installer on an isolated Btrfs snapshot and record its delta.

This runner is root-invoked with sudo, but package host-orchestrators run as the
original unprivileged user. Only a private mount namespace and exact Btrfs
snapshot operations are privileged. It never installs into /mnt/lfs in the
host mount namespace.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import pwd
import re
import shutil
import stat
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any


REPO = Path(__file__).resolve().parents[1]
DEFAULT_CANDIDATE = Path(
    "/home/yrslf/alpbahOS-nvme/d34-candidates/clean-lfs-root-20260929T205800Z"
)
RUNS_DIR = Path("/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs")
DATA_ROOT = Path("/mnt/alpbahOS-data/alpbahOS-build")
LOCK_PATH = DATA_ROOT / "locks/lfs-build-writer.lock"
LFS_MOUNT = Path("/mnt/lfs")
RUN_SCHEMA = "alpbahOS.d34-package-replay/v1"
APPROVED_HOST_REPLAYS = {
    "libpciaccess": "build-blfs-libpciaccess-d34.sh",
    "libdrm": "build-blfs-libdrm-d34.sh",
    "wayland": "build-blfs-wayland-d34.sh",
    "wayland-protocols": "build-blfs-wayland-protocols-d34.sh",
    "libyaml": "build-blfs-libyaml-d34.sh",
    "Cython": "build-blfs-cython-d34.sh",
    "Mako": "build-blfs-mako-d34.sh",
    "PyYAML": "build-blfs-pyyaml-d34.sh",
    "Mesa": "build-blfs-mesa-d34.sh",
    "freetype-bootstrap": "build-blfs-freetype-bootstrap-d34.sh",
    "harfbuzz": "build-blfs-harfbuzz-d34.sh",
    "fontconfig": "build-blfs-fontconfig-d34.sh",
    "dejavu-fonts": "build-blfs-dejavu-fonts-d34.sh",
    "libpng": "build-blfs-libpng-d34.sh",
    "QtBase": "build-blfs-qtbase-d34.sh",
    "CMake": "build-blfs-cmake-d34.sh",
    "sqlite-desktop": "build-blfs-sqlite-d34.sh",
    "qtshadertools": "build-blfs-qtshadertools-d34.sh",
    "qtdeclarative": "build-blfs-qtdeclarative-d34.sh",
    "qtwayland": "build-blfs-qtwayland-d34.sh",
    "extra-cmake-modules": "build-blfs-ecm-d34.sh",
    "qtsvg": "build-blfs-qtsvg-d34.sh",
    "qttools": "build-blfs-qttools-d34.sh",
    "hwdata": "build-blfs-hwdata.sh",
    "libdisplay-info": "build-blfs-libdisplay-info.sh",
    "libnl": "build-blfs-libnl.sh",
    "alsa-lib": "build-blfs-alsa-lib.sh",
    "libsndfile": "build-blfs-libsndfile.sh",
    "lua": "build-blfs-lua.sh",
    "pipewire": "build-blfs-pipewire.sh",
    "wireplumber": "build-blfs-wireplumber.sh",
    "pcre2": "build-blfs-pcre2.sh",
    "glib": "build-blfs-glib.sh",
    "libunistring": "build-blfs-libunistring.sh",
    "libidn2": "build-blfs-libidn2.sh",
    "libpsl": "build-blfs-libpsl.sh",
    "curl": "build-blfs-curl.sh",
    "ca-trust-stack": "build-blfs-qca-prereqs.sh",
    "duktape": "build-blfs-duktape.sh",
    "polkit": "build-blfs-polkit.sh",
    "pam-stack-config": "configure-blfs-pam-stack-d34.sh",
    "libndp": "build-blfs-libndp.sh",
    "nspr": "build-blfs-nspr.sh",
    "nss": "build-blfs-nss.sh",
    "nss-trust-integration": "configure-blfs-nss-trust-d34.sh",
    "wpa_supplicant": "build-blfs-wpa-supplicant.sh",
    "networkmanager": "build-blfs-networkmanager.sh",
    "libxslt": "build-blfs-libxslt-d34.sh",
    "libxml2": "build-blfs-libxml2-d34.sh",
    "plasma-wayland-protocols": "build-blfs-plasma-wayland-protocols-d34.sh",
    "xkeyboard-config": "build-blfs-xkb-d34.sh",
    "libxkbcommon": "build-blfs-xkb-d34.sh",
    "aspell": "build-blfs-aspell-d34.sh",
    "docbook-xml": "build-blfs-docbook-d34.sh",
    "docbook-xsl": "build-blfs-docbook-d34.sh",
    "docbook-catalogs": "build-blfs-docbook-d34.sh",
    "perl-uri": "build-blfs-perl-uri-d34.sh",
    "breeze-icons": "build-blfs-kf6-package-d34.sh",
    "libogg": "build-blfs-knotification-audio-d34.sh",
    "libvorbis": "build-blfs-knotification-audio-d34.sh",
    "libcanberra": "build-blfs-knotification-audio-d34.sh",
    "qtspeech": "build-blfs-qtspeech-d34.sh",
    "qtmultimedia": "build-blfs-qtmultimedia-d34.sh",
    "libgpg-error": "build-blfs-libgpg-error-d34.sh",
    "libgcrypt": "build-blfs-libgcrypt-d34.sh",
    "qca-qt6": "build-blfs-qca-d34.sh",
    "qt5compat": "build-blfs-qt5compat-d34.sh",
    "libsecret": "build-blfs-libsecret-d34.sh",
    "lmdb": "build-blfs-lmdb-d34.sh",
    "libqrencode": "build-blfs-qrencode-d34.sh",
    "libical": "build-blfs-libical-d34.sh",
}
KF6_PACKAGE_ORDER = json.loads((REPO / "scripts/kf6-d34-package-order.json").read_text(encoding="utf-8"))
APPROVED_HOST_REPLAYS.update({name: "build-blfs-kf6-package-d34.sh" for name in KF6_PACKAGE_ORDER})
PLASMA_PACKAGE_ORDER = json.loads((REPO / "scripts/plasma-d34-package-order.json").read_text(encoding="utf-8"))
APPROVED_HOST_REPLAYS.update({name: "build-blfs-plasma-core-d34.sh" for name in PLASMA_PACKAGE_ORDER})
APPROVED_HOST_REPLAYS["boost-headers"] = "build-blfs-boost-headers-d34.sh"
APPROVED_HOST_REPLAYS["qtsensors"] = "build-blfs-qtsensors-d34.sh"
APPROVED_HOST_REPLAYS["qtpositioning"] = "build-blfs-qtpositioning-d34.sh"
APPROVED_HOST_REPLAYS["qtlocation"] = "build-blfs-qtlocation-d34.sh"
APPROVED_HOST_REPLAYS["qtwebsockets"] = "build-blfs-qtwebsockets-d34.sh"
APPROVED_HOST_REPLAYS["qcoro"] = "build-blfs-qcoro-d34.sh"
APPROVED_HOST_REPLAYS["xtrans"] = "build-blfs-xtrans-d34.sh"
APPROVED_HOST_REPLAYS["libX11"] = "build-blfs-libX11-d34.sh"
APPROVED_HOST_REPLAYS["xcb-util-keysyms"] = "build-blfs-xcb-util-keysyms-d34.sh"
APPROVED_HOST_REPLAYS["xcb-util-wm"] = "build-blfs-xcb-util-wm-d34.sh"
APPROVED_HOST_REPLAYS["libXfixes"] = "build-blfs-libXfixes-d34.sh"
APPROVED_HOST_REPLAYS["libXrender"] = "build-blfs-libXrender-d34.sh"
APPROVED_HOST_REPLAYS["libXcursor"] = "build-blfs-libXcursor-d34.sh"
APPROVED_HOST_REPLAYS["libxkbfile"] = "build-blfs-libxkbfile-d34.sh"
APPROVED_HOST_REPLAYS["libgudev"] = "build-blfs-libgudev-d34.sh"
APPROVED_HOST_REPLAYS["libwacom"] = "build-blfs-libwacom-d34.sh"
APPROVED_HOST_REPLAYS["xcb-util"] = "build-blfs-xcb-util-d34.sh"
APPROVED_HOST_REPLAYS["xcb-util-image"] = "build-blfs-xcb-util-image-d34.sh"
APPROVED_HOST_REPLAYS["xcb-util-renderutil"] = "build-blfs-xcb-util-renderutil-d34.sh"
APPROVED_HOST_REPLAYS["xcb-util-cursor"] = "build-blfs-xcb-util-cursor-d34.sh"
APPROVED_HOST_REPLAYS["qtbase-xcb"] = "build-blfs-qtbase-xcb-d34.sh"
APPROVED_HOST_REPLAYS["libxkbcommon-x11"] = "build-blfs-xkb-d34.sh"
APPROVED_HOST_REPLAYS["kwindowsystem-x11"] = "build-blfs-kwindowsystem-x11-d34.sh"
APPROVED_HOST_REPLAYS["phonon"] = "build-blfs-phonon-d34.sh"
APPROVED_HOST_REPLAYS["icu"] = "build-blfs-icu-d34.sh"
APPROVED_HOST_REPLAYS["polkit-qt"] = "build-blfs-polkit-qt-d34.sh"
APPROVED_HOST_REPLAYS["lm-sensors"] = "build-blfs-lm-sensors-d34.sh"
APPROVED_HOST_REPLAYS["qtbase-xkbcommon"] = "build-blfs-qtbase-xkbcommon-d34.sh"
APPROVED_HOST_REPLAYS.update({name: "build-blfs-kwin-deps-d34.sh"
                              for name in ("libepoxy", "libevdev", "mtdev", "libinput", "libxcvt", "lcms2", "xcb-proto", "util-macros", "xorgproto", "libXau", "libxcb")})


class ReplayError(RuntimeError):
    pass


def _run(argv: list[str], *, check: bool = True, capture: bool = True,
         env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(argv, check=check, text=True,
                              stdout=subprocess.PIPE if capture else None,
                              stderr=subprocess.PIPE if capture else None,
                              env=env)
    except (OSError, subprocess.CalledProcessError) as exc:
        detail = getattr(exc, "stderr", "") or str(exc)
        raise ReplayError(f"command failed ({argv[0]}): {detail.strip()}") from exc


def _subvolume_identity(path: Path) -> dict[str, Any]:
    output = _run(["btrfs", "subvolume", "show", str(path)]).stdout
    uuid_match = re.search(r"^\s*UUID:\s+([0-9a-f-]{36})\s*$", output, re.M)
    id_match = re.search(r"^\s*Subvolume ID:\s+(\d+)\s*$", output, re.M)
    if not uuid_match or not id_match:
        raise ReplayError(f"not a Btrfs subvolume root: {path}")
    return {"uuid": uuid_match.group(1), "id": int(id_match.group(1))}


def _filesystem_identity(path: Path) -> dict[str, Any]:
    output = _run(["findmnt", "--json", "--target", str(path), "--output",
                   "ID,UUID,FSTYPE,TARGET"]).stdout
    filesystems = json.loads(output).get("filesystems")
    if not isinstance(filesystems, list) or len(filesystems) != 1:
        raise ReplayError("findmnt did not return a single containing filesystem")
    mount = filesystems[0]
    if mount.get("fstype") != "btrfs":
        raise ReplayError(f"expected Btrfs filesystem, got {mount.get('fstype')!r}")
    return {"uuid": mount["uuid"], "mount_id": str(mount["id"]), "target": mount["target"]}


def _reject_symlink_components(path: Path) -> None:
    absolute = Path(os.path.abspath(path))
    cursor = Path(absolute.anchor)
    for part in absolute.parts[1:]:
        cursor /= part
        info = os.lstat(cursor)
        if stat.S_ISLNK(info.st_mode):
            raise ReplayError(f"symlink component is forbidden: {cursor}")


def _reject_nested_mounts(root: Path) -> None:
    escapes = {"040": " ", "011": "\t", "012": "\n", "134": "\\"}
    nested: list[str] = []
    for line in Path("/proc/self/mountinfo").read_text(encoding="utf-8").splitlines():
        fields = line.split()
        if len(fields) < 6:
            raise ReplayError("malformed /proc/self/mountinfo record")
        raw = fields[4]
        mountpoint = re.sub(r"\\(040|011|012|134)", lambda match: escapes[match.group(1)], raw)
        try:
            relative = Path(mountpoint).relative_to(root)
        except ValueError:
            continue
        if relative.parts:
            nested.append(mountpoint)
    if nested:
        raise ReplayError(f"candidate has nested mountpoints: {nested}")


def _candidate_preflight(candidate: Path, expected_fs_uuid: str,
                         expected_subvolume_uuid: str, expected_subvolume_id: int) -> dict[str, Any]:
    candidate = Path(os.path.abspath(candidate))
    _reject_symlink_components(candidate)
    if candidate == Path("/") or candidate == LFS_MOUNT or LFS_MOUNT in candidate.parents:
        raise ReplayError("refusing /mnt/lfs or a descendant")
    if not candidate.is_dir():
        raise ReplayError("candidate is not a directory")
    try:
        candidate.relative_to(Path("/home/yrslf/alpbahOS-nvme/d34-candidates"))
    except ValueError as exc:
        raise ReplayError("candidate must be under the approved NVMe D34 candidate directory") from exc
    fs = _filesystem_identity(candidate)
    if fs["uuid"] != expected_fs_uuid:
        raise ReplayError(f"candidate filesystem UUID mismatch: {fs['uuid']}")
    if Path(fs["target"]) == candidate:
        raise ReplayError("candidate root is itself a mountpoint")
    _reject_nested_mounts(candidate)
    subvol = _subvolume_identity(candidate)
    if subvol["uuid"] != expected_subvolume_uuid or subvol["id"] != expected_subvolume_id:
        raise ReplayError(f"candidate subvolume identity mismatch: {subvol}")
    info = os.stat(candidate, follow_symlinks=False)
    return {
        "path": str(candidate), "filesystem_uuid": fs["uuid"],
        "containing_mount_id": fs["mount_id"], "subvolume_uuid": subvol["uuid"],
        "subvolume_id": subvol["id"], "root_device_inode": f"{info.st_dev}:{info.st_ino}",
    }


def _lock_identity(fd: int) -> None:
    try:
        target = os.readlink(f"/proc/{os.getpid()}/fd/{fd}")
    except OSError as exc:
        raise ReplayError(f"writer-lock FD {fd} is not inherited") from exc
    if os.path.realpath(target) != str(LOCK_PATH.resolve(strict=True)):
        raise ReplayError("inherited FD does not refer to the shared LFS writer lock")
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError as exc:
        raise ReplayError("inherited FD does not hold the exclusive writer lock") from exc


def _mount_command(argv: list[str]) -> None:
    _run(argv, capture=True)


def _prepare_namespace_mounts(work: Path) -> tuple[str, str, int, str]:
    # Detach every inherited mount under /mnt/lfs in this private namespace.
    _mount_command(["umount", "-R", str(LFS_MOUNT)])
    _mount_command(["mount", "--bind", str(work), str(LFS_MOUNT)])
    root = LFS_MOUNT
    for dirname in ("dev", "dev/pts", "dev/shm", "proc", "sys", "run"):
        (root / dirname).mkdir(parents=True, exist_ok=True)
    _mount_command(["mount", "--bind", "/dev", str(root / "dev")])
    _mount_command(["mount", "-t", "devpts", "-o", "gid=5,mode=0620", "devpts", str(root / "dev/pts")])
    _mount_command(["mount", "-t", "tmpfs", "-o", "nosuid,nodev", "tmpfs", str(root / "dev/shm")])
    _mount_command(["mount", "-t", "proc", "proc", str(root / "proc")])
    _mount_command(["mount", "-t", "sysfs", "sysfs", str(root / "sys")])
    _mount_command(["mount", "-t", "tmpfs", "-o", "mode=0755,nosuid,nodev", "tmpfs", str(root / "run")])

    mount_lines = _run(["findmnt", "-rn", "-M", str(root), "-o", "ID,UUID,FSTYPE"]).stdout.splitlines()
    if len(mount_lines) != 1:
        raise ReplayError(f"expected one exact /mnt/lfs root mount, got {len(mount_lines)}")
    fields = mount_lines[0].split()
    if len(fields) != 3 or fields[2] != "btrfs":
        raise ReplayError(f"unexpected D34 root mount record: {mount_lines[0]}")
    mount_id, fs_uuid = fields[0], fields[1]
    identity = _subvolume_identity(root)
    device_inode = f"{os.stat(root, follow_symlinks=False).st_dev}:{os.stat(root, follow_symlinks=False).st_ino}"
    return fs_uuid, mount_id, identity["id"], device_inode


def _execute_builder(script: Path, mode: str, uid: int, gid: int,
                     lock_fd: int, d34_env: dict[str, str], log_path: Path) -> int:
    account = pwd.getpwuid(uid)
    env = os.environ.copy()
    env.update(d34_env)
    env.update({"HOME": account.pw_dir, "USER": account.pw_name,
                "LOGNAME": account.pw_name, "PATH": "/usr/local/bin:/usr/bin:/bin"})
    if mode == "host":
        argv = ["setpriv", "--reuid", str(uid), "--regid", str(gid), "--init-groups",
                "--", "/bin/bash", str(script)]
        stdin = None
    else:
        continuation_env = [f"{key}={value}" for key, value in sorted(d34_env.items())
                            if key == "ALPBAHOS_D34_INITIAL_EXIT_CODE"]
        argv = ["setpriv", "--reuid", str(uid), "--regid", str(gid), "--init-groups", "--",
                "sudo", "-n", "chroot", str(LFS_MOUNT), "/usr/bin/env", "-i",
                "HOME=/root", "TERM=dumb", "PATH=/usr/bin:/usr/sbin", "LC_ALL=POSIX",
                "MAKEFLAGS=-j4", *continuation_env, "/bin/bash", "-s"]
        stdin = script.read_bytes()
    with log_path.open("wb") as log:
        process = subprocess.run(argv, input=stdin, stdout=log, stderr=subprocess.STDOUT,
                                 env=env, pass_fds=(lock_fd,), check=False)
    return process.returncode


def _worker(args: argparse.Namespace) -> int:
    lock_fd = args.lock_fd
    _lock_identity(lock_fd)
    run_dir = Path(args.run_dir)
    work = Path(args.work)
    script = Path(args.script)
    fs_uuid, mount_id, subvol_id, device_inode = _prepare_namespace_mounts(work)
    expected_work_uuid = args.work_uuid
    actual_work = _subvolume_identity(LFS_MOUNT)
    if fs_uuid != args.expected_fs_uuid or actual_work["uuid"] != expected_work_uuid or actual_work["id"] != subvol_id:
        raise ReplayError("working-snapshot identity changed during namespace setup")
    d34_env = {
        "ALPBAHOS_D34_LOCK_FD": str(lock_fd),
        "ALPBAHOS_D34_FS_UUID": fs_uuid,
        "ALPBAHOS_D34_MOUNT_ID": mount_id,
        "ALPBAHOS_D34_ROOT_DEVICE_INODE": device_inode,
        "ALPBAHOS_D34_SUBVOL_UUID": actual_work["uuid"],
        "ALPBAHOS_D34_SUBVOL_ID": str(actual_work["id"]),
        "ALPBAHOS_D34_LOG_PATH": str(run_dir / "package.log"),
        "ALPBAHOS_D34_CANDIDATE_PATH": str(Path(args.candidate_path).resolve()),
    }
    rc = _execute_builder(script, args.script_kind, args.run_uid, args.run_gid,
                          lock_fd, d34_env, run_dir / "builder.log")
    unmount = subprocess.run(["umount", "-R", str(LFS_MOUNT)],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if unmount.returncode:
        raise ReplayError(f"private /mnt/lfs cleanup failed: {unmount.stderr.strip()}")
    return rc


def _event_stream_check(stream_path: Path, base_uuid: str,
                        after_uuid: str) -> tuple[int, dict[str, Any]]:
    sys.path.insert(0, str(REPO / "scripts"))
    from btrfs_send_ledger import StreamError, parse_stream

    count = 0
    first: dict[str, Any] | None = None
    last: dict[str, Any] | None = None
    with stream_path.open("rb") as source, (stream_path.parent / "events.jsonl").open("w", encoding="utf-8") as events:
        for event in parse_stream(source):
            record = {"sequence": event.sequence, "version": event.version,
                      "command_id": event.command_id, **event.event}
            events.write(json.dumps(record, sort_keys=True) + "\n")
            if first is None:
                first = record
            last = record
            count += 1
    normalize_uuid = lambda value: value.replace("-", "").lower() if isinstance(value, str) else value
    if (not first or first.get("op") != "snapshot"
            or normalize_uuid(first.get("uuid")) != normalize_uuid(after_uuid)
            or normalize_uuid(first.get("clone_uuid")) != normalize_uuid(base_uuid)):
        raise ReplayError("send-stream header snapshot identities do not match expected base/final roots")
    if not last or last.get("op") != "end":
        raise ReplayError("send-stream has no final END event")
    return count, {"first_event": first, "event_count": count}


def _worker_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--worker", action="store_true")
    parser.add_argument("--lock-fd", type=int)
    parser.add_argument("--run-dir")
    parser.add_argument("--work")
    parser.add_argument("--candidate-path")
    parser.add_argument("--script")
    parser.add_argument("--script-kind", choices=("host", "chroot"))
    parser.add_argument("--run-uid", type=int)
    parser.add_argument("--run-gid", type=int)
    parser.add_argument("--work-uuid")
    parser.add_argument("--expected-fs-uuid")
    return parser


def main(argv: list[str] | None = None) -> int:
    raw_argv = sys.argv[1:] if argv is None else argv
    if "--worker" in raw_argv:
        worker_parser = _worker_parser()
        worker_args = worker_parser.parse_args(raw_argv)
        try:
            return _worker(worker_args)
        except (OSError, ReplayError) as exc:
            print(f"d34-worker: {exc}", file=sys.stderr)
            return 2

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--expected-fs-uuid", required=True)
    parser.add_argument("--expected-subvolume-uuid", required=True)
    parser.add_argument("--expected-subvolume-id", type=int, required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--script", type=Path)
    parser.add_argument("--script-kind", choices=("host", "chroot"), default="chroot")
    parser.add_argument("--preflight-only", action="store_true")
    args = parser.parse_args(raw_argv)

    if os.geteuid() != 0:
        parser.error("invoke with sudo; the runner drops to SUDO_UID for package builders")
    try:
        run_uid, run_gid = int(os.environ["SUDO_UID"]), int(os.environ["SUDO_GID"])
    except (KeyError, ValueError):
        parser.error("invoke through sudo from a regular user")
    if run_uid == 0:
        parser.error("refusing to run package builders as root on the host")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]{0,79}", args.package):
        parser.error("package must be a short filesystem-safe ID")
    script: Path | None = None
    if not args.preflight_only:
        if args.script is None:
            parser.error("--script is required unless --preflight-only is set")
        script = args.script.resolve(strict=True)
        if script.parent != (REPO / "scripts").resolve():
            parser.error("script must be in this repo's scripts directory")
        if args.script_kind == "host":
            if APPROVED_HOST_REPLAYS.get(args.package) != script.name:
                parser.error("host replay requires an explicitly approved package/script pair")
        elif not re.fullmatch(r"build-lfs-.+-ch8\.sh", script.name):
            parser.error("chroot replay script must be one of this repo's build-lfs-*-ch8.sh files")

    lock_fd = -1
    try:
        if not LOCK_PATH.is_file() or LOCK_PATH.is_symlink():
            raise ReplayError(f"writer lock path is missing or unsafe: {LOCK_PATH}")
        lock_fd = os.open(LOCK_PATH, os.O_RDWR | getattr(os, "O_NOFOLLOW", 0))
        if lock_fd != 200:
            os.dup2(lock_fd, 200, inheritable=True)
            os.close(lock_fd)
            lock_fd = 200
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        candidate = _candidate_preflight(args.candidate, args.expected_fs_uuid,
                                         args.expected_subvolume_uuid, args.expected_subvolume_id)
        if args.preflight_only:
            print(json.dumps({"result": "PASS", "candidate": candidate,
                              "writer_lock": str(LOCK_PATH)}, sort_keys=True))
            return 0

        run_id = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime()) + "-" + uuid.uuid4().hex[:8]
        run_dir = RUNS_DIR / f"{args.package}-{run_id}"
        base_ro = run_dir / "base-ro"
        work = run_dir / "working-root"
        after_ro = run_dir / "after-ro"
        RUNS_DIR.mkdir(parents=True, exist_ok=True)
        run_dir.mkdir(mode=0o750)
        os.chown(run_dir, run_uid, run_gid)
        _run(["btrfs", "subvolume", "snapshot", "-r", str(args.candidate), str(base_ro)])
        base_identity = _subvolume_identity(base_ro)
        _run(["btrfs", "subvolume", "snapshot", str(base_ro), str(work)])
        work_identity = _subvolume_identity(work)
        info = os.stat(work, follow_symlinks=False)
        if _filesystem_identity(work)["uuid"] != args.expected_fs_uuid:
            raise ReplayError("working snapshot is not on the expected NVMe filesystem")

        command = [shutil.which("unshare") or "unshare", "--mount", "--propagation", "private",
                   sys.executable, str(Path(__file__).resolve()), "--worker",
                   "--lock-fd", str(lock_fd), "--run-dir", str(run_dir), "--work", str(work),
                   "--candidate-path", str(args.candidate.resolve()),
                   "--script", str(script), "--script-kind", args.script_kind,
                   "--run-uid", str(run_uid), "--run-gid", str(run_gid),
                   "--work-uuid", work_identity["uuid"], "--expected-fs-uuid", args.expected_fs_uuid]
        child_env = os.environ.copy()
        child_env["ALPBAHOS_D34_LOCK_FD"] = str(lock_fd)
        child_env["ALPBAHOS_D34_PACKAGE"] = args.package
        worker = subprocess.run(command, env=child_env, pass_fds=(lock_fd,), check=False)
        status: dict[str, Any] = {
            "schema": RUN_SCHEMA, "package": args.package, "run_id": run_id,
            "candidate": candidate, "base_readonly": {"path": str(base_ro), **base_identity},
            "working_root": {"path": str(work), **work_identity,
                             "root_device_inode": f"{info.st_dev}:{info.st_ino}"},
            "script": str(script), "script_kind": args.script_kind,
            "builder_exit_code": worker.returncode,
        }
        if worker.returncode != 0:
            status["result"] = "FAILED_BUILDER_OR_NAMESPACE"
            (run_dir / "status.json").write_text(json.dumps(status, indent=2, sort_keys=True) + "\n")
            print(json.dumps(status, sort_keys=True))
            return worker.returncode or 2

        _run(["btrfs", "subvolume", "snapshot", "-r", str(work), str(after_ro)])
        after_identity = _subvolume_identity(after_ro)
        stream = run_dir / "incremental-send.bin"
        with stream.open("wb") as output:
            sent = subprocess.run(["btrfs", "send", "-p", str(base_ro), str(after_ro)],
                                  stdout=output, stderr=subprocess.PIPE, check=False)
        if sent.returncode:
            status.update(result="FAILED_BTRFS_SEND", send_error=sent.stderr.decode("utf-8", "replace"))
            (run_dir / "status.json").write_text(json.dumps(status, indent=2, sort_keys=True) + "\n")
            print(json.dumps(status, sort_keys=True))
            return sent.returncode
        event_count, stream_info = _event_stream_check(stream, base_identity["uuid"], after_identity["uuid"])
        status.update(result="PASS", after_readonly={"path": str(after_ro), **after_identity},
                      stream_path=str(stream), stream_bytes=stream.stat().st_size,
                      event_count=event_count, stream_info=stream_info)
        (run_dir / "status.json").write_text(json.dumps(status, indent=2, sort_keys=True) + "\n")
        print(json.dumps(status, sort_keys=True))
        return 0
    except (OSError, ReplayError, subprocess.CalledProcessError) as exc:
        if "run_dir" in locals() and run_dir.is_dir() and "status" in locals():
            status["result"] = "FAILED_RUNNER"
            status["runner_error"] = str(exc)
            (run_dir / "status.json").write_text(
                json.dumps(status, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"d34-package-replay: {exc}", file=sys.stderr)
        return 2
    finally:
        if lock_fd >= 0:
            os.close(lock_fd)


if __name__ == "__main__":
    raise SystemExit(main())
