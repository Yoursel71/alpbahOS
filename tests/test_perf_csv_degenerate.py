"""analyze_kwin_perf_csv.py must reject a CSV without a usable frame interval.

Found in the 29 Sep 2026 audit (handoff 020): two rows with the same pageflip
timestamp (or timestamps that never increase) pass load_rows()' "at least two frames"
check but produce no interval, and summarize() died with an uncaught
statistics.StatisticsError instead of the tool's "HATA: ..." / exit code 2.
"""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr
from io import StringIO
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "profiles" / "perf" / "analyze_kwin_perf_csv.py"
SPEC = importlib.util.spec_from_file_location("perf_csv_degenerate", SCRIPT)
perf = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(perf)

HEADER = ",".join(perf.COLUMNS)


def _csv(directory: Path, flips: list[int]) -> Path:
    lines = [HEADER]
    for flip in flips:
        lines.append(f"{flip},{flip},{flip - 3_000_000},{flip - 1_000_000},0,16666666,0,0,1")
    path = directory / "kwin perf statistics test.csv"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


class DegenerateCsvTests(unittest.TestCase):
    def test_identical_timestamps_are_a_data_error_not_a_crash(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = _csv(Path(tmp), [1000, 1000])
            with self.assertRaises(perf.PerfDataError):
                perf.summarize(perf.load_rows(path))

    def test_main_reports_exit_code_2(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = _csv(Path(tmp), [1000, 1000, 1000])
            err = StringIO()
            with redirect_stderr(err):
                code = perf.main([str(path)])
            self.assertEqual(code, 2)
            self.assertIn("HATA:", err.getvalue())

    def test_normal_csv_still_summarizes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = _csv(Path(tmp), [16_666_666 * i for i in range(1, 11)])
            summary = perf.summarize(perf.load_rows(path))
            self.assertEqual(summary["frames"], 10)
            self.assertAlmostEqual(summary["frame_interval_ms"]["median"], 16.667, places=2)


if __name__ == "__main__":
    unittest.main()
