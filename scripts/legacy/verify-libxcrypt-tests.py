#!/usr/bin/env python3
"""Verify the complete Automake test result for the LFS Libxcrypt build."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


STATUSES = ("PASS", "SKIP", "XFAIL", "FAIL", "XPASS", "ERROR")
SUMMARY_KEYS = ("TOTAL", "PASS", "SKIP", "XFAIL", "FAIL", "XPASS", "ERROR")
# Baseline is the Builder's pre-existing /mnt/lfs/build/libxcrypt-4.4.38/test-suite.log
# captured before this isolated run (SHA-256 e3912e4ceed71053ef61a16dc6682886c494ba03b76001ac4659c004113598be):
# 43 total, 32 PASS, 11 SKIP, no failures; the eleven exit-77 test names below.
# The fresh run must reproduce it exactly; deviations require investigation.
SUMMARY_RE = re.compile(r"^#\s*(TOTAL|PASS|SKIP|XFAIL|FAIL|XPASS|ERROR):\s*(\d+)\s*$", re.M)
RESULT_RE = re.compile(r"^(PASS|SKIP|XFAIL|FAIL|XPASS|ERROR):\s+(test/\S+)\s*$", re.M)
EXPECTED_SKIPS = {
    "test/ka-bcrypt-x",
    "test/ka-bigcrypt",
    "test/ka-bsdicrypt",
    "test/ka-nt",
    "test/ka-sha1crypt",
    "test/ka-sunmd5",
    "test/alg-hmac-sha1",
    "test/alg-md4",
    "test/alg-sha1",
    "test/gensalt-nthash",
    "test/getrandom-fallbacks",
}


def parse_summary(text: str, origin: str) -> dict[str, int]:
    values: dict[str, int] = {}
    for key, raw in SUMMARY_RE.findall(text):
        if key in values:
            raise SystemExit(f"duplicate {key} count in {origin}")
        values[key] = int(raw)
    if set(values) != set(SUMMARY_KEYS):
        raise SystemExit(f"incomplete Automake summary in {origin}: got {sorted(values)}")
    return values


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--transcript", required=True, type=Path)
    parser.add_argument("--suite-log", required=True, type=Path)
    parser.add_argument("--expected-tests", type=int, default=43)
    parser.add_argument("--expected-pass", type=int, default=32)
    parser.add_argument("--expected-skip", type=int, default=11)
    args = parser.parse_args()

    transcript = args.transcript.read_text(encoding="utf-8", errors="replace")
    suite_log = args.suite_log.read_text(encoding="utf-8", errors="replace")
    expected_summary = {"TOTAL": args.expected_tests, "PASS": args.expected_pass,
                        "SKIP": args.expected_skip, "XFAIL": 0, "FAIL": 0,
                        "XPASS": 0, "ERROR": 0}
    summary = parse_summary(transcript, "make check transcript")
    suite_summary = parse_summary(suite_log, "test-suite.log")
    if summary != expected_summary:
        raise SystemExit(f"unexpected transcript summary: {summary}; expected {expected_summary}")
    if suite_summary != expected_summary:
        raise SystemExit(f"unexpected test-suite.log summary: {suite_summary}; expected {expected_summary}")

    results = RESULT_RE.findall(transcript)
    names = [name for _, name in results]
    if len(results) != args.expected_tests or len(set(names)) != args.expected_tests:
        raise SystemExit(f"expected {args.expected_tests} unique per-test result lines; got {len(results)} lines/{len(set(names))} unique")
    counts = {status: 0 for status in STATUSES}
    for status, _ in results:
        counts[status] += 1
    expected_counts = {status: expected_summary[status] for status in STATUSES}
    if counts != expected_counts:
        raise SystemExit(f"unexpected per-test status counts: {counts}; expected {expected_counts}")
    skips = {name for status, name in results if status == "SKIP"}
    if skips != EXPECTED_SKIPS:
        raise SystemExit(f"unexpected skipped-test set: {sorted(skips)}; expected {sorted(EXPECTED_SKIPS)}")
    print(f"LIBXCRYPT_TESTS={args.expected_tests} total; {args.expected_pass} PASS, {args.expected_skip} SKIP, 0 XFAIL/FAIL/XPASS/ERROR")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
