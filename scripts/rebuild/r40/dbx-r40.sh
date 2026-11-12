#!/bin/bash
# Round 40 (DISTROBOX-01, D163): Distrobox with rootless Podman, so Debian/Ubuntu/Arch/Fedora packages run in containers
# without touching the base. None of these is in BLFS 13.1; upstream releases (sha256 printed; Go against go.dev/dl,
# crun's signature checked on the host):
#   go 1.27.4 (build tool only: built from source with the upstream binary as bootstrap; never recorded or shipped)
#   conmon 2.2.1, json-c 0.19 (BLFS 13.1, for crun), crun 1.30.1, passt 2026_10_02.cba3570 (pasta), podman 5.8.10, distrobox 1.8.2.5 (rows 427-431)
#   alpbahos-containers-r40: /etc/containers/{registries.conf,policy.json,storage.conf} from profiles/containers/
#   round 41 (NETAVARK-01, handoff 038): netavark 1.17.2 (row 435), aardvark-dns 1.17.1 (row 436); run: dbx-r40.sh netavark aardvark-dns
# Book-style commands in chroot/*.sh. Usage: dbx-r40.sh [NAME ...] (default: all, in order). Run as root.
# Env NICE (default 10), JOBS (default 14).
set -euo pipefail
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
A=$WT/scripts/rebuild/r40/chroot
S=$SB/apps01-src/dbx
TC=$SB/r40/go-1.27.4-toolchain.tar
export NICE=${NICE:-10} JOBS=${JOBS:-14}
mkdir -p "$SB/r10/dl"
ARGS=("$@")
w() { [ ${#ARGS[@]} -eq 0 ] && return 0; local x; for x in "${ARGS[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
sha() { [ "$(sha256sum < "$S/$1" | cut -c1-64)" = "$2" ] || { echo "sha256 mismatch: $1"; exit 1; }; }
link() { [ -e "$SB/r10/dl/$1" ] || ln "$S/$1" "$SB/r10/dl/$1"; }
cd "$WT"
step() {  # NAME VER URL TARBALL NN NOTE SCRIPT [extra files...]
    local n=$1 v=$2 u=$3 t=$4 nn=$5 note=$6 s=$7; shift 7
    link "$t"
    echo "== $n-$v ($(date +%T))"
    EXTRA_FILES="$s $*" CUSTOM_CMD="sh ../$(basename "$s")" \
      bash scripts/rebuild/r11/pkg-url-r11.sh "$n" "$v" "$u" "$t" custom - "$nn" "DISTROBOX-01 (D163): $note"
}
if w go; then
    sha go1.27.4.src.tar.gz 73cfb8571aec0c01177687db87163d46aa20e9779672772891aa17654d9a6099
    sha go1.27.4.linux-amd64.tar.gz 7226736c2339719cda28fbf3a54d71aa63bcefe376e98cef00034268dab24840
    EXTRA_FILES="$A/go.sh $S/go1.27.4.linux-amd64.tar.gz" CUSTOM_CMD="sh ../go.sh" \
      bash scripts/rebuild/r10/build-pkg-r10.sh go 1.27.4 "$S/go1.27.4.src.tar.gz" custom -
    cp "$SB/r10/go/stage/go-1.27.4-toolchain.tar" "$TC"
    rm -rf "$SB/r10/go/stage"
    echo "go toolchain: $TC ($(du -h "$TC" | cut -f1)), not recorded"
fi
if w conmon; then
    sha conmon-2.2.1.tar.gz 814fb5979a3a4b8576b1f901e606b482bebb41cb7e57926e6d5765ee786b96d3
    step conmon 2.2.1 https://github.com/containers/conmon/archive/refs/tags/v2.2.1.tar.gz conmon-2.2.1.tar.gz 427 \
        "upstream tag v2.2.1 archive, sha256 814fb597..." "$A/conmon.sh"
fi
if w json-c; then
    # crun 1.30 needs json-c (no longer yajl); BLFS 13.1-systemd general/json-c.html
    [ "$(md5sum < "$S/json-c-0.19.tar.gz" | cut -c1-32)" = 5678f1373ba51e0041b574c0411c696b ] || { echo "MD5 mismatch: json-c"; exit 1; }
    link json-c-0.19.tar.gz
    echo "== json-c-0.19 ($(date +%T))"
    bash scripts/rebuild/r11/pkg-url-r11.sh json-c 0.19 https://s3.amazonaws.com/json-c_releases/releases/json-c-0.19.tar.gz \
        json-c-0.19.tar.gz cmake - 432 "DISTROBOX-01: BLFS 13.1-systemd general/json-c.html: 0.19, book MD5 5678f137... matches" \
        -DBUILD_STATIC_LIBS=OFF
fi
if w crun; then
    sha crun-1.30.1.tar.gz 99d036d95113552b6df66c7c879432835504bf0e525fc0372745071df129527b
    step crun 1.30.1 https://github.com/containers/crun/releases/download/1.30.1/crun-1.30.1.tar.gz crun-1.30.1.tar.gz 428 \
        "upstream release 1.30.1, signature by Giuseppe Scrivano (AF60FCA3CDAA6DEAD157EA3A67E38F7A8BA21772) good" "$A/crun.sh"
fi
if w passt; then
    sha passt-2026_10_02.cba3570.tar.xz aa75616cc43925f0bd6c05bcfbbaecd77397c03d7bd23591b34ef535be5dfcdc
    step passt 2026_10_02 https://passt.top/passt/snapshot/passt-2026_10_02.cba3570.tar.xz \
        passt-2026_10_02.cba3570.tar.xz 429 "passt.top snapshot 2026_10_02.cba3570, sha256 aa75616c..." "$A/passt.sh"
fi
if w podman; then
    sha podman-5.8.10.tar.gz 8d047cd9a0e17b4a7a1c5ddd054c8f0d0e28667ef20144afd3a16b65975de10a
    [ -s "$TC" ] || { echo "no Go toolchain: run the go step first"; exit 1; }
    step podman 5.8.10 https://github.com/containers/podman/archive/refs/tags/v5.8.10.tar.gz podman-5.8.10.tar.gz 430 \
        "upstream tag v5.8.10 archive (vendored Go modules), sha256 8d047cd9..." "$A/podman.sh" "$TC"
fi
if w distrobox; then
    sha distrobox-1.8.2.5.tar.gz 0c3bc4785ee3be3b89f93abb7cc0a9f60e56989e81319af140a4b60403b18f80
    step distrobox 1.8.2.5 https://github.com/89luca89/distrobox/archive/refs/tags/1.8.2.5.tar.gz distrobox-1.8.2.5.tar.gz 431 \
        "upstream tag 1.8.2.5 archive, sha256 0c3bc478..." "$A/distrobox.sh"
fi
if w netavark; then
    # NETAVARK-01 (handoff 038, rc01 KUTU row: "could not find netavark"): podman 5.x supports only netavark.
    # Source tag archive and release vendor tarball: sha256 of the vendor tarball = the release sha256sum and GitHub's
    # asset digest; sha512 of both = Fedora 43's sources file (Fedora 43 ships netavark 1.17.2 with podman 5).
    # protoc 36.2 (build tool only, never recorded): the upstream binary zip, sha256 = GitHub's asset digest.
    sha netavark-1.17.2.tar.gz 284faa7cc525b869cbac4053e0a4127ac743ca7da1457c49fffb35558ea9c78d
    sha netavark-v1.17.2-vendor.tar.gz afa8e99a9691ef6ea485d6cb6b1897684d9f8a26719deaa3cbf37b5f17198e6f
    sha protoc-36.2-linux-x86_64.zip 121f6c7afe1d4d0e3ea6aab9432038599250134cbf4474cb1167d2c7decd4278
    [ "$(sha512sum < "$S/netavark-1.17.2.tar.gz" | cut -c1-128)" = bc3a38e26c2f6dba03ce74e671189a8c2b132e0820aa5740a04949fbb32ad33170e7816535503c6c394d14f93f8ae62dcd9da0cbe410984cee8070b1e3855430 ] || { echo "sha512 != Fedora: netavark"; exit 1; }
    step netavark 1.17.2 https://github.com/containers/netavark/archive/refs/tags/v1.17.2.tar.gz netavark-1.17.2.tar.gz 435 \
        "NETAVARK-01: upstream tag v1.17.2 archive + release vendor tarball (sha256 = release sha256sum; sha512 = Fedora 43)" \
        "$A/netavark.sh" "$S/netavark-v1.17.2-vendor.tar.gz" "$S/protoc-36.2-linux-x86_64.zip"
fi
if w aardvark-dns; then
    sha aardvark-dns-1.17.1.tar.gz 25b39bfad079a03862825b2f9db8b71b82fc80aad5552a9c76ea912edc9b889e
    sha aardvark-dns-v1.17.1-vendor.tar.gz 009198f042f150d42025c8a0456bb7a98293c9deeb012d37b2d364f44e52288f
    [ "$(sha512sum < "$S/aardvark-dns-1.17.1.tar.gz" | cut -c1-128)" = f7100ebaa9cde032bdef7975a0486a47c178543c6c6e35a538f4fe71b2cec788f7ceaae715637fb7a7e706aa31144efbcd1002af8b1300b1faedd3fbada37781 ] || { echo "sha512 != Fedora: aardvark-dns"; exit 1; }
    step aardvark-dns 1.17.1 https://github.com/containers/aardvark-dns/archive/refs/tags/v1.17.1.tar.gz aardvark-dns-1.17.1.tar.gz 436 \
        "NETAVARK-01: upstream tag v1.17.1 archive + release vendor tarball (sha256 = release sha256sum; sha512 = Fedora 43)" \
        "$A/aardvark-dns.sh" "$S/aardvark-dns-v1.17.1-vendor.tar.gz"
fi
if w containers-config; then
    ST=$SB/r40/stage-containers
    rm -rf "$ST" && install -d "$ST/etc/containers"
    install -m 644 "$WT/profiles/containers/registries.conf" "$WT/profiles/containers/policy.json" \
        "$WT/profiles/containers/storage.conf" "$ST/etc/containers/"
    REPLACE=1 bash scripts/rebuild/r7/apply-r7.sh scripts/rebuild/r8/stage-record-r8.py alpbahos-containers-r40 0.9-r40 \
        "$ST" alpbahos-containers-r40 0.9-r40
fi
echo "dbx-r40 done $(date +%T)"
