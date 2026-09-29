# Claude devir belgesi 019: M10 engeli — `@PREFIX@` kurulum hatası, Discover metadata'sı, wallpaper entegrasyonu

```text
Görev ID / durum: PKG-01/PKG-02 (alp motoru + katalog sözleşmesi) ve UI-03 entegrasyon adımı. Başlangıç: 29 Eylül 2026, Claude (Fedora ana host). Kod ve testler tamam; rootfs/VM/Discover doğrulaması ÇALIŞTIRILMADI (aşağıda).
Çalışılan host ve branch/commit: Fedora 44, Python 3.14.7, pytest 8.4.2. Dal `claude/alp-prefix-metadata`, PR #3'ün ucu (`claude/logic-fixes`, aa5e818) üzerine kurulu; o da Yoursel71/alpbahOS `main` 9c26ecf üzerinde.
Dosya sınırı: yalnız `docs/handoffs/claude/` (alp motoru, testleri, yama önerileri, bu belge). `scripts/`, `/mnt/lfs`, `alpbahOS-work` ağacı ve ortak WORKLOG/BACKLOG'a DOKUNULMADI.
Değişen dosyalar: alp-prototype/alp.py, alp-prototype/tests/test_catalog_contract.py (yeni), alp-prototype/tests/test_packagekit_backend.py (1 beklenti), patches/019-alpBackend-metadata.patch (yeni), patches/019-verify_alpbackend.py (yeni), bu belge.
Sonraki eylem: Entegratör (Codex) aşağıdaki "Entegrasyon" adımlarını atılabilir bir overlay'de uygular ve `pkcon install htop` kabulünü yeniden koşar.
```

## 1. Kök neden (kanıtlı)

M10 matrisinde "M08 kurulum/kaldırma" **BLOCKED**'di: `pkcon install htop`, `./configure --prefix=@PREFIX@` satırında düştü. Bu bir tarif hatası değil, **katalog ile motor sürümlerinin ayrışması**:

| Parça | Kanıt |
|---|---|
| Katalog (`Yoursel71/alpbahOS-alp`, HEAD `90ab3a1`, 48 girdi) | 28 yerde `@PREFIX@`, 3 yerde `@DESTDIR@` kullanıyor. |
| Rootfs'te kurulu motor `/usr/lib/alp/alp.py` (SHA-256 `0475ea32…`) | İki yer tutucuyu da **hiç genişletmiyor** (`grep -c` = 0). |
| Kurulu `alp` başlatıcısı | `alp update` her zaman GitHub `main` tarball'ını çekiyor; motor sabit kalırken katalog ilerliyor. Ayrışma her güncellemede yeniden oluşur. |

Yeniden üretim (Fedora, bu oturumda): kurulu motorun kopyası + gerçek katalog, `--dry-run install htop` → `[dry-run] $ ./configure --prefix=@PREFIX@`. Bu daldaki motor + aynı katalog → `./configure --prefix=/usr`.

Yeni motorla **gerçek** kur → çalıştır → kaldır (geçici kök, Fedora hostu, ağdan htop 3.3.0 indirildi): build log'da `./configure --prefix=/usr`, `htop --version` = `htop 3.3.0`, `alp --json list` doğru, `remove` sonrası dosya yok, `alp check`: sorun yok. Bu hedef rootfs'te değil, host'ta yapıldı.

## 2. Ne değişti (alp motoru)

1. **Bilinmeyen `@YER_TUTUCU@` erken hata verir.** Katalog motordan yeniyse (`@LIBDIR@` gibi) literal `./configure`'a ulaşıp indirmeden sonra düşmek yerine, indirme/derleme öncesinde "alp'i güncelleyin" mesajıyla durur. Yalnız `@[A-Z][A-Z0-9_]*@` biçimi. Kurulu eski motor bu korumayı taşımaz; yalnız bu sürümden sonraki ayrışmaları yakalar.
2. **`alp info` ve `alp --json search` sürüm, lisans, ana sayfa, boyut verir** (bilinenler): tarif dosyasındaki `version`/`license`/`homepage`, girdideki isteğe bağlı `size` (indirme boyutu, bayt). Girdideki alan tarifteki alanı ezer. Hiçbiri tahmin edilmez; bozuk/eksik tarif yalnız kendi alanlarını düşürür, aramayı bozmaz. `search` satırlarına `version` eklenmesi **eklemeli sözleşme değişikliğidir**: `test_packagekit_backend.py::test_alp_search_finds_real_entry` eski tam eşitliği bekliyordu, ek anahtarı içerecek şekilde güncellendi. Bilinen tüketiciler adlandırılmış anahtar okuyor (`item["name"]`, `.get("description")`).

## 3. Doğrulama (çalıştırılanlar)

- `python3 -m pytest docs/handoffs/claude/alp-prototype/tests`: **238 geçti, 0 atlandı** (PR #3 öncesi Linux tabanı 223; +15 yeni). PR #3'ün "205 geçti/18 atlandı" ölçümü Windows'tandı; Linux'ta atlanan 18 test de geçiyor.
- Yeni 15 testin **13'ü eski `alp.py`'de başarısız** (gerçek regresyon testi); 2'si değişmemesi gereken davranış korumasıdır.
- `check_docs.py`: 0 bulgu.
- Yardımcı yaması çevrimdışı doğrulandı (`patches/019-verify_alpbackend.py`): rootfs'in kendi `packagekit` Python modülü (salt okunur) + gerçek alp + gerçek katalog ile PackageKit tel satırları karşılaştırıldı:

| | package id | `details` (bytes / download_bytes) |
|---|---|---|
| Orijinal yardımcı | `htop;0;all;alp` | 18446744073709551615 / 18446744073709551615 |
| Yamalı | `htop;3.3.0;all;alp` | 18446744073709551615 / 18446744073709551615 |
| Yamalı + katalogda `size` | `htop;3.3.0;all;alp` | 18446744073709551615 / 1600000 |

`18446744073709551615` (MAXUINT64) Discover'da "16.0 EiB" olarak çıkan değerdir; `Version: 0` da yardımcının sürümü `"0"` olarak sabitlemesinden geliyordu.

- **Yaşam döngüsü (host'ta, `019-verify_alpbackend.py ... --lifecycle`):** yamalı yardımcı + bu daldaki motor + gerçek katalog, geçici kökte, süreç içinde: `install_packages` (htop gerçekten derlendi, `_installed()` = htop 3.3.0) → katalog htop'u 3.3.1'e çıkarılınca `get_updates` **`htop;3.3.1;all;alp`** üretti (yardımcının `^güncelleme var: …$` regex'i `alp check` çıktısıyla eşleşiyor; `(alp upgrade)` ekli biçim `alp update`'ten gelir, yardımcı onu kullanmaz) → `search_name` kurulu paketi *kurulu* sürümüyle (3.3.0) gösterdi → `remove_packages` sonrası DB boş. Sonuç `LIFECYCLE: PASS`. Bu, `pkcon install htop`'un host tarafındaki karşılığıdır; PackageKit daemon'u ve Discover **yok**.
- **Koruma yanlış pozitif taraması:** kataloğun 21 tarifinin tamamı `alp._recipe_steps`'ten geçirildi: `AlpError` yok, hiçbir argümanda `@` kalmadı (ham katalogda yalnız `@PREFIX@` ve `@DESTDIR@` var).
- **Metadata kapsamı:** `alp --json search ""` 48 girdinin tamamını dolaştı: 21 tarif satırının hepsi `version` taşıyor, 27 Flatpak satırında sürüm uydurulmuyor; hiçbir satırda `size`/`license`/`homepage` **yok** (katalog bunları henüz vermiyor, §5).

## 4. Entegrasyon (tek yazıcı: Codex) — önerilen sıra

Hiçbiri bu oturumda uygulanmadı. Bir atılabilir overlay'de dene, sonra rootfs'e al.

1. **Motoru dağıt.** Kaynak: bu daldaki `docs/handoffs/claude/alp-prototype/alp.py`, SHA-256 `92d519212d161159f6f083008b14c7b5b22c2d3e7e60f49fe17d493538fe25b2` (kopyadan önce `sha256sum` ile doğrula). Hedef `/usr/lib/alp/alp.py`; rootfs'teki mevcut dosya `0475ea32…`. **Dalı `alpbahOS-work` ağacına birleştirme:** o ağaç `a9bac38`'de ve çok sayıda commit'lenmemiş belge içeriyor; yalnız dosyayı hash ile kopyala (motoru `0475ea32…` → yeni sürüme taşımak `3f6f0f1`, `9475ce1`, `6243c44` ve PR #3'ü de birlikte getirir; `6243c44` Türkçe hata/yardım metinlerini değiştirir, yardımcı bunları ayrıştırmıyor, ama `get_updates` `alp check` metnini ayrıştırıyor: yukarıda doğrulandı). PR #3 açıklamasına göre (kodu bu oturumda okunmadı) `scripts/apply-m2-rootfs-fixes.sh` artık rootfs'teki motoru sessizce eski sürüme döndürmüyor; bilinçli değiştirme için `ALP_REPLACE=1` ve `EXPECTED_ALP` gerekir. Bu betik PR #3 birleşmeden Codex ağacında eski davranışta.
2. **Yardımcı yamasını uygula:** `patch -p1 < docs/handoffs/claude/patches/019-alpBackend-metadata.patch` (Codex ağacında `scripts/packagekit/alpBackend.py`; yama tabanı `e3cdda16…`, rootfs'teki `/usr/share/PackageKit/helpers/alp/alpBackend.py` ile aynı, `--dry-run` temiz uygulandı). Sonra rootfs'e aynı dosyayı kur.
3. **Wallpaper + Solid look-and-feel'i kur.** Rootfs'te (salt okunur bakıldı) yalnız Breeze look-and-feel'leri var; ne `/opt/kf6/share/wallpapers` ne `/usr/share/wallpapers` var, ve `org.alpbahos.solid.desktop` kurulu değil. Siyah arka planın nedeni olarak bu **büyük olasılıkla** yeterli, ama VM'de doğrulanmadı.

   ```bash
   profiles/desktop/install-desktop-profile.sh --destdir /mnt/lfs \
       --manifest <log dizini>/m08-desktop.manifest
   ```

   Yol seçimi (kanıt): oturum ortamını `/etc/profile` değil Codex'in `environment.d` dosyaları kuruyor (`build-m2-gen2-test-image.sh:265-266`, `sanitize-m09-live-rootfs-view.py:354-355`) ve şunları veriyor: `XDG_DATA_DIRS=/opt/kf6/share:/opt/qt6/share:/usr/local/share:/usr/share`, `XDG_CONFIG_DIRS=/opt/kf6/etc/xdg:…:/etc/xdg`. Betiğin **varsayılan** yolları (`/usr/share`, `/etc`) bu ortamda aranıyor; `/opt/kf6/...` (`--datadir /opt/kf6/share --sysconfdir /opt/kf6/etc`) de aranıyor. (Rootfs'teki `/etc/profile` `profile.d`'yi kaynak almıyor; `kf6.sh` oturum ortamının kaynağı değil.) Her iki yol da geçici bir stage'e kuruldu: 20 dosya doğru yollara düştü (`…/plasma/look-and-feel/org.alpbahos.solid.desktop`, `…/wallpapers/alpbahOS-Ataturk`, `…/xdg/{kdeglobals,kwinrc,kglobalshortcutsrc}`). Farklı içerikli dosyanın üzerine yazmaz. Gerçek Plasma oturumunda görüntülenme **doğrulanmadı**.

   **Not:** `alpbahOS-work` ağacı `a9bac38`'de; PR #1'i (bu paketi getiren) içermiyor. `profiles/desktop` ve `branding/` için önce `origin/main` (9c26ecf) alınmalı. Ayrıca yeni oturumda görünmesi için `look-and-feel` layout betiği yalnız **ilk girişte** uygulanır; canlı kullanıcının önceden üretilmiş Plasma yapılandırması (`plasma-org.kde.plasma.desktop-appletsrc`) varsa arka plan değişmeyebilir.
4. **Kabul (atılabilir overlay, gerçek Plasma oturumu):** `pkcon install htop` → `htop --version` → `pkcon remove htop`; ardından `alp check` ve DB boş. Discover ayrıntı sayfasında sürüm `3.3.0`. Yeni oturumda masaüstü arka planı Atatürk görseli.

## 5. Bilinen sorun ve açık karar

- **"Size: 16.0 EiB" büyük olasılıkla kalır.** Kaynaktan derlenen tarifin *kurulu* boyutu derlemeden önce bilinemez; yama bunu PackageKit'in "bilinmiyor" (MAXUINT64) değerinde bırakır ve Discover bunu birebir yazar. Yama bilinen indirme boyutunu `download_bytes`'a koyar. Bilinmeyen boyutu Discover'da nasıl göstereceğimiz açık UI kararı; Discover kaynağı bu makinede bulunamadı, bu yüzden `bytes=0` gibi bir deneme **yapılmadı**. Öneri: atılabilir VM'de tek satırlık deney (`bytes=0`) ve sonucu kaydetmek.
- **Lisans/ana sayfa hâlâ "unknown"/boş.** Motor ve yardımcı alanları taşıyor, ama kataloğun 21 tarifinde `license`/`homepage` **doldurulmadı**: doğrulanmamış lisans yazmak yerine kaynak arşivlerinden doğrulanıp ayrı bir katalog commit'inde eklenmeli.
- **Genel simge ve "tam erişim" izni** Codex'in AppStream üreticisinden (`generate_alp_appstream.py`, `package-x-generic`) ve Discover'ın genel-paket varsayımından geliyor; bu belgede ele alınmadı.
- **Katalog–motor eşleşmesi süreç sorunu:** `alp update` katalogu çekiyor, motoru çekmiyor. Kalıcı çözüm (ör. index'te asgari motor sürümü alanı) katalog deposunda ve motorda birlikte tasarlanmalı; bu turda yapılmadı.
- **Polkit GUI onayı** ve **Discover "Kur" düğmesi** bu belgenin kapsamı dışında, doğrulanmadı.

## 6. Çalıştırılmadı

VM/QEMU, Discover, gerçek PackageKit daemon'u ve hedef rootfs'te herhangi bir paket işlemi **çalıştırılmadı**. Oturum sırasında Codex aktifti (`lfs-build-writer.lock` ve kendi QEMU VM'i görüldü); tek yazıcı kuralı gereği rootfs'e ve VM'lere dokunulmadı. Yukarıdaki kur/kaldır kanıtı Fedora hostunda geçici bir kökte alındı.
