#!/usr/bin/env bash
exec /bin/bash "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build-blfs-gcrypt-d34.sh" libgcrypt
