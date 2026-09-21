# alpbahOS — `alp` hibrit paket yöneticisi mimari önerisi (taslak)

**Durum:** Öneri / tasarım taslağı. Ana plana entegre edilmemiştir; DECISIONS.md/MASTER_PLAN.md/BACKLOG.md içeriği bu belge tarafından değiştirilmemiştir.
**Sahip:** Claude Code, `claude/desktop-bootstrap` dalı, kullanıcı talebiyle.
**Tarih:** 21 Eylül 2026.
**Bağlı görev:** Yok — bu, BACKLOG.md'deki UI-01/SHELL-01 dışında, kullanıcının doğrudan istediği ayrı bir tasarım talebidir.

## 0. Bu belge neden var

Kullanıcı, GitHub'da barındırılan depoyu küçük tutmak için üç kurulum yöntemini birleştiren bir `alp` paket yöneticisi istedi: (1) küçük metin tarifleriyle kaynaktan derleme, (2) ağır masaüstü uygulamaları için Flatpak sarmalayıcı, (3) alpbahOS'a özel küçük önceden derlenmiş `.tar.gz` arşivleri. Bu istek mevcut proje kararlarıyla doğrudan çakışıyor; önce bu çakışma kayda geçiriliyor, sonra çakışmaya rağmen değerlendirilebilir somut bir tasarım+prototip sunuluyor.

## 1. Mevcut kararla çakışma — önce bu okunmalı

| Kaynak | İçerik | Çakışma |
|---|---|---|
| [DECISIONS.md D11](../../DECISIONS.md) | `pkg install/remove/update` komut ailesi kabul edildi; **motor seçilmedi** (açıkça not edilmiş) | `alp` motoru zaten seçiyor; D11'in "motor açık" durumunu kapatıyor |
| [DECISIONS.md P05](../../DECISIONS.md) | Teknik seçim: pacman/libalpm + ince `pkg` arayüzü + Discover/PackageKit alpm backend; M02 entegrasyon testi şart | `alp` bambaşka bir motor; P05'in yerini almayı önerir |
| [MASTER_PLAN.md §5.2](../../MASTER_PLAN.md) | "`pkg` komutları motorun üzerine ince, testli bir arayüz olur; ikinci bir paket veri tabanı veya sıfırdan bağımlılık çözücü oluşturmaz." M02 başarısızsa öngörülen alternatif **dpkg/APT + PackageKit**'tir, sıfırdan yazılmış bir motor değil | `alp`, ikinci bir paket veri tabanı ve sıfırdan yazılmış bir motordur — planın öngördüğü M02 başarısızlık yolu bu değil |
| [AGENTS.md:50](../../../AGENTS.md) | "Başka native paket motorunu aynı rootfs'de bağımsız kurma." | `alp`, pacman'ın yanında ikinci, bağımsız bir native motordur |
| [CLAUDE.md](../../../CLAUDE.md) (bu oturumun kendi talimatı) | "Paket motorunun API'si netleşmeden mağaza işlem mantığı yazma. Önce entegrasyon sözleşmesini belirle." | Bu belge tam olarak bu uyarının kapsadığı işi yapıyor — bilerek, öneri olarak işaretlenmiş biçimde |
| [BACKLOG.md](../../BACKLOG.md) | `PKG-01`/`PKG-02` Codex'e ait; eşzamanlı çalışma sözleşmesinde `recipes/`, `manifests/`, `packaging/` Codex'in dosya sınırı | `alp` bu dizinlere gerçek bir uygulama olarak yerleşseydi, Claude bu sınırın dışına çıkardı |

**Sonuç:** Bu belge ve ekli prototip, pacman/libalpm kararının yerine geçmiş **değildir**. Gerçek bir pivot için önce şunlar gerekir:

1. Kullanıcının D11/P05'i yeniden açık karara bağlaması (M02 testinden geçmeden pacman'ın terk edilmemesi genel ilkesiyle çelişmeyecek şekilde — ya M02 fiilen başarısız olmalı, ya kullanıcı gerekçeli olarak öncelik değiştirmelidir).
2. Codex ile `recipes/`, `packaging/`, `manifests/` dosya sınırı üzerinde koordinasyon; bu dizinlere gerçek kod bu onay olmadan yazılmaz.
3. AGENTS.md'nin "tek native motor" ilkesinin gerekçeli revizyonu veya `alp`'in tam ikame olarak konumlandırılması (pacman'ın tamamen bırakılması anlamına gelir, "ikisi birlikte" değil).
4. MASTER_PLAN §5.2'deki M02 kabul kriterlerinin (bölüm 6) `alp` için de kanıtlanması.

Bu adımlar alınmadan bu tasarım "kabul edilmiş" sayılmaz; aşağısı yalnız değerlendirme malzemesidir.

## 2. Amaç ve üç yöntemin gerekçesi

Amaç: özel GitHub deposunu küçük tutmak (D18/README.md: bulut/depo maliyeti istenmiyor, kaynak deposu istisna). Üç yöntem farklı maliyet profillerine karşılık gelir:

| Yöntem | Depoda ne tutulur | Maliyet nereye gider | Uygun paket türü |
|---|---|---|---|
| Recipe (kaynaktan derleme) | Birkaç KB'lık JSON tarif | Kullanıcının CPU/derleme süresi | Küçük CLI araçları (örn. `htop`) |
| Flatpak sarmalayıcı | Hiçbir şey (0 bayt) | Flathub'ın barındırması | Ağır masaüstü uygulamaları (tarayıcı, IDE) |
| Core (önceden derlenmiş `.tar.gz`) | Küçük ikili arşiv | Depoda az yer | alpbahOS'a özel marka/tema/config paketleri |

## 3. Sistem veritabanı mimarisi

Tek dosya, tek yazıcı kilidiyle korunan JSON veritabanı — AGENTS.md'nin "tek paket veri tabanı ve tek yazıcı/işlem kilidi" ilkesi burada da uygulanıyor, üç yöntem de aynı tabloyu paylaşıyor.

```
/var/lib/alp/
  db.json         # kurulu paket tablosu (tek dosya)
  alp.lock        # O_CREAT|O_EXCL ile alınan basit dosya kilidi; pid+zaman içerir
  cache/          # indirilen arşivler, build/destdir çalışma alanları
/var/log/alp/
  <ad>-<sürüm>.build.log   # yalnız recipe yöntemi için derleme çıktısı
```

`db.json` şeması (sürüm 1):

```json
{
  "schema_version": 1,
  "updated_at": "2026-09-21T17:09:08Z",
  "packages": {
    "<paket-adı>": {
      "name": "htop",
      "version": "3.3.0",
      "method": "recipe | flatpak | core",
      "status": "installed",
      "installed_at": "ISO-8601 UTC",
      "installed_by": "alp/<sürüm>",
      "source": { "yönteme özgü: url/sha256/recipe veya remote/ref" },
      "build": { "log_path": "..." },
      "files": ["/usr/bin/htop", "..."],
      "flatpak_ref": "org.mozilla.firefox veya null"
    }
  }
}
```

Alan seçimleri:

- `files`: recipe ve core yöntemlerinde dosya sahipliği izleme mekanizmasıdır (AGENTS.md'nin açıkça istediği şey — bölüm 6'da pacman ile karşılaştırılıyor). Flatpak yönteminde boş kalır; sahiplik flatpak'ın kendi runtime/app dizinlerinde tutulur, `alp` onu tekrar etmez.
- `source`: yöntem başına farklı alanlar taşır ama her zaman "bu paket nereden geldi, nasıl doğrulandı" sorusuna cevap verir — bir güvenlik/denetim izi.
- Ayrı bir `index.json` (bu dosyada değil, katalog tarafında) hangi paketlerin hangi yöntemle kurulabileceğini tanımlar; bu, "bizim GitHub deposu" için bir yerine geçer. Prototipte `demo/index.json`.

## 4. Üç kurulum yolunun akışı

### 4.1 Recipe (kaynaktan derleme)

1. `demo/recipes/<ad>.recipe.json` okunur: `source_url`, `sha256`, `build.configure/make/make_install`.
2. Kaynak arşivi indirilir, **sha256 doğrulanmadan hiçbir şey açılmaz/derlenmez** (AGENTS.md: "Kaynağı doğrulamadan derleme yapma").
3. Arşiv güvenli şekilde açılır (path-traversal koruması, bkz. bölüm 7).
4. `configure`/`make`/`make install DESTDIR=<staging>` çalıştırılır — gerçek sisteme değil, geçici bir DESTDIR'e kurulur.
5. DESTDIR ağacı `--root` altına kopyalanır; kopyalanan **her dosya** `files` listesine yazılır. Bu, dosya sahipliğini üretim zamanında yakalayan mekanizmadır.

### 4.2 Flatpak sarmalayıcı

`flatpak install -y <remote> <ref>` çağrılır; `alp` hiçbir ikili veri tutmaz, `flatpak_ref` dışında kayıt yoktur. Kaldırma `flatpak uninstall -y <ref>`.

### 4.3 Core (önceden derlenmiş alpbahOS arşivi)

Küçük `.tar.gz` indirilir, sha256 doğrulanır, `--root` altına güvenli şekilde açılır; açılan her girdi `files` listesine yazılır.

## 5. Kilit ve tek-yazıcı modeli

`DbLock`, `os.open(..., O_CREAT|O_EXCL)` ile basit bir dosya kilidi alır; kilit tutuluyorsa ikinci çağrı anında ve açık bir hata mesajıyla durur (bölüm 8'de test kanıtı var). Gerçek sistemde CLI ve mağaza (Discover benzeri bir GUI) aynı `db.json` + aynı kilidi paylaşmalıdır — MASTER_PLAN §5.3'ün "CLI ve mağaza aynı motoru, aynı veri tabanını ve aynı işlem kilidini kullanır" ilkesiyle aynı gerekçe.

## 6. MASTER_PLAN §5.2 M02 kriterlerine göre dürüst karşılaştırma

MASTER_PLAN.md kendi M02 değerlendirme ölçütlerini tanımlıyor; `alp` bu ölçütlere göre pacman/libalpm ile karşılaştırıldığında:

| Kriter | pacman/libalpm (P05) | `alp` prototipi | Not |
|---|---|---|---|
| Bağımlılık çözümü | Var, olgun | **Yok** | Recipe tarifleri doğrudan kaynak URL'sine bakar; paketler arası bağımlılık grafiği yok. Sıfırdan bağımlılık çözücü MASTER_PLAN tarafından zaten yasaklanmış — `alp` bunu "yok" diyerek karşılıyor, ekleyerek değil |
| Dosya sahipliği | Var, olgun | Var (recipe/core; DESTDIR + `files[]`) | Flatpak'ta yok — kasıtlı, flatpak kendi sahipliğini tutuyor |
| Yapılandırma korunması | Var (pacnew/pacsave) | **Yok** | Prototip güncelleme/upgrade akışını hiç ele almıyor, sadece install/remove |
| İmza / kaynak doğrulama | Paket imzası (pacman -Sv) | Sadece sha256 checksum, **imza yok** | Bölüm 7'de ayrıca tartışılıyor — recipe = güvenilen kod çalıştırma |
| Transaction kilidi | Var, olgun | Var (basit, tek dosya) | Kavramsal olarak doğru, ama pacman'ın kilit semantiğinin (kısmi işlem geri alma vb.) zenginliğine sahip değil |
| Kendi depo üretim/sürümleme maliyeti | Orta (repo-add vb. araçlar var) | Düşük (JSON dosyaları) | Ama sürüm geçişleri, kütüphane ABI kırılmaları gibi senaryolar hiç ele alınmıyor |
| Mağaza (Discover) entegrasyon yolu | PackageKit alpm backend, kaynakta mevcut | **Yok** | `alp` için PackageKit backend'i yazılmamış; bu, D11/AGENTS.md'nin GUI gereksinimini karşılamaz |
| Yarım kalan işlem / eşzamanlı istemci | pacman'ın kendi kilit dosyası | Basit kilit, test edildi (bölüm 8) | Kısmi indirme/kesinti sonrası temiz devam senaryosu prototipte yok |

Kısacası: `alp`, kullanıcının "depoyu küçük tut" hedefini gerçekten çözüyor, ama MASTER_PLAN'ın pacman'ı seçme sebebi olan olgun bağımlılık çözümü, imzalama ve mağaza entegrasyonunu **kaybediyor**. Bu, mimari tercih değil, dürüst bir eksiklik listesidir.

## 7. Güvenlik notları

- **Checksum zorunlu, atlanamaz:** `fetch()` her indirmede sha256'yı doğrular; uyuşmazsa dosya silinir ve işlem durur (bölüm 8'de gerçek bir ağ indirmesiyle test edildi).
- **`shell=True` kullanılmıyor:** Tüm `subprocess.run` çağrıları argv listesiyle çalışır; hiçbir yerde kabuk string'i interpolasyonu yok.
- **Path-traversal koruması:** `safe_extract`, Python 3.12+'nin `tarfile.extractall(..., filter="data")` güvenli filtresini kullanır; daha eski Python'da elle üye yolu doğrulaması yapılır.
- **Recipe = güvenilen kod çalıştırma (açık risk):** `configure && make && make install` bir tarif dosyasından geliyor — bu, PKGBUILD/ebuild/Homebrew formula modeliyle aynı güven sınırını taşır: **`recipes/`'e yazma erişimi olan herkes, `alp install` çalıştıran her kullanıcının makinesinde kod çalıştırabilir.** Bu, gerçek bir pivot kararı için Codex/entegratör ile konuşulması gereken bir tedarik zinciri riskidir; imzalı commit/recipe imzalama olmadan üretime alınmamalıdır.
- **Root kapsamı:** Prototip `--root` ile test edilebilir; gerçek sistemde yalnız dosya kopyalama/DESTDIR-merge adımı `/` yazma yetkisi ister — tüm `alp` sürecinin root çalışması gerekmez (AGENTS.md: "bütün akışı root yapma").

## 8. Prototip ve test durumu — gerçekten çalışan ile çalıştırılmayanın ayrımı

Ortam: bu Windows host (`win32`), Python 3.14.7. **`flatpak` ve `make`/`configure` bu hostta yok** (`which` ile doğrulandı) — bu üç yöntemden ikisi gerçek bir Linux masaüstü/build ortamı gerektirir ve orada koşulmadı.

| Senaryo | Gerçekten çalıştı mı? | Kanıt |
|---|---|---|
| `search`, `list`, `info` | ✅ Evet | Komut çıktıları aşağıda |
| Core yöntemi: indirme + sha256 doğrulama + güvenli açma + `files[]` kaydı + `db.json` yazımı | ✅ Evet, tam uçtan uca | `alpbah-theme-solid` demo arşivi kuruldu, dosyalar `--root` altında doğrulandı |
| Core yöntemi: kaldırma (`remove`) | ✅ Evet | Kurulan tüm dosyalar/dizinler geri temizlendi, `db.json` boşaldı |
| Checksum uyuşmazlığı reddi | ✅ Evet, gerçek bir ağ indirmesiyle | `htop` tarifi **gerçekten GitHub'dan indirildi** (bu hostun interneti var), yer tutucu sha256 ile karşılaştırıldı, uyuşmadı, işlem durduruldu — derleme adımına hiç geçilmedi |
| Tek-yazıcı kilidi | ✅ Evet | Sahte kilit dosyası bırakıldı, ikinci çağrı anında ve doğru mesajla reddedildi |
| Recipe yöntemi: gerçek `configure && make && make install` | ❌ **Çalıştırılmadı** | Bu hostta `make` yok; ayrıca test verisindeki sha256 kasıtlı olarak yer tutucu (`REPLACE_WITH_REAL_UPSTREAM_SHA256_BEFORE_USE`) — gerçek bir htop derlemesi hiç denenmedi |
| Flatpak yöntemi: gerçek `flatpak install/uninstall` | ❌ **Çalıştırılmadı** | Bu hostta `flatpak` yok; sadece `--dry-run` ile komut satırı doğrulandı |
| PackageKit/Discover entegrasyonu | ❌ **Yok / tasarlanmadı** | Bu prototipin kapsamı dışında |

Çalıştırılan komutlar (tekrarlanabilir, `docs/handoffs/claude/alp-prototype/` içinden):

```bash
python3 alp.py --root <scratch> --index demo/index.json search alp
python3 alp.py --root <scratch> --index demo/index.json install alpbah-theme-solid
python3 alp.py --root <scratch> --index demo/index.json list
python3 alp.py --root <scratch> --index demo/index.json info alpbah-theme-solid
python3 alp.py --root <scratch> --index demo/index.json remove alpbah-theme-solid
python3 alp.py --root <scratch> --index demo/index.json --dry-run install htop
python3 alp.py --root <scratch> --index demo/index.json --dry-run install firefox
```

Ayrıntılı yönergeler ve tam çıktı için [alp-prototype/README.md](alp-prototype/README.md).

**21 Eylül 2026 güncellemesi:** Yukarıdaki tablo bu belgenin ilk yazıldığı andaki test durumunu kaydeder (tarihsel kayıt, değiştirilmedi). Ardından yapılan bağımsız bir kod incelemesinde 3 gerçek sorun bulundu ve düzeltildi — bkz. [003-alp-review-fixes.md](003-alp-review-fixes.md) ve [alp-prototype/README.md](alp-prototype/README.md)'nin "Bağımsız inceleme sonrası düzeltmeler" bölümü. Özet: `--dry-run` artık gerçekten ağa çıkmıyor/diske yazmıyor; `recipe` yöntemiyle kurulan paketler `remove` ile artık dizinleriyle birlikte tam temizleniyor; indirmelere zaman aşımı eklendi. Bu düzeltmeler bölüm 1'deki dört onay adımını gerçekleştirmez — öneri hâlâ değerlendirme aşamasındadır.

## 9. Sıradaki adım

Bu belge tek başlı bir uygulama emri değildir. Önerilen sıra:

1. Kullanıcı bölüm 1'deki dört onay adımını (D11/P05 revizyonu, Codex koordinasyonu, AGENTS.md tek-motor ilkesi, M02 kriterleri) değerlendirir.
2. Kabul edilirse, DECISIONS.md/MASTER_PLAN.md/BACKLOG.md değişiklikleri entegratör (Codex) tarafından işlenir; Claude bu dosyaları kendi başına değiştirmez.
3. Kabul edilmezse, bu belge yalnız değerlendirilmiş ve reddedilmiş bir alternatif olarak DECISIONS.md'ye bir satır olarak eklenebilir (karar kaydı disiplini).
4. Her iki durumda da mevcut UI-01/SHELL-01 görevleri (bu oturumda henüz başlanmadı) bu öneriden bağımsız olarak sırada kalır.
