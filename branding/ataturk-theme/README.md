# Atatürk tema varlık planı — UI-03

Durum: **taslak / kaynak kaydı**. Hiçbir görsel indirilmedi veya repoya eklenmedi — bu bilinçli bir sınır: dosya indirme, bu oturumun güvenlik kurallarına göre kullanıcının açık onayını gerektiren bir eylemdir. Bu belge, kaynak adaylarını ve teknik planı kayda geçirir; nihai görsel seçimi ve indirme onayı kullanıcıdan beklenir.

Kapsam: yalnızca `branding/`. Kaynak: [docs/MASTER_PLAN.md](../../docs/MASTER_PLAN.md) §7.1, [docs/DECISIONS.md](../../docs/DECISIONS.md) D09, [docs/alpbahOS-design-mockups.md](../../docs/alpbahOS-design-mockups.md) §2.

## 1. Gereksinim özeti (D09, MASTER_PLAN §7.1)

- Varsayılan masaüstü ve kilit ekranı Atatürk temalı (açılış/boot ekranı **kapsam dışı**, ayrıca karara bağlanmamış).
- Kaynağı belli görsel seçilir; dağıtım için kullanım/izin bilgisi kayıt altına alınır.
- Görsele uydurma imza veya söz eklenmez.
- 16:9, 16:10 ve ultrawide kırpımlarda yüz, logo ve metin güvenli alanda kalır.
- Kilit ekranında şifre alanı ve kullanıcı adı okunaklı olmalı.
- Masaüstü ikonları için düşük detaylı alan bırakılmalı.

## 2. Araştırılan kaynak adayları (indirilmedi — yalnızca kayıt)

Web araması ile bulundu; **hiçbiri indirilmedi/repoya eklenmedi**. Nihai seçim ve indirme kullanıcı onayı gerektirir.

| Aday | Kaynak | Lisans/durum | Çözünürlük | Uygunluk notu |
|---|---|---|---|---|
| [Mustafa Kemal Ataturk – golden portrait](https://commons.wikimedia.org/wiki/File:Mustafa_Kemal_Ataturk_-_golden_portrait.png) | Wikimedia Commons | Public Domain Mark 1.0 | 210×275 px | **Çok düşük çözünürlük** — 1080p/4K duvar kâğıdı için doğrudan kullanılamaz. |
| [Ataturk1930s.jpg (1932)](https://commons.wikimedia.org/wiki/File:Ataturk1930s.jpg) | Wikimedia Commons, kaynağı mustafakemalim.com | PD-Turkey (Türk telif yasasına göre koruma süresi dolmuş) | 732×987 px | Düşük-orta çözünürlük; tam ekran değil, portre öğesi olarak kullanılabilir. |
| [Mustafa Kemal Atatürk 1921](https://commons.wikimedia.org/wiki/File:Mustafa_Kemal_Atat%C3%BCrk_1921.jpg) | Wikimedia Commons | **CC BY-SA 4.0** (public domain değil — atıf + aynı lisans şartı var) | Doğrulanmadı | Lisans şartı diğerlerinden farklı; kullanılırsa atıf zorunlu. |
| [Mustafa Kemal Ataturk.png (Jean Weinberg, 1927)](https://commons.wikimedia.org/wiki/File:Mustafa_Kemal_Ataturk.png) | Wikimedia Commons | Doğrulanmadı (sayfa okunmadı) | Doğrulanmadı | Çözünürlük/lisans bu turda kontrol edilmedi. |
| ATAM (Atatürk Araştırma Merkezi) portre galerisi | [atam.gov.tr/galeri/ataturk-portreleri](https://atam.gov.tr/galeri/ataturk-portreleri/) | Doğrulanmadı — resmi devlet kurumu, muhtemelen daha yüksek çözünürlük | Doğrulanmadı | **En umut verici aday**; her görsel için ayrı kullanım şartı kontrolü gerekir. |
| TCCB (Cumhurbaşkanlığı) fotoğraf arşivi | [tccb.gov.tr/ata_ozel/fotograf](https://www.tccb.gov.tr/ata_ozel/fotograf/) | Doğrulanmadı | Doğrulanmadı | Resmi kaynak; kullanım şartı sayfa bazında kontrol edilmeli. |
| TTK (Türk Tarih Kurumu) fotoğraf koleksiyonu | [ttk.gov.tr/ataturk-fotograflari-koleksiyonu](https://ttk.gov.tr/ataturk-fotograflari-koleksiyonu/) | Doğrulanmadı | Doğrulanmadı | Resmi kaynak; kullanım şartı sayfa bazında kontrol edilmeli. |

### 2.1 Önemli teknik uyarı

Wikimedia Commons'ta kolayca bulunan, net biçimde kamu malı işaretli adayların çözünürlüğü (**210×275** ve **732×987**) modern bir 1920×1080/4K duvar kâğıdı için **yetersizdir**; doğrudan büyütmek bulanıklaşmaya/piksel bozulmasına yol açar. İki gerçekçi yol var:

1. **Daha yüksek çözünürlüklü resmi arşiv taraması** — ATAM/TCCB/TTK üzerinden, her görsel için ayrı ayrı lisans/kullanım şartı kontrolü yapılarak.
2. **Stilize/vektör işleme** — düşük çözünürlüklü kaynak fotoğraftan, çizgi sanatı veya siluet tarzında yeniden çizilmiş bir versiyon üretmek (tasarım dokümanındaki `alpbahOS` logosunun "terminal + dağ silüeti" diline yakın bir yaklaşım); bu durumda çözünürlük sorunu ortadan kalkar ama üretim (illüstrasyon) ayrı bir iş kalemidir.

Bu karar kullanıcıya/entegratöre bırakılmıştır; bu belge yalnızca seçenekleri ve kısıtları kayda geçirir.

## 3. Kırpım ve güvenli alan planı (16:9 / 16:10 / ultrawide)

| Oran | Hedef çözünürlük örneği | Kural |
|---|---|---|
| 16:9 | 1920×1080 | Yüz/portre dikey eksende ortadan sağa kaydırılabilir (mockup'taki logo yerleşimiyle çakışmasın); alt %15 dock için düşük detaylı bırakılır. |
| 16:10 | 1920×1200 | 16:9 kırpımına göre üstte/altta ek `120px` güvenli boşluk; yüz konumu değişmez. |
| Ultrawide (21:9) | 3440×1440 | Portre yatayda ortalanır; sol/sağ kenarlara doğru düşük detaylı/gradyan alan genişletilir, yüz asla kenara yapışmaz. |

Genel kural: yüz ve logo, tasarım dokümanındaki logo koruma alanı kuralına benzer şekilde (§2.3: sembol yüksekliğinin en az `0.25x`'i kadar boşluk) hiçbir kırpımda kadraj dışına taşmaz veya kenara yapışmaz.

## 4. Kilit ekranı okunabilirlik kuralı

- Şifre alanı ve kullanıcı adı metninin arkasında, `--ab-bg-950` tonunda yarı saydam bir panel (`rgba(11,16,20,0.55)` öneri, ölçülmedi) kullanılır — portre fotoğrafının kontrastından bağımsız okunabilirlik sağlamak için.
- Metin rengi `--ab-text-strong` (`#f4f8fb`); WCAG AA kontrast hedefi (planlandı, ölçülmedi).
- Hatalı giriş mesajı `--ab-danger` (`#ff6575`) — mockup §10 ile tutarlı.

## 5. Masaüstü ikon alanı

Mockup §5.1 kuralına uyularak, sol üst köşede (`Home`, `Trash`, `Documents` ikonları) düşük detaylı/az kontrastlı bir bölge bırakılır; portrenin yüzü bu köşeyle çakışmaz.

## 6. Logo korunması

Duvar kâğıdına `alpbahOS` logosu eklenirse (mockup §5.1: "Duvar kâğıdında logo büyük ama düşük kontrastlı kullanılabilir"), logo kullanım kuralı (§2.3 koruma alanı, §2.4 yasak kullanımlar) aynen geçerlidir — Atatürk portresiyle logo çakıştırılmaz, logo gölgelendirilmez.

## 7. Doğrulanmamış / açık kararlar

1. Nihai görsel kaynağı seçilmedi — kullanıcı onayı gerekiyor (indirme dahil).
2. ATAM/TCCB/TTK sayfalarındaki tam kullanım şartları tek tek okunmadı.
3. Boot ekranının Atatürk temalı olup olmayacağı MASTER_PLAN §7.1'de "henüz istenmemiş" olarak işaretli — bu belge boot ekranını kapsamıyor.
4. Stilize/vektör alternatifi yalnızca fikir düzeyinde; üretilmedi.

## Sonraki adım

Kullanıcı bir kaynak adayı onaylarsa (ATAM/TCCB/TTK'dan yüksek çözünürlüklü bir tarama önerilir), o görsel açık onayla indirilir, kaynak/lisans bilgisi bu dosyaya işlenir ve kırpım/kontrast planı gerçek dosya üzerinde uygulanır. Bkz. [docs/handoffs/claude/001-desktop-bootstrap.md](../../docs/handoffs/claude/001-desktop-bootstrap.md).
