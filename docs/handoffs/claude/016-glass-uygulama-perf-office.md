# Claude devir belgesi 016: Glass profili, varsayılan uygulamalar, PERF-01 ve OFFICE-01

```text
Görev ID / durum: M08 Glass (D10/P04), APPS-01 Claude tarafı, PERF-01 yöntem/araç, OFFICE-01 plan. Hepsi dosya düzeyinde hazır ve birim testli; hiçbiri alpbahOS üzerinde çalıştırılmadı.
Çalışılan host ve branch/commit: YRSLF dışında Windows makinesi (Hyper-V/Builder/Gen2 erişimi yok); dal claude/m08-lookandfeel-shortcuts, PR Yoursel71/alpbahOS#1'e eklendi.
Değişen dosyalar: aşağıda.
Gerçekleştirilen davranış: aşağıda.
Çalıştırılan doğrulama ve sonuç: tests/test_m08_desktop_profile.py 36/36 (Windows, Python 3.14.4); OFFICE fixture'ları yerel Word/Excel 16.0 ile gidiş-dönüş GEÇTİ. Linux/VM testi çalıştırılmadı.
Bilinen sorun ve açık karar: aşağıda.
Entegrasyon için gereken: aşağıda "Codex için".
Sonraki eylem: 015'teki Gen2 adımlarından sonra `alpbah-gorunum durum` ve PERF-01 Solid ölçümü.
```

## Kapsam dışı bırakılan Claude işleri

- **PKG-01/PKG-02 (`alp` ve mağaza sözleşmesi):** 26 Eylül'de başka bir Claude oturumu `alp.py` üzerinde aktif çalışıyordu (main'de aynı gün 5 `alp` commit'i). Aynı dosya grubunu eşzamanlı değiştirmemek için bu oturumda dokunulmadı.
- **VM gerektiren doğrulamalar** (SHELL-01 oturum testi, UI-01/02/03 görüntü, PERF-01 ölçümleri): erişim yok. Adımlar 015 ve `profiles/perf/README.md` içinde.

## Ne yapıldı

**1. Glass profili (`profiles/desktop/bin/alpbah-gorunum`).** `durum | solid | glass [--zorla] [--deneme]`. Yalnız hazır KDE yollarını kullanır:
- kwriteconfig6/kreadconfig6 ile kullanıcı `kwinrc` ve `alpbahrc`;
- KWin D-Bus: `/Effects` `loadEffect`/`unloadEffect` blur ve contrast, `/KWin` `reconfigure` ve `supportInformation`;
- plasmashell `evaluateScript` ile panel `opacity`.

Glass'ta blur `BlurStrength=8` ve `NoiseStrength=0` (KWin varsayılanı 15). Panel `translucent`. KWin `supportInformation` softpipe/LLVMpipe/Software rasterizer ya da OpenGL dışı compositing bildirirse Glass reddedilir (çıkış kodu 3, MASTER_PLAN §7.3); `--zorla` bunu aşar. Değerler `tokens.json` → `profiles.*.kde` ile testte eşlenir. Kurulum betiği aracı `/usr/bin`'e 0755 ile kurar. Liquid uygulanmadı; plan ve ölçüt `profiles/desktop/liquid-prototype.md` içinde. KWin blur'un yalnız iki ayarı olduğundan gerçek kırılma ayrı bir efekt ister.

**2. Varsayılan uygulamalar (`profiles/apps/`).** `apps.json` tek kaynak: MASTER_PLAN §11 ihtiyacı → uygulama → masaüstü dosyası → varsayılan MIME. Üretici `/etc/xdg/mimeapps.list` yazar ve bir MIME türünün iki uygulamaya atanmasını, karar bekleyen türlerin sızmasını reddeder. Upstream doğrulama:
- Okular'da PDF, `org.kde.okular.desktop`'ta değil `okularApplication_pdf.desktop`'ta. Varsayılan buna göre yazıldı.
- VLC 3.0.21 (19/19) ve LibreOffice `libreoffice-25-8` (Writer/Calc/Impress) listeleri tuttu.
- Gwenview ve Ark listeleri derleme zamanında oluşuyor; Firefox ve LibreOffice dosya adları BLFS kurulum adımında oluşuyor. Bunlar işaretlendi.

Wine (.exe), Steam ve mağaza `karar_bekleyen` listesinde; dosyaya girmez. Test, dock başlatıcılarının profilde karşılığı olduğunu da denetler. Bu denetim, System Settings'in eksik olduğunu yakaladı ve profile eklendi.

**3. PERF-01 (`profiles/perf/`).** KWin 6.4.4, `KWIN_LOG_PERFORMANCE_DATA=1` ile her çıkış için `kwin perf statistics <çıkış>.csv` yazıyor (`src/core/renderloop.cpp`). `analyze_kwin_perf_csv.py` bu dosyadan kare süresi (pageflip farkı; medyan/p95/p99), render süresi, geç kare ve bütçe aşımı üretir; `--budget-ms 16.7` ile eşik denetler. `collect_session_metrics.py` salt okunurdur: `/proc` bellek, izlenen masaüstü süreçlerinin PSS/RSS değerleri, kullanıcının toplam PSS'i, KWin renderer/sürücü/etkin efektler ve görünüm profili. P08 hedefiyle (boşta ≤ 1 GiB) karşılaştırır. README'de sahneler (boşta, pencere sürükleme, Overview, Konsole çıktısı), Solid/Glass tekrarı ve kayıt yeri var.

**4. OFFICE-01 (`profiles/apps/office/`).** `office_fixtures.py` yalnız projenin yazdığı içerikle DOCX/XLSX üretir: Türkçe İ/ı, sekme, ₺/€, tablo, `SUM`. `check` alt komutu kaydedilmiş dosyayı karşılaştırır (sharedStrings destekli). Bu makinedeki Word/Excel 16.0 dosyaları açtı; `=SUM(B2:B3)` = 42 hesaplandı ve yeniden kaydedilen dosyalar `check`'ten geçti. Office çıktıları yazar bilgisi taşıdığı için repoya konmadı. Plan: LibreOffice L1–L9 hemen uygulanabilir; Word/Wine bölümü D22/D32 (COMPAT-01) kararına kadar askıda.

## Değişen dosyalar

- Yeni: `profiles/desktop/bin/alpbah-gorunum`, `profiles/desktop/liquid-prototype.md`
- Yeni: `profiles/apps/{README.md,apps.json,generate_mimeapps.py,generated/mimeapps.list}`, `profiles/apps/office/{README.md,office_fixtures.py}`
- Yeni: `profiles/perf/{README.md,analyze_kwin_perf_csv.py,collect_session_metrics.py}`
- Yeni: `docs/handoffs/claude/017-codex-betik-incelemesi.md`, bu belge
- Güncellendi: `profiles/desktop/tokens.json` (profiles.*.kde), `profiles/desktop/README.md` (§0 tablo, §5.1, §6.1), `profiles/desktop/install-desktop-profile.sh` (`--bindir`, araç ve mimeapps; 22 dosya), `tests/test_m08_desktop_profile.py` (19 → 36 test), `.gitattributes` (bin ve generated için LF)

## Bilinen sorun ve açık karar

1. Mevcut Gen2 imajı softpipe/VGEM ile çizdiği için orada Glass'ın reddedilmesi beklenir. Glass'ın görsel ve performans değerlendirmesi donanım hızlandırmalı bir ortam ister.
2. `alpbah-gorunum` panel opaklığını tüm panellere uygular; panel başına ayrım yok.
3. Uygulamaların hiçbiri imajda yok. `mimeapps.list` doğru olsa da işe yaraması derlemelere bağlı.
4. PERF-01 CSV'sinin konumu (KWin sürecinin çalışma dizini) gerçek oturumda doğrulanmadı.
5. D22/D32 kararı Wine/Steam/Office bölümlerini ve `.exe` ilişkisini bekletiyor.

## Codex için

- APPS-01 paketleri: Dolphin, Konsole, KWrite, Okular (poppler), Gwenview (+kimageformats), Ark (+libarchive), Spectacle, VLC, KCalc, Plasma System Monitor, Filelight, Firefox, LibreOffice; fontlar: Carlito, Caladea, Liberation, Noto/DejaVu; hunspell + tr_TR sözlüğü; CUPS.
- PERF-01 ölçümü için test oturumunda `plasma-kwin_wayland.service` drop-in'i ile `KWIN_LOG_PERFORMANCE_DATA=1` (yalnız ölçüm süresince).
- İkinci göz inceleme bulguları: [017](017-codex-betik-incelemesi.md). Öncelik: repoda olmayan dört M07/M09 dosyası ve `apply-m2-rootfs-fixes.sh`'ın `alp.py`yi geri döndürmesi.
