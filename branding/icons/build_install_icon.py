#!/usr/bin/env python3
"""build_install_icon.py -- the live desktop's "alpbahOS'u Kur" icon (INSTALLER-02).

A dark navy rounded tile with the alpbahOS mark (the paths of branding/alpbahos-brand/logo/alpbahOS-mark.svg, D113)
and an orange arrow into a drive at the bottom right: "install alpbahOS to the disk". Replaces the generic
system-software-install icon (a green download arrow) on the live desktop. Colours from profiles/desktop/tokens.json.
Own work, same licence as the brand files (GPL-3.0-or-later, branding/alpbahos-brand/README.md).

Output: branding/icons/hicolor/scalable/apps/alpbahos-install.svg
Usage: build_install_icon.py [--check]
"""
import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
MARK = REPO / "branding" / "alpbahos-brand" / "logo" / "alpbahOS-mark.svg"
OUT = HERE / "hicolor" / "scalable" / "apps" / "alpbahos-install.svg"


def build() -> str:
    src = MARK.read_text(encoding="utf-8")
    vb = [float(x) for x in re.search(r'viewBox="([^"]+)"', src).group(1).split()]
    paths = "\n".join("    " + p for p in re.findall(r"<path [^>]+/>", src))
    # Mark box inside the 128 px tile: 92 px wide, top-left part of the tile (the badge sits bottom right).
    w = 92.0
    s = w / vb[2]
    tx, ty = 10.0 - vb[0] * s, 16.0 - vb[1] * s
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
<!-- alpbahOS installer icon (INSTALLER-02): branding/icons/build_install_icon.py; mark from alpbahOS-mark.svg (D113). -->
  <defs>
    <linearGradient id="zemin" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#3b97d6"/>
      <stop offset="1" stop-color="#11497a"/>
    </linearGradient>
    <radialGradient id="isik" cx="0.42" cy="0.40" r="0.55">
      <stop offset="0" stop-color="#bfe8ff" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#bfe8ff" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect x="4" y="4" width="120" height="120" rx="26" fill="url(#zemin)"/>
  <rect x="4" y="4" width="120" height="120" rx="26" fill="url(#isik)"/>
  <rect x="4.75" y="4.75" width="118.5" height="118.5" rx="25.25" fill="none" stroke="#7cc6f0" stroke-opacity="0.6" stroke-width="1.5"/>
  <g transform="translate({tx:.3f} {ty:.3f}) scale({s:.5f})">
{paths}
  </g>
  <rect x="70" y="98" width="44" height="17" rx="5" fill="#0b1014" stroke="#ffffff" stroke-width="2.5"/>
  <circle cx="105" cy="106.5" r="2.8" fill="#35d07f"/>
  <path d="M92 66 V89" stroke="#0b1014" stroke-width="12" stroke-linecap="round"/>
  <path d="M81 80 L92 91 L103 80" fill="none" stroke="#0b1014" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M92 66 V89" stroke="#f5a623" stroke-width="6.5" stroke-linecap="round"/>
  <path d="M81 80 L92 91 L103 80" fill="none" stroke="#f5a623" stroke-width="6.5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    svg = build()
    if a.check:
        ok = OUT.exists() and OUT.read_text(encoding="utf-8") == svg
        print("ok" if ok else f"differs: {OUT}")
        return 0 if ok else 1
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(svg, encoding="utf-8")
    print(f"wrote {OUT.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
