# PRINT-01 step 2: BLFS 13.1 basicnet/avahi.html (the book's options) plus --disable-gtk --disable-gtk3
# (no bssh/bvnc/avahi-discover menu entries) and --disable-autoipd (NetworkManager does IPv4 link-local). The example
# ssh/sftp-ssh service files are left out: they would announce an SSH server the image does not run. The avahi user
# (uid/gid 84 as in the book) comes from sysusers.d; the book's resolved.conf.d/no-mdns.conf keeps systemd-resolved
# off port 5353.
# Round 45: the book's ipv6_race_condition_fix-1 patch is NOT applied. It makes every packet this host sent count as
# "from a local interface", and avahi 0.9-rc5 caches responses only when that is false, so services and the host name
# published by this machine were never found by itself (round 44 QEMU: avahi-publish established, avahi-browse and
# avahi-resolve of the own name empty; zone dump full, every cache empty). Fedora and Arch do not apply it either.
set -e
autoreconf -fiv
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-static --disable-libevent --disable-mono \
    --disable-monodoc --disable-manpages --disable-python --disable-qt3 --disable-qt4 --disable-qt5 --disable-gtk \
    --disable-gtk3 --disable-autoipd --enable-core-docs --with-distro=none \
    --with-dbus-system-address='unix:path=/run/dbus/system_bus_socket' CFLAGS="-O2 -march=x86-64 -mtune=generic"
make
make DESTDIR="$STAGE" install
rm -f "$STAGE"/usr/lib/*.la "$STAGE/etc/avahi/services/ssh.service" "$STAGE/etc/avahi/services/sftp-ssh.service"
install -d -m 755 "$STAGE/usr/lib/sysusers.d" "$STAGE/etc/systemd/resolved.conf.d"
cat > "$STAGE/usr/lib/sysusers.d/avahi.conf" << 'X'
# Avahi daemon user and group (BLFS 13.1 basicnet/avahi.html: uid/gid 84); netdev (86) may manage avahi over D-Bus.
g avahi 84
u avahi 84:84 "Avahi Daemon Owner" /run/avahi-daemon /usr/bin/false
g netdev 86
X
cat > "$STAGE/etc/systemd/resolved.conf.d/no-mdns.conf" << 'X'
# Avahi answers and resolves mDNS (.local); systemd-resolved stays off port 5353 (BLFS 13.1 basicnet/avahi.html).
[Resolve]
MulticastDNS=no
X
chmod 644 "$STAGE/usr/lib/sysusers.d/avahi.conf" "$STAGE/etc/systemd/resolved.conf.d/no-mdns.conf"
