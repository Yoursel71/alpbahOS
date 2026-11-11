# DISTROBOX-01, in the chroot of r4-root, from the podman v5.8.10 tag archive (Go modules vendored in the tree). Built with
# the Go toolchain of go.sh (unpacked into /tmp for this build only, removed afterwards), GOAMD64=v1, pure-Go OpenPGP
# instead of gpgme, no btrfs/devicemapper graph drivers. Installs the binaries and the systemd units.
set -e
B=$PWD
tar -xf ../go-1.27.4-toolchain.tar -C /tmp
GO=/tmp/build-go
trap 'rm -rf "$GO"' EXIT
export PATH=$GO/bin:$PATH GOROOT=$GO GOCACHE=$B/.gocache GOPATH=$B/.gopath GOFLAGS=-mod=vendor GOAMD64=v1 HOME=$B
TAGS='seccomp systemd exclude_graphdriver_btrfs exclude_graphdriver_devicemapper containers_image_openpgp'
make BUILDTAGS="$TAGS" GIT_COMMIT=v5.8.10 binaries
make DESTDIR="$STAGE" PREFIX=/usr BUILDTAGS="$TAGS" install.bin install.systemd
rm -rf .gocache .gopath
