#!/usr/bin/env bash
set -Eeuo pipefail

# D34 continuation for a Readline build whose install completed but whose
# original orchestrator exited before writing its final success marker.
# This script only verifies the installed package and its retained build tree.

readonly WORK_ROOT=/sources/readline-8.3-ch8-20260926T205500Z

[[ -d "$WORK_ROOT/readline-8.3" ]]
[[ -s "$WORK_ROOT/readline-8.3/Makefile" ]]
[[ -s /usr/lib/libreadline.so.8.3 ]]
[[ -s /usr/lib/libhistory.so.8.3 ]]
[[ -e /usr/lib/libreadline.so.8 ]]
[[ -e /usr/lib/libhistory.so.8 ]]
[[ -e /usr/lib/libreadline.so ]]
[[ -e /usr/lib/libhistory.so ]]
[[ -s /usr/include/readline/readline.h ]]
[[ -s /usr/include/readline/history.h ]]
[[ -s /usr/lib/pkgconfig/readline.pc ]]
[[ -s /usr/lib/pkgconfig/history.pc ]]
grep -qx 'Version: 8.3' /usr/lib/pkgconfig/readline.pc
grep -qx 'Requires.private: ncursesw' /usr/lib/pkgconfig/readline.pc
grep -qx 'Version: 8.3' /usr/lib/pkgconfig/history.pc
readelf -d /usr/lib/libreadline.so.8.3 | grep -q 'libncursesw.so'
readelf -d /usr/lib/libhistory.so.8.3 | grep -q 'libncursesw.so'
[[ -s /usr/share/info/readline.info ]]
[[ -s /usr/share/info/history.info ]]
[[ -s /usr/share/man/man3/readline.3 ]]
[[ -s /usr/share/man/man3/history.3 ]]
[[ -s /usr/share/doc/readline-8.3/readline.html ]]
[[ ! -e /usr/lib/libreadline.a ]]
[[ ! -e /usr/lib/libhistory.a ]]

printf 'Readline 8.3 install verification: PASS\n'
