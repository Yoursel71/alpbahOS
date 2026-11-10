#!/usr/bin/env python3
"""Round 23: stages two alp records that take files over from other records (stage-record-r8.py with REPLACE=1).

  <OUT>/alpbahos-name         NAME-CASE-01 (D110): the product name is written "alpbahOS". Copies of the r4-root
                              files below with "AlpbahOS" replaced; every file must contain it at least once.
  <OUT>/alpbahos-grub-config  GRUB-TITLES-01 (D157): /etc/grub.d/10_linux and 30_uefi-firmware of the GRUB 2.14
                              record with short titles: the newest kernel is "<GRUB_DISTRIBUTOR>" ("alpbahOS"),
                              older kernels "alpbahOS (Linux <version>)", the firmware entry "UEFI ayarları".
                              Each edit is an exact string replacement that must match once.
Runs on the host as the build user. Usage: product-r23.py <R4_ROOT> <OUT>
"""
import os
import shutil
import sys

R4, OUT = sys.argv[1:3]
if os.path.exists(OUT):
    raise SystemExit(f"{OUT} exists")

NAME_FILES = ["etc/os-release", "etc/lsb-release", "etc/xdg/kcm-about-distrorc", "etc/fastfetch/config.jsonc",
              "usr/share/sddm/themes/alpbahos/metadata.desktop", "usr/share/sddm/themes/alpbahos/NOTICE",
              "etc/sddm.conf.d/alpbahos-theme.conf"]

GRUB_EDITS = {
    "etc/grub.d/10_linux": [
        ('  OS="${GRUB_DISTRIBUTOR} GNU/Linux"\n',
         '  OS="${GRUB_DISTRIBUTOR}"   # alpbahOS (D157): no " GNU/Linux" suffix\n'),
        ('\t      title="$(gettext_printf "%s, with Linux %s" "${os}" "${version}")" ;;\n',
         '\t      # alpbahOS (D157): the newest kernel (first call) is just the OS name, older ones name the kernel.\n'
         '\t      if [ -z "${alpbahos_first_title}" ]; then\n'
         '\t\t  title="${os}"; alpbahos_first_title=done\n'
         '\t      else\n'
         '\t\t  title="$(printf \'%s (Linux %s)\' "${os}" "${version}")"\n'
         '\t      fi ;;\n'),
    ],
    "etc/grub.d/30_uefi-firmware": [
        ('LABEL="UEFI Firmware Settings"\n', 'LABEL="UEFI ayarları"   # alpbahOS (D157)\n'),
    ],
}


def copy_meta(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(src, dst)
    shutil.copymode(src, dst)


for rel in NAME_FILES:
    src = os.path.join(R4, rel)
    text = open(src, encoding="utf-8").read()
    if "AlpbahOS" not in text:
        raise SystemExit(f"{rel}: no AlpbahOS")
    dst = os.path.join(OUT, "alpbahos-name", rel)
    copy_meta(src, dst)
    open(dst, "w", encoding="utf-8").write(text.replace("AlpbahOS", "alpbahOS"))
    print(f"name: {rel}: {text.count('AlpbahOS')} replaced")

for rel, edits in GRUB_EDITS.items():
    src = os.path.join(R4, rel)
    text = open(src, encoding="utf-8").read()
    for old, new in edits:
        if text.count(old) != 1:
            raise SystemExit(f"{rel}: expected text found {text.count(old)} times: {old!r}")
        text = text.replace(old, new)
    dst = os.path.join(OUT, "alpbahos-grub-config", rel)
    copy_meta(src, dst)
    open(dst, "w", encoding="utf-8").write(text)
    print(f"grub: {rel}: {len(edits)} edit(s)")
