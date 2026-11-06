#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.20.1: Ninja-1.13.2.
# The book's test suite needs cmake and cannot run in the chroot; the bootstrap rebuild is the test.
set -euo pipefail

PKG=ninja-1.13.2.tar.gz
DIR=ninja-1.13.2

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.20.1 Installation of Ninja
sed -i '/int Guess/a \
  int j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc
python3 configure.py --bootstrap --verbose
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion /usr/share/zsh/site-functions/_ninja

cd /sources
rm -rf "$DIR"
echo "OK 18-ninja"
