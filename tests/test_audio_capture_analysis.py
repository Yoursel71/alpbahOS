import importlib.util
import io
import math
import struct
import tempfile
import unittest
import wave
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "analyze-audio-capture.py"
SPEC = importlib.util.spec_from_file_location("audio_capture_analysis", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class AudioCaptureAnalysisTests(unittest.TestCase):
    def test_analyzes_stereo_tone_metrics(self):
        rate = 48000
        frames = 4800
        samples = [int(12000 * math.sin(2 * math.pi * 440 * i / rate)) for i in range(frames)]
        interleaved = [sample for value in samples for sample in (value, value)]
        data = struct.pack("<" + "h" * len(interleaved), *interleaved)

        result = MODULE.analyze(data, rate, 2)

        self.assertEqual(result["frames"], frames)
        self.assertEqual(result["samples"], frames * 2)
        self.assertEqual(result["peak"], 12000)
        self.assertGreater(result["nonzero_samples"], frames)
        self.assertAlmostEqual(result["positive_zero_crossing_hz_channel_0"], 440, delta=10)

    def test_reads_wav_and_checks_header(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "tone.wav"
            with wave.open(str(path), "wb") as wav:
                wav.setnchannels(1)
                wav.setsampwidth(2)
                wav.setframerate(8000)
                wav.writeframes(struct.pack("<8h", 0, 1, 2, 3, 4, 3, 2, 1))

            data, rate, channels = MODULE.read_pcm(path, None, None)
            with self.assertRaisesRegex(ValueError, "conflicts"):
                MODULE.read_pcm(path, 16000, None)

        self.assertEqual((rate, channels, len(data)), (8000, 1, 16))

    def test_rejects_incomplete_pcm_frame(self):
        with self.assertRaisesRegex(ValueError, "whole number of frames"):
            MODULE.analyze(b"\x00\x00\x01", 48000, 1)

    def test_cli_thresholds_accept_and_reject_capture(self):
        rate = 8000
        samples = [int(10000 * math.sin(2 * math.pi * 440 * i / rate)) for i in range(rate)]
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "capture.raw"
            path.write_bytes(struct.pack("<" + "h" * len(samples), *samples))
            common = [str(path), "--sample-rate", str(rate), "--channels", "1"]
            with mock.patch.object(MODULE.sys, "stdout", new_callable=io.StringIO):
                self.assertEqual(MODULE.main(common + ["--expect-frames", str(rate), "--min-nonzero", "7000",
                                                       "--min-rms", "6000", "--tone-hz", "440"]), 0)
            errors = io.StringIO()
            with mock.patch.object(MODULE.sys, "stdout", new_callable=io.StringIO), \
                    mock.patch.object(MODULE.sys, "stderr", errors):
                self.assertEqual(MODULE.main(common + ["--expect-frames", "1"]), 1)
            self.assertIn("FAIL: frames", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
