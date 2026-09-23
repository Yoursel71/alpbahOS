# alpbahOS Masaüstü Profili — UI-01

Durum: **taslak**. Bu belge ve bağlı dosyalar statik olarak hazırlandı; gerçek bir KDE Plasma oturumunda henüz test edilmedi (bu oturumda Linux çalışma ortamı yok). "Uygulandı" değil, "uygulanabilir taslak" olarak okunmalıdır.

Kapsam: yalnızca `profiles/desktop/`. `pkg` backend'i, toolchain, kernel, rootfs ve Hyper-V ayarlarına dokunulmadı ([AGENTS.md](../../AGENTS.md), [CLAUDE_START.md](../../docs/CLAUDE_START.md)). Hazır KDE/Qt/GTK bileşenleri özelleştirilir; yeni compositor veya masaüstü kabuğu önerilmez.

Kaynaklar: [docs/MASTER_PLAN.md](../../docs/MASTER_PLAN.md) §6–7, [docs/alpbahOS-design-mockups.md](../../docs/alpbahOS-design-mockups.md), [docs/assets/alpbahOS-logo.png](../../docs/assets/alpbahOS-logo.png).

## 1. Global tema (Plasma Look-and-Feel)

- Paket kimliği (önerilen): `org.alpbahos.solid.desktop`
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
| Plasma global tema paketi | Taslak, test edilmedi | Gerçek Plasma oturumu gerekli (M07 sonrası) |
| Renk şeması (.colors) | Taslak dosya hazır, içe aktarma test edilmedi | `colorscheme/alpbah-dark.colors` |
| İkon teması | Karar açık | Breeze-tint vs Papirus, ölçüm bekliyor |
| Pencere dekorasyonu | Taslak, test edilmedi | Breeze tabanlı, değer önerisi hazır |
| Panel/dock | Karar açık | Native panel vs Latte Dock, PERF-01 bekliyor |
| GTK eşleme | Taslak, test edilmedi | kde-gtk-config planı var, çalıştırılmadı |
| Qt (Plasma dışı) eşleme | Taslak, test edilmedi | qt5ct/qt6ct + Kvantum planı var |

## 7. Codex için gereken paketler (BLFS/entegrasyon girdisi)

Aşağıdaki liste bir talep listesidir, kurulum komutu değildir; kaynak/checksum doğrulaması AGENTS.md kuralına göre Codex tarafında yapılmalıdır:

- `plasma-desktop`, `plasma-workspace`, `kwin`, `breeze`, `breeze-gtk`
- `kde-gtk-config`
- `qt5ct` veya `qt6ct`, `kvantum`
- (Açık karar) `papirus-icon-theme` — yalnızca ikon kararı Papirus yönünde netleşirse
- (Açık karar) `latte-dock` — yalnızca dock kararı Latte yönünde netleşirse

## 8. Entegrasyon notu

Bu taslak `claude/desktop-bootstrap` dalında hazırlandı, `main`'e birleştirilmedi. Gerçek görsel/işlevsel doğrulama, Codex tarafında BLFS grafik/oturum zinciri (M06–M07) tamamlanıp çalışan bir Plasma oturumu kurulduktan sonra yapılabilir. Bkz. [docs/handoffs/claude/001-desktop-bootstrap.md](../../docs/handoffs/claude/001-desktop-bootstrap.md).
