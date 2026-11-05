# BLFS 12.4-systemd build commands for lm-sensors-3-6-2 (added 2026-11-05 as order row 279a; required by libksysguard CMake)
# source: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/lm-sensors.html  md5 44c733f509cd4a31494fd3e355152b0a

# --- [BUILD] ---
make PREFIX=/usr        \
     BUILD_STATIC_LIB=0 \
     MANDIR=/usr/share/man

# --- [INSTALL,ROOT] ---
make PREFIX=/usr        \
     BUILD_STATIC_LIB=0 \
     MANDIR=/usr/share/man install &&
install -v -m755 -d /usr/share/doc/lm-sensors-3-6-2 &&
cp -rv              README INSTALL doc/* \
                    /usr/share/doc/lm-sensors-3-6-2
