#!/usr/bin/env python3
"""Strict, read-only parser for the Btrfs send stream used by D34 probes.

This emits operation/path metadata only. It is not a Btrfs receiver and does
not establish package provenance, final file ownership, or transaction safety.
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import BinaryIO, Iterator


MAGIC = b"btrfs-stream\0"
MAX_STREAM_VERSION = 2
MAX_COMMAND_BYTES = 128 * 1024 * 1024
MAX_SMALL_ATTRIBUTE_BYTES = 1024 * 1024

COMMANDS = {
    1: "subvol", 2: "snapshot", 3: "mkfile", 4: "mkdir", 5: "mknod",
    6: "mkfifo", 7: "mksock", 8: "symlink", 9: "rename", 10: "link",
    11: "unlink", 12: "rmdir", 13: "set_xattr", 14: "remove_xattr",
    15: "write", 16: "clone", 17: "truncate", 18: "chmod", 19: "chown",
    20: "utimes", 21: "end", 22: "update_extent", 23: "fallocate",
    24: "fileattr", 25: "encoded_write", 26: "enable_verity",
}
ATTRS = {
    1: "uuid", 2: "ctransid", 3: "ino", 4: "size", 5: "mode",
    6: "uid", 7: "gid", 8: "rdev", 9: "ctime", 10: "mtime",
    11: "atime", 12: "otime", 13: "xattr_name", 14: "xattr_data",
    15: "path", 16: "path_to", 17: "path_link", 18: "file_offset",
    19: "data", 20: "clone_uuid", 21: "clone_ctransid", 22: "clone_path",
    23: "clone_offset", 24: "clone_len", 25: "fallocate_mode",
    26: "fileattr", 27: "unencoded_file_len", 28: "unencoded_len",
    29: "unencoded_offset", 30: "compression", 31: "encryption",
    32: "verity_algorithm", 33: "verity_block_size", 34: "verity_salt_data",
    35: "verity_sig_data",
}
PATH_ATTRIBUTES = {"path", "path_to", "clone_path"}
STRING_ATTRIBUTES = PATH_ATTRIBUTES | {"path_link", "xattr_name"}
U64_ATTRIBUTES = {
    "ctransid", "ino", "size", "mode", "uid", "gid", "rdev",
    "file_offset", "clone_ctransid", "clone_offset", "clone_len",
    "fileattr", "unencoded_file_len", "unencoded_len", "unencoded_offset",
}
U32_ATTRIBUTES = {"fallocate_mode", "compression", "encryption", "verity_block_size"}


class StreamError(ValueError):
    """Malformed, unsupported, or unsafe Btrfs send stream."""


def _crc32c_table() -> tuple[int, ...]:
    values = []
    for byte in range(256):
        value = byte
        for _ in range(8):
            value = (value >> 1) ^ (0x82F63B78 if value & 1 else 0)
        values.append(value & 0xFFFFFFFF)
    return tuple(values)


CRC32C_TABLE = _crc32c_table()


def crc32c(data: bytes, crc: int = 0) -> int:
    """Btrfs CRC32C (Castagnoli), matching btrfs-progs crc32c(0, data, len)."""
    value = crc
    for byte in data:
        value = CRC32C_TABLE[(value ^ byte) & 0xFF] ^ (value >> 8)
    return value & 0xFFFFFFFF


def _read_exact(stream: BinaryIO, size: int, what: str, *, allow_eof: bool = False) -> bytes:
    data = bytearray()
    while len(data) < size:
        chunk = stream.read(size - len(data))
        if not chunk:
            if allow_eof and not data:
                return b""
            raise StreamError(f"truncated {what}: expected {size}, got {len(data)} bytes")
        data.extend(chunk)
    return bytes(data)


def _safe_path(raw: bytes, label: str) -> str:
    # Btrfs uses an empty path for metadata changes to the snapshot root.
    if not raw:
        return "."
    if b"\x00" in raw or raw.startswith(b"/"):
        raise StreamError(f"unsafe {label}: NUL or absolute path")
    try:
        value = raw.decode("utf-8", "strict")
    except UnicodeDecodeError as exc:
        raise StreamError(f"{label} is not valid UTF-8") from exc
    parts = value.split("/")
    if any(part in {"", ".", ".."} for part in parts):
        raise StreamError(f"unsafe {label}: dot or empty path component")
    return value


def _decode_attrs(payload: bytes, version: int) -> dict[str, bytes]:
    attrs: dict[str, bytes] = {}
    offset = 0
    while offset < len(payload):
        if len(payload) - offset < 2:
            raise StreamError("truncated TLV type")
        attr_id = struct.unpack_from("<H", payload, offset)[0]
        offset += 2
        name = ATTRS.get(attr_id)
        if name is None:
            raise StreamError(f"unsupported TLV type {attr_id}")
        if name in attrs:
            raise StreamError(f"duplicate TLV {name}")
        if version >= 2 and name == "data":
            length = len(payload) - offset
        else:
            if len(payload) - offset < 2:
                raise StreamError(f"truncated TLV length for {name}")
            length = struct.unpack_from("<H", payload, offset)[0]
            offset += 2
        if length > len(payload) - offset:
            raise StreamError(f"truncated TLV value for {name}")
        if name != "data" and length > MAX_SMALL_ATTRIBUTE_BYTES:
            raise StreamError(f"oversized metadata attribute {name}: {length} bytes")
        attrs[name] = payload[offset:offset + length]
        offset += length
        if version >= 2 and name == "data" and offset != len(payload):
            raise StreamError("BTRFS_SEND_A_DATA must be the final v2 attribute")
    return attrs


def _required(attrs: dict[str, bytes], *names: str) -> None:
    missing = [name for name in names if name not in attrs]
    if missing:
        raise StreamError(f"missing required TLV(s): {', '.join(missing)}")


def _validate_and_summarize(command: str, attrs: dict[str, bytes]) -> dict[str, object]:
    path_names: tuple[str, ...] = ()
    if command in {"subvol", "snapshot"}:
        path_names = ("path",)
        _required(attrs, "path", "uuid", "ctransid")
        if command == "snapshot":
            _required(attrs, "clone_uuid", "clone_ctransid")
    elif command in {"mkfile", "mkdir", "mkfifo", "mksock", "unlink", "rmdir"}:
        path_names = ("path",)
        _required(attrs, "path")
        if command in {"mkfile", "mkdir", "mkfifo", "mksock"}:
            _required(attrs, "ino")
    elif command == "mknod":
        path_names = ("path",)
        _required(attrs, "path", "ino", "mode", "rdev")
    elif command == "symlink":
        path_names = ("path",)
        _required(attrs, "path", "ino", "path_link")
    elif command == "rename":
        path_names = ("path", "path_to")
        _required(attrs, *path_names)
    elif command == "link":
        path_names = ("path", "path_link")
        _required(attrs, *path_names)
    elif command in {"set_xattr", "remove_xattr"}:
        path_names = ("path",)
        _required(attrs, "path", "xattr_name")
        if command == "set_xattr":
            _required(attrs, "xattr_data")
    elif command in {"write", "encoded_write"}:
        path_names = ("path",)
        _required(attrs, "path", "file_offset", "data")
        if command == "encoded_write":
            _required(attrs, "unencoded_file_len", "unencoded_len", "unencoded_offset")
    elif command in {"clone"}:
        path_names = ("path", "clone_path")
        _required(attrs, "path", "file_offset", "clone_len", "clone_uuid",
                  "clone_ctransid", "clone_path", "clone_offset")
    elif command in {"truncate", "fileattr"}:
        path_names = ("path",)
        _required(attrs, "path", "size" if command == "truncate" else "fileattr")
    elif command == "chmod":
        path_names = ("path",)
        _required(attrs, "path", "mode")
    elif command == "chown":
        path_names = ("path",)
        _required(attrs, "path", "uid", "gid")
    elif command == "utimes":
        path_names = ("path",)
        _required(attrs, "path", "atime", "mtime", "ctime")
    elif command == "update_extent":
        path_names = ("path",)
        _required(attrs, "path", "file_offset", "size")
    elif command == "fallocate":
        path_names = ("path",)
        _required(attrs, "path", "fallocate_mode", "file_offset", "size")
    elif command == "enable_verity":
        path_names = ("path",)
        _required(attrs, "path", "verity_algorithm", "verity_block_size",
                  "verity_salt_data", "verity_sig_data")
    elif command != "end":
        raise StreamError(f"unsupported command {command}")

    result: dict[str, object] = {"op": command}
    root_path_allowed = {"chmod", "chown", "utimes", "set_xattr", "remove_xattr", "fileattr"}
    for name in path_names:
        safe_path = _safe_path(attrs[name], name)
        if safe_path == "." and command not in root_path_allowed:
            raise StreamError(f"snapshot-root path is invalid for {command}")
        if name != "path" and safe_path == ".":
            raise StreamError(f"snapshot-root {name} is invalid for {command}")
        result[name] = safe_path
    if "path_link" in attrs:
        if command == "link":
            hardlink_source = _safe_path(attrs["path_link"], "hardlink source")
            if hardlink_source == ".":
                raise StreamError("snapshot root cannot be a hardlink source")
            result["path_link"] = hardlink_source
        else:
            # A symlink target is data, and may intentionally be absolute or contain '..'.
            if not attrs["path_link"] or b"\x00" in attrs["path_link"]:
                raise StreamError("symlink target is empty or contains NUL")
            result["path_link"] = attrs["path_link"].decode("utf-8", "replace")
    for name in U64_ATTRIBUTES:
        if name in attrs:
            if len(attrs[name]) != 8:
                raise StreamError(f"invalid {name} attribute length: {len(attrs[name])}")
            result[name] = struct.unpack("<Q", attrs[name])[0]
    for name in U32_ATTRIBUTES:
        if name in attrs:
            if len(attrs[name]) != 4:
                raise StreamError(f"invalid {name} attribute length: {len(attrs[name])}")
            result[name] = struct.unpack("<I", attrs[name])[0]
    for name in ("uuid", "clone_uuid"):
        if name in attrs:
            if len(attrs[name]) != 16:
                raise StreamError(f"invalid {name} attribute length: {len(attrs[name])}")
            result[name] = attrs[name].hex()
    if "data" in attrs:
        result["data_bytes"] = len(attrs["data"])
    if "xattr_data" in attrs:
        result["xattr_data_bytes"] = len(attrs["xattr_data"])
    if "verity_salt_data" in attrs:
        result["verity_salt_data_bytes"] = len(attrs["verity_salt_data"])
    if "verity_sig_data" in attrs:
        result["verity_sig_data_bytes"] = len(attrs["verity_sig_data"])
    for name in ("atime", "mtime", "ctime"):
        if name in attrs:
            if len(attrs[name]) != 12:
                raise StreamError(f"invalid {name} attribute length: {len(attrs[name])}")
            seconds, nanoseconds = struct.unpack("<QI", attrs[name])
            if nanoseconds >= 1_000_000_000:
                raise StreamError(f"invalid {name} nanoseconds: {nanoseconds}")
            result[name] = {"seconds": seconds, "nanoseconds": nanoseconds}
    if "xattr_name" in attrs:
        result["xattr_name"] = attrs["xattr_name"].decode("utf-8", "replace")
    return result


@dataclass(frozen=True)
class Event:
    sequence: int
    version: int
    command_id: int
    event: dict[str, object]


def parse_stream(stream: BinaryIO) -> Iterator[Event]:
    header = _read_exact(stream, len(MAGIC) + 4, "stream header")
    if header[:len(MAGIC)] != MAGIC:
        raise StreamError("invalid Btrfs stream magic")
    version = struct.unpack_from("<I", header, len(MAGIC))[0]
    if not 1 <= version <= MAX_STREAM_VERSION:
        raise StreamError(f"unsupported Btrfs stream version {version}")

    sequence = 0
    ended = False
    while True:
        raw_header = _read_exact(stream, 10, "command header", allow_eof=True)
        if not raw_header:
            break
        payload_len, command_id, expected_crc = struct.unpack("<IHI", raw_header)
        if payload_len > MAX_COMMAND_BYTES:
            raise StreamError(f"command exceeds {MAX_COMMAND_BYTES} byte safety limit")
        if command_id not in COMMANDS:
            raise StreamError(f"unsupported command id {command_id}")
        if ended:
            raise StreamError("data follows BTRFS_SEND_C_END")
        payload = _read_exact(stream, payload_len, "command payload")
        checksum_header = raw_header[:6] + b"\0\0\0\0"
        actual_crc = crc32c(checksum_header + payload)
        if actual_crc != expected_crc:
            raise StreamError(f"CRC32C mismatch in command {sequence}: expected {expected_crc:08x}, got {actual_crc:08x}")
        attrs = _decode_attrs(payload, version)
        command = COMMANDS[command_id]
        if sequence == 0 and command not in {"subvol", "snapshot"}:
            raise StreamError("stream must begin with SUBVOL or SNAPSHOT")
        if sequence != 0 and command in {"subvol", "snapshot"}:
            raise StreamError("unexpected second SUBVOL/SNAPSHOT record")
        if command == "end" and attrs:
            raise StreamError("BTRFS_SEND_C_END must not contain attributes")
        event = _validate_and_summarize(command, attrs)
        sequence += 1
        yield Event(sequence, version, command_id, event)
        if command == "end":
            ended = True
    if sequence == 0 or not ended:
        raise StreamError("stream does not contain a terminal BTRFS_SEND_C_END command")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stream", type=Path, help="Btrfs send stream to inspect")
    args = parser.parse_args(argv)
    try:
        with args.stream.open("rb") as source:
            for event in parse_stream(source):
                print(json.dumps(asdict(event), sort_keys=True))
    except (OSError, StreamError) as exc:
        print(f"btrfs-send-ledger: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
