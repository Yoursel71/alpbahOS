# Liquid profile — prototype plan (not implemented)

Not in the first release (D116). Kept as a design note for a possible later prototype.

Status (26 September 2026): **plan.** No code, no measurements. The v1 decision D10 says "liquid glass or plain glass on strong devices". Under MASTER_PLAN §7.2, if only blur is applied, the result counts as **Glass**, not Liquid. The Glass profile uses KWin's ready-made blur/contrast effects through `bin/alpbah-gorunum glass`. Liquid needs a separate KWin effect.

## Why it cannot be done with a ready-made component

KWin 6.4.4's `blur` effect (`src/plugins/blur/`) samples the area behind a window and blurs it. Its only settings are `BlurStrength` and `NoiseStrength` (`blur.kcfg`). Glass-edge refraction (the background shifting near the edge of the glass), light highlights and a sense of thickness need the background sample to be read through a displacement map. None of the existing effects has a setting for this.

## Prototype route (ready-made mechanisms)

1. Source: on a source copy of KWin's `blur` effect, a separate effect (`alpbah_liquid`) written against the effect API (C++ `KWin::Effect`, `GLShader`). The compositor, panel and window manager are not changed.
2. Shader: while the blur's background texture is read, only the area N px inside the window or panel edge gets a small UV offset along the normal vector, plus a thin edge highlight. The centre stays the same as Glass, for readability.
3. Scope: only Plasma panels and the taskbar (the surfaces that ask for blur). Application windows are not affected.
4. Gate: OpenGL compositing and a hardware driver are required. The effect does not load on softpipe/LLVMpipe (the `alpbah-gorunum` Glass check uses the same rule).

## Acceptance criteria (not "ready" until measured)

| Measurement | Method | Threshold (proposed) |
|---|---|---|
| Frame time | Same scene under Glass and Liquid, 60 s; PERF-01 method (`profiles/perf/`) | At 1080p/60 Hz, median ≤ 16.7 ms; p95 increase versus Glass ≤ 2 ms |
| Memory | KWin RSS difference with `profiles/perf/collect_session_metrics.py` | ≤ +30 MiB versus Glass |
| Readability | Panel text and icons on light and dark wallpapers | Same contrast as Glass (WCAG AA target) |
| Fallback | After `alpbah-gorunum solid`, the effect is not loaded | Not present in `/Effects loadedEffects` |

## Open items

- The effect is compiled C++. Compilation and packaging belong to the BLFS build chain. asistan prepares the source and shader; the build runs in the BLFS chain.
- The target hardware class (RTX) is not available in the earlier Windows-host VM setup (history in [docs/archive/](../../docs/archive/)). Measurement needs bare-metal hardware and can be deferred to BETA-01.
- If it fails, the alpha ships with Glass, and Liquid is written up as a known limitation (MASTER_PLAN §13).
