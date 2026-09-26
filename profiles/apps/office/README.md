# OFFICE-01 — ofis uyumluluk test planı

Durum (26 Eylül 2026): **plan ve test belgesi üreticisi hazır; alpbahOS üzerinde hiçbir ofis testi yapılmadı.** OFFICE-01: Claude plan, Codex test. Kaynak: [MASTER_PLAN §11](../../../docs/MASTER_PLAN.md) ("LibreOffice günlük belge işlerini ilk günden sağlar; Microsoft Word ile aynı uygulama diye sunulmaz"; Word 2016/2019/2021 Wine'da ayrı prefix'lerde denenir).

## 1. Test belgeleri

[`office_fixtures.py`](office_fixtures.py) (stdlib) yalnız bu projenin yazdığı içerikle `alpbah-test.docx` ve `alpbah-test.xlsx` üretir: Türkçe karakterler (ğüşıöç ĞÜŞİÖÇ, İ/ı ayrımı), sekme, € ₺ ve akıllı tırnaklar, 3x2 tablo, `B4 = SUM(B2:B3)` formülü. `check` alt komutu kaydedilmiş dosyadaki metni ve hücre değerlerini beklenenle karşılaştırır; paylaşılan dizgi tablosu (sharedStrings) ve satır içi dizgiler desteklenir. Biçim/sayfa düzeni bu betikle değil, PDF çıktısı ve gözle değerlendirilir.

**Referans doğrulama (26 Eylül 2026, bu depoyu hazırlayan Windows makinesi):** Microsoft Word 16.0 ve Excel 16.0 üretilen dosyaları hatasız açtı; Excel `B4` için `=SUM(B2:B3)` = 42 hesapladı. Word/Excel ile yeniden kaydedilen dosyalar `check` ile GEÇTİ. Bu, belgelerin geçerli OOXML olduğunu gösterir; alpbahOS/LibreOffice sonucu değildir. Office çıktıları yazar bilgisi taşıdığı için repoya eklenmedi.

## 2. LibreOffice (P09, D22/D32'den bağımsız — önce bu)

| # | Senaryo | Adım | Geçti ölçütü |
|---|---|---|---|
| L1 | DOCX aç/kaydet | `alpbah-test.docx` → Writer → DOCX kaydet | `check` GEÇTİ; Türkçe karakterler ve tablo bozulmadan |
| L2 | XLSX aç/kaydet | `alpbah-test.xlsx` → Calc → XLSX kaydet | `check` GEÇTİ; formül korunur, değer 42 |
| L3 | Başsız dönüşüm | `soffice --headless --convert-to docx --outdir out alpbah-test.docx` (ve xlsx) | `check` GEÇTİ |
| L4 | PDF | Writer → PDF dışa aktar; CUPS varsa PDF yazıcıya yazdır | PDF'te Türkçe glifler doğru (kare yok), metin seçilebilir |
| L5 | Yazı tipi eşleme | Calibri/Cambria/Arial/Times içeren belge (kendi ürettiğimiz) | Carlito/Caladea/Liberation ile metrik uyumlu eşleme; satır kayması kaydedilir |
| L6 | Türkçe yazım denetimi | Writer'da Türkçe metin | tr_TR sözlüğü (hunspell) etkin; yanlış kelime işaretlenir |
| L7 | Türkçe Q klavye | Writer'da ğüşıöçİ yazma | Tüm karakterler doğru girer |
| L8 | PPTX | Impress'te sunu oluştur → PPTX kaydet → yeniden aç | Metin ve slayt sayısı korunur (üretici PPTX yazmaz; Impress ile oluşturulur) |
| L9 | Varsayılan ilişki | Dolphin'de .docx/.xlsx/.pptx çift tık | `profiles/apps/generated/mimeapps.list`'teki LibreOffice uygulaması açılır |

Gerekli paketler (Codex BLFS): LibreOffice, Carlito ve Caladea fontları (Calibri/Cambria metrik uyumu), Liberation fontları, hunspell + Türkçe sözlük, CUPS (yazdırma).

## 3. Microsoft Office / Wine — karar bekliyor

Bu bölüm **D22/D32 çatışması (COMPAT-01) çözülmeden uygulanmaz ve sonuç vaat edilmez.** Wine .exe ilişkisi de bu yüzden `mimeapps.list`'e yazılmadı (`profiles/apps/apps.json` → `karar_bekleyen`).

Karar sonrası plan (MASTER_PLAN §11): Office 2016, 2019 ve 2021 için ayrı temiz Wine prefix'i; kullanıcının lisanslı kurulum medyası (ISO'ya gömülmez); Click-to-Run/MSI ayrımı ve tam sürüm kaydı; her sürümde W1 kurulum, W2 Word'de `alpbah-test.docx` aç/kaydet (`check`), W3 Excel'de `alpbah-test.xlsx` (formül 42), W4 PDF/yazdır, W5 Türkçe Q giriş, W6 kapat/yeniden aç. D32 korunursa yalnız 64-bit Office ve Wine'ın yeni WoW64 modu denenebilir; bu yolun Office kurucusu için çalıştığı doğrulanmadı.

## 4. Kayıt

Her senaryo sürüm, prefix, komut ve sonuçla `docs/verification/office01-<tarih>.md` altına geçti/kaldı olarak yazılır. Hiçbiri çalıştırılmadan "Word çalışıyor" ya da "LibreOffice DOCX uyumlu" denmez.
