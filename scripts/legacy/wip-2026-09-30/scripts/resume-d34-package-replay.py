#!/usr/bin/env python3
"""Resume a failed D34 package run without discarding its verified work tree.

This is intended for a builder that completed useful work (for example, a
critical test suite returning its documented nonzero status) but did not
finish installation. It reuses the exact failed run's writable Btrfs snapshot,
then sends one complete delta from the original base snapshot to the final
root. It never edits the source candidate or host /mnt/lfs.
"""

from __future__ import annotations

import argparse
import fcntl
import importlib.util
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

_REPLAY_PATH = Path(__file__).with_name("run-d34-package-replay.py")
_REPLAY_SPEC = importlib.util.spec_from_file_location("alpbahos_d34_replay", _REPLAY_PATH)
if _REPLAY_SPEC is None or _REPLAY_SPEC.loader is None:
    raise RuntimeError(f"cannot load D34 replay implementation: {_REPLAY_PATH}")
replay = importlib.util.module_from_spec(_REPLAY_SPEC)
_REPLAY_SPEC.loader.exec_module(replay)


class ResumeError(RuntimeError):
    pass


def _same_uuid(left: Any, right: Any) -> bool:
    return isinstance(left, str) and isinstance(right, str) and left.replace("-", "").lower() == right.replace("-", "").lower()


def _assert_readonly(path: Path, expected: bool) -> None:
    output = replay._run(["btrfs", "property", "get", "-ts", str(path), "ro"]).stdout.strip()
    if output != f"ro={'true' if expected else 'false'}":
        raise ResumeError(f"unexpected Btrfs read-only property for {path}: {output!r}")


def _worker(args: argparse.Namespace) -> int:
    replay._lock_identity(args.lock_fd)
    work = Path(args.work)
    fs_uuid, mount_id, subvol_id, root_inode = replay._prepare_namespace_mounts(work)
    identity = replay._subvolume_identity(replay.LFS_MOUNT)
    if (fs_uuid != args.expected_fs_uuid or not _same_uuid(identity["uuid"], args.work_uuid)
            or identity["id"] != args.work_id or subvol_id != args.work_id
            or root_inode != args.root_device_inode):
        raise ResumeError("resumed work snapshot identity changed in private mount namespace")
    d34_env = {
        "ALPBAHOS_D34_LOCK_FD": str(args.lock_fd),
        "ALPBAHOS_D34_FS_UUID": fs_uuid,
        "ALPBAHOS_D34_MOUNT_ID": mount_id,
        "ALPBAHOS_D34_ROOT_DEVICE_INODE": root_inode,
        "ALPBAHOS_D34_SUBVOL_UUID": identity["uuid"],
        "ALPBAHOS_D34_SUBVOL_ID": str(identity["id"]),
        "ALPBAHOS_D34_INITIAL_EXIT_CODE": str(args.initial_exit_code),
        "ALPBAHOS_D34_LOG_PATH": str(Path(args.run_dir) / "package.log"),
    }
    code = replay._execute_builder(Path(args.script), args.script_kind, args.run_uid,
                                   args.run_gid, args.lock_fd, d34_env,
                                   Path(args.run_dir) / "continuation.log")
    unmount = subprocess.run(["umount", "-R", str(replay.LFS_MOUNT)],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if unmount.returncode:
        raise ResumeError(f"private /mnt/lfs cleanup failed: {unmount.stderr.strip()}")
    return code


def _worker_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--worker", action="store_true")
    parser.add_argument("--lock-fd", type=int)
    parser.add_argument("--run-dir")
    parser.add_argument("--work")
    parser.add_argument("--work-uuid")
    parser.add_argument("--work-id", type=int)
    parser.add_argument("--root-device-inode")
    parser.add_argument("--expected-fs-uuid")
    parser.add_argument("--initial-exit-code", type=int)
    parser.add_argument("--script")
    parser.add_argument("--script-kind", choices=("host", "chroot"))
    parser.add_argument("--run-uid", type=int)
    parser.add_argument("--run-gid", type=int)
    return parser


def main(argv: list[str] | None = None) -> int:
    raw = sys.argv[1:] if argv is None else argv
    if "--worker" in raw:
        try:
            return _worker(_worker_parser().parse_args(raw))
        except (OSError, replay.ReplayError, ResumeError) as exc:
            print(f"d34-resume-worker: {exc}", file=sys.stderr)
            return 2

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--expected-fs-uuid", required=True)
    parser.add_argument("--expected-subvolume-uuid", required=True)
    parser.add_argument("--expected-subvolume-id", type=int, required=True)
    parser.add_argument("--script", type=Path, required=True)
    parser.add_argument("--script-kind", choices=("host", "chroot"), default="chroot")
    parser.add_argument("--continue-pass", action="store_true",
                        help="continue a PASS build/test run in its retained working snapshot and re-emit one final package delta")
    args = parser.parse_args(raw)
    if os.geteuid() != 0:
        parser.error("invoke with sudo; the runner drops to SUDO_UID for package builders")
    try:
        run_uid, run_gid = int(os.environ["SUDO_UID"]), int(os.environ["SUDO_GID"])
    except (KeyError, ValueError):
        parser.error("invoke through sudo from a regular user")
    if not run_uid:
        parser.error("refusing to resume as root on the host")

    lock_fd = -1
    try:
        run_dir = args.run_dir.resolve(strict=True)
        if run_dir.parent != replay.RUNS_DIR.resolve(strict=True):
            raise ResumeError("run directory must be an immediate child of the approved D34 runs directory")
        status_path = run_dir / "status.json"
        initial = json.loads(status_path.read_text(encoding="utf-8"))
        if initial.get("schema") != replay.RUN_SCHEMA:
            raise ResumeError("run has an unsupported D34 schema")
        continuing_pass = args.continue_pass
        if continuing_pass:
            if initial.get("result") != "PASS" or initial.get("builder_exit_code") != 0:
                raise ResumeError("--continue-pass requires a completed PASS run")
            if not isinstance(initial.get("after_readonly"), dict):
                raise ResumeError("PASS run has no final read-only build/test snapshot")
        else:
            if initial.get("result") != "FAILED_BUILDER_OR_NAMESPACE":
                raise ResumeError("only a failed D34 package run can be resumed")
            if not isinstance(initial.get("builder_exit_code"), int) or initial["builder_exit_code"] == 0:
                raise ResumeError("failed run has no nonzero builder exit code")
        script = args.script.resolve(strict=True)
        if (script.parent != (replay.REPO / "scripts").resolve()
                or not script.name.startswith("build-lfs-") or not script.name.endswith("-ch8.sh")):
            raise ResumeError("continuation script must be a repo build-lfs-*-ch8.sh script")

        if not replay.LOCK_PATH.is_file() or replay.LOCK_PATH.is_symlink():
            raise ResumeError(f"writer lock path is missing or unsafe: {replay.LOCK_PATH}")
        lock_fd = os.open(replay.LOCK_PATH, os.O_RDWR | getattr(os, "O_NOFOLLOW", 0))
        if lock_fd != 200:
            os.dup2(lock_fd, 200, inheritable=True)
            os.close(lock_fd)
            lock_fd = 200
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)

        candidate = replay._candidate_preflight(args.candidate, args.expected_fs_uuid,
                                                args.expected_subvolume_uuid,
                                                args.expected_subvolume_id)
        if candidate != initial.get("candidate"):
            raise ResumeError("failed-run candidate identity no longer matches the current candidate")
        base = Path(initial["base_readonly"]["path"]).resolve(strict=True)
        work = Path(initial["working_root"]["path"]).resolve(strict=True)
        if base != run_dir / "base-ro" or work != run_dir / "working-root":
            raise ResumeError("failed-run snapshot paths do not match the expected run layout")
        base_identity = replay._subvolume_identity(base)
        work_identity = replay._subvolume_identity(work)
        if (not _same_uuid(base_identity["uuid"], initial["base_readonly"]["uuid"])
                or base_identity["id"] != initial["base_readonly"]["id"]
                or not _same_uuid(work_identity["uuid"], initial["working_root"]["uuid"])
                or work_identity["id"] != initial["working_root"]["id"]):
            raise ResumeError("failed-run Btrfs snapshot identities changed")
        _assert_readonly(base, True)
        _assert_readonly(work, False)
        if replay._filesystem_identity(work)["uuid"] != args.expected_fs_uuid:
            raise ResumeError("failed-run work snapshot is not on the expected NVMe filesystem")
        root_info = os.stat(work, follow_symlinks=False)
        root_inode = f"{root_info.st_dev}:{root_info.st_ino}"
        if root_inode != initial["working_root"]["root_device_inode"]:
            raise ResumeError("failed-run root device/inode changed")
        build_test_evidence: dict[str, Any] | None = None
        if continuing_pass:
            build_after = run_dir / "after-ro"
            archived_after = run_dir / "build-test-after-ro"
            original_stream = run_dir / "incremental-send.bin"
            archived_stream = run_dir / "build-test-incremental-send.bin"
            original_events = run_dir / "events.jsonl"
            archived_events = run_dir / "build-test-events.jsonl"
            if not build_after.is_dir() or not original_stream.is_file() or not original_events.is_file():
                raise ResumeError("PASS run is missing its build/test snapshot or send evidence")
            if any(path.exists() for path in (archived_after, archived_stream, archived_events,
                                               run_dir / "build-test-status.json")):
                raise ResumeError("build/test evidence was already archived; refusing a second finalization")
            after_identity = replay._subvolume_identity(build_after)
            declared_after = initial["after_readonly"]
            if (not _same_uuid(after_identity["uuid"], declared_after.get("uuid"))
                    or after_identity["id"] != declared_after.get("id")):
                raise ResumeError("build/test after-ro identity differs from the PASS status")
            _assert_readonly(build_after, True)
            if initial.get("stream_path") != str(original_stream.resolve()):
                raise ResumeError("PASS status does not point to the expected initial send stream")
            build_test_evidence = {
                "after_readonly": {"path": str(archived_after), **after_identity},
                "stream_path": str(archived_stream),
                "stream_bytes": original_stream.stat().st_size,
                "event_count": initial.get("event_count"),
                "status_path": str(run_dir / "build-test-status.json"),
            }
        elif (run_dir / "after-ro").exists() or (run_dir / "incremental-send.bin").exists():
            raise ResumeError("failed run already has final snapshot/send artifacts")

        command = [shutil.which("unshare") or "unshare", "--mount", "--propagation", "private",
                   sys.executable, str(Path(__file__).resolve()), "--worker",
                   "--lock-fd", str(lock_fd), "--run-dir", str(run_dir), "--work", str(work),
                   "--work-uuid", work_identity["uuid"], "--work-id", str(work_identity["id"]),
                   "--root-device-inode", root_inode, "--expected-fs-uuid", args.expected_fs_uuid,
                   "--initial-exit-code", str(initial["builder_exit_code"]),
                   "--script", str(script), "--script-kind", args.script_kind,
                   "--run-uid", str(run_uid), "--run-gid", str(run_gid)]
        if continuing_pass:
            # Keep the first successful build/test evidence immutable before the
            # final install mutates the retained working snapshot.
            archived_status = dict(initial)
            archived_status["after_readonly"] = {
                **initial["after_readonly"], "path": str(run_dir / "build-test-after-ro")}
            archived_status["stream_path"] = str(run_dir / "build-test-incremental-send.bin")
            (run_dir / "build-test-status.json").write_text(
                json.dumps(archived_status, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            os.rename(run_dir / "after-ro", run_dir / "build-test-after-ro")
            os.rename(run_dir / "incremental-send.bin", run_dir / "build-test-incremental-send.bin")
            os.rename(run_dir / "events.jsonl", run_dir / "build-test-events.jsonl")
            initial["result"] = "FAILED_INSTALL_CONTINUATION"
            initial["build_test_evidence"] = build_test_evidence
            status_path.write_text(json.dumps(initial, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        child_env = os.environ.copy()
        child_env["ALPBAHOS_D34_LOCK_FD"] = str(lock_fd)
        worker = subprocess.run(command, env=child_env, pass_fds=(lock_fd,), check=False)
        resume_status: dict[str, Any] = {
            "schema": replay.RUN_SCHEMA, "package": initial["package"], "run_id": initial["run_id"],
            "candidate": candidate, "base_readonly": initial["base_readonly"],
            "working_root": initial["working_root"], "original_script": initial["script"],
            "initial_builder_exit_code": initial["builder_exit_code"],
            "continuation_script": str(script), "continuation_exit_code": worker.returncode,
        }
        if worker.returncode:
            resume_status["result"] = "FAILED_CONTINUATION"
            (run_dir / "resume-status.json").write_text(json.dumps(resume_status, indent=2, sort_keys=True) + "\n")
            if continuing_pass:
                failed_status = {**initial, "result": "FAILED_INSTALL_CONTINUATION",
                                 "install_continuation_script": str(script),
                                 "install_continuation_exit_code": worker.returncode}
                status_path.write_text(json.dumps(failed_status, indent=2, sort_keys=True) + "\n",
                                       encoding="utf-8")
            print(json.dumps(resume_status, sort_keys=True))
            return worker.returncode

        after_ro = run_dir / "after-ro"
        replay._run(["btrfs", "subvolume", "snapshot", "-r", str(work), str(after_ro)])
        after_identity = replay._subvolume_identity(after_ro)
        stream = run_dir / "incremental-send.bin"
        with stream.open("wb") as output:
            sent = subprocess.run(["btrfs", "send", "-p", str(base), str(after_ro)],
                                  stdout=output, stderr=subprocess.PIPE, check=False)
        if sent.returncode:
            raise ResumeError(f"incremental send failed: {sent.stderr.decode('utf-8', 'replace').strip()}")
        count, stream_info = replay._event_stream_check(stream, base_identity["uuid"], after_identity["uuid"])
        resume_status.update(result="PASS", after_readonly={"path": str(after_ro), **after_identity},
                             builder_exit_code=0, event_count=count, stream_path=str(stream),
                             stream_bytes=stream.stat().st_size, stream_info=stream_info)
        (run_dir / "resume-status.json").write_text(json.dumps(resume_status, indent=2, sort_keys=True) + "\n")
        os.replace(status_path, run_dir / "initial-attempt-status.json")
        status = {**initial, **resume_status, "result": "PASS",
                  "initial_result": "PASS_BUILD_TEST" if continuing_pass else initial["result"],
                  "continuation_script": str(script)}
        if continuing_pass:
            status.update(build_test_evidence=build_test_evidence,
                          install_continuation_script=str(script),
                          install_continuation_exit_code=0)
        status_path.write_text(json.dumps(status, indent=2, sort_keys=True) + "\n")
        print(json.dumps({"result": "PASS", "package": status["package"],
                          "run_id": status["run_id"], "event_count": count,
                          "stream_bytes": stream.stat().st_size,
                          "after_readonly": str(after_ro)}, sort_keys=True))
        return 0
    except (OSError, json.JSONDecodeError, replay.ReplayError, ResumeError, subprocess.CalledProcessError) as exc:
        print(f"d34-package-resume: {exc}", file=sys.stderr)
        return 2
    finally:
        if lock_fd >= 0:
            os.close(lock_fd)


if __name__ == "__main__":
    raise SystemExit(main())
