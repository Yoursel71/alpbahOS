#!/bin/bash
# BLFS 13.1-systemd postlfs/ntfs-3g.html (internal FUSE as the book says), DESTDIR stage; run in the chroot of r4-root.
set -e
./autogen.sh
./configure --prefix=/usr --disable-static --with-fuse=internal --docdir=/usr/share/doc/ntfs-3g-2026.7.7
make
make DESTDIR="$STAGE" install
# the package installs ntfs-3g/lowntfs-3g into /bin and the mount helpers into /sbin; /bin and /sbin are symlinks to
# /usr/bin and /usr/sbin here and the alp record refuses a path below a symlink: move them into the usr tree
install -d "$STAGE/usr/bin" "$STAGE/usr/sbin"
for d in bin sbin; do [ -d "$STAGE/$d" ] && { cp -a "$STAGE/$d/." "$STAGE/usr/$d/" && rm -rf "$STAGE/$d"; }; done
ln -svf ../bin/ntfs-3g "$STAGE/usr/sbin/mount.ntfs-3g" ; ln -svf ../bin/lowntfs-3g "$STAGE/usr/sbin/mount.lowntfs-3g"
ln -svf ../bin/ntfs-3g "$STAGE/usr/sbin/mount.ntfs"
