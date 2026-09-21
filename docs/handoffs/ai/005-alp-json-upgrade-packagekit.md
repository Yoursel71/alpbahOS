# Claude devir belgesi 005 — `alp`: `upgrade` + `.alpnew`/`.alpsave` + `--json` + PackageKit backend kodu

Görev ID / durum: (Backlog dışı, kullanıcı talebi — "PackageKit + config koruma tasarımlarını gerçekten kodla") tamamlandı.

Çalışılan host ve branch/commit: Windows host, worktree `C:\alpbahOS-claude`, dal `claude/desktop-bootstrap`. Bu belgenin yazıldığı anda henüz commit atılmadı; hash bu turun commit'iyle güncellenecek.

Değişen dosyalar:
- `docs/handoffs/claude/alp-prototype/alp.py` (upgrade, config-aware merge, `.alpsave`, `--json`)
- `docs/handoffs/claude/alp-prototype/alp_packagekit_backend.py` (yeni)
- `docs/handoffs/claude/alp-prototype/tests/test_alp.py` (+12 test)
- `docs/handoffs/claude/alp-prototype/tests/test_packagekit_backend.py` (yeni, 7 test)
- `docs/handoffs/claude/alp-prototype/README.md`
- `docs/handoffs/claude/alp-prototype/design/config-protection.md` (durum güncellendi: koda döküldü)
- `docs/handoffs/claude/alp-prototype/design/packagekit-integration.md` (durum güncellendi: kısmen koda döküldü)
- `docs/handoffs/claude/001-alp-hybrid-pkg-proposal.md` (gap tablosu güncellendi)
- `docs/handoffs/claude/005-alp-json-upgrade-packagekit.md` (bu dosya)

Gerçekleştirilen davranış:

**1. `--json` çıktı modu:** `cmd_search`/`cmd_list` artık `as_json` parametresi alıyor, `--json` global bayrağıyla tetikleniyor. `cmd_info` zaten JSON basıyordu, değişmedi.

**2. Config koruma + `alp upgrade`:** `design/config-protection.md`'deki tasarım birebir kodlandı:
- `_config_aware_merge()` — staged bir ağacı hedefe kopyalarken, `config_files` listesindeki her yol için pacman'ın pacnew karar ağacını uygular (değişmemiş -> sessizce üzerine yaz; değişmiş -> `.alpnew` yaz, kullanıcının dosyasına dokunma).
- `upgrade_recipe()` / `upgrade_core()` — mevcut `install_recipe`/`install_core`'un fetch/build/extract mantığını yeniden kullanıp `_config_aware_merge` ile birleştiriyor; düşen dosyaları (`_drop_stale_files`) temizliyor.
- `remove_package()` artık config dosyaları için `.alpsave` üretiyor (değiştirilmiş dosya siliniyor değil, `<yol>.alpsave` olarak korunuyor).
- `cmd_upgrade` + CLI `upgrade` alt komutu eklendi; `flatpak` yöntemi için açıkça reddediliyor (flatpak kendi günceller).
- `install_recipe`/`install_core`'un gerçek-kurulum dönüşleri artık `config_files`/`config_hashes` alanlarını da dolduruyor (ileride upgrade'in karşılaştıracağı taban).

**3. PackageKit backend kodu:** `alp_packagekit_backend.py` iki katmanlı: (a) `alp_search/list/info/install/remove/upgrade` — gerçek `alp.py`'yi subprocess ile çağırıp JSON ayrıştıran, PackageKit'e hiç bağımlı olmayan sarmalayıcılar; (b) `AlpPackageKitBackend(PackageKitBaseBackend)` — design belgesindeki yöntem eşlemesinin gerçek kodu, `packagekit.backend` import'una bağımlı.

Çalıştırılan doğrulama ve sonuç:
- **Regresyon yok:** Önceki 29 test hâlâ geçiyor (değişmeden).
- **12 yeni upgrade/config testi geçti:** değiştirilmemiş config sessizce yükseltiliyor; değiştirilmiş config `.alpnew` üretiyor VE kullanıcının dosyası birebir korunuyor VE kayıtlı hash bilerek değişmiyor (tasarımın kendi kararı); `remove` değiştirilmiş config'i `.alpsave` yapıyor, değiştirilmemişi normal siliyor; düşen dosyalar upgrade'de temizleniyor; `upgrade --dry-run` hiç `fetch()` çağırmıyor (install'daki aynı disiplin); `cmd_upgrade` bilinmeyen/kurulu-olmayan/flatpak paketleri reddediyor; uçtan uca CLI testi (`install` sonra `upgrade`, gerçek dosya içeriği değişiyor, db güncelleniyor) geçti.
- **7 yeni PackageKit-sarmalayıcı testi geçti, GERÇEK subprocess ile** (mock değil): `alp_search` gerçek eşleşme buluyor, `alp_install/list/info/remove` uçtan uca döngü çalışıyor, bilinmeyen paket `AlpBackendError` fırlatıyor, kilit çakışması `is_locked=True` olarak doğru tespit ediliyor.
- **Test yazarken iki test hatası bulundu ve düzeltildi** (implementasyon değil, testin kendisi yanlıştı): (a) `"ho"` aslında `"htop"`'un alt dizesi değil (yanlış test verisi), (b) `.alpnew` testinde yanlış hash karşılaştırması bekleniyordu — tasarımın kendi kuralına göre düzeltildi (kayıtlı hash, kullanıcının değiştirdiği içerikle değil, ESKİ kurulum-anı hash'iyle eşleşmeli).
- **Hâlâ çalıştırılamayan/test edilemeyen:** `AlpPackageKitBackend` sınıfı (bu ortamda `packagekit` modülü yok — hiç import edilemedi); gerçek `recipe` yöntemiyle (toolchain gerektiren) bir `upgrade` döngüsü; gerçek bir PackageKit daemon'una backend'in yüklenip `pkcon`/Discover ile denenmesi.

Log / ekran görüntüsü / artifact: pytest çıktısı bu belgenin "Çalıştırılan doğrulama" bölümünde özetlendi (48/48 yeşil).

Bilinen sorun ve açık karar:
1. `AlpPackageKitBackend`'in kullandığı `packagekit.backend`/`packagekit.enums` API'lerinin tam imzaları bu ortamda doğrulanamadı — genel bilinen backend sözleşmesine göre yazıldı, Codex'in gerçek bir PackageKit kurulumunda satır satır kontrol etmesi gerekiyor.
2. `GetUpdates`/`update-packages`'ın "hangi paketlerin yeni sürümü var" tarafı (index.json vs db.json sürüm karşılaştırması) henüz `alp`'e eklenmedi; `update_packages()` var ama yalnızca bilinen bir paketi yükseltiyor, "tüm güncellemeleri listele" akışı yok.
3. `upgrade`'in `recipe` yöntemi hâlâ hiçbir gerçek Linux ortamında (toolchain'le) çalıştırılmadı.

Entegrasyon için gereken: Codex'in gerçek BLFS/PackageKit ortamı (`AlpPackageKitBackend`'i gerçek daemon'a yükleyip test etmek için) ve LFS toolchain'i (recipe upgrade'i test etmek için).

Sonraki eylem: Yok — kullanıcı isteği tamamlandı. Sıradaki gerçek iş Codex'in Cumartesi dönüşüne veya kullanıcının başka bir önceliklendirmesine bağlı.
