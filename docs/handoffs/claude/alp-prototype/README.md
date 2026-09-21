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
