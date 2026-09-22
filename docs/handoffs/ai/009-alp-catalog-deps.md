# Claude devir belgesi 009 — `alp`'e Seviye 2 katalog-içi bağımlılık zinciri

Görev ID / durum: (Backlog dışı, kullanıcı talebi — "seviye 2" onayıyla) tamamlandı.

Çalışılan host: Windows (kod/test) + `alpbah-builder` Ubuntu VM (SSH, gerçek uçtan uca doğrulama). Dal: `claude/desktop-bootstrap`.

## Ne yapıldı

`index.json`'daki her girdiye isteğe bağlı `"depends": ["pkg-a", "pkg-b"]` alanı eklenebilir hale geldi. Yeni `_resolve_install_order(index, target, already_installed)` fonksiyonu, hedef paketin bağımlılık zincirini **yalnızca bu kataloğun kendi içinde** (DFS ile topological sort) çözüp doğru kurulum sırasını üretir; zaten kurulu olanları atlar, döngü veya bilinmeyen bağımlılık varsa net bir `AlpError` fırlatır. `cmd_install` bu sırayla her paketi tek tek kurup `db.json`'a işleyecek şekilde yeniden yazıldı.

**Bilerek yapılmadı (kullanıcıya önceden anlatıldığı gibi):** sürüm kısıtları ("libfoo >= 2.0"), çakışan gereksinim çözümü, kataloğun dışına (apt/PyPI tarzı bir evrene) açılan bir çözücü — Seviye 3, MASTER_PLAN'ın yasağıyla ve `alp`'in "basit kalsın" felsefesiyle çelişir.

## Gerçek doğrulama (SSH, `alpbah-builder` VM)

Mevcut 9 gerçek paketin hiçbiri birbirine gerçekten bağımlı değil (bilerek basit/bağımsız araçlar seçilmişti) — bu yüzden **açıkça sentetik, iki `core` paketlik** (`libfoo`, `app` → `libfoo`'ya bağımlı) gerçek bir test kurgusu hazırlandı (gerçek tarball, gerçek sha256, gerçek dosya işlemleri):

- `--dry-run install app` → "Bağımlılık zinciri: libfoo -> app" yazdırdı, **hiçbir şey diske yazılmadı** (cache dizini boş kaldı, `install_core`'un zaten kanıtlanmış dry-run disiplini sayesinde).
- Gerçek `install app` → önce `libfoo`, sonra `app` doğru sırayla kuruldu, ikisi de `db.json`'a işlendi.
- `list` → her ikisi de görünüyor.
- `app`'i tekrar kurmaya çalışmak → "app zaten kurulu" ile temiz no-op, `libfoo`'ya dokunulmadı.
- Dosyalar (`/usr/share/libfoo/data`, `/usr/bin/app`) gerçekten diskte, doğru yerde.

## Yerel test seti

10 yeni test (`_resolve_install_order`: doğrusal zincir, fan-out/diamond, zaten-kurulu atlama, hedef zaten kurulu → boş sıra, döngü tespiti, bilinmeyen bağımlılık; `cmd_install`: uçtan uca zincir kurulumu, kurulu bağımlılığın yeniden kurulmaması, `--reinstall`'ın yalnızca hedefi etkilemesi, dry-run'ın hiçbir şeye dokunmaması). Toplam: `test_alp.py` **63 geçti + 2 atlandı** (Windows symlink izni yok, değişmedi).

## Bilinen sınır / açık karar

1. `cmd_upgrade` bu turda değiştirilmedi — upgrade hâlâ yalnızca zaten kurulu tek bir paketi günceller, yeni bağımlılık çekmez (kapsam dışı bırakıldı, gerekirse ayrı bir iş).
2. Mevcut 9 gerçek pakette birbirine gerçekten bağımlı olan yok — bu özelliğin gerçek faydası, katalog büyüyüp gerçek iç-bağımlılıklar oluştuğunda ortaya çıkacak.
3. `flatpak` yöntemi paketlerinin `depends` alanı olması engellenmedi (genel/yöntem-bağımsız tutuldu) ama pratikte anlamlı bir senaryosu henüz yok.

## Entegrasyon için gereken

Yok. Sonraki eylem: Yok — kullanıcı isteği tamamlandı.
