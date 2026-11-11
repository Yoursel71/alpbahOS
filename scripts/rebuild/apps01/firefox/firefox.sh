# APPS-01, in the chroot of r4-root (as root), from the unpacked firefox-153.2.0 tree (BLFS 13.1-systemd
# xsoft/firefox.html). The build runs as the unprivileged user alpbuild (as the book builds as a normal user); the
# install into $STAGE runs as root. HOME, the mach state and the cargo home stay inside the build tree.
set -e
export PATH=/opt/rustc/bin:$PATH
# The book: "mountpoint -q /dev/shm || mount -t tmpfs devshm /dev/shm". The chroot's /dev is a plain bind of the
# host's /dev, so /dev/shm is not a mount here and mach's process pool (POSIX semaphores) fails as alpbuild
# (round 37 first try: PermissionError in multiprocessing SemLock). The tmpfs is removed again on any exit, so the
# builder can unmount /dev afterwards.
SHM_MOUNTED=0
if ! mountpoint -q /dev/shm; then
    mount -t tmpfs -o mode=1777,nosuid,nodev devshm /dev/shm
    SHM_MOUNTED=1
fi
trap '[ "$SHM_MOUNTED" = 1 ] && umount /dev/shm' EXIT
cp ../mozconfig mozconfig
mkdir -p .home
chown -R alpbuild:alpbuild .
B=$PWD
chroot --userspec=alpbuild:alpbuild / /usr/bin/env -i PATH="$PATH" HOME="$B/.home" LANG=C.UTF-8 \
    MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=none MOZBUILD_STATE_PATH="$B/mozbuild" CARGO_HOME="$B/.home/.cargo" \
    sh -c "cd '$B' && ./mach build -j$JOBS"
export MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=none MOZBUILD_STATE_PATH="$B/mozbuild" HOME="$B/.home"
DESTDIR="$STAGE" ./mach install
mkdir -p "$STAGE/usr/share/applications" "$STAGE/usr/share/pixmaps"
MIMETYPE="text/xml;text/mml;text/html;application/xhtml+xml;application/vnd.mozilla.xul+xml;x-scheme-handler/http;x-scheme-handler/https"
cat > "$STAGE/usr/share/applications/firefox.desktop" <<DESK
[Desktop Entry]
Encoding=UTF-8
Name=Firefox Web Browser
Name[tr]=Firefox Web Tarayıcısı
Comment=Browse the World Wide Web
Comment[tr]=İnternette gezinin
GenericName=Web Browser
GenericName[tr]=Web Tarayıcısı
Exec=firefox %u
Terminal=false
Type=Application
Icon=firefox
Categories=GNOME;GTK;Network;WebBrowser;
MimeType=$MIMETYPE
StartupNotify=true
StartupWMClass=firefox
DESK
ln -sfv /usr/lib/firefox/browser/chrome/icons/default/default128.png "$STAGE/usr/share/pixmaps/firefox.png"
