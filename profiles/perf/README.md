# PERF-01 — RAM, frame time and effect measurement method

Status (26 September 2026): **method and tools ready; no measurements taken.** Updated 2026-11-06: the targets now follow D135. Owner: asistan (D100; asistan is the only agent, so there is no owner split). Prerequisite: DESKTOP-01 (a running Plasma session). The tools themselves were tested on Windows with fake data (`tests/test_m08_desktop_profile.py`). There is no real Gen2 or bare-metal data yet.

Liquid is not in the first release (D116). Its plan is in [liquid-prototype.md](../desktop/liquid-prototype.md); this document only covers the Liquid measurement criteria that depend on it.

## Targets (not met until measured)

| Metric | Target | Source |
|---|---|---|
| Idle memory used (MemTotal − MemAvailable) | ≤ 1024 MiB (1 GiB), on the 4 GiB x86_64 class | D135 (v1 P08). Design target; measured before it is published as a requirement |
| Frame time (median, 1080p/60 Hz, moving scene) | ≤ 16.7 ms | MASTER_PLAN §7.3 |
| Glass − Solid difference | Memory, median and p95 frame time recorded separately | MASTER_PLAN §7.3 |
| Liquid (later prototype) | p95 increase versus Glass ≤ 2 ms; KWin PSS ≤ +30 MiB (proposed) | [liquid-prototype.md](../desktop/liquid-prototype.md) |

The earlier Windows-host VM results do not replace real hardware results (MASTER_PLAN §11.1). The current Gen2 image draws with softpipe/VGEM, so frame times from it are recorded as a "virtual/software renderer" row. They are not evidence for the old-PC target.

## Tools

- [`collect_session_metrics.py`](collect_session_metrics.py): read-only snapshot. Covers `/proc/meminfo`, the PSS/RSS values of the monitored desktop processes, the user's total PSS, the KWin compositing type, renderer and driver, active effects and the `alpbah-gorunum` profile. Writes JSON.
- [`analyze_kwin_perf_csv.py`](analyze_kwin_perf_csv.py): reads the `kwin perf statistics <output>.csv` file that KWin 6.4.4 writes with `KWIN_LOG_PERFORMANCE_DATA=1`. Produces frame time (difference between successive pageflips), render time, late-frame count and budget-overrun ratio. Source: kwin `src/core/renderloop.cpp`.

## Method (Gen2 test VM or bare metal)

1. **Environment record:** CPU/RAM/GPU, resolution/refresh rate, kernel, renderer (the `kwin` field of `collect_session_metrics.py` output), profile.
2. **Turn on KWin measurement (test session only):** add `[Service]` and `Environment=KWIN_LOG_PERFORMANCE_DATA=1` to `~/.config/systemd/user/plasma-kwin_wayland.service.d/perf.conf`, then restart the session. The CSV is written to the KWin process working directory (find it with `/proc/$(pidof kwin_wayland)/cwd`). Remove the drop-in after measuring; the file keeps growing.
3. **Idle memory:** after login, wait 5 minutes, then run `collect_session_metrics.py --label <profile>-idle`.
4. **Moving scenes (each 60 s, same order):** (a) drag a window, (b) open and close Overview with Win+Tab, (c) continuous output in Konsole. Before each scene, reset the CSV (move the file away), then run `analyze_kwin_perf_csv.py <csv> --json --budget-ms 16.7`.
5. **Profiles:** each scene is repeated under `alpbah-gorunum solid` and `alpbah-gorunum glass`. Glass is refused on a software renderer; a result obtained with `--zorla` is marked separately.
6. **Record:** JSON and summaries go to `docs/verification/perf01-<environment>-<date>/`; the table is linked from the PERF-01 row. Failed measurements are recorded too.

## Known limits

- KWin's CSV records only drawn frames. An empty desktop has no frames; frame time is measured during moving scenes.
- Client-side (application) frame time is not measured; only the compositor side is.
- PSS splits shared memory between processes; it is not one process's "own" memory. Comparisons use the same metric throughout.
