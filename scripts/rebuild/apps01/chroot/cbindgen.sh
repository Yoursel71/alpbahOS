# APPS-01, in the chroot of r4-root, from the unpacked cbindgen-0.29.4 tree (BLFS 13.1-systemd general/cbindgen.html).
# Crates come from crates.io, pinned and checksum-checked by the tarball's Cargo.lock (--locked). The registry cache
# stays inside the build tree (CARGO_HOME), not in the root's /root. Name resolution: r4-root's resolv.conf points to
# systemd-resolved's stub file under /run (a tmpfs during the build); the host's stub resolver answers on 127.0.0.53.
set -e
export PATH=/opt/rustc/bin:$PATH CARGO_HOME=$PWD/.cargo-home
mkdir -p /run/systemd/resolve
echo 'nameserver 127.0.0.53' > /run/systemd/resolve/stub-resolv.conf
cargo build --release --locked -j "$JOBS"
install -Dm755 target/release/cbindgen "$STAGE/usr/bin/cbindgen"
