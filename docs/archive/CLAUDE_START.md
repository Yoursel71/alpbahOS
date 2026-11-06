# Claude Code — ilk görev paketi

Çalışma klasörü: `C:\alpbahOS-claude`. Bu klasör ayrı Git worktree'dir; yoksa yanlış klasörde başlamadan repo durumunu kontrol et. Dal: `claude/desktop-bootstrap`.

## Önce oku

1. `AGENTS.md` ve `CLAUDE.md`.
2. `docs/MASTER_PLAN.md`, `docs/DECISIONS.md`, `docs/BACKLOG.md`.
3. `docs/alpbahOS-design-mockups.md` ve seçilmiş logo.

## İlk oturumun amacı

UI-01 ve SHELL-01 için uygulanabilir ilk dosya taslaklarını hazırla. Linux çalıştırma ortamın yoksa statik doğrulamayı ve gerçek oturum testi beklediğini açıkça yaz. Hedef makinede kurulu masaüstü varmış gibi davranma.

Teslimler:

- `profiles/desktop/README.md`: Plasma global theme, renk şeması, ikon, pencere dekorasyonu, panel/dock ve GTK/Qt eşleme planı.
- `profiles/desktop/tokens.json`: mevcut logo paleti, tipografi/boşluk ve Solid/Glass profili token'ları.
- `profiles/shortcuts/shortcuts.json`: ana plandaki kısayol → eylem eşlemesi; upstream eylem ID'leri doğrulanmamışsa açıkça işaretle.
- `profiles/shell/README.md` ve etkileşimli Zsh/Konsole yapılandırma taslağı: soluk öneri, Tab, geçmiş araması, kabul/çalıştır ayrımı ve düzeltme davranışı.
- `docs/handoffs/claude/001-desktop-bootstrap.md`: değişiklikler, testler, bekleyen entegrasyon ve gereken paketler.

## Sınırlar ve kabul

- Hazır KDE/Zsh bileşenlerini özelleştir; yeni compositor veya paket yöneticisi yazma.
- Üst panel ve dock düzenini koru; varsayılanı `alpbah-solid` yap.
- Türkçe arayüz/Türkçe Q ve Atatürk masaüstü/kilit kararı korunur.
- Atatürk görseli bulunmadıysa kaynak/yerleşim planı hazırla; kaynak yokken varmış gibi işaretleme.
- Glass/Liquid seçenek; düşük RAM ve okunabilirlik hedefleri ana planda.
- `pkg` backend'i, toolchain, kernel, rootfs ve Hyper-V ayarlarına müdahale etme.
- Shell önerileri otomatik çalışmaz; kullanıcı scriptlerinin yorumlayıcısını değiştirme.
- Git diff ve dosya doğrulaması yap; gerçek masaüstü testi yoksa açık yaz.
- Kendi dalında küçük, anlaşılır commit oluştur; main'i veya Codex dalını değiştirip birleştirme.

Sonunda devir belgesinin yolunu, commit'i, değişen dosyaları ve tek sonraki entegrasyon adımını Türkçe bildir.
