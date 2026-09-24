# Claude devir belgesi 014: `alp` M02 kapanışı (geri alma, recover, korumalı paket, update)

```text
Görev ID / durum: M02 (paket motoru) Claude kısmı. Kullanıcı 24 Eylül 2026'da "m2'yi kapat" dedi. `alp.py` tarafı tamamlandı; M02'nin resmî kapanışı Codex entegrasyonuna bağlı (aşağıda). Rootfs'e KURULMADI.
Çalışılan host ve branch/commit: Windows (kod ve test) + Builder yrsk (Ubuntu 24.04.5, kullanıcı sa; yalnız /tmp/claude-alp-m2, iş sonunda silindi). Dal claude/desktop-bootstrap; main 8cc0445 birleştirildi. Bu belgeyle birlikte commit.
Test edilen alp.py SHA-256: 3c72bbf27ee601311c1b84c8968c45ebafb951841229b08b01463ee363fe1c89 (Windows ve Builder kopyası aynı).
Değişen dosyalar: alp-prototype/alp.py, alp-prototype/tests/test_m02_rollback.py (yeni), alp-prototype/README.md, bu belge.
Gerçekleştirilen davranış: aşağıda.
Çalıştırılan doğrulama ve sonuç: aşağıda.
Bilinen sorun ve açık karar: aşağıda.
Entegrasyon için gereken: Codex rootfs'e bu commit'ten kurmalı (bkz. "Codex için").
Sonraki eylem: yok (Codex entegrasyonu ve M04 taban kaydı bekleniyor).
```

## Önce bir düzeltme

23 Eylül gecesi başka bir Claude oturumu Seviye 3'ü (sürüm kısıtları, `conflicts`, **ters bağımlılık koruması**, `autoremove`, tam sistem `upgrade`, `alp check`) yazmış ve `8df1ac4` ile commit'lemişti (belge 013), ama push'lanmamıştı. Bu oturumun ilk yarısında "ters bağımlılık kontrolü yok" demiştim; o yanlıştı. Bu işi yinelemedim; `8df1ac4` bu commit ile birlikte push'landı.

## Ne yapıldı

**1. İşlemsel geri alma (M02'nin asıl eksiği, bilinen sınır 2).** `FileJournal` + `_transaction()` (alp.py). Her paket için dosya değişiklikleri ile veritabanı güncellemesi tek işlemdir:
- Her yazma/silme/mkdir'den **önce** günlüğe (`var/lib/alp/rollback/<zaman>-<pid>-<paket>/journal.jsonl`) satır yazılır ve ezilecek dosyanın yedeği alınır (sabit bağlantı; olmazsa `copy2`).
- Hata, veritabanı yazma hatası ya da Ctrl-C olursa günlük tersten oynatılır: yazılan dosyalar silinir, ezilen dosyalar/symlink'ler geri gelir, silinen dosyalar (yükseltmede artık gelmeyenler dahil) geri gelir, `merge`'in yarattığı dizinler kaldırılır.
- Değişmez kural: alp dosyaları yerinde yazmaz (geçici kardeş dosya + `os.replace`); bu yüzden sabit bağlantı yedeği eski içeriği korur. (Testi bunu gösterdi: yerinde yazan bir simülasyon yedeği de bozuyordu.)
- Başarıda veritabanı kaydedildikten sonra günlüğe `commit` işareti yazılır ve dizin silinir.
- Kapsam: `install`, `upgrade`, `--reinstall`, `remove`, `autoremove` (recipe ve core). Flatpak kendi araç zincirini kullanır, kapsam dışı.

**2. `alp recover`.** `kill -9`/elektrik kesintisiyle yarım kalan işlemi günlükten geri alır (en yeniden eskiye). `commit` işareti olan günlüğe dokunmaz. Yarım günlük varken `install/upgrade/remove/autoremove/update` reddedilir; `alp check` "SORUN" olarak gösterir ve çıkış kodu 1 döner.

**3. Korumalı paket.** `alp protect|unprotect NAME`; katalog girişinde `"protected": true` kurulumda kayda geçer. Korumalı paket `remove`, `remove --cascade` (bağımlı olarak da) ve `autoremove` ile kaldırılmaz; yükseltilebilir ve yükseltmede işareti korunur. `list --json` alanı yalnız `true` iken yazar (PackageKit'in ayrıştırdığı sözleşme değişmedi; ilk denemede alanı hep yazmak iki mevcut testi kırdı, geri aldım).

**4. Gerçek `alp update`.** Kaynak: `--source` ya da `index.json`'daki `"source"` alanı; düz `index.json` ya da tepesinde `index.json` olan `.tar.gz` katalog paketi. `http://` indirmeden reddedilir. Yeni katalog önce doğrulanır (`entries` var mı, yöntemler tanımlı mı, tarif dosyaları katalog içinde ve okunur mu, core'da `url`/`sha256` var mı); `--sha256` verilirse denetlenir. Fark basılır (yeni/değişti/kalktı, kurulu paketler için `güncelleme var`). `--dry-run` hiçbir şeyi değiştirmez. Uygulama sırası: paket dosyaları, `index.json` en son (katalog hiçbir zaman olmayan dosyaya işaret etmez); önceki `index.json` `index.json.prev` olarak, değişen dosyalar `.alp-catalog-prev/` altında kalır. Reddedilen her durumda yerel katalog aynı kalır ve `.alp-update` çalışma dizini silinir.

**5. Build temizliği (bilinen sınır 6).** Başarılı recipe kurulum/yükseltmesinden sonra build ve DESTDIR ağaçları silinir; başarısız build'de kalır; `--keep-build` hepsini saklar.

## Doğrulama

- **Windows** (Python 3.14): `python -m pytest tests/ -q` → **153 geçti, 12 atlandı** (symlink/mod/gerçek izin/eski kilit testleri bu hostta yapılamaz).
- **Linux** (Builder, Ubuntu 24.04.5, Python 3.12.3, kullanıcı `sa`, root değil; pytest wheel'den `PYTHONPATH` ile): **165 geçti, 0 atlandı**. Bu koşuda atlanan gerçek izin testi de çalıştı: `usr/share/tool` salt okunur yapıldı, yükseltme gerçek `EACCES` ile düştü, her dosya ve veritabanı eski hâline döndü.
- **Mutasyon kontrolü:** 12 bilinçli bozma (geri alma oynatılmıyor, merge günlüğe yazmıyor, silme günlüğe yazmıyor, `commit` işareti yok sayılıyor, korumalı paket koruması yok, orphan korumalıyı siliyor, bekleyen günlük denetimi yok, `http://` kabul, katalog doğrulaması yok, checksum yok sayılıyor, `_run_plan`'da işlem yok, build temizliği yok). **12'si de** testlerce yakalandı. Bir tanesi ilk turda hayatta kalmıştı (`http://` testi hata mesajında URL geçtiği için tesadüfen geçiyordu); test indirmenin hiç çağrılmadığını doğrulayacak şekilde sıkılaştırıldı.
- **Gerçek `kill -9` (Builder, izole `/tmp`):** gerçek `alp.py` ile `demo` paketi 1.0.0 kuruldu; ikinci sürümün yükseltmesi, ikinci dosya kopyalandıktan hemen sonra süreç kendine `SIGKILL` gönderdi (çıkış kodu -9). Sonuç: `usr/bin/demo` ve `usr/share/demo/a` yarım değişmişti, veritabanı hâlâ `1.0.0`, günlük dizini kalmıştı. Sonraki `upgrade` reddedildi, `alp check` "1 yarım kalmış işlem" dedi. `alp recover` → "geri alındı"; dosya sistemi yükseltme öncesiyle **birebir aynı**, günlük dizini boş. Yeniden `upgrade` başarılı (`v2`), `usr/bin/demo` modu `0755`.

## Çalıştırılmadı / bilinen sınırlar

1. **Gerçek `/mnt/lfs` rootfs'te denenmedi** (rootfs'e kurulmadı; sahibi Codex). `--root` ile sahte LFS düzeninde ve gerçek Linux'ta denendi.
2. **Elektrik kesintisi** (fsync yok): günlük her satırdan sonra `flush` edilir, `fsync` edilmez. Süreç ölümü (`kill -9`) kapsanır; ani güç kaybında son satırlar kaybolabilir (kesik son satır tolere edilir ama kaybolan satırın işlemi geri alınmaz). Bedeli binlerce dosyada yavaşlamak olurdu; karar gerekirse `fsync` eklenir.
3. **Küçük pencere:** veritabanı kaydedildikten sonra `commit` işareti yazılmadan süreç ölürse `recover` yeni dosyaları geri alır ama veritabanı yeni sürümü söyler. Pencere tek satırlık bir yazma; kapatılmadı.
4. **Yedek sabit bağlantı** aynı dosya sistemi ister; `var/lib/alp` ayrı bir bağlama noktasındaysa `copy2`'ye düşer (yavaş ama doğru). Bu yol testlerde zorlanmadı.
5. **Katalog imzalı değil** (`update`): güven https + isteğe bağlı `--sha256`. Katalog imzası ayrı bir karar/iş.
6. **Bağımlılık çözümü hâlâ sınırlı**: katalogda paket başına tek sürüm, SAT çözücü yok (belge 013). Gerçek katalogdaki (alpbahOS-alp) 4 tarifte `depends` hâlâ yok.
7. **Flatpak** yolu ve **Discover/PackageKit** gerçek daemon testi yapılmadı (M02'nin GUI kabul koşulu hâlâ açık).
8. **Taban sistem sahipliği (M04)** `alp` veritabanında yok; korumalı-paket mekanizması hazır, dolduracak veri Codex'te.

## Codex için (entegrasyon)

1. `git show <bu commit>:docs/handoffs/claude/alp-prototype/alp.py | sha256sum` → `3c72bbf27ee601311c1b84c8968c45ebafb951841229b08b01463ee363fe1c89` olmalı. Bu, rootfs'teki `e8b0376` sürümünün (`7b2998a5…`) yerini alır; arada Seviye 3 (`8df1ac4`) ve bu iş var.
2. Rootfs'e kurduktan sonra hash'i doğrula; yeni imajda `alp --help` komut listesinde `recover`, `protect`, `unprotect`, `update` görünmeli.
3. Gerçek rootfs'te (yalnız bir test imajında, `/mnt/lfs`'de değil önce): `alp upgrade` başarılı, ardından kasıtlı `kill -9` ile `alp recover` denemesi. Benim `kill -9` betiğim belgede anlatıldığı gibi tekrarlanabilir.
4. M04'te taban paketlerin kaydı girildiğinde `"protected": true` işaretle (ya da `alp protect`); ayrıca `alp remove` taban paketlerinde bu sayede reddedilir.
5. M02'yi kapatmak için Codex'in yapacağı: (a) yukarıdaki 1-3, (b) Discover/PackageKit'in gerçek daemon'la denenmesi. (b) yapılmadan M02 "Kısmi" kalır; kanıtsız kapatma.
6. `python docs/handoffs/claude/tools/check_docs.py` bu dalda çalıştırıldı (main birleştirildikten sonra): **0 bulgu** (broken-link=0, commit-ref=0, decision-ref=0, stale-term=0).

## Kapsam dışı bırakılan istek

Kullanıcı bu turda "M04'ü de kapat" dedi. M04 Codex'in alanı ve alt ajanlarla yürüyor; `alp` tarafında M04 için yalnız koruma mekanizması eklendi (madde 3).
