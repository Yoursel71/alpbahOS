#!/usr/bin/env python3
"""analyze_kwin_perf_csv.py -- KWin kare zamanlaması CSV'sini özetler (stdlib-only).

KWin 6.4.4, `KWIN_LOG_PERFORMANCE_DATA=1` ortam değişkeniyle çalıştığında her çıkış
için çalışma dizinine "kwin perf statistics <çıkış>.csv" yazar (src/core/renderloop.cpp).
Sütunlar (nanosaniye, steady clock): target pageflip timestamp, pageflip timestamp,
render start, render end, safety margin, refresh duration, vrr, tearing,
predicted render time.

Hesaplanan:
  frame_interval_ms   ardışık pageflip zaman damgaları arası süre (kare süresi)
  render_ms           render end - render start (KWin'in kareyi çizme süresi)
  late_frames         pageflip, hedef pageflip zamanından yarım yenileme süresinden fazla geç
  over_budget_pct     kare süresi > 1.5 x yenileme süresi olan karelerin oranı (atlanan kare)
Boştaki masaüstünde KWin kare üretmez; kare süresi ancak sürekli değişen bir sahnede
(pencere sürükleme, Overview açma) anlamlıdır. Bu yüzden özet sahne başına alınır.

Kullanım:
    python analyze_kwin_perf_csv.py "kwin perf statistics Virtual-1.csv" [--json] [--budget-ms 16.7]
Çıkış kodu: 0 özetlendi, 1 medyan kare süresi bütçeyi aştı (--budget-ms verilmişse), 2 girdi hatası.
"""

from __future__ import annotations

import argparse
import csv
import json
import statistics
import sys
from pathlib import Path

COLUMNS = [
    "target pageflip timestamp", "pageflip timestamp", "render start", "render end",
    "safety margin", "refresh duration", "vrr", "tearing", "predicted render time",
]


class PerfDataError(Exception):
    pass


def percentile(values: list[float], pct: float) -> float:
    if not values:
        return float("nan")
    ordered = sorted(values)
    k = (len(ordered) - 1) * pct / 100
    lo, hi = int(k), min(int(k) + 1, len(ordered) - 1)
    return ordered[lo] + (ordered[hi] - ordered[lo]) * (k - lo)


def load_rows(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.reader(handle)
        header = [h.strip() for h in next(reader, [])]
        if header != COLUMNS:
            raise PerfDataError(f"beklenmeyen başlık: {header}")
        rows = []
        for lineno, raw in enumerate(reader, start=2):
            if not raw:
                continue
            if len(raw) != len(COLUMNS):
                raise PerfDataError(f"satır {lineno}: {len(raw)} sütun")
            try:
                rows.append({name: int(value) for name, value in zip(COLUMNS, raw)})
            except ValueError as exc:
                raise PerfDataError(f"satır {lineno}: {exc}") from exc
    if len(rows) < 2:
        raise PerfDataError("en az iki kare gerekir")
    return rows


def summarize(rows: list[dict]) -> dict:
    ms = 1_000_000.0
    flips = [r["pageflip timestamp"] for r in rows]
    intervals = [(b - a) / ms for a, b in zip(flips, flips[1:]) if b > a]
    renders = [(r["render end"] - r["render start"]) / ms for r in rows if r["render end"] >= r["render start"] > 0]
    refresh = statistics.median(r["refresh duration"] for r in rows) / ms
    late = sum(1 for r in rows if r["pageflip timestamp"] - r["target pageflip timestamp"] > r["refresh duration"] / 2)
    over = sum(1 for v in intervals if v > 1.5 * refresh)
    return {
        "frames": len(rows),
        "duration_s": round((flips[-1] - flips[0]) / 1e9, 3),
        "refresh_ms": round(refresh, 3),
        "frame_interval_ms": {
            "median": round(statistics.median(intervals), 3),
            "p95": round(percentile(intervals, 95), 3),
            "p99": round(percentile(intervals, 99), 3),
            "max": round(max(intervals), 3),
        },
        "render_ms": {
            "median": round(statistics.median(renders), 3) if renders else None,
            "p95": round(percentile(renders, 95), 3) if renders else None,
            "max": round(max(renders), 3) if renders else None,
        },
        "late_frames": late,
        "over_budget_pct": round(100.0 * over / len(intervals), 2),
        "vrr_frames": sum(r["vrr"] for r in rows),
        "tearing_frames": sum(r["tearing"] for r in rows),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("csv", type=Path)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--budget-ms", type=float, help="medyan kare süresi için eşik (ör. 16.7)")
    args = parser.parse_args(argv)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    try:
        summary = summarize(load_rows(args.csv))
    except (OSError, PerfDataError) as exc:
        print(f"HATA: {exc}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(summary, ensure_ascii=False, indent=1))
    else:
        fi, rt = summary["frame_interval_ms"], summary["render_ms"]
        print(f"kareler: {summary['frames']} ({summary['duration_s']} sn), yenileme {summary['refresh_ms']} ms")
        print(f"kare süresi ms: medyan {fi['median']}, p95 {fi['p95']}, p99 {fi['p99']}, en çok {fi['max']}")
        print(f"render ms: medyan {rt['median']}, p95 {rt['p95']}, en çok {rt['max']}")
        print(f"geç kare: {summary['late_frames']}, bütçe aşımı: %{summary['over_budget_pct']}")
    if args.budget_ms is not None and summary["frame_interval_ms"]["median"] > args.budget_ms:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
