# NETAVARK-01 (handoff 038), in the chroot of r4-root, from the netavark v1.17.2 tag archive and its release vendor
# tarball (crates offline). Rust from BLFS 13.1 (/opt/rustc), default target CPU x86-64. protoc (build tool only, the
# upstream protobuf 36.2 binary, unpacked into /tmp for this build and removed) compiles the DHCP proxy's proto file.
# Installs the binary to /usr/libexec/podman (podman 5.x supports only netavark) and the systemd units; no man pages
# (go-md2man is not in the image).
set -e
B=$PWD
P=/tmp/protoc-36.2
trap 'rm -rf "$P"' EXIT
python3 -c 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' ../protoc-36.2-linux-x86_64.zip "$P"
chmod 755 "$P/bin/protoc"
tar -xzf ../netavark-v1.17.2-vendor.tar.gz
mkdir -p .cargo
printf '[source.crates-io]\nreplace-with = "vendored-sources"\n[source.vendored-sources]\ndirectory = "vendor"\n' > .cargo/config.toml
export PATH=/opt/rustc/bin:$PATH PROTOC=$P/bin/protoc CARGO_HOME=$B/.cargo-home CARGO_NET_OFFLINE=true
make PREFIX=/usr CARGO="cargo --offline --locked" build
sed -i 's/^\t\$(MAKE) -C docs install$/\t@true/' Makefile
make DESTDIR="$STAGE" PREFIX=/usr install
rm -rf .cargo-home
