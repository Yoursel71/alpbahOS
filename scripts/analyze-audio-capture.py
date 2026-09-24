#!/usr/bin/env python3
"""Report deterministic metrics for an S16_LE audio capture.

Accepts WAV (PCM 16-bit little-endian) or headerless raw PCM. Raw input needs
an explicit sample rate and channel count. This is a signal-quality helper for
M06 acceptance evidence; it does not prove that sound reached a physical
speaker or came from a physical microphone.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
import wave
from pathlib import Path


def read_pcm(path: Path, sample_rate: int | None, channels: int | None) -> tuple[bytes, int, int]:
    with path.open("rb") as stream:
        is_wave = stream.read(12)[0:4] == b"RIFF"
    if is_wave:
        with wave.open(str(path), "rb") as wav:
            if wav.getcomptype() != "NONE" or wav.getsampwidth() != 2:
                raise ValueError("WAV must be uncompressed 16-bit PCM")
            if sample_rate is not None and sample_rate != wav.getframerate():
                raise ValueError("--sample-rate conflicts with WAV header")
            if channels is not None and channels != wav.getnchannels():
                raise ValueError("--channels conflicts with WAV header")
            return wav.readframes(wav.getnframes()), wav.getframerate(), wav.getnchannels()

    if sample_rate is None or channels is None:
        raise ValueError("raw PCM requires --sample-rate and --channels")
    return path.read_bytes(), sample_rate, channels


def analyze(data: bytes, sample_rate: int, channels: int) -> dict[str, int | float | str]:
    if sample_rate <= 0 or channels <= 0:
        raise ValueError("sample rate and channel count must be positive")
    if len(data) % (2 * channels):
        raise ValueError("PCM byte count is not a whole number of frames")
    if not data:
        raise ValueError("PCM capture is empty")

    samples = struct.unpack("<" + "h" * (len(data) // 2), data)
    frames = len(samples) // channels
    peak = max(abs(value) for value in samples)
    nonzero = sum(value != 0 for value in samples)
    rms = math.sqrt(sum(value * value for value in samples) / len(samples))

    # Count positive-going zero crossings on channel 0. This is a useful
    # frequency estimate for clean sine captures, not a general pitch detector.
    mono = samples[0::channels]
    crossings = sum(a <= 0 < b for a, b in zip(mono, mono[1:]))
    duration = frames / sample_rate
    tone_hz = crossings / duration if duration else 0.0
    return {
        "sample_rate_hz": sample_rate,
        "channels": channels,
        "frames": frames,
        "samples": len(samples),
        "nonzero_samples": nonzero,
        "peak": peak,
        "rms": round(rms, 4),
        "positive_zero_crossing_hz_channel_0": round(tone_hz, 4),
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--sample-rate", type=int, help="required for raw PCM")
    parser.add_argument("--channels", type=int, help="required for raw PCM")
    parser.add_argument("--expect-frames", type=int)
    parser.add_argument("--min-nonzero", type=int)
    parser.add_argument("--min-rms", type=float)
    parser.add_argument("--tone-hz", type=float, help="check channel-0 zero-crossing estimate")
    parser.add_argument("--tone-tolerance-hz", type=float, default=5.0)
    args = parser.parse_args(argv)

    try:
        data, rate, channels = read_pcm(args.capture, args.sample_rate, args.channels)
        result = analyze(data, rate, channels)
    except (OSError, ValueError, wave.Error) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, indent=2, sort_keys=True))
    failures = []
    if args.expect_frames is not None and result["frames"] != args.expect_frames:
        failures.append(f"frames {result['frames']} != {args.expect_frames}")
    if args.min_nonzero is not None and result["nonzero_samples"] < args.min_nonzero:
        failures.append(f"nonzero samples {result['nonzero_samples']} < {args.min_nonzero}")
    if args.min_rms is not None and result["rms"] < args.min_rms:
        failures.append(f"RMS {result['rms']} < {args.min_rms}")
    if args.tone_hz is not None:
        measured = float(result["positive_zero_crossing_hz_channel_0"])
        if abs(measured - args.tone_hz) > args.tone_tolerance_hz:
            failures.append(f"tone estimate {measured} Hz outside {args.tone_hz} +/- {args.tone_tolerance_hz} Hz")
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
