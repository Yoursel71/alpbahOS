#!/usr/bin/env python3
"""REBUILD-R9 D2: fastfetch key and separator colours readable on dark and light terminals.

Reads the round 8 config (the r4-root file, or a path given as argument 2), sets display.color (keys: bold cyan via
the 1;36 SGR, separator: bold white), and writes it to STAGE/etc/fastfetch/config.jsonc. Usage: fastfetch-colour-r9.py <STAGE_DIR> [CONFIG_IN]
"""
import os
import sys
STAGE = sys.argv[1]
SRC = sys.argv[2] if len(sys.argv) > 2 else "/home/yrslf/alpbahOS/scratch-lfs-bench/r4-root/etc/fastfetch/config.jsonc"
cfg = open(SRC, encoding="utf-8").read()
old = '  "display": {"separator": "  "},'
assert cfg.count(old) == 1, "display line not found"
new = ('  "display": {\n'
       '    "separator": "  ",\n'
       '    "color": {"keys": "1;36", "separator": "1;37"}\n'
       '  },')
cfg = cfg.replace(old, new)
p = os.path.join(STAGE, "etc/fastfetch/config.jsonc")
os.makedirs(os.path.dirname(p), exist_ok=True)
open(p, "w", encoding="utf-8").write(cfg)
print("wrote", p)
