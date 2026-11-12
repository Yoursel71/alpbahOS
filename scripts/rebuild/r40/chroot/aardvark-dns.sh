# NETAVARK-01 (handoff 038): aardvark-dns v1.17.1 (DNS for podman networks), tag archive plus the release vendor
# tarball, offline; Rust from BLFS 13.1 (/opt/rustc). Installs /usr/libexec/podman/aardvark-dns.
set -e
B=$PWD
tar -xzf ../aardvark-dns-v1.17.1-vendor.tar.gz
mkdir -p .cargo
printf '[source.crates-io]\nreplace-with = "vendored-sources"\n[source.vendored-sources]\ndirectory = "vendor"\n' > .cargo/config.toml
export PATH=/opt/rustc/bin:$PATH CARGO_HOME=$B/.cargo-home CARGO_NET_OFFLINE=true
make PREFIX=/usr CARGO="cargo --offline --locked" build
make DESTDIR="$STAGE" PREFIX=/usr install
rm -rf .cargo-home
