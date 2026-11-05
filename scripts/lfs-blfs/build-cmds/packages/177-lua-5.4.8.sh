# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: lua-5.4.8   (order.txt row 177, REC-INC)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/general/lua.html
# INLINE-TEST (test command given in a sentence on the page, not an active block): make test

# --- [BUILD] ---
# Some packages check for the pkg-config file for Lua, which is created with:
cat > lua.pc << "EOF"
V=5.4
R=5.4.8

prefix=/usr
INSTALL_BIN=${prefix}/bin
INSTALL_INC=${prefix}/include
INSTALL_LIB=${prefix}/lib
INSTALL_MAN=${prefix}/share/man/man1
INSTALL_LMOD=${prefix}/share/lua/${V}
INSTALL_CMOD=${prefix}/lib/lua/${V}
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: Lua
Description: An Extensible Extension Language
Version: ${R}
Requires:
Libs: -L${libdir} -llua -lm -ldl
Cflags: -I${includedir}
EOF

# --- [BUILD] ---
# Install Lua by running the following commands:
patch -Np1 -i ../lua-5.4.8-shared_library-1.patch &&
make linux

# --- [BUILD,INSTALL,ROOT] ---
# Now, as the root user:
make INSTALL_TOP=/usr                \
     INSTALL_DATA="cp -d"            \
     INSTALL_MAN=/usr/share/man/man1 \
     TO_LIB="liblua.so liblua.so.5.4 liblua.so.5.4.8" \
     install &&

mkdir -pv                      /usr/share/doc/lua-5.4.8 &&
cp -v doc/*.{html,css,gif,png} /usr/share/doc/lua-5.4.8 &&

install -v -m644 -D lua.pc /usr/lib/pkgconfig/lua.pc
