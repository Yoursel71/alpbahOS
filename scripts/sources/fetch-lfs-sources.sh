#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

release='13.1-systemd'
download_root="https://www.linuxfromscratch.org/lfs/downloads/stable-systemd"
source_dir="${1:-/sources}"

for command_name in curl md5sum mkdir find sed wc; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'ERROR: gerekli komut bulunamadı: %s\n' "$command_name" >&2
        exit 2
    fi
done

mkdir -p -- "$source_dir"
list_file="$source_dir/wget-list-$release"
sum_file="$source_dir/md5sums-$release"

curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
    --output "$list_file" "$download_root/wget-list"
curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
    --output "$sum_file" "$download_root/md5sums"

printf 'Kaynaklar indiriliyor: %s\n' "$source_dir"
while IFS= read -r url; do
    [ -z "$url" ] && continue
    case "$url" in
        https://*) ;;
        *) printf 'ERROR: beklenmeyen kaynak URL biçimi: %s\n' "$url" >&2; exit 3 ;;
    esac
    file_name="${url##*/}"
    curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
        --output "$source_dir/$file_name" "$url"
done < "$list_file"

printf 'Resmi MD5 listesi doğrulanıyor...\n'
(cd "$source_dir" && sed "s#^#./#" "$sum_file" | md5sum --check --quiet)
printf 'Tamam: %s kaynak dosyası indirildi ve doğrulandı.\n' "$(find "$source_dir" -maxdepth 1 -type f | wc -l)"
