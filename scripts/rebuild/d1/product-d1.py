#!/usr/bin/env python3
"""GRUB-THEME-01 (D1): stages three alp packages for r4-root (DESTDIR-style trees, recorded by stage-record-r8.py).

  <OUT>/font-inter            Inter 4.1 variable TTFs + OFL      -> /usr/share/fonts/inter/
  <OUT>/font-jetbrains-mono   JetBrains Mono 2.304 variable TTFs -> /usr/share/fonts/jetbrains-mono/
  <OUT>/alpbahos-grub-theme   branding/grub-theme/alpbahos       -> /boot/grub/themes/alpbahos/
The release zips are checked against the pinned sha256 before anything is copied. theme.txt is made from
theme.txt.in with the version line "<VERSION> · x86_64", VERSION read from <R4>/etc/os-release (not hard-coded).
Runs on the host as the build user. Usage: product-d1.py <R4_ROOT> <ZIP_DIR> <OUT>
"""
import hashlib
import os
import shutil
import sys
import zipfile

R4, ZIPS, OUT = sys.argv[1:4]
WT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
PINS = {
    "Inter-4.1.zip": "9883fdd4a49d4fb66bd8177ba6625ef9a64aa45899767dde3d36aa425756b11e",
    "JetBrainsMono-2.304.zip": "6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf",
}
FILES = {
    "Inter-4.1.zip": ("font-inter", "usr/share/fonts/inter", "usr/share/licenses/font-inter",
                      ["InterVariable.ttf", "InterVariable-Italic.ttf"], "LICENSE.txt"),
    "JetBrainsMono-2.304.zip": ("font-jetbrains-mono", "usr/share/fonts/jetbrains-mono",
                                "usr/share/licenses/font-jetbrains-mono",
                                ["fonts/variable/JetBrainsMono[wght].ttf",
                                 "fonts/variable/JetBrainsMono-Italic[wght].ttf"], "OFL.txt"),
}

if os.path.exists(OUT):
    raise SystemExit(f"{OUT} exists")
for zname, want in PINS.items():
    got = hashlib.sha256(open(os.path.join(ZIPS, zname), "rb").read()).hexdigest()
    if got != want:
        raise SystemExit(f"{zname}: sha256 {got} != pinned {want}")
    pkg, fdir, ldir, members, lic = FILES[zname]
    with zipfile.ZipFile(os.path.join(ZIPS, zname)) as z:
        for m, dst in [(x, fdir) for x in members] + [(lic, ldir)]:
            os.makedirs(os.path.join(OUT, pkg, dst), exist_ok=True)
            target = os.path.join(OUT, pkg, dst, os.path.basename(m))
            with z.open(m) as src, open(target, "wb") as f:
                shutil.copyfileobj(src, f)
            os.chmod(target, 0o644)

env = {}
for line in open(os.path.join(R4, "etc/os-release")):
    if "=" in line:
        k, v = line.rstrip("\n").split("=", 1)
        env[k] = v.strip('"')
version_line = f"{env['VERSION']} · x86_64"
src = os.path.join(WT, "branding/grub-theme/alpbahos")
dst = os.path.join(OUT, "alpbahos-grub-theme/boot/grub/themes/alpbahos")
os.makedirs(dst)
for fn in sorted(os.listdir(src)):
    if fn.endswith((".png", ".pf2")) or fn == "MANIFEST.txt":
        shutil.copyfile(os.path.join(src, fn), os.path.join(dst, fn))
    elif fn == "theme.txt.in":
        text = open(os.path.join(src, fn), encoding="utf-8").read()
        assert text.count("@VERSION_LINE@") == 1
        open(os.path.join(dst, "theme.txt"), "w", encoding="utf-8").write(text.replace("@VERSION_LINE@", version_line))
for root, _d, names in os.walk(dst):
    for n in names:
        os.chmod(os.path.join(root, n), 0o644)
print(f"staged into {OUT}; version line: {version_line}")
