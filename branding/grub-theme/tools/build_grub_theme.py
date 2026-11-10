#!/usr/bin/env python3
"""GRUB-THEME-01 (review item D1): builds the alpbahOS GRUB theme into branding/grub-theme/alpbahos/.

Host tool (Python 3 + Pillow + grub2-mkfont or grub-mkfont). The target GRUB 2.14 is built without FreeType, so the
.pf2 fonts are made on the host and committed with their sha256 (MANIFEST.txt). Label positions are computed from
the device widths stored in the generated .pf2 files, so they match what GRUB draws (no kerning in GRUB).

Inputs:
  --inter-dir DIR   Inter 4.1 static TTFs (extras/ttf of Inter-4.1.zip)
  --jbm-dir DIR     JetBrains Mono 2.304 TTFs (fonts/ttf of JetBrainsMono-2.304.zip)
  --logo PNG        scripts/rebuild/iso/live/calamares/branding/logo.png (mark = rows above the wordmark)
  --mkfont PROG     grub2-mkfont (Fedora host) or grub-mkfont
Output: theme.txt.in (the version line is @VERSION_LINE@, filled from /etc/os-release when the package is staged),
        *.png, *.pf2, MANIFEST.txt.
Designed at 1280x720; positions are fractions of the screen plus pixel offsets (GRUB "N%+M" form), so the
layout scales with the screen while sizes stay in pixels (GRUB fonts are bitmaps).
"""
import argparse
import hashlib
import json
import os
import struct
import subprocess
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "..", "alpbahos")

# Design values (master task D, shared values; profiles/desktop/tokens.json)
BG = "#0b1014"; TRACK = "#1d2c38"; BORDER = "#29404f"; NAVY = "#062746"
CYAN = "#00aeef"; CYAN_SOFT = "#54d6ff"; ORANGE = "#ffc45d"
TEXT_STRONG = "#f4f8fb"; TEXT = "#d4e0e8"; MUTED = "#8ea2af"

LATIN = "0x20-0x7E,0xA0-0x17F,0x2010-0x2027"          # ASCII, Latin-1, Latin Extended-A (ç ğ ı İ ö ş ü), dashes
ARROWS = "0x2190-0x2193"
BOX = "0x2500-0x257F"                                  # box drawing for the E (edit) and C (command line) screens

# name: (family dir key, file, size px, ranges)
FONTS = {
    "inter-20":       ("inter", "Inter-Regular.ttf", 20, LATIN),
    "inter-sb-20":    ("inter", "Inter-SemiBold.ttf", 20, LATIN),
    "inter-15":       ("inter", "Inter-Regular.ttf", 15, LATIN),
    "inter-bold-52":  ("inter", "Inter-Bold.ttf", 52, "0x20-0x7E"),
    "jbm-15":         ("jbm", "JetBrainsMono-Regular.ttf", 15, LATIN),                       # 0xB7 (·) is in Latin-1
    "jbm-14":         ("jbm", "JetBrainsMono-Regular.ttf", 14, LATIN + "," + ARROWS),
    "jbm-16":         ("jbm", "JetBrainsMono-Regular.ttf", 16, LATIN + "," + ARROWS + "," + BOX),
}

# Inter-SemiBold.ttf calls its style "Regular", so its .pf2 name would clash with Inter-Regular.ttf.
FAMILY = {"inter-sb-20": "Inter SemiBold"}

# Layout (px at 1280x720 unless a percentage)
PAD_X = 7            # % left and right
MARK_W = 220
ITEM_H = 60          # visual height of a menu row
RADIUS = 10          # corner radius of the selected row
ITEM_GAP = 8
ITEM_PAD = 24        # inner left/right padding of a row
ROWS = 3             # rows the menu area shows before it scrolls (installed: BIOS 1 entry, UEFI 2)
MENU_LEFT = 39       # % (left column 7 % + 28 % + 4 % gap)
MENU_W = 54          # % (to 93 %)


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def read_pf2(path):
    """Returns name, ascent, descent and {codepoint: device_width} from a PFF2 file."""
    data = open(path, "rb").read()
    pos, info, chix = 0, {}, []
    while pos < len(data):
        tag = data[pos:pos + 4].decode("ascii"); ln = struct.unpack(">I", data[pos + 4:pos + 8])[0]
        body = data[pos + 8:pos + 8 + ln]
        if tag == "DATA":
            break
        if tag == "CHIX":
            chix = [struct.unpack(">IBI", body[i:i + 9]) for i in range(0, ln, 9)]
        elif tag in ("NAME", "FAMI", "WEIG", "SLAN"):
            info[tag] = body.rstrip(b"\0").decode()
        elif tag in ("PTSZ", "MAXW", "MAXH", "ASCE", "DESC"):
            info[tag] = struct.unpack(">H", body[:2])[0]
        pos += 8 + ln
    widths = {}
    for cp, _flags, off in chix:
        w, h, xo, yo, dw = struct.unpack(">HHhhh", data[off:off + 10])
        widths[cp] = dw
    return info["NAME"], info["ASCE"], info["DESC"], widths


def text_w(font, s):
    return sum(font["w"].get(ord(c), font["w"].get(ord("?"), 0)) for c in s)


def hexrgb(c):
    return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5))


def solid(path, w, h, colour):
    Image.new("RGB", (w, h), hexrgb(colour)).save(path, optimize=True)


def rounded_box(w, h, r, fill, border, outside, scale=4):
    """Anti-aliased rounded rectangle with a 1 px border, composited on the outside colour (no alpha in GRUB)."""
    big = Image.new("RGB", (w * scale, h * scale), hexrgb(outside))
    d = ImageDraw.Draw(big)
    d.rounded_rectangle([0, 0, w * scale - 1, h * scale - 1], radius=r * scale, fill=hexrgb(border))
    d.rounded_rectangle([scale, scale, w * scale - 1 - scale, h * scale - 1 - scale], radius=(r - 1) * scale,
                        fill=hexrgb(fill))
    return big.resize((w, h), Image.LANCZOS)


def slices(img, prefix, left, right, top, bottom):
    """Cuts a 9-slice set (prefix_nw.png ... prefix_se.png). Centre column/row is one pixel wide/high."""
    w, h = img.size
    xs = {"w": (0, left), "c": (left, left + 1), "e": (w - right, w)}
    ys = {"n": (0, top), "c": (top, h - bottom), "s": (h - bottom, h)}
    names = {("n", "w"): "nw", ("n", "c"): "n", ("n", "e"): "ne", ("c", "w"): "w", ("c", "c"): "c",
             ("c", "e"): "e", ("s", "w"): "sw", ("s", "c"): "s", ("s", "e"): "se"}
    for (ry, cx), nm in names.items():
        x0, x1 = xs[cx]; y0, y1 = ys[ry]
        img.crop((x0, y0, x1, y1)).save(os.path.join(OUT, f"{prefix}_{nm}.png"), optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--inter-dir", required=True)
    ap.add_argument("--jbm-dir", required=True)
    ap.add_argument("--logo", default=os.path.join(REPO, "scripts/rebuild/iso/live/calamares/branding/logo.png"))
    ap.add_argument("--mkfont", default="grub2-mkfont")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    dirs = {"inter": a.inter_dir, "jbm": a.jbm_dir}
    manifest = ["# GRUB-THEME-01: generated by branding/grub-theme/tools/build_grub_theme.py; do not edit by hand.",
                "# Fonts: Inter 4.1 (Inter-4.1.zip sha256 9883fdd4a49d4fb66bd8177ba6625ef9a64aa45899767dde3d36aa425756b11e)",
                "#        JetBrains Mono 2.304 (JetBrainsMono-2.304.zip sha256 "
                "6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf)",
                "# Both SIL OFL 1.1; zips downloaded over HTTPS from the GitHub releases on 2026-11-10 (no upstream",
                "# checksum is published; the pins are first-download pins).",
                f"# mkfont: {subprocess.run([a.mkfont, '--version'], capture_output=True, text=True).stdout.strip()}"]
    F = {}
    for key, (fam, fn, size, ranges) in FONTS.items():
        ttf = os.path.join(dirs[fam], fn)
        out = os.path.join(OUT, f"{key}.pf2")
        cmd = [a.mkfont, "-s", str(size), "-r", ranges, "-o", out, ttf]
        if key in FAMILY:
            cmd[1:1] = ["-n", FAMILY[key]]
        subprocess.run(cmd, check=True, stderr=subprocess.DEVNULL)   # GSUB feature warnings only
        name, asc, desc, w = read_pf2(out)
        F[key] = {"name": name, "asc": asc, "desc": desc, "h": asc + desc, "w": w}
        manifest.append(f"font {key}.pf2 name='{name}' asc={asc} desc={desc} ttf={fn} ttf_sha256={sha(ttf)}")
        nflag = f"-n '{FAMILY[key]}' " if key in FAMILY else ""
        manifest.append(f"  cmd: {os.path.basename(a.mkfont)} {nflag}-s {size} -r {ranges} -o {key}.pf2 {fn}")

    # Mark: rows above the wordmark, trimmed to the bounding box, scaled down to MARK_W (never up), on BG.
    logo = Image.open(a.logo).convert("RGBA")
    alpha = logo.getchannel("A")
    rows = [y for y in range(logo.height) if alpha.crop((0, y, logo.width, y + 1)).getextrema()[1] > 8]
    cut = next(rows[i] for i in range(1, len(rows)) if rows[i] - rows[i - 1] > 1)   # first row of the wordmark
    mark = logo.crop((0, 0, logo.width, cut))
    mark = mark.crop(mark.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())   # ignore faint haze
    native = mark.size
    if mark.width > MARK_W:
        mark = mark.resize((MARK_W, round(mark.height * MARK_W / mark.width)), Image.LANCZOS)
    bg = Image.new("RGBA", mark.size, hexrgb(BG) + (255,))
    Image.alpha_composite(bg, mark).convert("RGB").save(os.path.join(OUT, "mark.png"), optimize=True)
    MW, MH = mark.size

    # Selected row: rounded box, 1 px cyan border, navy fill; "Enter" baked into the right slices.
    hint_font = ImageFont.truetype(os.path.join(a.jbm_dir, "JetBrainsMono-Regular.ttf"), 14)
    hint_w = round(hint_font.getlength("Enter"))
    right = ITEM_PAD + hint_w + 16
    box = rounded_box(RADIUS + 1 + right, ITEM_H, RADIUS, NAVY, CYAN, BG)
    d = ImageDraw.Draw(box)
    bb = hint_font.getbbox("Enter")
    d.text((box.width - ITEM_PAD - hint_w, (ITEM_H - (bb[3] + bb[1])) // 2), "Enter", font=hint_font,
           fill=hexrgb(CYAN_SOFT))
    slices(box, "select", RADIUS, right, RADIUS, RADIUS)
    # Unselected rows: same padding, background colour only (no blending needed).
    slices(Image.new("RGB", box.size, hexrgb(BG)), "item", RADIUS, right, RADIUS, RADIUS)
    # Progress bar and lines.
    solid(os.path.join(OUT, "line.png"), 1, 1, BORDER)
    # Progress bar pixmaps (see the progress_bar component below).
    pb = Image.new("RGB", (3, 28), hexrgb(BG))
    pb.paste(hexrgb(TRACK), (0, 12, 3, 16))
    slices(pb, "progress_bar", 1, 1, 12, 12)
    slices(Image.new("RGB", (3, 3), hexrgb(CYAN)), "progress_highlight", 1, 1, 1, 1)
    # Edit/command-line screen frame (E and C keys): 1 px border, app surface fill.
    term = rounded_box(2 * RADIUS + 1, 2 * RADIUS + 1, RADIUS, "#11171c", BORDER, BG)
    slices(term, "terminal_box", RADIUS, RADIUS, RADIUS, RADIUS)

    inner_h = ITEM_H - 2 * RADIUS
    menu_h = ROWS * ITEM_H + (ROWS - 1) * ITEM_GAP

    # Left column, centred vertically: mark, 18 px, wordmark, 6 px, version line.
    fw, fv = F["inter-bold-52"], F["jbm-15"]
    left_h = MH + 18 + fw["h"] + 6 + fv["h"]
    y_mark = -(left_h // 2)
    y_word = y_mark + MH + 18
    y_ver = y_word + fw["h"] + 6
    alp_w = text_w(fw, "alpbah")

    # Right column: menu, 24 px, countdown line, 12 px, 4 px bar; centred vertically.
    fc = F["inter-15"]
    right_h = menu_h + 24 + fc["h"] + 12 + 4
    y_menu = -(right_h // 2)
    y_cd = y_menu + menu_h + 24
    y_bar = y_cd + fc["h"] + 12
    pre, num, suf = "Seçili sistem ", "%d", " saniye içinde başlatılacak"
    pre_w = text_w(fc, pre)
    num_w = max(text_w(fc, str(n)) for n in range(10))

    # Footer above a 1 px line.
    ff = F["jbm-14"]
    parts = [("↑ ↓", TEXT), (" Seç", MUTED), ("   ", None), ("Enter", TEXT), (" Başlat", MUTED), ("   ", None),
             ("E", TEXT), (" Düzenle", MUTED), ("   ", None), ("C", TEXT), (" Komut satırı", MUTED)]

    def at(pct, px):
        return f"{pct}%{px:+d}" if px else f"{pct}%"

    t = ["# alpbahOS GRUB theme (GRUB-THEME-01, D1). Generated by branding/grub-theme/tools/build_grub_theme.py.",
         "title-text: \"\"", f"desktop-color: \"{BG}\"",
         f"terminal-font: \"{F['jbm-16']['name']}\"", "terminal-box: \"terminal_box_*.png\"",
         "terminal-left: \"7%\"", "terminal-top: \"10%\"", "terminal-width: \"86%\"", "terminal-height: \"72%\"",
         "terminal-border: \"0\"", ""]

    def label(left, top, width, text, font, colour, extra=""):
        t.extend(["+ label {", f"  left = {left}", f"  top = {top}", f"  width = {width}",
                  f"  height = {F[font]['h']}", f"  text = \"{text}\"", f"  font = \"{F[font]['name']}\"",
                  f"  color = \"{colour}\""] + ([extra] if extra else []) + ["}"])

    t += ["+ image {", f"  left = {at(PAD_X, 0)}", f"  top = {at(50, y_mark)}", f"  width = {MW}",
          f"  height = {MH}", "  file = \"mark.png\"", "}"]
    label(at(PAD_X, 0), at(50, y_word), alp_w, "alpbah", "inter-bold-52", TEXT_STRONG)
    label(at(PAD_X, alp_w), at(50, y_word), text_w(fw, "OS") + 4, "OS", "inter-bold-52", CYAN)
    label(at(PAD_X, 0), at(50, y_ver), "28%", "@VERSION_LINE@", "jbm-15", MUTED)

    t += ["+ boot_menu {", f"  left = {at(MENU_LEFT, 0)}", f"  top = {at(50, y_menu)}", f"  width = {MENU_W}%",
          f"  height = {menu_h}", f"  item_font = \"{F['inter-20']['name']}\"",
          f"  selected_item_font = \"{F['inter-sb-20']['name']}\"", f"  item_color = \"{TEXT}\"",
          f"  selected_item_color = \"{TEXT_STRONG}\"", f"  item_height = {inner_h}", "  item_padding = 0",
          f"  item_spacing = {ITEM_GAP + 2 * RADIUS}", "  icon_width = 0", "  icon_height = 0",
          f"  item_icon_space = {ITEM_PAD - RADIUS}", "  item_pixmap_style = \"item_*.png\"",
          "  selected_item_pixmap_style = \"select_*.png\"", "  scrollbar = true", "  scrollbar_width = 4",
          "  scrollbar_frame = \"line.png\"", "  scrollbar_thumb = \"line.png\"", "}"]
    tid = "  id = \"__timeout__\""
    label(at(MENU_LEFT, 0), at(50, y_cd), pre_w, pre, "inter-15", MUTED, tid)
    label(at(MENU_LEFT, pre_w), at(50, y_cd), num_w, num, "inter-15", ORANGE, tid)
    label(at(MENU_LEFT, pre_w + text_w(fc, "5")), at(50, y_cd), text_w(fc, suf) + 4, suf, "inter-15", MUTED, tid)
    # 4 px bar. GRUB gives a progress_bar at least 28 px of height, so the bar is 28 px high and its pixmaps
    # keep the outer 12 px rows in the background colour: track and fill are 4 px in the middle.
    t += ["+ progress_bar {", tid, f"  left = {at(MENU_LEFT, 0)}", f"  top = {at(50, y_bar - 12)}",
          f"  width = {MENU_W}%", "  height = 28", "  bar_style = \"progress_bar_*.png\"",
          "  highlight_style = \"progress_highlight_*.png\"", "  show_text = false", "}"]

    t += ["+ image {", f"  left = {at(PAD_X, 0)}", "  top = 100%-60", f"  width = {100 - 2 * PAD_X}%",
          "  height = 1", "  file = \"line.png\"", "}"]
    x = 0
    for s, colour in parts:
        if colour:
            label(at(PAD_X, x), "100%-44", text_w(ff, s) + 2, s, "jbm-14", colour)
        x += text_w(ff, s)
    open(os.path.join(OUT, "theme.txt.in"), "w").write("\n".join(t) + "\n")

    manifest.append(f"mark from {os.path.relpath(a.logo, REPO)} sha256={sha(a.logo)} rows 0..{cut - 1}, "
                    f"bbox {native[0]}x{native[1]}, scaled to {MW}x{MH} (LANCZOS, never enlarged)")
    for fn in sorted(os.listdir(OUT)):
        if fn != "MANIFEST.txt":
            manifest.append(f"{sha(os.path.join(OUT, fn))}  {fn}")
    open(os.path.join(OUT, "MANIFEST.txt"), "w").write("\n".join(manifest) + "\n")
    print(json.dumps({k: v["name"] for k, v in F.items()}, ensure_ascii=False))


if __name__ == "__main__":
    main()
