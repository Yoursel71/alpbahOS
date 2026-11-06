import io
import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import btrfs_send_ledger as ledger  # noqa: E402


def _tlv(attr_id: int, value: bytes, version: int, *, data: bool = False) -> bytes:
    head = struct.pack("<H", attr_id)
    if data and version >= 2:
        return head + value
    return head + struct.pack("<H", len(value)) + value


def _command(command_id: int, payload: bytes) -> bytes:
    header = struct.pack("<IHI", len(payload), command_id, 0)
    checksum = ledger.crc32c(header + payload)
    return struct.pack("<IHI", len(payload), command_id, checksum) + payload


def _u64(value: int) -> bytes:
    return struct.pack("<Q", value)


def _synthetic(version: int = 1, *, path: bytes = b"bin/tool") -> bytes:
    header = ledger.MAGIC + struct.pack("<I", version)
    start = b"".join((
        _tlv(15, b"root", version),
        _tlv(1, bytes(range(16)), version),
        _tlv(2, _u64(7), version),
    ))
    write = b"".join((
        _tlv(15, path, version),
        _tlv(18, _u64(4), version),
        _tlv(19, b"payload", version, data=True),
    ))
    return header + _command(1, start) + _command(15, write) + _command(21, b"")


class BtrfsSendLedgerTests(unittest.TestCase):
    def parse(self, raw: bytes):
        return list(ledger.parse_stream(io.BytesIO(raw)))

    def test_valid_stream_reports_operation_and_byte_count(self):
        events = self.parse(_synthetic())
        self.assertEqual([event.event["op"] for event in events], ["subvol", "write", "end"])
        self.assertEqual(events[1].event["path"], "bin/tool")
        self.assertEqual(events[1].event["file_offset"], 4)
        self.assertEqual(events[1].event["data_bytes"], len(b"payload"))

    def test_protocol_v2_data_tlv_consumes_remaining_command(self):
        events = self.parse(_synthetic(version=2))
        self.assertEqual(events[1].event["data_bytes"], len(b"payload"))

    def test_crc_mismatch_is_rejected(self):
        raw = bytearray(_synthetic())
        raw[-2] ^= 0x80
        with self.assertRaisesRegex(ledger.StreamError, "CRC32C mismatch"):
            self.parse(bytes(raw))

    def test_truncated_command_is_rejected(self):
        with self.assertRaisesRegex(ledger.StreamError, "truncated command payload"):
            self.parse(_synthetic()[:-13])

    def test_parent_escape_is_rejected(self):
        with self.assertRaisesRegex(ledger.StreamError, "dot or empty path component"):
            self.parse(_synthetic(path=b"../outside"))

    def test_second_root_record_is_rejected(self):
        raw = _synthetic()
        first_command_end = len(ledger.MAGIC) + 4 + 10 + struct.unpack_from(
            "<I", raw, len(ledger.MAGIC) + 4
        )[0]
        second_start = raw[len(ledger.MAGIC) + 4:first_command_end]
        with self.assertRaisesRegex(ledger.StreamError, "unexpected second"):
            self.parse(raw[:first_command_end] + second_start + raw[first_command_end:])

    def test_empty_path_is_snapshot_root(self):
        self.assertEqual(ledger._safe_path(b"", "path"), ".")

    def test_snapshot_root_path_is_limited_to_metadata_operations(self):
        self.assertEqual(
            ledger._validate_and_summarize("chown", {"path": b"", "uid": _u64(0), "gid": _u64(0)})["path"],
            ".",
        )
        with self.assertRaisesRegex(ledger.StreamError, "snapshot-root path is invalid for write"):
            self.parse(_synthetic(path=b""))

    def test_timestamps_are_decoded_and_nanoseconds_are_checked(self):
        attrs = {
            "path": b"etc/config",
            "atime": struct.pack("<QI", 1_700_000_000, 123),
            "mtime": struct.pack("<QI", 1_700_000_001, 456),
            "ctime": struct.pack("<QI", 1_700_000_002, 789),
        }
        event = ledger._validate_and_summarize("utimes", attrs)
        self.assertEqual(event["mtime"], {"seconds": 1_700_000_001, "nanoseconds": 456})
        attrs["mtime"] = struct.pack("<QI", 1, 1_000_000_000)
        with self.assertRaisesRegex(ledger.StreamError, "invalid mtime nanoseconds"):
            ledger._validate_and_summarize("utimes", attrs)


if __name__ == "__main__":
    unittest.main()
