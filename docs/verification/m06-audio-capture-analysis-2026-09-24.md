# M06 PCM capture analysis helper — 24 September 2026

## Purpose and limits

Added `scripts/analyze-audio-capture.py` to make PCM capture evidence repeatable
for future M06 audio tests. It accepts uncompressed 16-bit PCM WAV files or
headerless raw S16_LE data (raw files require explicit sample rate and channel
count), then reports frame/sample counts, nonzero samples, peak, RMS,
channel-0 positive zero-crossing frequency estimate, and the PCM payload
SHA-256. Optional CLI thresholds can reject unexpected frame counts, silence,
low RMS, or a tone outside the requested frequency tolerance.

This is an offline signal-analysis helper. It does not establish which device
produced the recording, prove an ALSA/PipeWire/RDP route, or prove physical
speaker/microphone output. Acceptance still needs separately recorded command,
guest/host environment, device and graph evidence, and the raw capture artifact.

## Validation

- Windows host: `python -m pytest -q tests/test_audio_capture_analysis.py` —
  **4 passed**.
- `python -m py_compile scripts/analyze-audio-capture.py` — passed.
- `python docs/handoffs/claude/tools/check_docs.py` — 0 findings.
- `git diff --check` — passed.

The tests cover stereo tone metrics, WAV header validation, rejection of an
incomplete raw frame, and CLI acceptance/rejection thresholds. No guest,
Builder, rootfs, VM image, or physical audio hardware was changed or tested by
this helper validation.
