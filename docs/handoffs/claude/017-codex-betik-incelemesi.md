# Claude devir belgesi 017: Codex betiklerinin ikinci göz incelemesi (M04/M07/M09)

```text
Görev ID / durum: AGENTS.md "Her iki ajan diğerinin kritik değişikliklerini inceleyebilir" kapsamında salt okunur inceleme. Hiçbir betik değiştirilmedi (scripts/ Codex'in alanı); düzeltmeler öneri/yama olarak aşağıda.
Çalışılan host ve branch/commit: YRSLF dışında Windows makinesi; main 3aead65 üzerinden, dal claude/m08-lookandfeel-shortcuts.
İncelenen: scripts/build-m2-gen2-test-image.sh, scripts/apply-m2-rootfs-fixes.sh, scripts/build-m07-vgem-kernel.sh, scripts/patch-m2-gen2-autoseat.sh, scripts/refresh-ssh-hosts.ps1, scripts/vm-screenshot.ps1, scripts/build-m04-*-stage.sh içindeki mount korumaları; CURRENT.md, docs/WORKLOG.md, docs/NEW_SESSION_HANDOFF.md ve M07 kanıt belgesindeki betik/kanıt atıfları.
Çalıştırılan doğrulama: atıf taraması (git ls-tree ile), bash errexit davranışının küçük bir yeniden üretimi (Git Bash 5.x). Builder/VM'de hiçbir şey çalıştırılmadı.
Sonraki eylem: Codex bulgu 1-3'ü değerlendirip kendi dalında düzeltir; inceleme gerekiyorsa Claude'a geri verir.
```

Önem sırasıyla. Her bulguda kanıt ve önerilen düzeltme var; "önerilen" yamalar uygulanmadı ve test edilmedi.

## 1. Yüksek — kanıt olarak anılan dört dosya git'te yok (M09 tekrar üretilebilirlik kapısı)

`CURRENT.md`, `docs/WORKLOG.md` ve `docs/verification/m07-gen2-plasma-session-bringup-2026-09-25.md` şu dosyalara "yeniden üretim/kanıt" olarak atıf yapıyor, fakat `origin/main` (3aead65) içinde yoklar:

| Dosya | Atıf yapan |
|---|---|
| `scripts/build-m07-runtime-deps.sh` | WORKLOG (25 Eylül M07), M07 kanıt belgesi ("Rebuild/install is repeatable with ...") |
| `scripts/build-m07-plasma.sh` | M07 kanıt belgesi (no-X11 yamalarının uygulandığı yer) |
| `scripts/verify-m09-live-iso.sh` | WORKLOG ("passed") |
| `docs/verification/m09-live-iso-preflight-2026-09-25.md` | CURRENT M09 satırı, WORKLOG |

Etkisi: M07 "masaüstü ve panel görüldü" sonucu ile M09 ISO adayı repodan yeniden üretilemez ve incelenemez; M09 çıkış koşulu "temiz, tekrarlanabilir imaj" ister. `docs/handoffs/claude/tools/check_docs.py` yalnız Markdown bağlantılarını denetlediği için bunu yakalamıyor. Muhtemelen `C:\alpbahOS` çalışma ağacında commitlenmemiş duruyorlar (NEW_SESSION_HANDOFF §11 benzer bir durumu kaydetmiş). **Öneri:** dosyaları içerikleri incelenerek commit'lemek; commitlenene kadar CURRENT/WORKLOG'da "repoda değil" diye işaretlemek. İstenirse `check_docs.py`'ye backtick içindeki `scripts/…`, `docs/verification/…` yollarını da denetleyen bir kural eklenebilir (Claude'un aracı; ayrı iş).

## 2. Orta-Yüksek — `apply-m2-rootfs-fixes.sh`, rootfs'teki `alp.py`yi sessizce `e8b0376` sürümüne geri döndürür

```bash
target="$ROOTFS/usr/lib/alp/alp.py"
if [[ $(sha256sum "$target" | cut -d' ' -f1) != "$EXPECTED_ALP" ]]; then
    cp -a "$target" "$ROOTFS/tmp/alp-logs/alp.py.before-e8b0376"
    install -o 0 -g 0 -m 0755 "$ALP_SOURCE" "$target"
fi
```

`build-m2-gen2-test-image.sh` bu betiği her imaj üretiminde çağırıyor. `alp` bugün main'de hızla ilerliyor (26 Eylül'de 5 commit). Entegratör yeni bir `alp.py`yi `/mnt/lfs`'e kurduktan sonra bir test imajı üretilirse, **yetkili rootfs'teki yeni motor yerine e8b0376 kurulur**. Yedek yalnızca `/mnt/lfs/tmp` altında kalır ve bu, tek yazıcı ile D34 sahiplik kaydıyla çelişir. **Öneri:** hash farklıysa değiştirmek yerine durmak (`echo "rootfs alp.py beklenen sürüm değil; bilinçli güncelleme için ALP_EXPECTED_SHA256 verin" >&2; exit 1`). Pin'i sabit değer yerine parametre yapmak (`EXPECTED_ALP=${EXPECTED_ALP:?}`). `build-m2-gen2-test-image.sh` sonundaki sabit hash denetimini de aynı parametreye bağlamak.

## 3. Orta — `set -e` altında `! komut` denetimleri hiçbir şeyi durdurmuyor (8 betik)

Bash, `!` ile tersine çevrilmiş komutlarda `errexit`'i ve `ERR` trap'ini uygulamaz. Yeniden üretim (`set -Eeuo pipefail; trap 'echo ERR' ERR; ! true; echo devam`) "devam" yazdı, trap çalışmadı. Etkilenen satırlar:

- `scripts/apply-m2-rootfs-fixes.sh:39`: `! grep -q '@[A-Z_]*@' "$tmp_service" "$tmp_socket"`. D-Bus şablonunda açılmamış `@…@` kalırsa kurulum yine de sürer. Sonraki `ExecStart`/`ListenStream` grep'leri bilinen iki satırı yakalar, diğerlerini yakalamaz.
- `scripts/build-m04-{bc,dejagnu,flex,iana-etc,man-pages,sed,tcl}-stage.sh`: `for target in "$LFS/dev" … ; do ! mountpoint -q "$target"; done`. "Chroot bağlamaları zaten var mı?" koruması etkisiz. Başka bir oturumun açık bağlaması varsa betik onun üstüne bağlar ve temizlikte ayırabilir. Bu, AGENTS.md'deki "aynı rootfs'yi eşzamanlı değiştirme" korumasının deliği.

Önerilen yama (uygulanmadı):

```diff
--- a/scripts/apply-m2-rootfs-fixes.sh
+++ b/scripts/apply-m2-rootfs-fixes.sh
-! grep -q '@[A-Z_]*@' "$tmp_service" "$tmp_socket"
+if grep -q '@[A-Z_]*@' "$tmp_service" "$tmp_socket"; then
+    echo 'dbus user unit şablonunda açılmamış @...@ kaldı' >&2; exit 1
+fi
--- a/scripts/build-m04-bc-stage.sh   (ve diğer altı build-m04-*-stage.sh)
 for target in "$LFS/dev" "$LFS/dev/pts" "$LFS/proc" "$LFS/sys" "$LFS/run"; do
-    ! mountpoint -q "$target"
+    if mountpoint -q "$target"; then
+        echo "önceden bağlı: $target -- başka bir chroot oturumu açık olabilir" >&2; exit 1
+    fi
 done
```

## 4. Orta — test imajı üretimi yetkili rootfs'i değiştiriyor; ortam kilidi ve disk alanı denetimi yok

`build-m2-gen2-test-image.sh`, imaj üretmeden önce `apply-m2-rootfs-fixes.sh` ile `/mnt/lfs`'i değiştiriyor (getty/resolved bağları, D-Bus user unit'leri, `alp.py`). Aynı anda başka bir ajanın paket kurulumunu ya da `tar` kopyasını dışlayan bir kilit yok. `tar` kopyası sırasında rootfs'e yazılırsa tutarsız bir imaj çıkar. 24 GiB ham dosya için boş alan da denetlenmiyor (Builder diski bir kez %100 doldu, AGENT_STANDING_RULES §2.3). **Öneri:** ortak bir kilit (ör. `exec 9>/run/alpbahos-rootfs.lock; flock -n 9 || exit 1`), bunun rootfs'e yazan tüm betiklerde kullanılması, `df` ile en az SIZE + %10 boş alan denetimi ve rootfs düzeltmesiyle imaj üretiminin iki ayrı adıma ayrılması.

## 5. Orta — aynı kernel kaynak ağacı iki farklı yapılandırmayla kullanılıyor

`build-m07-vgem-kernel.sh`, `/mnt/lfs/sources/linux-6.16.1/.config`'in `/boot/config-6.16.1-alpbahOS` ile aynı olmasını şart koşuyor. M07 belgesindeki 25 Eylül eki, bu ağacın `.config`'inin artık M09 `-miso1` kernel'ine ait olduğunu söylüyor. Sonuç: VGEM betiği artık yeniden çalışmaz, `/boot`'taki kernel ile kaynak ağacı uyuşmaz. Hyper-V fare modülü de bu yüzden ayrı derlenmek zorunda kalmış. **Öneri:** her kernel çeşidi için ayrı çıktı dizini (`make O=/mnt/lfs/build/kernel-<çeşit>`), yapılandırmaların `configs/kernel/` altında commit'lenmesi ve `CONFIG_HID_HYPERV_MOUSE=y` eklemesinin (M07 bulgusu) ana yapılandırmaya alınması.

## 6. Düşük-Orta — `patch-m2-gen2-autoseat.sh` repodaki hâliyle eski; kopya olduğunu doğrulamıyor

- Betik `.bash_profile` içinde işaret dosyasını `/run/alp-plasma-tried`'a yazıyor. `/run` root'a ait olduğundan `admin` kullanıcısı yazamaz: yazma hatası verir, `exec startplasma-wayland` yine çalışır ve her tty1 girişinde tekrarlanabilir. WORKLOG'a göre runtimefix imajında işaret `XDG_RUNTIME_DIR`'e taşınmış, ama bu düzeltme repodaki betikte yok. `docs/AGENT_STANDING_RULES.md` hâlâ `sudo rm /run/alp-plasma-tried` diyor. Aynı dosyada anılan "KDE QML/plugin yolları" profili de repoda yok.
- Başlık "COPY" diyor, ama betik `IMG`'in bir kopya olduğunu denetlemiyor. `artifacts/` altındaki bir sürüm VHDX'i yerinde değiştirilebilir (NEW_SESSION_HANDOFF §1: "M1 final VHDX'i yerinde değiştirme"). **Öneri:** `IMG` yolu `*/artifacts/*` ise ya da bilinen sürüm SHA-256'larından biriyse reddetmek. Güncel `.bash_profile` içeriğini repoya almak.

Not: Bu betiği 25 Eylül'de bir Claude oturumu yazmış (`claude-autoseat` geçici dizin adı). Düzeltme sahipliği Codex ile konuşulmalı.

## 7. Düşük — `refresh-ssh-hosts.ps1` dosyayı ANSI kodlamasıyla geri yazıyor

Windows PowerShell 5.1'de `Set-Content` varsayılanı sistem ANSI kod sayfasıdır. `~/.ssh/config` içinde UTF-8 (ör. Türkçe) yorum varsa bozulur. **Öneri:** `Set-Content -Encoding ascii` (OpenSSH yapılandırması için yeterli) ya da `[IO.File]::WriteAllText($cfgPath, $cfg)`.

## Sorun görülmeyenler

- `build-m2-gen2-test-image.sh`: `set -Eeuo pipefail`, ayrıntılı temizlik ve durum bayrakları, üzerine yazmama, `/tmp` ve `/mnt/lfs` dışı çıktı yolu, test parolasının yalnız test imajına yazılması, SSH host anahtarlarının taşınmadığının denetimi.
- `build-m07-vgem-kernel.sh`: eşzamanlı derleme/nbd/mount ön denetimleri, `/boot` yedekleri, bağlamaların ters sırayla temizlenmesi.
- `vm-screenshot.ps1`: salt okunur WMI çağrısı.
