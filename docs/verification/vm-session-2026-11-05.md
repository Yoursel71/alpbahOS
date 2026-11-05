# QEMU VM oturumu — 5 Kasım 2026 (T2, T3, T4, T5 canlı kontrol)

Ortam: `disk-blfs3.img` (LFS 12.4 + BLFS/Plasma 6.4.4), QEMU/KVM, kernel 6.16.1, GL (virtio-vga-gl) + seri konsol. Test imajı; şifre ve yazı tipi repoya girmedi.

**Açılış sayısı:** 2. İlk açılışta seri konsolda giriş yapılamadı (kullanıcı şifresi yok); test imajına geçici, rastgele bir root şifresi yazılıp VM yeniden açıldı. Onaylanan plan "tek boot" idi; bu bir sapma. Şifre `scratchpad` içinde 600 izinli dosyada, repoda değil.

## Sonuçlar

| Madde | Test | Sonuç |
|---|---|---|
| T5 alp htop | `alp install -y htop` (VM, `--root /`) | **GEÇTİ**: `INST_RC=0`; `htop --version` → `htop 3.3.0`; `alp list` → `htop 3.3.0 recipe`; `alp remove -y htop` → `REMRC=0`; `/usr/bin/htop` yok; liste boş |
| T3 §4.3 1,2,3,5 (zsh, pty, `alpbah`) | `zt.py`: öneri, sağ ok, Ctrl+C, `ehco` düzeltmesi + `n` | **GEÇTİ** (VM içi, Konsole değil): `suggestion_visible`, `accept_did_not_run`, `ctrl_c_prompt_back`, `correction_prompt`, `rejected_back_to_prompt` = True; `ZT_RC=0` |
| T3 §4.3 4 (alp tamamlama) | — | **Uygulanmadı** |
| T3 §4.3 6 (logo) | — | **Uygulanmadı** |
| T2 kısayol (verify_shortcuts_live.py) | Plasma oturumu gerekli | **Çalıştırılmadı** — aşağıdaki autologin engeli |
| T4 duvar kâğıdı | paket `/usr/share/wallpapers/alpbahOS-Ataturk` imajda; varsayılan ayar ve görsel kontrol | **Varsayılan doğrulanmadı** (oturum yok) |
| Dolphin (Meta+E) | derleme chroot'ta başarılı (`DOLPHIN_BUILD_RC=0`) | VM'de açılış/Meta+E **çalıştırılmadı** |

## Engel: SDDM autologin başarısız

- `/etc/sddm.conf` → `[Autologin] User=alpbah Session=plasma.desktop` doğru.
- Journal: `pam_kwallet5 ... Empty or missing password`, ardından `Autologin failed!`; greeter açık kalıyor.
- `alpbah` hesabı şifresiz (kilitli). `sddm-autologin` PAM yığını `pam_permit` içeriyor; hangi modülün reddettiği bu oturumda tespit edilemedi (`pam_shells`, `account` aşaması veya `pam_faillock` olası).
- Bu oturumda `sddm-autologin`'e dokunulmadı; `systemctl restart sddm` seri kabuğu bir süre kilitledi (Ctrl+C ile çözüldü).
- **Sonraki adım:** `sddm-autologin` için PAM ve hesap durumunu ayrı bir oturumda teşhis et; kalıcı çözüm build aşamasında olmalı.

## Test imajına yapılan değişiklikler (repoda yok)

- Root şifresi (geçici, rastgele) — `scratchpad/vm-session-root.pw`.
- Dolphin dosyaları (manifest'ten 365 dosya), `/usr/bin/alp`, `/root/alp-catalog` (htop), `/root/alp-src/htop-3.3.0.tar.xz`, `/usr/share/wallpapers/alpbahOS-Ataturk`, `~alpbah/{verify_shortcuts_live.py,generate_kglobalshortcutsrc.py,shortcuts.json}`.
- zsh 5.9 (yeniden derlenmiş), zsh eklentileri, `/etc/alpbahos/zshrc.alpbah`, `~alpbah/.zshrc`, `/etc/shells` (`/bin/zsh`), `alpbah` kabuğu `/bin/zsh`.

## Açık işler

1. SDDM autologin teşhisi, sonra T2 canlı kısayol doğrulaması (`verify_shortcuts_live.py`).
2. Dolphin'in VM'de açılışı ve Meta+E.
3. T4 varsayılan duvar kâğıdı ve kilit ekranı görsel kontrolü.
4. T3 §4.3 maddeleri 4 (alp tamamlama) ve 6 (logo).
