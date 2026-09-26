# Kısayol kullanıcı yardımı — UI-02

Durum: **tasarım planı**, gerçek bir arayüz bileşeni değil; hiçbir parçası uygulanmadı.

Amaç: D08 kararını ("Windows'a tanıdık kısayollar hedeflenecek") somut bir keşif/yardım yüzeyine bağlamak. Kaynak: [docs/DECISIONS.md](../../docs/DECISIONS.md) D08, [docs/MASTER_PLAN.md](../../docs/MASTER_PLAN.md) §6.

## 1. İlk oturum kısa referans kartı

İlk girişte, yalnızca ilk oturumda gösterilen, kapatılabilir bir bildirim/kart: en sık kullanılan 5 kısayolu listeler (`Win+D`, `Win+E`, `Win+L`, `Alt+Tab`, `Win+I`). Tek seferlik; her açılışta tekrar gösterilmez. Kalıcı bir "tekrar göster" seçeneği Ayarlar'da bulunur.

## 2. Kalıcı erişim

System Settings → Kısayollar ekranında ayrı bir "Windows kullanıcıları için" filtre/grup etiketi; `shortcuts.json`'daki her satır bu gruba işaretlenir. Yeni bir ayarlar sayfası **yazılmaz** — Plasma'nın yerleşik Kısayollar modülü kullanılır, yalnızca gruplama/etiketleme eklenir.

## 3. Sıfırlama

Her kısayol satırı, Plasma'nın System Settings → Shortcuts ekranının **yerleşik** "Varsayılana Sıfırla" özelliğiyle geri alınabilir olmalı (MASTER_PLAN §6: *"ayarlarda düzenlenebilir ve varsayılana dönebilir"*). Yeni bir sıfırlama mekanizması icat edilmez.

> M08 bulgusu (Plasma 6.4.4 kaynağı): yerleşik "Varsayılanlar" düğmesi, eylemi kaydeden uygulamanın bildirdiği **KDE** varsayılanına döner; alpbahOS profili `/etc/xdg/kglobalshortcutsrc` katmanındadır. alpbahOS profiline dönüş için kullanıcının `~/.config/kglobalshortcutsrc` içindeki ilgili girdinin silinmesi gerekir. Bu fark açık karar olarak [conflicts.md](conflicts.md) §4'te.

## 4. Kapsam dışı bırakılan fikir

Meta tuşuna basılı tutunca kısayol overlay'i gösterme fikri (bazı masaüstü ortamlarında var) — yalnızca seçilen Plasma sürümünde **hazır** bir özellik olarak mevcutsa değerlendirilir; bunun için özel bir bileşen yazılmaz (AGENTS.md: hazır bileşenleri özelleştir, yeni compositor/kabuk parçası icat etme).

## Doğrulanmamış / test edilmedi

Bu belgedeki her madde tasarım seviyesinde bir plandır. Gerçek bildirim/kart/gruplama mekanizması hiçbir Plasma oturumunda uygulanmadı veya test edilmedi.
