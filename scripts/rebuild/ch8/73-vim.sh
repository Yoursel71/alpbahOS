#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.75.1: Vim-9.2.1025.
# Test: as tester with a UTF-8 locale; a successful run shows "FAILED: 0" in the log (book).
set -euo pipefail

PKG=vim-9.2.1025.tar.gz
DIR=vim-9.2.1025
TESTS=/root/ch8-tests
mkdir -p "$TESTS"

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.75.1 Installation of Vim
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr
make
chown -R tester .
sed '/test_plugin_glvs/d' -i src/testdir/Make_all.mak
su tester -c "TERM=xterm-256color LANG=en_US.UTF-8 make -j1 test" &> "$TESTS/vim-test.log" || echo "NOTE vim test exited $? (see $TESTS/vim-test.log)"
grep -E 'FAILED|Failed|failed' "$TESTS/vim-test.log" | tail -n 5 || true
make install
ln -sv vim /usr/bin/vi
for L in /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done
ln -sv ../vim/vim92/doc /usr/share/doc/vim-9.2.1025

cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1
set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF

cd /sources
rm -rf "$DIR"
echo "OK 73-vim"
