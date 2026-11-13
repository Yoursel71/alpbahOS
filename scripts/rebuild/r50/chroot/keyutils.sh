#!/bin/bash
# BLFS 13.1-systemd general/keyutils.html: make; make NO_ARLIB=1 LIBDIR=/usr/lib BINDIR=/usr/bin SBINDIR=/usr/sbin install (DESTDIR stage)
set -e
make
make DESTDIR="$STAGE" NO_ARLIB=1 LIBDIR=/usr/lib BINDIR=/usr/bin SBINDIR=/usr/sbin install
