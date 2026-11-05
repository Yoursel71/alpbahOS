# T3 — Zsh varsayılan kabuk ve eklentiler (5 Kasım 2026)

Kapsam: MASTER_PLAN §4.3 etkileşim maddeleri. Test ortamı: LFS rootfs (`/mnt/lfs`) üzerinde **chroot + pty**. VM açılmadı, Konsole içinde gerçek oturum yapılmadı. Bu nedenle sonuçlar "chroot pty'de doğrulandı" olarak okunmalı.

## Kaynaklar (etiket commit'i ile doğrulandı)

| Paket | Etiket | Commit (tam SHA) | Kurulum yolu |
|---|---|---|---|
| zsh-autosuggestions | v0.7.1 | `e52ee8ca55bcc56a17c828767a3f98f22a68d4eb` | `/usr/share/zsh-autosuggestions/` |
| zsh-syntax-highlighting | 0.8.0 | `db085e4661f6aafd24e5acb5b2e17e4dd5dddf3e` | `/usr/share/zsh-syntax-highlighting/` |

Etiket commit'leri GitHub API'deki değerlerle eşleşti. Dosyalar `git archive HEAD` ile, `.github` ve `tests` hariç kuruldu.

## Yapılanlar

- `profiles/shell/zshrc.alpbah` → `/etc/alpbahos/zshrc.alpbah`; `~alpbah/.zshrc` bunu `source` eder.
- `/bin/zsh` `/etc/shells` içine eklendi; `alpbah` kabuğu `/bin/zsh`.
- **LFS zsh 5.9 yeniden derlendi** (önceki derleme kilitleniyordu, aşağıya bakın). Yeni derleme: `make install` ile rootfs'e kuruldu.

## Hata ve kök neden: zsh komut ikamesinde kilitlenme

- Belirti: chroot içinde `x=$(echo ok)` ve `compinit -u` sonsuza kadar bekliyordu; `alias`, `bindkey`, `compinit -D` çalışıyordu. Ana makinedeki zsh 5.9 aynı işlemleri sorunsuz yapıyordu; chroot'taki bash da yapıyordu.
- `strace`: çocuk süreç çıkıyor, ebeveyn SIGCHLD'yi alıp topluyor, iş durumunu güncellemeden `pause()` çağırıp hiç uyanmıyordu.
- `config.log` (derleme `337.log`): `checking if POSIX sigsuspend() works... no`, ayrıca `link() works = no`, `kill(pid,0) returns ESRCH correctly = no`, `tcsetpgrp() actually works = no`. Derleme tty'siz ortamda yapıldığı için bu testler yanlış negatif verdi; zsh de kırılgan `pause()` yoluna düştü.
- Düzeltme: `configure`'a `zsh_cv_sys_sigsuspend=yes zsh_cv_sys_killesrch=yes zsh_cv_sys_link=yes zsh_cv_sys_tcsetpgrp=yes` verilerek yeniden derlendi. Derleme betiği (`build-cmds/packages/337-zsh-5.9.sh`) buna göre güncellendi.

## Sonuçlar (chroot pty, uid 1000 `alpbah`)

| MASTER_PLAN §4.3 | Test | Sonuç |
|---|---|---|
| 1. Öneri görünür, ağ gerekmez | `echo sugg` yazılınca geçmişten `estme_123` önerisi gösterildi; eklentiler yerel | Chroot pty'de doğrulandı (ağ kullanılmadı, eklenti yerel) |
| 2. Kabul çalıştırmaz, Enter gerekir | Sağ ok ile öneri satıra alındı; ikinci kez çıktı üretilmedi | Chroot pty'de doğrulandı |
| 3. Yazım düzeltmesi açıklanır, reddedilebilir | `ehco` → `zsh: correct 'ehco' to 'echo' [nyae]?`; `n` yanıtından sonra prompt'a dönüldü | Chroot pty'de istem ve red doğrulandı; "command not found" metni ayrıca kontrol edilmedi |
| 4. Paket adı tamamlama | PKG-01/02 (`alp`) bekliyor | **Uygulanmadı** |
| 5. Ctrl+C kesme davranışı | `sleep 60` Ctrl+C ile kesildi; prompt geri geldi | Chroot pty'de doğrulandı |
| 6. Logo, gerçek terminal renkleri | Kontrol edilmedi | **Uygulanmadı** |

Betikler: `scripts/lfs-blfs/tests/zsh_pty_test.py` (1, 2, 5) ve `zsh_correct_test.py` (3). Her ikisi `sudo python3` ile `/mnt/lfs` üzerinde çalıştırılır.

## Açık işler

- Maddeler 1–3 ve 5 için **Konsole içinde gerçek oturum** doğrulaması (VM sınırı nedeniyle bu turda yapılmadı).
- Madde 4: `alp` tamamlandıktan sonra.
- Madde 6: logo testi.
- `zshrc.alpbah` içindeki `_zsh_autosuggest`/syntax-highlighting sırası upstream uyarısına uygun (`source`, sonra keybinding'ler). Renk ve strateji ayarı değiştirilmedi.
