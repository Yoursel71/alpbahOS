# alpbahOS Masaüstü Profili — UI-01

Durum: **M08 ilk dilim — kurulabilir paket hazır, gerçek Plasma oturumunda test edilmedi.** Look-and-feel paketi, Atatürk duvar kâğıdı, sembol ikonu, sistem varsayılanları ve kurulum betiği repoda; biçimleri Plasma 6.4.4 kaynak koduna göre yazıldı ve statik testlerden geçti (`tests/test_m08_desktop_profile.py`). Gen2 imajına kurulup ekran görüntüsüyle doğrulanmadıkça "uygulandı" sayılmaz. Ayrıntı: [015 devir belgesi](../../docs/handoffs/claude/015-m08-lookandfeel-wallpaper-shortcuts.md).

## 0. M08 dosya düzeni ve kurulum

| Repo yolu | Kurulum hedefi | İçerik |
|---|---|---|
| `lookandfeel/org.alpbahos.solid.desktop/` | `/usr/share/plasma/look-and-feel/org.alpbahos.solid.desktop/` | `metadata.json`, `contents/defaults` (renk şeması, ikon, dekorasyon, duvar kâğıdı adı), `contents/layouts/org.kde.plasma.desktop-layout.js` (üst panel + dock) |
| `colorscheme/alpbah-dark.colors` | `/usr/share/color-schemes/alpbah-dark.colors` | Renk şeması |
| `../../branding/ataturk-theme/wallpaper/alpbahOS-Ataturk/` | `/usr/share/wallpapers/alpbahOS-Ataturk/` | `Wallpaper/Images` paketi (5 çözünürlük) |
| `../../branding/icons/hicolor/` | `/usr/share/icons/hicolor/` | `alpbahos` sembol ikonu (32–256 px, geçici raster) |
| `xdg/kdeglobals` | `/etc/xdg/kdeglobals` | `LookAndFeelPackage=org.alpbahos.solid.desktop` |
| `xdg/kwinrc` | `/etc/xdg/kwinrc` | Solid: blur/kontrast efekti kapalı |
| `../shortcuts/generated/kglobalshortcutsrc` | `/etc/xdg/kglobalshortcutsrc` | Windows'a tanıdık kısayollar ([conflicts.md](../shortcuts/conflicts.md)) |

Kurulum: `profiles/desktop/install-desktop-profile.sh --destdir <kök> [--datadir /usr/share] [--manifest dosya]`. Betik hedef kökü zorunlu ister, `/` için ayrıca `--allow-live-root` ister, farklı içerikli dosyanın üzerine `--force` olmadan yazmaz ve kurduğu her dosyayı SHA-256 ile manifest'e yazar. Builder `/mnt/lfs` rootfs'ine kurulum entegratörün (Codex) işidir. Plasma `/opt/kf6` önekiyle kurulu olduğundan `XDG_DATA_DIRS` içinde `/usr/share` bulunmalı (ayrı `--datadir` de verilebilir).

Mekanizma (Plasma 6.4.4 kaynağından): `startplasma` ilk oturumda `kdeglobals [KDE] LookAndFeelPackage` paketinin `contents/defaults` dosyasını `~/.config/kdedefaults/` altına uygular; varsayılan duvar kâğıdı `libkworkspace` `DefaultWallpaper` ile aynı dosyanın `[Wallpaper] Image` anahtarından bulunur (kilit ekranı da aynı varsayılanı kullanır); `contents/layouts/...-layout.js` yalnız düzeni olmayan yeni kullanıcıda ya da `plasma-apply-lookandfeel -a org.alpbahos.solid.desktop --resetLayout` ile çalışır.

Kapsam: yalnızca `profiles/desktop/`. `pkg` backend'i, toolchain, kernel, rootfs ve Hyper-V ayarlarına dokunulmadı ([AGENTS.md](../../AGENTS.md), [CLAUDE_START.md](../../docs/CLAUDE_START.md)). Hazır KDE/Qt/GTK bileşenleri özelleştirilir; yeni compositor veya masaüstü kabuğu önerilmez.

Kaynaklar: [docs/MASTER_PLAN.md](../../docs/MASTER_PLAN.md) §6–7, [docs/alpbahOS-design-mockups.md](../../docs/alpbahOS-design-mockups.md), [docs/assets/alpbahOS-logo.png](../../docs/assets/alpbahOS-logo.png).

## 1. Global tema (Plasma Look-and-Feel)

- Paket kimliği: `org.alpbahos.solid.desktop` ([`lookandfeel/`](lookandfeel/org.alpbahos.solid.desktop/metadata.json))
- Üst tema (parent/fallback): **Breeze Dark** — olgun, erişilebilirlik desteği test edilmiş, düşük ek yük.
- Paket biçimi KDE'nin standart `lookandfeel` yapısını izler: `metadata.json` + `contents/{colorscheme,icons,splash,lockscreen,windowswitcher,...}`. Yeni bir paket formatı icat edilmez.
- Varsayılan profil adı `alpbah-solid` (bkz. MASTER_PLAN §7.1). Glass/Liquid ayrı profil paketleri olarak düşünülür, aynı token setinden türetilir (bkz. `tokens.json`).

## 2. Renk şeması

Taslak KDE renk şeması dosyası: [`colorscheme/alpbah-dark.colors`](colorscheme/alpbah-dark.colors). Değerler `docs/alpbahOS-design-mockups.md` §3.1 renk token'larından hex→RGB dönüştürülerek üretildi (dönüşüm elle yapıldı, System Settings → Renkler içinde içe aktarma testi **çalıştırılmadı**).

| Rol | Token | Hex | Kullanım |
|---|---|---|---|
| Pencere zemini | `--ab-bg-900` | `#11171c` | Window arka planı |
| Görünüm zemini | `--ab-bg-950` | `#0b1014` | View/terminal zemini |
| Yüzey | `--ab-surface-800` | `#16232d` | Kart, buton zemini |
| Vurgu (seçim/odak) | `--ab-cyan` | `#00aeef` | Seçim, odak dekorasyonu, aktif pencere kenarlığı |
| İkincil vurgu | `--ab-orange` | `#f5a623` | Uyarı, birincil eylem butonu, imleç |
| Metin | `--ab-text` / `--ab-text-strong` | `#d4e0e8` / `#f4f8fb` | Gövde / başlık metni |

## 3. İkon teması

Açık teknik seçim — **test edilmedi**, iki aday var:

1. **Papirus-Dark + `papirus-folders` accent** — klasör rengini cyan'a çevirmek kolay (hazır araç), geniş uygulama kapsamı. Kaynak: ayrı upstream proje; Codex tarafında kaynak/checksum doğrulaması ABI-01/BUILD-01 kapsamında yapılmalı.
2. **Breeze-Dark (tint edilmiş)** — ek bağımlılık yok, LFS/BLFS zincirine zaten dahil olması muhtemel, düşük RAM hedefine (P08) daha uygun.

Öneri: önce Breeze-Dark tint ile başla (bağımlılık eklemez), Papirus'u P08 ölçümlerinden sonra görsel zenginlik için değerlendir. Karar DECISIONS.md'ye işlenmeli.

## 4. Pencere dekorasyonu

- Temel: **Breeze** dekorasyonu (Aurorae/Breeze ayar API'si üzerinden özelleştirilir, yeni dekorasyon motoru yazılmaz).
- Aktif pencere kenarlığı: `--ab-cyan`, `1px` (mockup §4.2 ile birebir).
- Pasif pencere kenarlığı: `--ab-border` (`#29404f`).
- Köşe yarıçapı: `10px` (genel), buton/rozet `999px` — bkz. `tokens.json` → `radius`.
- Ağır blur/gölge yok (Solid profilinde); Glass profilinde kontrollü saydamlık ayrı token setiyle.

## 5. Panel ve dock

Mockup §4.1 düzeni korunur: üst panel (32–36px, `--ab-bg-950` yarı saydam) + merkez/alt dock.

Açık teknik seçim — **test edilmedi**:

| Seçenek | Artı | Eksi |
|---|---|---|
| Plasma yerel yüzen panel (icons-only task manager) | Ek bağımlılık yok, düşük RAM (P08 önceliği) | Mockup'taki tam görsel yoğunluğu native araçlarla sınırlı olabilir |
| Latte Dock | Mockup'a daha yakın görsel sonuç, hazır ve yaygın kullanılan açık kaynak proje | Ayrı süreç/RAM ek yükü; eski PC hedefiyle ölçülmeli |

Öneri: düşük kaynak profilinde (P08) yerel panel, genel/güçlü profilde Latte Dock değerlendirmesi — ölçüm sonrası PERF-01'de karara bağlanır.

**M08 uygulaması (26 Eylül 2026):** varsayılan düzen Plasma'nın yerel panelleriyle yazıldı, ek bağımlılık yok. Üst panel 34 px, opak (Solid): Kickoff (alpbahOS sembolü) + `org.kde.plasma.windowlist` (etkin pencere adı), ortada saat, sağda sistem tepsisi. Dock: alt ortada yüzen, içeriğe göre genişleyen `icontasks` paneli; başlatıcılar Konsole, `preferred://filemanager`, `preferred://browser`, System Settings. Mockup'tan bilinçli farklar: (1) dock sonundaki "Uygulamalar" yerine uygulama menüsü üst paneldeki alpbahOS sembolündedir — iki başlatıcı olursa tek başına Win tuşu yalnız ilkini açar (`shellcorona.cpp`); (2) App Center, `alp` mağaza arayüzü hazır olunca (PKG-02) eklenecek; (3) mockup üst paneli yarı saydam gösterir, Solid profili opak yüzey ister (MASTER_PLAN §7.2) — yarı saydamlık Glass profiline bırakıldı.

Panel içeriği (mockup §4.1'den):
- Sol: küçük alpbahOS sembolü + aktif uygulama adı.
- Orta: tarih/saat.
- Sağ: ağ, ses, pil/güç, hızlı ayarlar.
- Dock sırası: Terminal, Dosyalar, Tarayıcı, Ayarlar, App Center, Uygulamalar.

## 6. GTK/Qt eşleme

- GTK2/3/4 senkronizasyonu için **kde-gtk-config** (hazır KDE bileşeni) kullanılır.
- Plasma dışı Qt5/Qt6 uygulamaları için **qt5ct / qt6ct** + **Kvantum** teması, aynı renk token'larından üretilir.
- AGENTS.md/MASTER_PLAN uyarısı korunur: tek tema paketinin GTK/Qt/üçüncü taraf uygulamaların tamamını birebir aynı gösterileceği varsayılmaz. Aşağıdaki tablo test kapsamını sınırlar.

### 6.1 Doğrulama durumu

| Bileşen | Durum | Not |
|---|---|---|
| Plasma global tema paketi | Paket yazıldı, statik test geçti; Plasma'da yüklenmedi | `lookandfeel/org.alpbahos.solid.desktop/` |
| Renk şeması (.colors) | Paket varsayılanına bağlandı; içe aktarma test edilmedi | `colorscheme/alpbah-dark.colors` |
| İkon teması | `breeze-dark` seçildi (bağımlılık eklemez); Breeze ikonları Gen2 imajında eksik (M07 bulgusu) | Papirus ölçüm sonrasına bırakıldı |
| Pencere dekorasyonu | `org.kde.breeze` seçildi; imajda Breeze dekorasyonunun kurulu olduğu doğrulanmadı | Özel renk ayarı yok, renk şemasından gelir |
| Panel/dock | Yerel Plasma panelleriyle düzen yazıldı; çalıştırılmadı | Latte Dock kullanılmadı |
| Atatürk duvar kâğıdı | Paket üretildi, güvenli alan testi geçti; Plasma'da gösterilmedi | `branding/ataturk-theme/wallpaper/` |
| Kilit ekranı | Duvar kâğıdı varsayılanı hazır; KScreenLocker derlenmediği için çalışmaz | SCREENLOCK-01 |
| GTK eşleme | Taslak, test edilmedi | kde-gtk-config planı var, çalıştırılmadı |
| Qt (Plasma dışı) eşleme | Taslak, test edilmedi | qt5ct/qt6ct + Kvantum planı var |

## 7. Codex için gereken paketler (BLFS/entegrasyon girdisi)

Aşağıdaki liste bir talep listesidir, kurulum komutu değildir; kaynak/checksum doğrulaması AGENTS.md kuralına göre Codex tarafında yapılmalıdır:

- `plasma-desktop`, `plasma-workspace`, `kwin`, `breeze`, `breeze-gtk`
- M08 düzeni için: `breeze-icons` (panel/başlatıcıda ikon yok bulgusu), `kirigami-addons` (Kickoff açılmıyor), Türkçe karakterli font paketi (Noto/DejaVu/Liberation; imajda font yoktu), `konsole`, `dolphin`, `systemsettings`, bir tarayıcı (dock başlatıcıları), `spectacle` ve `plasma-systemmonitor` (kısayollar)
- `kde-gtk-config`
- `qt5ct` veya `qt6ct`, `kvantum`
- (Açık karar) `papirus-icon-theme` — yalnızca ikon kararı Papirus yönünde netleşirse
- (Açık karar) `latte-dock` — yalnızca dock kararı Latte yönünde netleşirse

## 8. Entegrasyon notu

UI-01 taslağı `claude/desktop-bootstrap` dalında hazırlanıp main'e alındı ([001](../../docs/handoffs/claude/001-desktop-bootstrap.md)). M08 ilk dilimi `claude/m08-lookandfeel-shortcuts` dalındadır; Gen2 doğrulama adımları [015](../../docs/handoffs/claude/015-m08-lookandfeel-wallpaper-shortcuts.md) içindedir.
