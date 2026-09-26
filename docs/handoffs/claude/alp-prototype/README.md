# `alp` prototipi — çalıştırma ve test notları

Bu dizin, [../001-alp-hybrid-pkg-proposal.md](../001-alp-hybrid-pkg-proposal.md) önerisinin çalışan kanıtıdır. `alp`, D31/P13 kararıyla alpbahOS'un kabul edilen başlangıç motorudur; prototip ve sistem entegrasyonu bitmiş/üretime hazır değildir.

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

## Otomatik test seti (22 Eylül 2026, güncellendi)

`tests/test_alp.py` + `tests/test_packagekit_backend.py` — pytest, gerçek ağa hiç çıkmaz. 24 Eylül 2026'da Windows Python 3.14.7 üzerinde, TTY'li PowerShell oturumunda **82 test geçti, 10 POSIX-özelliği testi atlandı**. Ayrıntı: [`docs/verification/m02-alp-tests-2026-09-24.md`](../../../verification/m02-alp-tests-2026-09-24.md).

```bash
cd docs/handoffs/claude/alp-prototype
python3 -m pytest tests/ -v
```

## Gerçek Linux'ta ilk uçtan uca test (22 Eylül 2026)

`alp` ilk kez **gerçek bir Linux ortamında** (Codex'in `alpbah-builder` Ubuntu 24.04.5 VM'i, SSH ile, `sa@172.28.174.11`) test edildi — bkz. [006-alp-real-linux-test.md](../006-alp-real-linux-test.md) tam ayrıntı için. Özet:

- **Gerçek bug bulundu ve düzeltildi:** `recipe` yönteminde `./configure` gerçekte var ve çalıştırılabilir olduğu hâlde "bulunamadı" hatası veriyordu. Sebep: `shutil.which("./configure")` yolu, adım `cwd=src_dir` ile çalıştırılsa bile, `alp.py`'nin kendi çalıştığı dizine göre arıyordu. `_tool_available()` yeni yardımcı fonksiyonu bunu doğru dizine (`src_dir`) göre çözüyor. Bu hata **yalnızca gerçek bir Linux'ta configure gerçekten mevcutken** ortaya çıkabilirdi — Windows'ta zaten `make` yoktu, hata her iki nedenden de aynı görünüyordu.
- Düzeltmeden sonra `htop` tarifi gerçekten `./configure`'ı çalıştırdı, gerçek bir bağımlılık hatasıyla (`libncursesw` eksik) durdu — bu, prototipin kendi dürüst eksiklik listesindeki "bağımlılık çözümü yok" ile tam tutarlı, `alp`'in hatası değil.
- `core` yöntemiyle **tam bir yaşam döngüsü** (kurulum → değiştirilmemiş config'in sessizce yükseltilmesi → değiştirilmiş config'in `.alpnew` üretmesi, kullanıcı dosyasına dokunmadan → `remove`'un değiştirilmiş config'i `.alpsave` olarak koruması) gerçek Linux'ta uçtan uca doğrulandı, tasarıma birebir uydu.

Testlerin gerçekten anlamlı olduğu (yalnızca "her zaman geçen" testler olmadığı) şöyle doğrulandı: bu testler, düzeltmeden ÖNCEKİ `alp.py` sürümüne (`51f93b9`) karşı çalıştırıldı ve **tam olarak 3 düzeltmeye karşılık gelen 7 test başarısız oldu** (dry-run'ın gerçekten fetch çağırmadığını doğrulayan 3 test, `_merge_destdir`'in dizinleri kaydettiğini doğrulayan 2 test, indirme timeout'unu doğrulayan 2 test); diğer 22 test zaten geçiyordu. Bu, testlerin gerçek regresyon koruması sağladığının kanıtıdır — kozmetik/anlamsız testler değil.

Kapsanmayan (bu hostta hâlâ test edilemeyen, testlerde de öyle işaretli): gerçek `configure/make/make install` çalıştırma, gerçek `flatpak install/uninstall`, gerçek internet üzerinden `htop`/`jq`/`zsh`/`tmux` indirme (o testler `alpbahOS-alp` reposunda elle doğrulandı, bu test setinde değil — burada network tamamen mock'lu tutuluyor, hız ve tekrarlanabilirlik için).

## Seviye 3 bağımlılık denetimi (23 Eylül 2026)

Ayrıntı: [../013-alp-seviye3-deps.md](../013-alp-seviye3-deps.md). Kısaca:

- `index.json` girdilerinde `depends` artık sürüm kısıtı alıyor: `"libfoo>=2.0"`, `"libfoo>=2.0,<3"` (virgül = VE). İsteğe bağlı yeni `conflicts` alanı var.
- Kurulum, yükseltme ve kaldırma önce bir **işlem planı** gösteriyor. Etkileşimli terminalde `[E/h]` onayı soruyor; betikler ve PackageKit backend'i için `-y/--yes` var.
- Plan sonunda bir kısıt veya çakışma bozulacaksa işlem **tek bayt yazılmadan** reddediliyor.
- Yeni komutlar ve seçenekler:
  - `alp remove --cascade <ad>`: bağımlı paketlerle birlikte kaldırır. `--cascade` olmadan, başka paketin ihtiyaç duyduğu bir paket kaldırılamaz.
  - `alp autoremove`: bağımlılık olarak gelip artık kimsenin ihtiyaç duymadığı paketleri kaldırır.
  - `alp upgrade` (ad vermeden): bütün eski paketleri yükseltir. Takılan bir paketi nedeniyle "geri tutuldu" diye bildirir, diğerlerini yükseltir.
  - `alp check`: kurulu sistemdeki bozuk kısıtları, çakışmaları, güncellemeleri ve sahipsiz bağımlılıkları listeler.
- `info`, kurulu paketin `required_by` listesini, `list` ise "(bağımlılık)" işaretini gösteriyor.
- Sınır: katalogda her paketin tek bir sürümü var. Bu yüzden bu bir SAT çözücü değil, deterministik bir kısıt denetleyicisi. Katalog dışındaki sistem kütüphaneleri hâlâ Seviye 1'de (`requires_commands` / `requires_libraries`).

Test: Windows'ta **126 geçti, 10 atlandı**. Builder'da (Ubuntu 24.04.5) **136 geçti, 0 atlandı**.

## M02 kapanışı: geri alma, recover, korumalı paket, update (24 Eylül 2026)

- **İşlemsel geri alma.** Her paket kurulumu, yükseltmesi ve kaldırması bir işlem (transaction) içinde çalışır: dosya değişiklikleri **yazılmadan önce** `var/lib/alp/rollback/` altındaki günlüğe (write-ahead) ve yedeğe (sabit bağlantı, gerekirse kopya) kaydedilir. Dosya kopyalanırken hata (disk dolu, G/Ç hatası, Ctrl-C) ya da veritabanı yazma hatası olursa her dosya eski hâline döner. Değişmez kural: alp dosyaları hiç yerinde yazmaz (geçici dosya + `os.replace`), bu yüzden yedek eski inode'u korur.
- **`alp recover`.** `kill -9` ya da elektrik kesintisiyle yarım kalan işlemi günlükten geri alır. Yarım işlem varken `install/upgrade/remove/autoremove/update` reddedilir, `alp check` sorunu gösterir. Veritabanı kaydedildikten sonra yazılan `commit` işareti olan günlük geri alınmaz.
- **`alp protect NAME` / `alp unprotect NAME`** ve katalog girişinde `"protected": true`. Korumalı paket `remove`, `--cascade` ve `autoremove` ile kaldırılamaz; sıradan korumalı paketler yükseltilebilir. `method: "lfs-base"` kayıtları ayrıca upgrade, reinstall, remove ve unprotect işleminden korunur. `list --json` yalnız korumalıysa `"protected": true` yazar (JSON sözleşmesi değişmez).
- **`alp update [--source URL|YOL] [--sha256 HEX]`.** Kaynak `index.json` ya da tepesinde `index.json` olan `.tar.gz` katalog paketidir; `index.json`'daki `"source"` alanı varsayılan kaynaktır. `http://` reddedilir. Yeni katalog doğrulanır (tarif dosyaları katalog içinde ve okunur mu), yerel katalog değiştirilmeden önce fark (yeni/değişti/kalktı ve `güncelleme var`) gösterilir; `--dry-run` hiçbir şeyi değiştirmez. Önceki `index.json` `index.json.prev` olarak, değişen paket dosyaları `.alp-catalog-prev/` altında kalır. **Katalog imzalı değil**: güven https + isteğe bağlı `--sha256` ile sağlanır; paket arşivleri kurulumda yine sha256 ile doğrulanır.
- **Build temizliği.** Başarılı recipe kurulumundan sonra `build-*`/`destdir-*` (ve upgrade eşdeğerleri) silinir; başarısız build'de hata ayıklama için kalır. `--keep-build` hepsini saklar.

Claude 014 doğrulaması: Windows 153 geçti/12 atlandı; Linux (Ubuntu 24.04, Python 3.12.3, kullanıcı `sa`, gerçek izinler) 165 geçti/0 atlandı; 12 mutasyonun 12'si testlerce yakalandı; gerçek `kill -9` denemesi (aşağıda devir belgesi 014).

## M04: kurulu LFS paketlerini güvenle içeri alma (24 Eylül 2026)

`alp adopt-base --manifest FILE --name NAME --version VERSION --source-sha256 HEX [--manifest-sha256 HEX]`, önceden kurulmuş dosyaları canlı root ile karşılaştırdıktan sonra sahiplik kaydı yapar. Çağıran, kaynak arşivin ve manifestin beklenen checksum'ını ayrıca doğrulamalıdır; manifest JSON'u tek başına kaynak kimliğini doğrulamaz. Komut dosya/symlink türünü, içeriğini/hedefini, boyutunu, modu, uid/gid'yi doğrular; çakışan yolları reddeder ve ortak dizinleri sahiplenmez. `method: "lfs-base"` ve `protected: true` kaydı oluşturur; Alp bu kayıtları remove, unprotect, upgrade ve reinstall'dan korur. `--dry-run` önerilen kaydı yazmadan gösterir.

Uygulama Claude 014 sonrasındaki `7b2c657` commit'inde eklendi; `alp.py` SHA-256 `0475ea324b16895d3acbf3aebdab01d5d3a36900570f2562ca514008b11c2fc3`. Windows tam test paketi **170 geçti, 13 atlandı**; `py_compile`, `check_docs.py` (0 bulgu) ve `git diff --check` geçti. Builder Linux üzerinde adoption testi yapılmadı; özellik `/mnt/lfs`'e kurulmadı ve canlı paket DB hâlâ boş. Sınırlamalar ve gereken doğrulama [`m02-alp-base-adoption-2026-09-24.md`](../../../verification/m02-alp-base-adoption-2026-09-24.md) belgesinde.
## `--relocate` ve `@PREFIX@` (26 Eylül 2026)

Tarifler kurulum önekini sabit `/usr` yerine `@PREFIX@` ile yazar. alp bunu varsayılan olarak `/usr` yapar; alpbahOS'taki davranış değişmez. `--relocate` verildiğinde ve `--root` `/` değilse önek `<root>/usr` olur: paket kök dizininin kendisi için derlenir, `make install DESTDIR=...` çıktısının `DESTDIR/<root>` alt ağacı köke kopyalanır. Kök dışına dosya kuran (ör. sabit `/etc`) paket reddedilir. Amaç, başka bir dağıtımda (ör. Fedora'da `~/.local/share/alp/root`) kurulan programların veri dosyalarını çalışma anında bulabilmesidir; `--relocate` olmadan figlet `Unable to open font file` hatası veriyordu.

Doğrulama (Fedora 44, Python 3.14.7, GCC 16.2.1, glibc 2.43): `python3 -m pytest tests/ -q` → 189 geçti, 0 atlandı (yeni `tests/test_relocate.py`: 6 test, 3'ü gerçek `make` ile). `alpbahOS-alp` kataloğuyla `--relocate` kurulumu: figlet, units, jq, bc kuruldu ve çalıştı; socat glibc 2.43'ün const `strchr` değişikliği nedeniyle derlenmedi; tmux (`libevent`), zsh/htop/less (`ncursesw`) sistem geliştirme kütüphaneleri eksik olduğu için durdu. alpbahOS rootfs'inde bu değişiklik çalıştırılmadı.

## Türkçe yardım ekranı (26 Eylül 2026)

`alp`, `alp help` ve `alp --help` komutları gruplu, örnekli bir Türkçe ekran gösterir (terminalde renkli, `NO_COLOR` desteklenir). `alp <komut> --help` de Türkçedir. Yanlış yazılan komut için öneri verilir (`alp instal` → `alp install`). Genel seçenekler (`--dry-run`, `--json`, `--root` …) artık komuttan önce veya sonra yazılabilir. Geliştirici seçenekleri: `alp help gelistirici`. Test: `tests/test_cli_help.py`; Fedora 44'te tam paket 198 geçti.

## Katalog büyütme için: açıklamalı arama, `@DESTDIR@`, Flatpak sürümü (26 Eylül 2026)

- Katalog girdileri isteğe bağlı `description` alır. `alp search` artık ad ve açıklamada arar, sonucu hizalı tablo olarak açıklamasıyla gösterir. Türkçe `İ` doğru eşleşir (`DÜZENLEYİCİ` → `düzenleyici`). `--json` çıktısına varsa `description` eklenir (ek alan, sözleşme bozulmaz).
- Tarifte `@DESTDIR@` yer tutucusu: `make_install` bunu içerirse alp sona `DESTDIR=` eklemez, yer tutucuyu hazırlık dizinine çevirir. DESTDIR'ı standart dışı kullanan Makefile'lar için (ör. tree: `DESTDIR=@DESTDIR@@PREFIX@/bin`).
- Flatpak girdisinde `version` yoksa plan sürüm yazmaz ("unknown" gösterilmez). Kurulumdan sonra gerçek sürüm `flatpak list --columns=application,version` ile okunup kaydedilir.

Doğrulama: Fedora 44, 209 test geçti. Gerçek Flatpak kurulum/kaldırma: `alp install -y flatseal` → `flatseal (flatpak) -> 2.4.1 kuruldu`, `alp remove -y flatseal` temiz.
