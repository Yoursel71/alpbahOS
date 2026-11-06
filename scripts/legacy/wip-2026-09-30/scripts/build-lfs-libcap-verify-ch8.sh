#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

for path in /usr/sbin/capsh /usr/sbin/getcap /usr/sbin/getpcaps /usr/sbin/setcap \
            /usr/lib/libcap.so /usr/lib/libcap.so.2 /usr/lib/libcap.so.2.76 \
            /usr/lib/libpsx.so /usr/lib/libpsx.so.2 /usr/lib/libpsx.so.2.76; do
    [[ -e "$path" || -L "$path" ]] || { echo "Missing installed Libcap path: $path" >&2; exit 1; }
done
[[ ! -e /usr/lib/libcap.a && ! -e /usr/lib/libpsx.a ]]
/usr/sbin/capsh --print >/dev/null
/usr/sbin/getcap /usr/sbin/capsh >/dev/null
printf 'Verified Libcap 2.76 installed commands, shared libraries, and capsh runtime.\n'
