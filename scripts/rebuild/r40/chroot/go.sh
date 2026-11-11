# DISTROBOX-01, in the chroot of r4-root, from the unpacked go1.27.4 source tree (go.dev/dl, sha256 checked). Go is only
# a build tool for Podman: built from source with the upstream linux-amd64 release as bootstrap (both sha256-checked
# against go.dev/dl), GOAMD64=v1 (D146); the result is packed as a tar in $STAGE and never recorded or shipped.
set -e
B=$PWD
mkdir -p /tmp/go-bootstrap
tar -xzf ../go1.27.4.linux-amd64.tar.gz -C /tmp/go-bootstrap --strip-components=1
cd src
env GOROOT_BOOTSTRAP=/tmp/go-bootstrap GOAMD64=v1 GOCACHE=$B/.gocache HOME=$B ./make.bash
cd ..
rm -rf /tmp/go-bootstrap .gocache
"$B/bin/go" version
mkdir -p "$STAGE"
tar -C /tmp -cf "$STAGE/go-1.27.4-toolchain.tar" "$(basename "$B")"
