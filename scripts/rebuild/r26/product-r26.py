#!/usr/bin/env python3
"""Round 26: stages two alp records that take files over (stage-record-r8.py with REPLACE=1).

  <OUT>/grub     GRUB-BOOTMSG-01: /etc/grub.d/10_linux without the "Loading Linux ..." and "Loading initial ramdisk ..."
                 echo lines (two exact line removals on the r4-root file), and a new /etc/grub.d/06_alpbahos that sets
                 the gfxterm background to the theme colour when a theme is active (boot messages, E and C screens).
  <OUT>/profile  Section E layers from the repo: /etc/xdg/kdeglobals (Inter / JetBrains Mono, E1), /etc/xdg/plasmarc
                 (Breeze following the colour scheme, E2), /etc/xdg/ksplashrc and the look-and-feel splash (E3),
                 the look-and-feel defaults, /etc/fonts/conf.d/60-alpbahos-fonts.conf (E1).
Usage: product-r26.py <R4_ROOT> <OUT>   (host, build user)
"""
import os
import shutil
import sys

R4, OUT = sys.argv[1:3]
WT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if os.path.exists(OUT):
    raise SystemExit(f"{OUT} exists")

ECHO = "\techo\t'$(echo \"$message\" | grub_quote)'\n"
src = os.path.join(R4, "etc/grub.d/10_linux")
text = open(src, encoding="utf-8").read()
if text.count(ECHO) != 2:
    raise SystemExit(f"10_linux: expected 2 echo lines, found {text.count(ECHO)}")
text = text.replace(ECHO, "")
os.makedirs(os.path.join(OUT, "grub/etc/grub.d"))
dst = os.path.join(OUT, "grub/etc/grub.d/10_linux")
open(dst, "w", encoding="utf-8").write(text)
shutil.copymode(src, dst)
hdr = os.path.join(OUT, "grub/etc/grub.d/06_alpbahos")
open(hdr, "w").write(
    "#! /bin/sh\nset -e\n"
    "# alpbahOS (GRUB-BOOTMSG-01, round 26): GRUB's text window (boot messages, E and C screens) uses the theme\n"
    "# background #0b1014 instead of black. Only when a theme is active, so a text console never sees the command.\n"
    "cat << 'EOF'\nif [ \"x${theme}\" != x ]; then\n  background_color \"#0b1014\"\nfi\nEOF\n")
os.chmod(hdr, 0o755)

P = os.path.join(OUT, "profile")
LNF = "usr/share/plasma/look-and-feel/org.alpbahos.solid.desktop/contents"
files = {
    "profiles/desktop/xdg/kdeglobals": "etc/xdg/kdeglobals",
    "profiles/desktop/xdg/plasmarc": "etc/xdg/plasmarc",
    "profiles/desktop/xdg/ksplashrc": "etc/xdg/ksplashrc",
    "profiles/desktop/fontconfig/60-alpbahos-fonts.conf": "etc/fonts/conf.d/60-alpbahos-fonts.conf",
    "profiles/desktop/lookandfeel/org.alpbahos.solid.desktop/contents/defaults": f"{LNF}/defaults",
    "profiles/desktop/lookandfeel/org.alpbahos.solid.desktop/contents/splash/Splash.qml": f"{LNF}/splash/Splash.qml",
    "profiles/desktop/lookandfeel/org.alpbahos.solid.desktop/contents/splash/images/mark.png": f"{LNF}/splash/images/mark.png",
    "profiles/desktop/lookandfeel/org.alpbahos.solid.desktop/contents/splash/images/wordmark.png": f"{LNF}/splash/images/wordmark.png",
}
for s, d in files.items():
    t = os.path.join(P, d)
    os.makedirs(os.path.dirname(t), exist_ok=True)
    shutil.copyfile(os.path.join(WT, s), t)
    os.chmod(t, 0o644)
print("staged", OUT)
