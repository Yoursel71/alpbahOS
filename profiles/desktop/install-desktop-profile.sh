#!/bin/bash
# install-desktop-profile.sh -- alpbahOS M08 masaüstü profilini bir kök dizine kurar.
#
# Kurulanlar (DATADIR varsayılanı /usr/share, SYSCONFDIR varsayılanı /etc):
#   DATADIR/plasma/look-and-feel/org.alpbahos.solid.desktop/   look-and-feel paketi
#   DATADIR/color-schemes/alpbah-dark.colors                  renk şeması
#   DATADIR/wallpapers/alpbahOS-Ataturk/                      Atatürk duvar kâğıdı paketi
#   DATADIR/icons/hicolor/<N>x<N>/apps/alpbahos.png           alpbahOS sembol ikonu
#   SYSCONFDIR/xdg/kdeglobals                                 LookAndFeelPackage varsayılanı
#   SYSCONFDIR/xdg/kwinrc                                     Solid: blur/kontrast kapalı
#   SYSCONFDIR/xdg/kglobalshortcutsrc                         Windows'a tanıdık kısayollar
#
# Kurallar (AGENTS.md, docs/AGENT_STANDING_RULES.md):
# - Hedef kök açıkça verilir (--destdir). Canlı "/" yalnız --allow-live-root ile kabul edilir;
#   Builder /mnt/lfs rootfs'ine kurulum tek entegratörün (Codex) işidir.
# - Hedefte farklı içerikli dosya varsa üzerine yazılmaz, betik durur (--force ile yazılır).
# - Kurulan her dosya "sha256  yol" biçiminde --manifest dosyasına yazılır (sahiplik kaydı için).
#
# Kullanım:
#   profiles/desktop/install-desktop-profile.sh --destdir /mnt/lfs --manifest /tmp/m08-desktop.manifest
#   profiles/desktop/install-desktop-profile.sh --destdir /tmp/stage --datadir /opt/kf6/share
set -euo pipefail
export LC_ALL=C

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DESTDIR=""
DATADIR="/usr/share"
SYSCONFDIR="/etc"
MANIFEST=""
FORCE=0
ALLOW_LIVE_ROOT=0
DRY_RUN=0

usage() {
    sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed -e '$d' -e 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --destdir) DESTDIR="${2:?--destdir değer ister}"; shift 2 ;;
        --datadir) DATADIR="${2:?--datadir değer ister}"; shift 2 ;;
        --sysconfdir) SYSCONFDIR="${2:?--sysconfdir değer ister}"; shift 2 ;;
        --manifest) MANIFEST="${2:?--manifest değer ister}"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --allow-live-root) ALLOW_LIVE_ROOT=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "HATA: bilinmeyen argüman: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$DESTDIR" ]; then
    echo "HATA: --destdir zorunlu (ör. --destdir /mnt/lfs ya da geçici bir stage dizini)" >&2
    exit 2
fi
if [ ! -d "$DESTDIR" ]; then
    echo "HATA: hedef kök yok: $DESTDIR" >&2
    exit 2
fi
DESTDIR="$(cd "$DESTDIR" && pwd -P)"
if [ "$DESTDIR" = "/" ] && [ "$ALLOW_LIVE_ROOT" -ne 1 ]; then
    echo "HATA: hedef kök '/' -- canlı sisteme kurulum için --allow-live-root gerekir" >&2
    exit 2
fi
case "$DATADIR$SYSCONFDIR" in
    *..*) echo "HATA: --datadir/--sysconfdir '..' içeremez" >&2; exit 2 ;;
esac
case "$DATADIR" in /*) ;; *) echo "HATA: --datadir mutlak yol olmalı" >&2; exit 2 ;; esac
case "$SYSCONFDIR" in /*) ;; *) echo "HATA: --sysconfdir mutlak yol olmalı" >&2; exit 2 ;; esac

# Kaynaklar güncel mi? Üretilmiş kısayol dosyası tek kaynakla eşleşmeli.
PYTHON="${PYTHON:-python3}"
command -v "$PYTHON" >/dev/null 2>&1 || PYTHON=python
(cd "$REPO" && "$PYTHON" profiles/shortcuts/generate_kglobalshortcutsrc.py --check >/dev/null)

# "kaynak|hedef" çiftleri (hedef, DESTDIR'e göre mutlak yol).
PAIRS=()
add_tree() {
    local src_root="$1" dst_root="$2" rel
    while IFS= read -r -d '' file; do
        rel="${file#"$src_root"/}"
        PAIRS+=("$file|$dst_root/$rel")
    done < <(find "$src_root" -type f ! -name '*.md' -print0 | sort -z)
}

LNF_SRC="$REPO/profiles/desktop/lookandfeel/org.alpbahos.solid.desktop"
WALL_SRC="$REPO/branding/ataturk-theme/wallpaper/alpbahOS-Ataturk"
add_tree "$LNF_SRC" "$DATADIR/plasma/look-and-feel/org.alpbahos.solid.desktop"
add_tree "$WALL_SRC" "$DATADIR/wallpapers/alpbahOS-Ataturk"
PAIRS+=("$WALL_SRC/ATTRIBUTION.md|$DATADIR/wallpapers/alpbahOS-Ataturk/ATTRIBUTION.md")
add_tree "$REPO/branding/icons/hicolor" "$DATADIR/icons/hicolor"
PAIRS+=("$REPO/profiles/desktop/colorscheme/alpbah-dark.colors|$DATADIR/color-schemes/alpbah-dark.colors")
PAIRS+=("$REPO/profiles/desktop/xdg/kdeglobals|$SYSCONFDIR/xdg/kdeglobals")
PAIRS+=("$REPO/profiles/desktop/xdg/kwinrc|$SYSCONFDIR/xdg/kwinrc")
PAIRS+=("$REPO/profiles/shortcuts/generated/kglobalshortcutsrc|$SYSCONFDIR/xdg/kglobalshortcutsrc")

# Önce tüm çakışmaları denetle; yarım kurulum bırakma.
conflicts=0
for pair in "${PAIRS[@]}"; do
    src="${pair%%|*}"; dst="$DESTDIR${pair#*|}"
    [ -f "$src" ] || { echo "HATA: kaynak yok: $src" >&2; exit 1; }
    if [ -L "$dst" ] || { [ -e "$dst" ] && [ ! -f "$dst" ]; }; then
        echo "HATA: hedef normal dosya değil: $dst" >&2; conflicts=$((conflicts + 1))
    elif [ -f "$dst" ] && ! cmp -s "$src" "$dst" && [ "$FORCE" -ne 1 ]; then
        echo "ÇAKIŞMA: farklı içerikli dosya var: $dst" >&2; conflicts=$((conflicts + 1))
    fi
done
if [ "$conflicts" -gt 0 ]; then
    echo "Durdu: $conflicts çakışma. İçeriği inceleyin; bilerek değiştirmek için --force." >&2
    exit 1
fi

manifest_lines=()
for pair in "${PAIRS[@]}"; do
    src="${pair%%|*}"; rel="${pair#*|}"; dst="$DESTDIR$rel"
    sum="$(sha256sum "$src" | cut -d' ' -f1)"
    manifest_lines+=("$sum  $rel")
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "kurulacak: $rel"
        continue
    fi
    install -D -m 0644 "$src" "$dst"
done

if [ -n "$MANIFEST" ]; then
    printf '%s\n' "${manifest_lines[@]}" > "$MANIFEST"
fi
echo "tamam: ${#PAIRS[@]} dosya -> $DESTDIR (DATADIR=$DATADIR, SYSCONFDIR=$SYSCONFDIR)$([ "$DRY_RUN" -eq 1 ] && echo ' [dry-run]')"
