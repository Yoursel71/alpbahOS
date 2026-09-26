# Varsayılan uygulama profili — APPS-01 (Claude tarafı)

Durum (26 Eylül 2026): **dosya düzeyinde hazır, test edilmedi.** Listedeki uygulamaların hiçbiri Gen2 test imajında kurulu değil; derleme ve kurulum Codex'in BLFS işidir (APPS-01 sahibi Codex, Claude inceleme + profil). Kaynak: [MASTER_PLAN §11](../../docs/MASTER_PLAN.md), [DECISIONS P09](../../docs/DECISIONS.md).

- Tek kaynak: [`apps.json`](apps.json) — ihtiyaç → uygulama → masaüstü dosyası → varsayılan MIME türleri → MASTER_PLAN kabul senaryosu.
- Üretici: [`generate_mimeapps.py`](generate_mimeapps.py) → [`generated/mimeapps.list`](generated/mimeapps.list), kurulum hedefi `/etc/xdg/mimeapps.list` (`profiles/desktop/install-desktop-profile.sh` kurar). Kullanıcının kendi seçimi `~/.config/mimeapps.list` içinde her zaman önce gelir.
- Dock'taki `preferred://browser` ve `preferred://filemanager` başlatıcıları bu dosyadaki `x-scheme-handler/https` ve `inode/directory` ilişkilerinden çözülür.

## Doğrulama düzeyi

| Kod | Anlamı | Uygulamalar |
|---|---|---|
| `upstream` | MIME türü upstream masaüstü dosyasında var | Dolphin, KWrite, Okular (PDF), VLC, Konsole/Spectacle/KCalc/System Monitor (MIME yok) |
| `derleme_zamani` | Upstream liste derlemede üretiliyor; kurulu dosyada bakılmalı | Gwenview (Qt görüntü eklentileri), Ark (arşiv eklentileri) |
| `blfs_adi` | Masaüstü dosya adı BLFS kurulum adımında oluşuyor | Firefox, LibreOffice Writer/Calc/Impress (LibreOffice MIME listeleri upstream `libreoffice-25-8` dalında doğrulandı) |

Önemli ayrıntı: Okular'da PDF, `org.kde.okular.desktop` değil `okularApplication_pdf.desktop` (poppler üreteci) tarafından bildirilir; varsayılan buna göre yazıldı.

## Bilinçli olarak dışarıda bırakılanlar

- **Wine (.exe ilişkisi), Steam:** D22/D32 çatışması (COMPAT-01) kullanıcı kararını bekliyor; `karar_bekleyen` listesinde, `mimeapps.list`'e girmez.
- **Mağaza:** `alp` grafik arayüzü ve işlem sözleşmesi (PKG-02) yok.
- **Chrome:** varsayılan değil; MASTER_PLAN §11'e göre ayrı, doğrulanmış kurulum seçeneği.

## Doğrulama (kurulu sistemde yapılacak)

1. Uygulamalar kurulduktan sonra her `desktop` adının `/usr/share/applications` (ya da Plasma'nın `XDG_DATA_DIRS` yolları) altında bulunduğunu doğrula.
2. `xdg-mime query default application/pdf` gibi sorgularla her MIME türünün beklenen uygulamaya çözüldüğünü kaydet; `derleme_zamani` satırlarında kurulu masaüstü dosyasının `MimeType=` listesine bak.
3. MASTER_PLAN §11 kabul senaryolarını uygulama başına geçti/kaldı olarak yaz.
