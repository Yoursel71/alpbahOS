#!/usr/bin/env python3
"""Round 33 (greeter and lock screen, user report 2026-11-11 "giriş ekranında yazılar uymamış"): stages three records.

  <OUT>/pam      SCREENLOCK-01: /etc/pam.d/kde and /etc/pam.d/kscreensaver as BLFS 13.1 (kde/plasma-all.html) writes
                 them. Without "kde" the screen locker fell back to PAM "other" (deny): "Kilit açılamadı" and no unlock
                 (round 32). BLFS's kde-np (pam_permit, any password) is NOT added: no component here was found to need
                 it, and a missing service fails closed.
  <OUT>/sddm     GREETER-01: /etc/sddm.conf GreeterEnvironment gets QT_QPA_PLATFORMTHEME=kde and
                 QT_PLUGIN_PATH=/usr/lib/plugins:/opt/qt6/plugins (the greeter found no Kirigami platform plugin and drew
                 black text on the blue background); the theme's Hibernate button is hidden when not possible (zram
                 swap only, D152) instead of greyed; the theme logo is the mark with the live wordmark (D155) instead of
                 the logo PNG whose navy wordmark is unreadable on dark backgrounds.
  <OUT>/colors   alpbah-dark.colors and /etc/xdg/kdeglobals with [Colors:Complementary] and [Colors:Header] (text on
                 the wallpaper: greeter, lock screen, OSDs).
Usage: product-r33.py <R4_ROOT> <OUT>   (host, build user)
"""
import os
import shutil
import sys
from PIL import Image

R4, OUT = sys.argv[1:3]
WT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if os.path.exists(OUT):
    raise SystemExit(f"{OUT} exists")

PAM_KDE = """# Begin /etc/pam.d/kde

auth     requisite      pam_nologin.so
auth     required       pam_env.so

auth     required       pam_succeed_if.so uid >= 1000 quiet
auth     include        system-auth

account  include        system-account
password include        system-password
session  include        system-session

# End /etc/pam.d/kde
"""
PAM_KSS = """# Begin /etc/pam.d/kscreensaver

auth    include system-auth
account include system-account

# End /etc/pam.d/kscreensaver
"""
os.makedirs(os.path.join(OUT, "pam/etc/pam.d"))
for name, text in (("kde", PAM_KDE), ("kscreensaver", PAM_KSS)):
    p = os.path.join(OUT, "pam/etc/pam.d", name)
    if os.path.exists(os.path.join(R4, "etc/pam.d", name)):
        raise SystemExit(f"/etc/pam.d/{name} already exists in r4-root")
    open(p, "w").write(text)
    os.chmod(p, 0o644)


def edit(rel, edits, out_sub):
    src = os.path.join(R4, rel)
    text = open(src, encoding="utf-8").read()
    for old, new in edits:
        if text.count(old) != 1:
            raise SystemExit(f"{rel}: expected text found {text.count(old)} times: {old!r}")
        text = text.replace(old, new)
    dst = os.path.join(OUT, out_sub, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, "w", encoding="utf-8").write(text)
    shutil.copymode(src, dst)


edit("etc/sddm.conf", [(
    "GreeterEnvironment=QML2_IMPORT_PATH=/usr/lib/qml,LANG=tr_TR.UTF-8,LC_ALL=tr_TR.UTF-8\n",
    "GreeterEnvironment=QML2_IMPORT_PATH=/usr/lib/qml,LANG=tr_TR.UTF-8,LC_ALL=tr_TR.UTF-8,QT_QPA_PLATFORMTHEME=kde,"
    "QT_PLUGIN_PATH=/usr/lib/plugins:/opt/qt6/plugins\n")], "sddm")
edit("usr/share/sddm/themes/alpbahos/Main.qml", [(
    "                        onClicked: sddm.hibernate()\n                        enabled: sddm.canHibernate\n",
    "                        onClicked: sddm.hibernate()\n                        visible: sddm.canHibernate   // alpbahOS: zram only, no resume device\n")],
    "sddm")
mark = Image.open(os.path.join(WT, "branding/plymouth-theme/alpbahos/mark.png")).convert("RGBA")
word = Image.open(os.path.join(WT, "branding/plymouth-theme/alpbahos/wordmark.png")).convert("RGBA")
W = max(mark.width, word.width)
logo = Image.new("RGBA", (W, mark.height + 14 + word.height), (0, 0, 0, 0))
logo.alpha_composite(mark, ((W - mark.width) // 2, 0))
logo.alpha_composite(word, ((W - word.width) // 2, mark.height + 14))
dst = os.path.join(OUT, "sddm/usr/share/sddm/themes/alpbahos/logo.png")
logo.save(dst, optimize=True)
os.chmod(dst, 0o644)

for s, d in (("profiles/desktop/colorscheme/alpbah-dark.colors", "usr/share/color-schemes/alpbah-dark.colors"),
             ("profiles/desktop/xdg/kdeglobals", "etc/xdg/kdeglobals")):
    t = os.path.join(OUT, "colors", d)
    os.makedirs(os.path.dirname(t), exist_ok=True)
    shutil.copyfile(os.path.join(WT, s), t)
    os.chmod(t, 0o644)
print("staged", OUT, "logo", logo.size)
