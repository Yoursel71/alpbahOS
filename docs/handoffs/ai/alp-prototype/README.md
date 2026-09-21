# `alp` prototipi — çalıştırma ve test notları

Bu dizin, [../001-alp-hybrid-pkg-proposal.md](../001-alp-hybrid-pkg-proposal.md) önerisinin çalışan kanıtıdır. **alpbahOS'un kabul edilmiş paket motoru değildir** — bkz. o belgenin 1. bölümü.

## Dosyalar

- `alp.py` — prototip CLI (Python 3.10+; test 3.14.7 ile yapıldı).
- `demo/index.json` — örnek katalog: bir `recipe` (htop), bir `flatpak` (firefox), bir `core` (alpbah-theme-solid) girdisi.
- `demo/recipes/htop.recipe.json` — örnek derleme tarifi. **`sha256` alanı kasıtlı olarak yer tutucudur** (`REPLACE_WITH_REAL_UPSTREAM_SHA256_BEFORE_USE`); gerçek htop sürüm doğrulaması yapılmadı.
- `demo/core/alpbah-theme-solid-1.0.0.tar.gz` — birkaç yüz baytlık, gerçek test amaçlı üretilmiş sahte tema arşivi (gerçek bir alpbahOS teması değildir).

## Çalıştırma

```bash
cd docs/handoffs/claude/alp-prototype
python3 alp.py --root /tmp/alp-test --index demo/index.json search alp
python3 alp.py --root /tmp/alp-test --index demo/index.json install alpbah-theme-solid
python3 alp.py --root /tmp/alp-test --index demo/index.json list
python3 alp.py --root /tmp/alp-test --index demo/index.json info alpbah-theme-solid
python3 alp.py --root /tmp/alp-test --index demo/index.json remove alpbah-theme-solid
```

`--root` gerçek `/` yerine bir DESTROOT verir; alpbahOS'ta bu bayrak olmadan çalıştırılır.

## Bu ortamda gerçekten test edilenler (win32, Python 3.14.7)

- `search` / `list` / `info` — çalıştı.
- `core` yöntemi tam döngü: indirme (yerel dosya, `file://` çözümlemesiyle), sha256 doğrulama, güvenli arşiv açma, `--root` altına kopyalama, `db.json`'a kayıt, `list`/`info` ile doğrulama, `remove` ile temiz geri alma. Tüm adımlar gerçekten çalıştı, çıktılar `001-alp-hybrid-pkg-proposal.md` bölüm 8'de.
- Tek-yazıcı kilidi: sahte kilit dosyasıyla ikinci yazıcının reddedildiği doğrulandı.
- Checksum reddi: `htop` tarifi gerçek ağdan indirildi (bu host internete çıkabiliyor), yer tutucu sha256 ile karşılaştırıldı, uyuşmadı, işlem güvenle durduruldu.

## Bu ortamda test edilemeyenler — açıkça "çalıştırılmadı"

- Gerçek `./configure && make && make install` — bu hostta `make`/`configure` toolchain'i yok (`which make` boş döndü).
- Gerçek `flatpak install`/`uninstall` — bu hostta `flatpak` kurulu değil.
- PackageKit/Discover entegrasyonu — hiç yazılmadı, kapsam dışı.
- Gerçek bir alpbahOS rootfs üzerinde `--root /` ile üretim testi — hiç denenmedi, denenmemeli (bu bir prototip, gerçek sisteme yazma yolu hiç egzersiz edilmedi).

Bu ayrımın nedeni AGENTS.md'nin "Yapılmamış derleme, test, donanım doğrulaması ... yapılmış gibi raporlanamaz" kuralı — recipe ve flatpak yollarının kod yolu doğru yazılmıştır ama gerçek dış araçlarla hiç koşulmamıştır.

## Bağımsız inceleme sonrası düzeltmeler (21 Eylül 2026)

Claude tarafından yapılan bağımsız kod incelemesinde bulunan 3 sorun düzeltildi (bkz. [../003-alp-review-fixes.md](../003-alp-review-fixes.md)):

1. **`--dry-run` artık gerçekten ağa çıkmıyor/diske yazmıyor.** Önceki sürümde `recipe`/`core` kurulumlarında `fetch()` (indirme+checksum) `dry_run` kontrolünden ÖNCE, koşulsuz çalışıyordu — CLI'nin kendi "touch nothing persistent" sözünü çiğniyordu. Artık dry-run erken çıkıyor, hiçbir ağ isteği veya kalıcı dosya yazımı yapmıyor. Yeniden test edildi: `--dry-run install htop/firefox/alpbah-theme-solid` sonrası `var/lib/alp/cache/` boş kalıyor.
2. **`recipe` yöntemiyle kurulan paketler artık `remove` ile tam temizleniyor.** `_merge_destdir` artık dizinleri de `files[]`'e kaydediyor (öncesinde yalnız dosyalar kaydediliyordu, `make install`'ün oluşturduğu dizinler kalıcı olarak öksüz kalıyordu).
3. **İndirmelerde 30 saniyelik zaman aşımı eklendi** (`urllib.request.urlopen(..., timeout=...)`), yanıt vermeyen bir kaynağın `alp install`'ı sonsuza kadar askıda bırakmasını önlemek için.

Checksum reddi testi artık gerçek (dry-run olmayan) bir `install htop` çağrısıyla yeniden doğrulandı — davranış aynı: gerçek ağdan indirilen dosya checksum uyuşmazlığında silinip işlem durduruluyor.

## `upgrade` komutu ve `--json` çıktı modu (21 Eylül 2026)

- **`alp upgrade <ad>`** eklendi — kurulu bir `recipe`/`core` paketi yeni sürüme yükseltir, config dosyalarını pacman'ın `pacnew`/`pacsave`'i gibi korur (`.alpnew`/`.alpsave`). Tasarım ve durum: [design/config-protection.md](design/config-protection.md). `flatpak` yöntemi için `upgrade` reddedilir (flatpak kendi güncellemesini yönetir).
- **`--json`** bayrağı eklendi (`search`/`list` için; `info` zaten JSON basıyordu) — bir PackageKit backend'inin veya başka bir aracın metin ayrıştırmadan güvenilir okuyabilmesi için. Tasarım: [design/packagekit-integration.md](design/packagekit-integration.md).
- **`alp_packagekit_backend.py`** eklendi — `alp_*` sarmalayıcı fonksiyonları (gerçek `alp.py`'yi subprocess ile çağırıp JSON ayrıştırır) **gerçekten test edildi**; `AlpPackageKitBackend` sınıfının kendisi gerçek `packagekit` modülü olmadığı için **hiç import/test edilemedi** — modülün kendi docstring'inde bu ayrım açıkça yazılı.

## Otomatik test seti (21 Eylül 2026, güncellendi)

`tests/test_alp.py` + `tests/test_packagekit_backend.py` — pytest, gerçek ağa hiç çıkmaz. **48 test**, bu ortamda çalıştırıldı, hepsi geçti:

```bash
cd docs/handoffs/claude/alp-prototype
python3 -m pytest tests/ -v
```

Testlerin gerçekten anlamlı olduğu (yalnızca "her zaman geçen" testler olmadığı) şöyle doğrulandı: bu testler, düzeltmeden ÖNCEKİ `alp.py` sürümüne (`51f93b9`) karşı çalıştırıldı ve **tam olarak 3 düzeltmeye karşılık gelen 7 test başarısız oldu** (dry-run'ın gerçekten fetch çağırmadığını doğrulayan 3 test, `_merge_destdir`'in dizinleri kaydettiğini doğrulayan 2 test, indirme timeout'unu doğrulayan 2 test); diğer 22 test zaten geçiyordu. Bu, testlerin gerçek regresyon koruması sağladığının kanıtıdır — kozmetik/anlamsız testler değil.

Kapsanmayan (bu hostta hâlâ test edilemeyen, testlerde de öyle işaretli): gerçek `configure/make/make install` çalıştırma, gerçek `flatpak install/uninstall`, gerçek internet üzerinden `htop`/`jq`/`zsh`/`tmux` indirme (o testler `alpbahOS-alp` reposunda elle doğrulandı, bu test setinde değil — burada network tamamen mock'lu tutuluyor, hız ve tekrarlanabilirlik için).
