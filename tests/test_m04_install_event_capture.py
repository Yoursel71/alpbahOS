"""Fixture-only tests for the Linux M04 install-event capture runner."""

from __future__ import annotations

import importlib.util
import io
import json
import stat
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "capture-m04-install-event.py"
SPEC = importlib.util.spec_from_file_location("m04_install_capture", SCRIPT)
capture = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(capture)
RECONCILER_SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "reconcile-m04-final-owners.py"
RECONCILER_SPEC = importlib.util.spec_from_file_location("m04_final_owner_reconciler_for_capture", RECONCILER_SCRIPT)
reconciler = importlib.util.module_from_spec(RECONCILER_SPEC)
assert RECONCILER_SPEC and RECONCILER_SPEC.loader
RECONCILER_SPEC.loader.exec_module(reconciler)


class Fixture:
    def __init__(self):
        self.temp = tempfile.TemporaryDirectory(prefix="m04-event-fixture-")
        self.root = Path(self.temp.name)
        (self.root / capture.MARKER).write_text(capture.MARKER_TEXT, encoding="utf-8")

    def close(self):
        self.temp.cleanup()


class InstallEventCaptureTests(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()
        self.which = mock.patch.object(capture.shutil, "which", side_effect=lambda name: f"/usr/bin/{name}")
        self.which.start()
        self.platform = mock.patch.object(capture.sys, "platform", "linux")
        self.platform.start()
        self.machine = mock.patch.object(capture.platform, "machine", return_value="x86_64")
        self.machine.start()
        self.listxattr = mock.patch.object(capture.os, "listxattr", return_value=[], create=True)
        self.listxattr.start()
        self.getxattr = mock.patch.object(capture.os, "getxattr", create=True)
        self.getxattr.start()
        self.execute = mock.patch.object(capture, "_execute", side_effect=self.fake_execute)
        self.execute_mock = self.execute.start()

    def tearDown(self):
        mock.patch.stopall()
        self.fx.close()

    def fake_execute(self, argv, cwd, env, root, trace_path, seccomp_path, strace, bwrap, stdout_path, stderr_path):
        action = argv[-1]
        (root / "usr/bin").mkdir(parents=True, exist_ok=True)
        trace_path.write_text("", encoding="utf-8")
        stdout_path.write_bytes(b"install stdout\n")
        stderr_path.write_bytes(b"install stderr\n")
        if action == "write":
            (root / "usr/bin/new-tool").write_bytes(b"new payload")
            trace_path.write_text(f'openat(AT_FDCWD, {json.dumps(str(root / "usr/bin/new-tool"))}, O_WRONLY|O_CREAT, 0644) = 3\n', encoding="utf-8")
            return 0
        if action == "replace-delete":
            (root / "usr/bin/existing").write_bytes(b"after")
            (root / "usr/bin/gone").unlink()
            trace_path.write_text(
                f'openat(AT_FDCWD, {json.dumps(str(root / "usr/bin/existing"))}, O_WRONLY, 0644) = 3\n'
                f'unlink({json.dumps(str(root / "usr/bin/gone"))}) = 0\n', encoding="utf-8")
            return 0
        if action == "fail":
            (root / "usr/bin/partial").write_bytes(b"partial")
            trace_path.write_text(f'openat(AT_FDCWD, {json.dumps(str(root / "usr/bin/partial"))}, O_WRONLY, 0644) = 3\n', encoding="utf-8")
            return 7
        if action == "outside":
            outside = str(Path(root.anchor) / "etc/passwd")
            trace_path.write_text(f'unlink({json.dumps(outside)}) = -1 EROFS (Read-only file system)\n', encoding="utf-8")
            return 1
        if action == "io-uring":
            trace_path.write_text("io_uring_setup(2, 0x7ffc1234) = -1 ENOSYS (Function not implemented)\n",
                                  encoding="utf-8")
            return 0
        if action == "change-root-id":
            (root / capture.CAPTURE_DIR / "root-id").write_text("f" * 32 + "\n", encoding="ascii")
            return 0
        if action == "attempt-root-id":
            root_id = root / capture.CAPTURE_DIR / "root-id"
            trace_path.write_text(
                f'openat(AT_FDCWD, {json.dumps(str(root_id))}, O_WRONLY|O_TRUNC) = -1 EROFS (Read-only file system)\n',
                encoding="utf-8")
            return 0
        raise AssertionError(action)

    def test_install_write_records_command_environment_logs_trace_and_snapshots(self):
        recipe = self.fx.root / "recipe.sh"
        recipe.write_text("make install DESTDIR=/fixture\n", encoding="utf-8")
        event = capture.capture_install(self.fx.root, ["make", "install", "write"],
                                        cwd=self.fx.root, env_overrides={"DESTDIR": "/fixture"},
                                        input_paths=[recipe], package="demo", version="1.2")
        self.assertEqual(event["argv"], ["make", "install", "write"])
        self.assertEqual(event["environment"]["DESTDIR"], "/fixture")
        self.assertEqual(event["exit_status"], 0)
        self.assertEqual(event["root_id"], json.loads(
            (self.fx.root / event["artifacts"]["before_snapshot"]["path"]).read_text())["root_id"])
        self.assertTrue(event["environment"]["HOME"].startswith(str(self.fx.root / capture.CAPTURE_DIR / "work")))
        self.assertTrue(event["environment"]["TMPDIR"].startswith(str(self.fx.root / capture.CAPTURE_DIR / "work")))
        self.assertNotIn("/events/", event["environment"]["HOME"].replace("\\", "/"))
        self.assertFalse(Path(event["environment"]["HOME"]).parent.exists())
        self.assertEqual(event["changed_paths"], ["/usr", "/usr/bin", "/usr/bin/new-tool"])
        self.assertEqual(len(event["inputs"]), 1)
        artifact_dir = self.fx.root / event["artifacts"]["strace"]["path"]
        self.assertIn("new-tool", artifact_dir.read_text(encoding="utf-8"))
        self.assertEqual(event["artifacts"]["stdout"]["sha256"], capture._sha256(
            self.fx.root / event["artifacts"]["stdout"]["path"]))
        self.assertTrue((self.fx.root / event["artifacts"]["before_snapshot"]["path"]).is_file())
        self.assertTrue((self.fx.root / event["artifacts"]["after_snapshot"]["path"]).is_file())
        manifest_path = self.fx.root / event["event_manifest"]["path"]
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        persisted_event_path = self.fx.root / manifest["event_path"]
        event_bytes = persisted_event_path.read_bytes()
        self.assertEqual(manifest["schema"], capture.EVENT_MANIFEST_SCHEMA)
        self.assertEqual(manifest["size"], len(event_bytes))
        self.assertEqual(manifest["sha256"], capture.hashlib.sha256(event_bytes).hexdigest())
        self.assertNotIn("event_manifest", json.loads(event_bytes))
        snapshot = json.loads((self.fx.root / event["artifacts"]["before_snapshot"]["path"]).read_text())
        self.assertEqual(snapshot["schema"], "alpbahOS.m04-reconcile-snapshot/v3")
        reconciler._snapshot(snapshot, event["root_id"], "captured fixture snapshot")
        entry = snapshot["entries"]["/recipe.sh"]
        self.assertEqual(set(entry["metadata_support"]), {
            "xattrs_sha256", "capabilities_sha256", "hardlink_count", "hardlink_group_sha256"})
        self.assertEqual(entry["metadata_support"]["hardlink_count"], 1)
        self.assertIsNone(entry["metadata_support"]["hardlink_group_sha256"])

    def test_overwrite_and_delete_are_visible_in_before_after_diff(self):
        (self.fx.root / "usr/bin").mkdir(parents=True)
        (self.fx.root / "usr/bin/existing").write_bytes(b"before")
        (self.fx.root / "usr/bin/gone").write_bytes(b"remove me")
        event = capture.capture_install(self.fx.root, ["installer", "replace-delete"], cwd=self.fx.root)
        self.assertEqual(event["changed_paths"], ["/usr/bin/existing", "/usr/bin/gone"])
        before = json.loads((self.fx.root / event["artifacts"]["before_snapshot"]["path"]).read_text())
        after = json.loads((self.fx.root / event["artifacts"]["after_snapshot"]["path"]).read_text())
        self.assertNotEqual(before["entries"]["/usr/bin/existing"]["sha256"],
                            after["entries"]["/usr/bin/existing"]["sha256"])
        self.assertIn("/usr/bin/gone", before["entries"])
        self.assertNotIn("/usr/bin/gone", after["entries"])

    def test_nonzero_exit_keeps_complete_failure_evidence(self):
        with self.assertRaises(capture.InstallCommandFailed) as raised:
            capture.capture_install(self.fx.root, ["installer", "fail"], cwd=self.fx.root)
        event = raised.exception.event
        self.assertEqual(event["exit_status"], 7)
        self.assertIn("/usr/bin/partial", event["changed_paths"])
        self.assertTrue((self.fx.root / event["artifacts"]["stderr"]["path"]).is_file())

    def test_outside_root_write_attempt_is_rejected_and_recorded(self):
        with self.assertRaisesRegex(capture.CaptureError, "outside the fixture"):
            capture.capture_install(self.fx.root, ["installer", "outside"], cwd=self.fx.root)
        event_files = list((self.fx.root / capture.CAPTURE_DIR / "events").glob("*/event.json"))
        self.assertEqual(len(event_files), 1)
        event = json.loads(event_files[0].read_text(encoding="utf-8"))
        self.assertTrue(event["outside_root_write_attempts"])
        self.assertRegex(event["outside_root_write_attempts"][0], r"etc[\\/]passwd")

    def test_io_uring_setup_invalidates_event_as_observation_violation(self):
        with self.assertRaisesRegex(capture.CaptureError, "observation/integrity violations"):
            capture.capture_install(self.fx.root, ["installer", "io-uring"], cwd=self.fx.root)
        event_files = list((self.fx.root / capture.CAPTURE_DIR / "events").glob("*/event.json"))
        self.assertEqual(len(event_files), 1)
        event = json.loads(event_files[0].read_text(encoding="utf-8"))
        self.assertEqual(event["outside_root_write_attempts"], [])
        self.assertEqual(len(event["observation_violations"]), 1)
        self.assertIn("io_uring_setup observed", event["observation_violations"][0])
        self.assertTrue(event["observation_violations"][0].startswith("line 1:"))

    def test_root_id_mutation_is_detected_and_persisted_as_integrity_violation(self):
        with self.assertRaisesRegex(capture.CaptureError, "observation/integrity violations"):
            capture.capture_install(self.fx.root, ["installer", "change-root-id"], cwd=self.fx.root)
        event_files = list((self.fx.root / capture.CAPTURE_DIR / "events").glob("*/event.json"))
        self.assertEqual(len(event_files), 1)
        event = json.loads(event_files[0].read_text(encoding="utf-8"))
        self.assertEqual(event["exit_status"], 0)
        self.assertTrue(any("root-id content or inode metadata changed" in item
                            for item in event["observation_violations"]))

    def test_denied_root_id_write_attempt_and_errno_are_persisted(self):
        with self.assertRaisesRegex(capture.CaptureError, "observation/integrity violations"):
            capture.capture_install(self.fx.root, ["installer", "attempt-root-id"], cwd=self.fx.root)
        event_files = list((self.fx.root / capture.CAPTURE_DIR / "events").glob("*/event.json"))
        event = json.loads(event_files[0].read_text(encoding="utf-8"))
        self.assertEqual(len(event["root_id_write_attempts"]), 1)
        self.assertIn("O_WRONLY|O_TRUNC", event["root_id_write_attempts"][0])
        self.assertIn("EROFS (Read-only file system)", event["root_id_write_attempts"][0])
        self.assertEqual((self.fx.root / capture.CAPTURE_DIR / "root-id").read_text(encoding="ascii"),
                         event["root_id"] + "\n")

    def test_trace_observation_parser_detects_pid_prefixed_io_uring_setup(self):
        trace = self.fx.root / "trace.log"
        trace.write_text(
            "openat(AT_FDCWD, \"/fixture/read-only\", O_RDONLY) = 3\n"
            "[pid 4242] io_uring_setup(2, 0x7ffc1234) = 5\n",
            encoding="utf-8")
        violations = capture._trace_observation_violations(trace)
        self.assertEqual(len(violations), 1)
        self.assertIn("line 2: io_uring_setup observed", violations[0])

    def test_trace_distinguishes_symlink_destination_from_target(self):
        trace = self.fx.root / "trace.log"
        outside = self.fx.root.parent / "outside-target"
        link = self.fx.root / "link"
        trace.write_text(
            f"symlink({json.dumps(str(outside))}, {json.dumps(str(link))}) = 0\n"
            f"symlink({json.dumps(str(link))}, {json.dumps(str(outside / 'bad-link'))}) = 0\n",
            encoding="utf-8")
        violations = capture._trace_outside_writes(trace, self.fx.root, self.fx.root)
        self.assertEqual(len(violations), 1)
        self.assertIn(str(outside / "bad-link"), violations[0])

    def test_trace_ignores_outside_readonly_open_and_rejects_write_open(self):
        trace = self.fx.root / "trace.log"
        outside = self.fx.root.parent / "outside-source"
        trace.write_text(
            f"openat(AT_FDCWD, {json.dumps(str(outside))}, O_RDONLY|O_CLOEXEC) = 3\n"
            f"openat(AT_FDCWD, {json.dumps(str(outside))}, O_WRONLY|O_CREAT, 0644) = 4\n",
            encoding="utf-8")
        violations = capture._trace_outside_writes(trace, self.fx.root, self.fx.root)
        self.assertEqual(len(violations), 1)
        self.assertIn(str(outside), violations[0])

    def test_trace_resolves_symlinkat_dirfd_and_linkat_destination(self):
        trace = self.fx.root / "trace.log"
        destination = self.fx.root / "usr/bin/new-link"
        source = self.fx.root.parent / "read-only-source"
        trace.write_text(
            f"symlinkat({json.dumps('/usr/lib/tool')}, 42<{self.fx.root / 'usr/bin'}>, \"new-link\") = 0\n"
            f"linkat(AT_FDCWD, {json.dumps(str(source))}, AT_FDCWD, {json.dumps(str(destination))}, 0) = 0\n",
            encoding="utf-8")
        self.assertEqual(capture._trace_outside_writes(trace, self.fx.root, self.fx.root), [])

    def test_trace_checks_descriptor_mutations_and_allows_pipe_writes(self):
        trace = self.fx.root / "trace.log"
        outside = self.fx.root.parent / "outside-open-file"
        inside_log = self.fx.root / capture.CAPTURE_DIR / "events/event/stdout.log"
        trace.write_text(
            f'write(1<pipe:[12345]>, "command output", 14) = 14\n'
            f'write(3<{inside_log}>, "captured", 8) = 8\n'
            f'ftruncate(4<{outside}>, 0) = 0\n',
            encoding="utf-8")
        violations = capture._trace_outside_writes(trace, self.fx.root, self.fx.root)
        self.assertEqual(len(violations), 1)
        self.assertIn("ftruncate", violations[0])

    def test_trace_fchmodat2_checks_path_and_relative_dirfd(self):
        trace = self.fx.root / "trace.log"
        outside = self.fx.root.parent / "outside-mode-target"
        inside_dir = self.fx.root / "usr/bin"
        trace.write_text(
            f"fchmodat2(AT_FDCWD, {json.dumps(str(outside))}, 0644, 0) = 0\n"
            f"fchmodat2(42<{inside_dir}>, \"tool\", 0755, 0) = 0\n",
            encoding="utf-8")
        violations = capture._trace_outside_writes(trace, self.fx.root, self.fx.root)
        self.assertEqual(len(violations), 1)
        self.assertIn(str(outside), violations[0])

    def test_missing_strace_refuses_before_running_command(self):
        with mock.patch.object(capture.shutil, "which", side_effect=lambda name: None if name == "strace" else "/usr/bin/bwrap"):
            with self.assertRaisesRegex(capture.CaptureError, "strace is required"):
                capture.capture_install(self.fx.root, ["installer", "write"], cwd=self.fx.root)
        self.execute_mock.assert_not_called()

    def test_symlinked_capture_root_is_rejected_before_outside_directory_creation(self):
        with tempfile.TemporaryDirectory(prefix="m04-event-outside-") as outside_name:
            outside = Path(outside_name)
            try:
                (self.fx.root / capture.CAPTURE_DIR).symlink_to(outside, target_is_directory=True)
            except (OSError, NotImplementedError) as exc:
                self.skipTest(f"symlink creation is unavailable: {exc}")
            with self.assertRaisesRegex(capture.CaptureError, "symlink path component refused"):
                capture.capture_install(self.fx.root, ["installer", "write"], cwd=self.fx.root)
            self.assertEqual(list(outside.iterdir()), [])

    def test_bwrap_mounts_host_readonly_fixture_writable_and_evidence_readonly(self):
        self.execute.stop()
        event_store = self.fx.root / capture.CAPTURE_DIR / "events"
        event_store.mkdir(parents=True)
        root_id_path = self.fx.root / capture.CAPTURE_DIR / "root-id"
        root_id_path.write_text("0" * 32 + "\n", encoding="ascii")
        trace = self.fx.root / "trace.log"
        stdout, stderr = self.fx.root / "stdout.log", self.fx.root / "stderr.log"
        fake_proc = SimpleNamespace(stdout=io.BytesIO(), stderr=io.BytesIO(),
                                    poll=lambda: 0, wait=lambda: 0)
        with mock.patch.object(capture.subprocess, "Popen", return_value=fake_proc) as run:
            policy = self.fx.root / "policy.bpf"
            policy.write_bytes(capture._seccomp_deny_io_uring_program())
            status = capture._execute(["installer"], self.fx.root, {}, self.fx.root,
                                      trace, policy, "/usr/bin/strace", "/usr/bin/bwrap", stdout, stderr)
        self.assertEqual(status, 0)
        argv = run.call_args.args[0]
        self.assertEqual(run.call_args.kwargs["stdout"], subprocess.PIPE)
        self.assertEqual(run.call_args.kwargs["stderr"], subprocess.PIPE)
        self.assertTrue(run.call_args.kwargs["close_fds"])
        self.assertEqual(len(run.call_args.kwargs["pass_fds"]), 1)
        self.assertIn("--seccomp", argv)
        self.assertLess(argv.index("--ro-bind"), argv.index("--bind"))
        read_only = [index for index, arg in enumerate(argv) if arg == "--ro-bind"]
        self.assertGreater(read_only[1], argv.index("--bind"))
        self.assertIn(str(event_store), argv)
        self.assertIn(str(root_id_path), argv)
        self.assertEqual(argv.count("--ro-bind"), 3)
        self.assertEqual(argv.count("--bind"), 1)
        trace_arg = argv[argv.index("-e") + 1]
        self.assertIn("io_uring_setup", trace_arg)

    def test_seccomp_policy_denies_io_uring_and_allows_other_syscalls(self):
        program = capture._seccomp_deny_io_uring_program()
        self.assertEqual(len(program), 4 * 8)
        instructions = [struct.unpack("=HBBI", program[index:index + 8])
                        for index in range(0, len(program), 8)]
        self.assertEqual(instructions[0], (0x20, 0, 0, 0))
        self.assertEqual(instructions[1][0:3], (0x15, 0, 1))
        self.assertEqual(instructions[2], (0x06, 0, 0, 0x00050001))
        self.assertEqual(instructions[3], (0x06, 0, 0, 0x7FFF0000))

    def test_parent_streams_mocked_pipe_output_without_opening_logs_for_child(self):
        stdout_path, stderr_path = self.fx.root / "stdout.log", self.fx.root / "stderr.log"
        observed = {}

        def fake_popen(argv, **kwargs):
            observed.update(kwargs)
            self.assertFalse(stdout_path.exists())
            self.assertFalse(stderr_path.exists())
            return SimpleNamespace(stdout=io.BytesIO(b"descendant stdout\nparent stdout\n"),
                                   stderr=io.BytesIO(b"descendant stderr\nparent stderr\n"),
                                   poll=lambda: 0, wait=lambda: 0)

        with mock.patch.object(capture.subprocess, "Popen", side_effect=fake_popen):
            status = capture._run_with_parent_logs(
                ["installer"], self.fx.root, {}, stdout_path, stderr_path)

        self.assertEqual(status, 0)
        self.assertEqual(observed["stdout"], subprocess.PIPE)
        self.assertEqual(observed["stderr"], subprocess.PIPE)
        self.assertTrue(observed["close_fds"])
        self.assertEqual(stdout_path.read_bytes(), b"descendant stdout\nparent stdout\n")
        self.assertEqual(stderr_path.read_bytes(), b"descendant stderr\nparent stderr\n")

    @unittest.skipUnless(sys.platform == "linux", "real inherited-pipe process test requires Linux")
    def test_command_descendant_uses_pipe_stdio_and_parent_preserves_output(self):
        stdout_path, stderr_path = self.fx.root / "stdout.log", self.fx.root / "stderr.log"
        child_code = "import os; os.write(1, b'descendant stdout\\n'); os.write(2, b'descendant stderr\\n')"
        parent_code = (
            "import os, subprocess, sys; "
            f"subprocess.run([sys.executable, '-c', {child_code!r}], check=True); "
            "os.write(1, b'parent stdout\\n'); os.write(2, b'parent stderr\\n')"
        )
        real_popen = subprocess.Popen
        observed = {}

        def checked_popen(argv, **kwargs):
            observed.update(kwargs)
            # The regular evidence files do not exist/open until after spawn.
            self.assertFalse(stdout_path.exists())
            self.assertFalse(stderr_path.exists())
            return real_popen(argv, **kwargs)

        with mock.patch.object(capture.subprocess, "Popen", side_effect=checked_popen):
            status = capture._run_with_parent_logs(
                [sys.executable, "-c", parent_code], self.fx.root, {}, stdout_path, stderr_path)

        self.assertEqual(status, 0)
        self.assertEqual(observed["stdout"], subprocess.PIPE)
        self.assertEqual(observed["stderr"], subprocess.PIPE)
        self.assertTrue(observed["close_fds"])
        self.assertEqual(stdout_path.read_bytes(), b"descendant stdout\nparent stdout\n")
        self.assertEqual(stderr_path.read_bytes(), b"descendant stderr\nparent stderr\n")

    def test_snapshot_rejects_symlink_target_escape(self):
        link = self.fx.root / "escape"
        try:
            link.symlink_to("../../outside", target_is_directory=False)
        except (OSError, NotImplementedError) as exc:
            self.skipTest(f"symlink creation is unavailable: {exc}")
        with self.assertRaisesRegex(capture.CaptureError, "symlink target escapes"):
            capture._snapshot(self.fx.root, "fixture-root-id")

    def test_metadata_hashes_xattrs_and_capabilities_and_fails_closed(self):
        path = self.fx.root / "metadata-file"
        path.write_bytes(b"payload")
        values = {"user.example": b"value", "security.capability": b"cap-data"}
        with mock.patch.object(capture.os, "listxattr", return_value=list(values), create=True), \
                mock.patch.object(capture.os, "getxattr", side_effect=lambda _path, name, **_kw: values[name], create=True):
            metadata = capture._metadata_support(path, path.lstat())
        canonical = json.dumps([
            {"name": name, "value_sha256": capture.hashlib.sha256(value).hexdigest()}
            for name, value in sorted(values.items())],
            sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        self.assertEqual(metadata["xattrs_sha256"], capture.hashlib.sha256(canonical).hexdigest())
        self.assertEqual(metadata["capabilities_sha256"], capture.hashlib.sha256(b"cap-data").hexdigest())
        with mock.patch.object(capture.os, "listxattr", side_effect=OSError("denied"), create=True):
            with self.assertRaisesRegex(capture.CaptureError, "cannot read xattrs"):
                capture._metadata_support(path, path.lstat())

    def test_snapshot_fingerprint_preserves_special_node_subtype(self):
        path = self.fx.root / "special-node"
        support = {"xattrs_sha256": "0" * 64, "capabilities_sha256": "0" * 64,
                   "hardlink_count": 1, "hardlink_group_sha256": None}
        fifo_info = SimpleNamespace(st_mode=stat.S_IFIFO | 0o644, st_uid=0, st_gid=0, st_rdev=0)
        socket_info = SimpleNamespace(st_mode=stat.S_IFSOCK | 0o644, st_uid=0, st_gid=0, st_rdev=0)
        with mock.patch.object(capture.os, "lstat", side_effect=[fifo_info, socket_info]), \
                mock.patch.object(capture, "_metadata_support", return_value=support):
            fifo = capture._fingerprint(path, self.fx.root)
            socket = capture._fingerprint(path, self.fx.root)
        self.assertEqual(fifo["type"], "special")
        self.assertEqual(fifo["special_type"], "fifo")
        self.assertEqual(socket["special_type"], "socket")
        self.assertNotEqual(fifo, socket)

    def test_hardlink_count_and_group_identity_are_emitted(self):
        first, second = self.fx.root / "hardlink-a", self.fx.root / "hardlink-b"
        first.write_bytes(b"shared inode")
        try:
            second.hardlink_to(first)
        except (OSError, NotImplementedError) as exc:
            self.skipTest(f"hardlinks are unavailable: {exc}")
        one = capture._metadata_support(first, first.lstat())
        two = capture._metadata_support(second, second.lstat())
        self.assertEqual(one["hardlink_count"], 2)
        self.assertEqual(two["hardlink_count"], 2)
        self.assertEqual(one["hardlink_group_sha256"], two["hardlink_group_sha256"])


if __name__ == "__main__":
    unittest.main()
