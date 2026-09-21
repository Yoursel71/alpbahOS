# `alp` — PackageKit/Discover entegrasyon tasarımı

Durum: **kısmen koda döküldü (21 Eylül 2026).** §2'deki `--json` bayrağı ve `alp_packagekit_backend.py`'deki `alp_*` sarmalayıcı fonksiyonları gerçekten yazıldı ve **gerçekten test edildi** (`tests/test_packagekit_backend.py`, alp.py'ye karşı subprocess ile, mock yok). `AlpPackageKitBackend` sınıfının kendisi (gerçek `packagekit.backend` importu gerektiren kısım) **hâlâ hiç çalıştırılamadı/import edilemedi** — bu Windows host'ta `packagekit` modülü yok. Ayrıntı: `alp_packagekit_backend.py`'nin modül docstring'i.

Bu, proposal belgesinin (§6) kendi dürüst eksiklik listesindeki "Mağaza (Discover) entegrasyon yolu: Yok" maddesini kapatmak için yazıldı. Aşağıdaki orijinal tasarım metni (§1-7) hâlâ geçerli sözleşmedir; §2 ve §3'ün "sarmalayıcı fonksiyon" kısmı artık kod olarak var, geri kalanı (gerçek PackageKit daemon testi) hâlâ yapılmadı.

## 1. Neden bu yaklaşım

MASTER_PLAN §5.3 zaten sözleşmeyi tanımlıyor: *"CLI ve mağaza aynı motoru, aynı veri tabanını ve aynı işlem kilidini kullanır."* `alp` bunu zaten `db.json` + `DbLock` ile sağlıyor (D31/P13). Eksik olan tek şey: Discover'ın konuştuğu protokolü (`org.freedesktop.PackageKit` D-Bus arayüzü) `alp`'e bağlayan katman.

İki gerçekçi seçenek var:

| Seçenek | Artı | Eksi |
|---|---|---|
| **A. Python PackageKit backend'i** (`packagekit.backend` modülü, CLI'yı sarmalar) | Az kod, `alp`'in kendi süreç/kilit modeli korunur, C yazmaya gerek yok | Python backend'ler PackageKit ekosisteminde daha az yaygın/bakımlı; performans CLI spawn maliyetine bağlı |
| **B. C backend (libalpm örneğindeki gibi)** | PackageKit'in native beklediği yol, en olgun | `alp`'in Python mantığını C'ye taşımak/köprülemek gerekir — büyük ek iş, `alp`'in "basit, stdlib-only" tasarım hedefiyle çelişir |

**Öneri: A.** `alp`'in kendisi zaten "basit, hızlı" hedefiyle tasarlandı (D31 kararının gerekçesi); CLI spawn maliyeti kurulum/kaldırma gibi seyrek işlemler için kabul edilebilir. B, `alp`'in tüm felsefesini (basitlik) feda eder.

## 2. Zorunlu ön koşul: `alp`'e yapılandırılmış çıktı modu

**Şu an `alp search`/`alp list` insan-okunur düz metin basıyor.** Bir backend'in bunu güvenilir şekilde ayrıştırması kırılgan olur (proposal §7'nin "Yazım yardımı argümanları/dosya adlarını sessizce yeniden yazmaz" ruhuyla aynı: kırılgan metin ayrıştırma yerine sözleşmeli biçim). Bu yüzden backend yazılmadan önce `alp`'e `--json` bayrağı eklenmeli:

```
alp --json search <terim>   -> JSON dizi: [{"name":..., "method":...}, ...]
alp --json info <ad>        -> zaten JSON basıyor (cmd_info), --json bayrağı olmadan da
alp --json list             -> JSON dizi: [{"name":..., "version":..., "method":...}, ...]
```

Bu, `alp.py`'ye eklenmesi gereken küçük, izole bir değişikliktir (mevcut `cmd_search`/`cmd_list`'in çıktı biçimini dallamak) — bu belge bunu kod olarak yazmıyor, yalnızca ön koşul olarak kayda geçiriyor.

## 3. PackageKit yöntem eşlemesi

| PackageKit yöntemi | `alp` karşılığı | Not |
|---|---|---|
| `SearchNames` / `SearchDetails` | `alp --json search <terim>` | Doğrudan eşleşir |
| `Resolve` | `alp --json info <ad>` | Kurulu/kurulu değil ayrımı zaten `cmd_info`'da var |
| `GetDetails` | `alp --json info <ad>` | `source`, `version` alanları zaten var |
| `GetFiles` | `db.json`'daki `files[]` | `alp --json info` çıktısına zaten dahil |
| `InstallPackages` | `alp install <ad>` | İlerleme raporlama eksik, bkz. §4 |
| `RemovePackages` | `alp remove <ad>` | Aynı |
| `GetUpdates` / `UpdatePackages` | **Yok — `alp`'te `update`/`upgrade` komutu henüz gerçek değil** (`cmd` şu an no-op, bkz. `alp.py` `update` alt komutu) | Bu backend özelliği, `alp upgrade`'in gerçek bir uygulaması olmadan yazılamaz. Bkz. [config-protection.md](config-protection.md) — upgrade tasarımı orada. |
| `GetRepoList` | `demo/index.json`'un (gerçek sistemde `alpbahOS-alp` reposunun) tek girişi | `alp`'te çoklu depo kavramı yok; MASTER_PLAN §5.3 "birden fazla kaynak varsa görünür olsun" ilkesi tek depoyla otomatik sağlanıyor |

## 4. İlerleme raporlama (eksik, tasarım gerekli)

PackageKit, `InstallPackages` sırasında `Percentage`/`Status` sinyalleri bekler; Discover bunu bir ilerleme çubuğunda gösterir. `alp` şu an tek seferlik bir komut, ilerleme akışı yok.

Önerilen protokol: `alp install <ad> --progress-fd <N>`, ilerlemeyi `N` numaralı dosya tanıtıcısına tek satırlık JSON olarak yazar (`{"phase":"download","pct":42}`, `{"phase":"build"}`, `{"phase":"done"}`). Backend bu FD'yi okuyup PackageKit sinyallerine çevirir. Bu, `alp`'in stdout'unu (insan tarafından okunan mesajlar) FD ayrımıyla kirletmez — Unix araçlarının standart "makine-okunur ek kanal" deseni.

**Bu protokol henüz uygulanmadı; yalnızca tasarım.**

## 5. Yetkilendirme (polkit)

MASTER_PLAN §5.3: *"Root yetkisi tüm mağazaya verilmez; ayrı yetkili işlem mekanizması kullanılır."* AGENTS.md: *"Gerekli root işlemlerini açıkça sınırla; bütün akışı root yapma."*

Tasarım: `org.alpbahos.alp.pkgkit.policy` adında bir PolicyKit action dosyası:

```xml
<action id="org.alpbahos.alp.pkgkit.install-remove">
  <description>alp ile paket kur/kaldır</description>
  <defaults>
    <allow_any>auth_admin</allow_any>
    <allow_inactive>auth_admin</allow_inactive>
    <allow_active>auth_admin_keep</allow_active>
  </defaults>
</action>
```

`search`/`list`/`info`/`get-files` için **yetkilendirme istenmez** (salt okunur, `--root /` ile bile herkesin `db.json`'u okuyabilmesi gerekir — dosya izinleri `0644` olmalı, `alp.lock`/yazma işlemleri `0600`+root). Yalnızca `install`/`remove` (ve gelecekteki `upgrade`) `auth_admin` ister — bu, `install_recipe`'in zaten root gerektiren tek adımının (`_merge_destdir`'in `/` altına kopyalama) kapsamıyla örtüşür (AGENTS.md: "yalnız dosya kopyalama/DESTDIR-merge adımı `/` yazma yetkisi ister — tüm `alp` sürecinin root çalışması gerekmez").

## 6. Kilit/eşzamanlılık ile etkileşim

Backend, `alp install`'i spawn ettiğinde `alp`'in kendi `DbLock`'u zaten tek-yazıcı garantisini sağlıyor. Eğer CLI'dan biri elle `alp install` çalıştırıyorsa ve aynı anda Discover da bir kurulum başlatırsa, ikinci çağrı `AlpError: "Veritabanı kilitli..."` ile döner (mevcut, test edilmiş davranış — bkz. `tests/test_alp.py::test_db_lock_blocks_second_writer`). Backend bu spesifik hata metnini (`stderr`'de `alp: hata: ... kilitli ...`) yakalayıp PackageKit'in `PK_ERROR_ENUM_LOCK_REQUIRED` kodunu döndürmeli — Discover kullanıcıya "başka bir işlem sürüyor" diye anlaşılır gösterir, ham hata metni değil.

## 7. Kabul kriterleri (MASTER_PLAN §5.2/§5.3'e göre)

Bu tasarım "kabul edilmiş" sayılmadan önce (proposal §6'daki PKG-02 kabul ölçütüyle aynı):

1. `alp --json` çıktı modu uygulanmalı ve test edilmeli (bu tasarımın §2'si).
2. Python PackageKit backend'i yazılmalı, gerçek bir PackageKit daemon'una (bir Linux/BLFS ortamında) yüklenip `pkcon`/Discover ile uçtan uca test edilmeli.
3. §4'teki ilerleme protokolü uygulanmalı.
4. §5'teki polkit action dosyası gerçek bir polkit kurulumunda test edilmeli.
5. `GetUpdates`/`UpdatePackages` ancak [config-protection.md](config-protection.md)'deki `alp upgrade` tasarımı koda dönüştükten sonra eklenebilir.

**21 Eylül 2026 durumu:** Madde 1 (`--json`) ve madde 2'nin ilk yarısı (`alp_*` sarmalayıcılar) tamamlandı+test edildi. 2, 3, 4 tam olarak gerçekleşmedi — `AlpPackageKitBackend` yazıldı ama gerçek bir PackageKit daemon'una hiç yüklenmedi. MASTER_PLAN §5.3 M02 kriterinin "entegrasyon testi" kısmını **hâlâ karşılamıyor**; bunun için Codex'in gerçek BLFS/PackageKit ortamı gerekiyor.
