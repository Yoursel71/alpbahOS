# alpbahOS Terminal/Shell Profili — SHELL-01

Durum (29 Eylül 2026): **Konsole profili Gen2 Plasma oturumunda uygulandı** (terminal zemini `alpbah-dark` rengi 11,16,20, eş aralıklı font). O kopya Codex'in ev dizinine elle koyduğu dosyalardı. Artık profil `install-desktop-profile.sh` ile sistem geneline kuruluyor, ama bu kurulum VM'de denenmedi. Gen2 imajında kabuk bash; **zsh ve eklentileri imajda yok**, `zshrc.alpbah` hiç çalıştırılmadı. Kabul kriterlerinin statik karşılığı `tests/test_m08_desktop_profile.py` `ShellProfileTests` içinde denetlenir.

Kapsam: yalnızca `profiles/shell/`. Kullanıcı shell tercihi için `/bin/sh` hedefi değiştirilmez; build scriptlerinin yorumlayıcısı bu profilden etkilenmez (AGENTS.md).

Kaynak: [docs/MASTER_PLAN.md](../../docs/MASTER_PLAN.md) §4, [docs/DECISIONS.md](../../docs/DECISIONS.md) D06.

## Yaklaşım

Hazır bileşenler özelleştirilir, yeni bir shell veya tamamlama motoru yazılmaz:

- **Zsh** + yerleşik `compinit`/tamamlama sistemi
- **[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)** — soluk öneri
- **[zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)** — sözdizimi renklendirme
- **Konsole** — renk şeması ve profil dosyası

Kaynak paketlerin sürüm/checksum doğrulaması ve LFS/BLFS zincirine eklenmesi Codex tarafında yapılır (AGENTS.md: "Kaynağı doğrulamadan derleme yapma").

## Dosyalar

- [`zshrc.alpbah`](zshrc.alpbah) — interaktif Zsh yapılandırma taslağı, hedef sistemde `/etc/alpbahos/zshrc.alpbah` olarak konumlanıp kullanıcı `.zshrc`'sinden `source` edilmesi planlanır.
- [`konsole/alpbah-dark.colorscheme`](konsole/alpbah-dark.colorscheme) — `profiles/desktop/tokens.json` ile aynı renk kaynağından üretildi.
- [`konsole/alpbahOS.profile`](konsole/alpbahOS.profile) — font (JetBrains Mono) ve imleç ayarını renk şemasına bağlar.
- [`konsole/konsolerc`](konsole/konsolerc) — `/etc/xdg/konsolerc`: `DefaultProfile=alpbahOS.profile`. Konsole bu dosyayı katmanlı okur, profil ve şema `/usr/share/konsole/` altında aranır (konsole v25.08.1 `ProfileManager.cpp`, `ColorSchemeManager.cpp`). Dolphin'in gömülü terminali de bu varsayılana düşer.

Kurulum: `profiles/desktop/install-desktop-profile.sh` üç Konsole dosyasını da kurar. Ev dizinine root olarak kopyalamaya gerek yoktur. Gen2'de bu yüzden `/home/admin/.local` root'a kalmıştı ([020](../../docs/handoffs/claude/020-m08-canli-dogrulama.md)).

## Öneri kabul/çalıştırma ayrımı (MASTER_PLAN §4.1 gereksinimi)

`zsh-autosuggestions` eklentisinin **varsayılan** davranışı zaten bu ayrımı sağlar: sağ ok veya `End` önericiyi satıra "kabul eder" (buffer'a yazar) ama **çalıştırmaz**; komutu çalıştırmak için ayrı bir `Enter` gerekir. `zshrc.alpbah` bu davranışı bozacak bir override yapmaz; yalnızca öneri rengini (`--ab-text-muted`, soluk gri-mavi) ve kaynak stratejisini (`history` + `completion`) özelleştirir. **Bu davranış gerçek terminalde doğrulanmadı** — eklentinin sürümüne göre farklılık ihtimaline karşı M08'de test edilmeli.

## Yazım düzeltme (MASTER_PLAN §4.1)

`setopt CORRECT` açık, `CORRECT_ALL` kapalı tutulur: yalnızca **komut adı** düzeltmesi önerilir, argümanlar/dosya adları sessizce değiştirilmez (AGENTS.md: "Yazım yardımı argümanları/dosya adlarını sessizce yeniden yazmaz"). Zsh bu öneriyi `y/n/a/e` istemiyle sunar; kullanıcı reddedebilir.

## Ctrl+C / Ctrl+R

- `Ctrl+C`: Zsh'nin varsayılan SIGINT/iş kesme davranışı **hiç değiştirilmez**. Bu bilinçli bir tercih — Windows'a benzer bir "kopyala" davranışına eşlenmesi terminalde kabul edilmez (MASTER_PLAN §4.3 madde 5, `shortcuts.json` içindeki `clipboard-ops` istisna notu).
- `Ctrl+R`: geçmiş aramasına bağlanır (`history-incremental-search-backward`). Ayrıntılı/fuzzy görünüm (ör. fzf entegrasyonu) ayrı bir açık karar; bu taslakta yerleşik Zsh aramasıyla sınırlı tutuldu.

## `pkg` tamamlama

`compdef _pkg pkg` satırı yorum halinde bırakıldı; PKG-01/PKG-02'de komut motoru ve alt komutlar sabitlenmeden gerçek bir tamamlama fonksiyonu yazmak MASTER_PLAN'ın "paket motorunun API'si netleşmeden mağaza işlem mantığı yazma" uyarısına aykırı olur.

## Kabul kriterleri karşısında durum

| MASTER_PLAN §4.3 maddesi | Durum |
|---|---|
| 1. Temiz kullanıcıda öneri görünür, ağ gerekmez | Tasarlandı, **test edilmedi** |
| 2. Öneri kabulü komutu çalıştırmaz, Enter gerekir | Eklenti varsayılanına dayanıyor, **test edilmedi** |
| 3. Hatalı komut düzeltmesi açıklanır ve reddedilebilir | `CORRECT` açık, `CORRECT_ALL` kapalı (statik test); **terminalde test edilmedi** |
| 4. Paket adı tamamlama, yazarken gereksiz root/ağ işlemi yok | PKG-01/02 bekliyor, **uygulanmadı** |
| 5. Ctrl+C kesme davranışı korunur | Değiştirilmedi (varsayılan korunuyor); statik test `^C` bağlanmadığını denetler; **terminalde test edilmedi** |
| 6. Logo çıktısı gerçek terminalde doğru renklerle çizilir | `docs/assets/alpbahOS-neofetch-ansi.txt` referansı var, **gerçek terminal doğrulaması yapılmadı** |

## Entegrasyon notu

Gerçek doğrulama Codex tarafında BLFS terminal/oturum zinciri kurulduktan sonra yapılabilir. Bkz. [docs/handoffs/claude/001-desktop-bootstrap.md](../../docs/handoffs/claude/001-desktop-bootstrap.md).
