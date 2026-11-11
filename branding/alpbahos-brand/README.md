# alpbahOS brand assets

Default wallpaper package for alpbahOS (D113, D114). The desktop and the look-and-feel
default (`profiles/desktop/lookandfeel/org.alpbahos.solid.desktop/contents/defaults`) use
`alpbahOS-Brand`. The Atatürk wallpaper (`branding/ataturk-theme/`) stays installed and can be
picked in the wallpaper dialog (D114).

## Contents

| Path | What |
|---|---|
| `tools/build_brand_wallpaper.py` | Generator (Python 3 + Pillow). `--check` compares the repo files with a fresh build. |
| `wallpaper/alpbahOS-Brand/metadata.json` | KPlugin metadata: Id `alpbahOS-Brand`, Name `alpbahOS`, License `GPL-3.0-or-later`. |
| `wallpaper/alpbahOS-Brand/contents/images/<W>x<H>.png` | Wallpapers: 1366x768, 1920x1080, 1920x1200, 2560x1440, 3440x1440. |
| `wallpaper/alpbahOS-Brand/contents/screenshot.png` | 400x250 preview for the wallpaper picker. |

## Design

- Background: vertical gradient from a mix of `navy` to `bg-950` (colours read from `profiles/desktop/tokens.json`).
- Logo: the mark of `docs/assets/alpbahOS-logo.png` with the live wordmark (white "alpbah", cyan "OS", D155; from
  `branding/plymouth-theme/alpbahos/wordmark.png`), height 22 % of the image height, centred horizontally.
  It is scaled with LANCZOS and never enlarged above its native size (296x359).
  The source logo has an opaque flat #141414 box. The generator makes pixels within distance 18 of that
  colour transparent in memory, with a 12-step soft edge. The source file is not changed.
- Glow: a soft, blurred light navy/cyan radial glow behind the logo so the dark lettering stays readable.
  Fixed parameters in the generator; no hard edges.
- Accent: thin cyan line (16 % of the width) with a short orange segment at its left end.
- No text other than what the logo contains. No timestamps or metadata in the PNGs.

## Rebuild and check

```sh
python3 -B branding/alpbahos-brand/tools/build_brand_wallpaper.py          # regenerate
python3 -B branding/alpbahos-brand/tools/build_brand_wallpaper.py --check  # verify, exit 1 if stale
```

The output is deterministic for the same Pillow version. Change the generator or its inputs,
then regenerate; do not edit the PNGs by hand.

## Licence

The artwork (background, accent and layout) is project work under GPL-3.0-or-later (D109).
The logo is project work from `docs/assets/`, under the same project licence.

## Atatürk wallpaper

`alpbahOS-Ataturk` is installed next to the brand package by `profiles/desktop/install-desktop-profile.sh`.
It is a selectable alternative, not the default. Its source, licence (PD-Turkey) and generator are in
`branding/ataturk-theme/`.

## Not verified

Lock-screen behaviour (whether KScreenLocker follows the look-and-feel wallpaper) and the
appearance in a real Plasma session have not been tested on a running system.
