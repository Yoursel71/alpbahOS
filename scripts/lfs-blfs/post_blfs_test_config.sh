#!/bin/bash
# BLFS/Plasma TEST imajı için kök dosya sistemi yapılandırması (idempotent).
# Kullanım: sudo LFS=/mnt/lfs [ALPBAH_TEST_PASSWORD=...] [TEST_FONT_DIR=/yol] bash post_blfs_test_config.sh
# Kimlik bilgisi bu dosyada YOK: şifre yalnızca ortam değişkeninden alınır. Yazı tipi yalnızca test içindir
# (noto-sans paketi, plan satırı 191, kaynak eksik). Release imajı için bu betik yeniden gözden geçirilmeli.
set -eu
LFS=${LFS:-/mnt/lfs}
USER_NAME=alpbah
log(){ echo "[post-blfs] $*"; }
in_chroot(){ chroot "$LFS" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin "$@"; }

# 1) Oturum ortam değişkenleri (pam_env /etc/environment okur)
ENVF="$LFS/etc/environment"
touch "$ENVF"
for line in \
  "QT_QPA_PLATFORMTHEME=generic" \
  "QT_PLUGIN_PATH=/usr/lib/plugins:/opt/qt6/plugins" \
  "QML_IMPORT_PATH=/usr/lib/qml" \
  "QML2_IMPORT_PATH=/usr/lib/qml"; do
  key=${line%%=*}
  if ! grep -q "^${key}=" "$ENVF"; then echo "$line" >> "$ENVF"; log "environment: $line"; fi
done
# Mesa override'ı (kms_swrast) kaldır: EGL/drisw yolunu bozuyordu
sed -i '/^MESA_LOADER_DRIVER_OVERRIDE=/d' "$ENVF"

# 2) PAM: sddm ve login yığınları system-login'i include eder; LFS'te bu dosyalar yoktu
mkdir -p "$LFS/etc/pam.d"
if [ ! -e "$LFS/etc/pam.d/system-login" ]; then
cat > "$LFS/etc/pam.d/system-login" <<'EOF'
# Begin /etc/pam.d/system-login
auth      include   system-auth
account   include   system-account
password  include   system-password
session   include   system-session
# End /etc/pam.d/system-login
EOF
log "pam: system-login yazıldı"; fi
if [ ! -e "$LFS/etc/pam.d/login" ]; then
cat > "$LFS/etc/pam.d/login" <<'EOF'
# Begin /etc/pam.d/login
auth      include   system-login
account   include   system-login
password  include   system-login
session   include   system-login
# End /etc/pam.d/login
EOF
log "pam: login yazıldı"; fi

# 3) SDDM: X sunucusu yolu ve test oturumu (otomatik giriş hedefi)
SDDMC="$LFS/etc/sddm.conf"
if [ -f "$SDDMC" ]; then
  sed -i 's#^ServerPath=.*#ServerPath=/usr/bin/X#' "$SDDMC"
  sed -i "s#^User=.*#User=$USER_NAME#" "$SDDMC"
  sed -i 's#^Session=.*#Session=plasma.desktop#' "$SDDMC"
  log "sddm.conf: ServerPath, User, Session ayarlandı"
else
  log "UYARI: $SDDMC yok (sddm kurulu değil?)"
fi

# 4) Test kullanıcısı (uid 1000). 'render' grubu LFS'te yok, bu yüzden yalnızca mevcut gruplar.
if ! in_chroot /usr/bin/id "$USER_NAME" >/dev/null 2>&1; then
  in_chroot /usr/sbin/useradd -m -u 1000 -G video,input,audio -s /bin/bash "$USER_NAME"
  log "kullanıcı oluşturuldu: $USER_NAME"
fi
if [ -n "${ALPBAH_TEST_PASSWORD:-}" ]; then
  echo "$USER_NAME:$ALPBAH_TEST_PASSWORD" | in_chroot /usr/sbin/chpasswd
  log "test şifresi ayarlandı (ortam değişkeninden)"
else
  log "test şifresi ayarlanmadı (ALPBAH_TEST_PASSWORD yok): hesap kilitli kalır"
fi

# 5) systemd: display-manager, graphical hedefi ve sddm'in wants bağlantısı
SYS="$LFS/etc/systemd/system"
mkdir -p "$SYS/graphical.target.wants"
ln -sfn /usr/lib/systemd/system/sddm.service "$SYS/display-manager.service"
ln -sfn /usr/lib/systemd/system/sddm.service "$SYS/graphical.target.wants/sddm.service"
ln -sfn /usr/lib/systemd/system/graphical.target "$SYS/default.target"
log "systemd: display-manager, graphical.target.wants/sddm, default.target"

# 6) KActivities veritabanı dizini (kullanıcının ev dizininde)
HOMEDIR="$LFS/home/$USER_NAME"
if [ -d "$HOMEDIR" ]; then
  mkdir -p "$HOMEDIR/.local/share/kactivitymanagerd/resources"
  chown -R 1000:1000 "$HOMEDIR/.local"
  log "kactivitymanagerd dizini hazır"
fi

# 7) Test yazı tipi (isteğe bağlı; yalnızca test)
if [ -n "${TEST_FONT_DIR:-}" ] && [ -d "$TEST_FONT_DIR" ]; then
  mkdir -p "$LFS/usr/share/fonts/TTF"
  cp -f "$TEST_FONT_DIR"/NotoSans-Regular.ttf "$LFS/usr/share/fonts/TTF/" 2>/dev/null || true
  in_chroot /usr/bin/fc-cache -f >/dev/null 2>&1 || true
  log "test yazı tipi: $TEST_FONT_DIR"
fi

# 8) Kısayol profili. kglobalacceld yalnızca ~/.config/kglobalshortcutsrc okur (/etc/xdg okumaz).
#    SHORTCUT_PROFILE=/yol/generated/kglobalshortcutsrc ile verilir. Kullanıcı dosyası zaten varsa
#    ELLENMEZ. Daha önce açılmış bir imajda dosya upstream varsayılanlarıyla dolu olabilir; o durumda
#    dosyayı elle değiştirin (2026-11-05 T2: disk-blfs3.img bu yolla yamalandı, yedek t2-backup/).
if [ -n "${SHORTCUT_PROFILE:-}" ] && [ -f "$SHORTCUT_PROFILE" ]; then
  install -D -m 0644 "$SHORTCUT_PROFILE" "$LFS/usr/share/alpbahos/kglobalshortcutsrc"
  install -d -o 1000 -g 1000 -m 0700 "$LFS/home/$USER_NAME/.config"
  if [ ! -e "$LFS/home/$USER_NAME/.config/kglobalshortcutsrc" ]; then
    install -o 1000 -g 1000 -m 0600 "$SHORTCUT_PROFILE" "$LFS/home/$USER_NAME/.config/kglobalshortcutsrc"
    log "kısayol profili: ~$USER_NAME/.config/kglobalshortcutsrc yazıldı"
  else
    log "kısayol profili: kullanıcı dosyası mevcut, değiştirilmedi"
  fi
else
  log "UYARI: SHORTCUT_PROFILE yok; kısayol profili kurulmadı"
fi

sync
log "tamam"
