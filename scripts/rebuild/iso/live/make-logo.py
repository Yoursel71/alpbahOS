#!/usr/bin/env python3
# AlpbahOS BETA: writes a plain 256x256 PNG logo (no external tools) for the Calamares branding.
# Usage: make-logo.py OUT.png
import struct
import sys
import zlib

W = H = 256


def chunk(tag, data):
    body = tag + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def main():
    out = sys.argv[1]
    raw = bytearray()
    for y in range(H):
        raw.append(0)
        for x in range(W):
            # Dark blue field with a lighter diamond in the centre.
            d = abs(x - W // 2) + abs(y - H // 2)
            if d < 90:
                px = (74, 163, 255)
            else:
                px = (29, 42, 58)
            raw += bytes(px)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(out, "wb") as f:
        f.write(png)


if __name__ == "__main__":
    main()
