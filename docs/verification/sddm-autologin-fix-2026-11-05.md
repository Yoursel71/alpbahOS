# SDDM autologin kalıcı düzeltmesi (5 Kasım 2026)

Durum: **düzeltildi ve test imajında doğrulandı** (VM açılışı, seri konsol). Autologin şifre girilmeden `alpbah` Plasma oturumunu açtı.

## Kök nedenler (sırayla bulundu)

1. **`/run/faillock` yok:** `sddm-autologin` yığını `pam_faillock preauth` kullanıyor; dizin açılışta oluşmuyordu. Düzeltme: `tmpfiles.d` kuralı (`scripts/lfs-blfs/sddm-autologin/alpbahos-autologin.conf`).
2. **Rootfs kök dizini `alpbah` (uid 1000) sahipliğindeydi:** systemd tmpfiles bunu güvenlik nedeniyle reddetti. Düzeltme: `chown 0:0 /mnt/lfs` (test imajında zaten `0:0`); post-config adımı eklendi.
3. **`system-local-login` PAM dosyası yoktu (asıl neden):** `sddm-autologin` bu dosyayı include ediyor; eksikliği `[PAM] acctMgmt: Permission denied` ve `Autologin failed!` üretiyordu. Düzeltme: `system-login` kopyası (`scripts/lfs-blfs/sddm-autologin/system-local-login`).

## Doğrulama

Journal (autologin açılışı):
- `pam_unix(sddm-autologin:session): session opened for user alpbah(uid=1000) by (uid=0)`
- `loginctl`: alpbah oturumu; `kwin_wayland` ve `plasmashell` çalışıyor.

## Açık

- Canlı ISO imajında da aynı düzeltmeler gerekiyor (squashfs yeniden üretilecek).
- Autologin açılışında KWin/plasmashell oturumu başladı; T2 kısayol doğrulayıcısı bu oturumda yeniden çalıştırılmadı.
