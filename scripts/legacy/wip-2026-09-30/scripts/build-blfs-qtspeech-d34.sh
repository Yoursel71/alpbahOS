#!/usr/bin/env bash
exec /bin/bash "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build-blfs-qt-module-d34-common.sh" qtspeech
