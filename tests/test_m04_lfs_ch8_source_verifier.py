"""Focused tests for the read-only LFS Chapter 8 source checksum verifier."""

from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
import json
import os
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "verify-lfs-ch8-sources.py"
SPEC = importlib.util.spec_from_file_location("lfs_ch8_sources", SCRIPT)
verify = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(verify)


class LfsChapter8SourceVerifierTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.sources = self.root / "sources"
        self.sources.mkdir()
        self.payloads = {
            "alpha.tar.xz": b"alpha archive\n",
            "beta.tar.gz": b"beta archive\n",
            "gamma.tar.xz": b"gamma archive\n",
            "delta.tar.gz": b"delta archive\n",
        }
        self.entries = [
            {
                "index": index,
                "package": f"Fixture {index}",
                "archive": filename,
                "md5": hashlib.md5(payload, usedforsecurity=False).hexdigest(),
            }
            for index, (filename, payload) in enumerate(self.payloads.items(), start=1)
        ]

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write_payloads(self) -> None:
        for filename, payload in self.payloads.items():
            (self.sources / filename).write_bytes(payload)

    def copy_pinned_manifest(self, name: str = "fixture.json") -> tuple[dict, Path]:
        manifest = json.loads(verify.DEFAULT_MANIFEST.read_text(encoding="utf-8"))
        snapshot = verify.DEFAULT_MANIFEST.parent / manifest["source"]["snapshot_file"]
        (self.root / snapshot.name).write_bytes(snapshot.read_bytes())
        path = self.root / name
        path.write_text(json.dumps(manifest), encoding="utf-8")
        return manifest, path

    def test_pinned_manifest_has_exact_coverage_order_and_snapshot(self) -> None:
        manifest = verify.load_manifest(verify.DEFAULT_MANIFEST, verify.DEFAULT_COVERAGE)
        self.assertEqual(manifest["expected_count"], 79)
        self.assertEqual(len(manifest["entries"]), 79)
        self.assertEqual(
            [entry["package"] for entry in manifest["entries"]],
            verify.read_coverage_order(verify.DEFAULT_COVERAGE),
        )
        self.assertEqual(
            verify.sha256_file(
                verify.DEFAULT_MANIFEST.parent
                / manifest["source"]["snapshot_file"]
            ),
            manifest["source"]["snapshot_sha256"],
        )

    def test_matching_sources_pass_and_leave_source_tree_unchanged(self) -> None:
        self.write_payloads()
        before = {
            path.relative_to(self.sources): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in self.sources.rglob("*")
            if path.is_file()
        }

        results, counts, errors = verify.verify_sources(self.entries, self.sources)

        self.assertFalse(errors)
        self.assertEqual([result["status"] for result in results], ["MATCH"] * 4)
        self.assertEqual(counts["matched"], 4)
        self.assertEqual(
            results[0]["actual_sha256"],
            hashlib.sha256(self.payloads["alpha.tar.xz"]).hexdigest(),
        )
        after = {
            path.relative_to(self.sources): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in self.sources.rglob("*")
            if path.is_file()
        }
        self.assertEqual(before, after)

    def test_missing_and_mismatching_archives_fail(self) -> None:
        self.write_payloads()
        (self.sources / "beta.tar.gz").write_bytes(b"wrong bytes\n")
        (self.sources / "gamma.tar.xz").unlink()

        results, counts, errors = verify.verify_sources(self.entries, self.sources)

        self.assertFalse(errors)
        self.assertEqual(
            [result["status"] for result in results],
            ["MATCH", "MISMATCH", "MISSING", "MATCH"],
        )
        self.assertEqual(counts["mismatch"], 1)
        self.assertEqual(counts["missing"], 1)
        self.assertEqual(
            results[1]["actual_sha256"], hashlib.sha256(b"wrong bytes\n").hexdigest()
        )

    def test_duplicate_archive_basename_fails(self) -> None:
        self.write_payloads()
        nested = self.sources / "mirror"
        nested.mkdir()
        (nested / "alpha.tar.xz").write_bytes(self.payloads["alpha.tar.xz"])

        results, counts, _errors = verify.verify_sources(self.entries, self.sources)

        self.assertEqual(results[0]["status"], "DUPLICATE")
        self.assertEqual(counts["duplicate"], 1)
        self.assertEqual(len(results[0]["paths"]), 2)

    def test_duplicate_manifest_archive_is_rejected(self) -> None:
        manifest, manifest_path = self.copy_pinned_manifest("duplicate.json")
        manifest["entries"][1]["archive"] = manifest["entries"][0]["archive"]
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

        with self.assertRaisesRegex(verify.VerificationError, "duplicate archive"):
            verify.load_manifest(manifest_path, verify.DEFAULT_COVERAGE)

    def test_manifest_md5_must_match_official_snapshot(self) -> None:
        manifest, manifest_path = self.copy_pinned_manifest("altered.json")
        manifest["entries"][0]["md5"] = "0" * 32
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

        with self.assertRaisesRegex(verify.VerificationError, "differs from official"):
            verify.load_manifest(manifest_path, verify.DEFAULT_COVERAGE)

    def test_report_is_json_lines_with_counts(self) -> None:
        self.write_payloads()
        results, counts, errors = verify.verify_sources(self.entries, self.sources)
        import io

        output = io.StringIO()
        verify.emit_report(results, counts, errors, output)
        lines = [json.loads(line) for line in output.getvalue().splitlines()]

        self.assertEqual(len(lines), 5)
        self.assertEqual(lines[-1]["type"], "summary")
        self.assertEqual(lines[-1]["expected"], 4)
        self.assertEqual(lines[-1]["matched"], 4)

    def test_cli_exits_nonzero_for_missing_archive(self) -> None:
        output = io.StringIO()

        with contextlib.redirect_stdout(output):
            status = verify.main(["--source-dir", str(self.sources)])

        self.assertEqual(status, 1)
        self.assertIn('"status": "MISSING"', output.getvalue())
        self.assertIn('"expected": 79', output.getvalue())
        self.assertIn('"missing": 79', output.getvalue())

    def test_manifest_requires_exact_fields_types_and_safe_basenames(self) -> None:
        mutations = [
            (lambda data: data.__setitem__("extra", True), "manifest fields invalid"),
            (
                lambda data: data["source"].__setitem__("extra", True),
                "manifest source provenance is required",
            ),
            (
                lambda data: data["entries"][0].__setitem__("extra", True),
                "entry 1 fields invalid",
            ),
            (
                lambda data: data["entries"][0].__setitem__("index", True),
                "entry order/index mismatch",
            ),
            (
                lambda data: data["entries"][0].__setitem__("index", 1.0),
                "entry order/index mismatch",
            ),
            (
                lambda data: data.__setitem__("expected_count", True),
                "expected_count are required",
            ),
            (
                lambda data: data["entries"][0].__setitem__("archive", "../escape.tar"),
                "unsafe archive name",
            ),
            (
                lambda data: data["entries"][0].__setitem__("archive", "dir\\escape.tar"),
                "unsafe archive name",
            ),
            (
                lambda data: data["entries"][0].__setitem__("archive", "bad\0name.tar"),
                "unsafe archive name",
            ),
        ]
        for mutate, message in mutations:
            with self.subTest(message=message):
                manifest, manifest_path = self.copy_pinned_manifest("invalid.json")
                mutate(manifest)
                manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
                with self.assertRaisesRegex(verify.VerificationError, message):
                    verify.load_manifest(manifest_path, verify.DEFAULT_COVERAGE)

    def test_source_replacement_before_hash_is_rejected(self) -> None:
        self.write_payloads()
        path = self.sources / "alpha.tar.xz"
        replacement = self.sources / "replacement.tmp"
        replacement.write_bytes(b"replacement archive\n")
        original_open = Path.open

        def replace_then_open(target: Path, *args, **kwargs):
            if target == path:
                replacement.replace(path)
            return original_open(target, *args, **kwargs)

        from unittest import mock

        with mock.patch.object(Path, "open", replace_then_open):
            with self.assertRaises(verify.SourceFileChangedError):
                verify.digest_source_file(path)

    def test_source_metadata_change_while_hashing_is_rejected(self) -> None:
        self.write_payloads()
        path = self.sources / "alpha.tar.xz"
        original_open = Path.open

        class TouchDuringRead:
            def __init__(self, stream):
                self.stream = stream
                self.changed = False

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return self.stream.__exit__(*args)

            def fileno(self):
                return self.stream.fileno()

            def read(self, size=-1):
                if not self.changed:
                    info = path.stat()
                    os.utime(
                        path,
                        ns=(info.st_atime_ns, info.st_mtime_ns + 1_000_000_000),
                    )
                    self.changed = True
                return self.stream.read(size)

        def touch_on_open(target: Path, *args, **kwargs):
            stream = original_open(target, *args, **kwargs)
            return TouchDuringRead(stream) if target == path else stream

        from unittest import mock

        with mock.patch.object(Path, "open", touch_on_open):
            with self.assertRaises(verify.SourceFileChangedError):
                verify.digest_source_file(path)


if __name__ == "__main__":
    unittest.main()
