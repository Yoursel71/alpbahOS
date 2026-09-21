# `alp` — Yapılandırma koruma (`upgrade` + `.alpnew`/`.alpsave`) tasarımı

Durum: **koda döküldü ve test edildi (21 Eylül 2026).** `_config_aware_merge()`, `upgrade_recipe()`/`upgrade_core()`, `cmd_upgrade`, ve `remove_package`'ın `.alpsave` dalı `alp.py`'ye eklendi. 12 yeni test (`tests/test_alp.py`) bu davranışı gerçekten doğruladı: değiştirilmemiş config sessizce yükseltiliyor, değiştirilmiş config `.alpnew` üretip kullanıcının dosyasına dokunmuyor, `remove` değiştirilmiş config'i `.alpsave` olarak koruyor, düşen dosyalar temizleniyor. **Hâlâ test edilmeyen:** gerçek bir Linux ortamında `recipe` yöntemiyle (`configure/make` gerektiren) uçtan uca bir upgrade — bu hostta toolchain yok, yalnızca `core` yöntemiyle (yerel dosya tabanlı) uçtan uca doğrulandı.

Proposal belgesinin (§6) kendi karşılaştırma tablosundaki en büyük açığı kapatmak için yazıldı: *"Yapılandırma korunması: Yok — prototip güncelleme/upgrade akışını hiç ele almıyor, sadece install/remove."* Aşağıdaki tasarım, pacman'ın `pacnew`/`pacsave` mekanizmasının (kullanıcıların zaten aşina olduğu, kanıtlanmış bir UX deseni) `alp` karşılığıdır — sıfırdan bir mekanizma icat etmek yerine bilinen, iyi anlaşılmış deseni yeniden kullanmak, AGENTS.md'nin "hazır bileşenleri özelleştir, icat etme" ruhuna uygun (burada "bileşen" bir UX deseni). Aşağıdaki metin orijinal tasarım olarak korunuyor; gerçekleşen kod bire bir bu tasarımı izledi.

## 1. Kapsam

Şu an `alp`'te **`upgrade` komutu yok** — `alp.py`'nin `build_parser()`'ında yalnızca `search/info/install/remove/list/update` alt komutları var, `update` de şu an yalnızca "index.json'ı yeniden okur" diyen bir no-op (`cmd` fonksiyonlarında `upgrade` hiç tanımlı değil). Bu tasarım iki yeni parça öneriyor:

1. Manifest şemasına `config_files` alanı (hangi kurulu dosyaların "yapılandırma" sayıldığını işaretlemek için).
2. Yeni bir `alp upgrade <ad>` komutu ve onun `.alpnew`/`.alpsave` davranışı.

## 2. Manifest şeması genişletmesi

Recipe/core girdilerine isteğe bağlı bir alan eklenir:

```json
{
  "name": "htop",
  "version": "3.3.1",
  "...": "...",
  "config_files": ["/etc/htoprc.default"]
}
```

`config_files`, `files[]`'in bir alt kümesidir — kurulum sırasında `_merge_destdir`/`safe_extract`'in ürettiği tam yol listesiyle kesiştirilir. Bu, Debian'ın `conffiles` listesine veya pacman'ın `.PKGINFO` içindeki `backup` dizisine denk düşer; yeni bir kavram değil, iyi bilinen bir desenin `alp` şemasına eklenmesi.

## 3. `db.json` şema genişletmesi

Her paket kaydına, yalnızca `config_files` içindeki yollar için bir hash tablosu eklenir (tüm dosyalar için değil — db'yi şişirmemek için):

```json
{
  "name": "htop",
  "version": "3.3.0",
  "...": "...",
  "config_hashes": {
    "/etc/htoprc.default": "<kurulum anındaki sha256>"
  }
}
```

Bu, `save_db`'nin zaten yaptığı atomik yazma (`tmp` + `replace`) ile aynı yoldan kalıcı olur — yeni bir dosya/kilit mekanizması gerekmez.

## 4. `alp upgrade <ad>` akışı

```
1. db.json'dan eski kaydı oku (yoksa: "kurulu değil", dur).
2. index.json'dan yeni sürümün recipe/core girdisini çöz.
3. Yeni sürümü indir + checksum doğrula (mevcut fetch() aynen kullanılır).
4. Yeni sürümü geçici bir DESTDIR/extract alanına aç (mevcut install_recipe/
   install_core adımlarıyla aynı — kod tekrarı yerine bu fonksiyonlar
   "hedef kök" parametresiyle yeniden kullanılabilir).
5. Eski files[] ile yeni dosya listesini karşılaştır:
   a. Yalnız eskide olan, config olmayan dosyalar -> silinir (kaldırılan
      dosya, mevcut remove_package mantığıyla aynı, dizin temizliği dahil).
   b. Yalnız yenide olan dosyalar -> normal kopyalanır.
   c. Her iki sürümde de olan, config OLMAYAN dosyalar -> üzerine yazılır.
   d. config_files içindeki her yol için §5'teki karar ağacı uygulanır.
6. db.json'u yeni kayıtla (yeni files[], yeni config_hashes) güncelle.
7. Oluşan .alpnew dosyalarının tam listesini kullanıcıya YAZDIR (sessizce
   bırakılmaz) -- pacman'ın "Warning: .pacnew files" çıktısının eşdeğeri.
```

## 5. Karar ağacı: bir config dosyası neden `.alpnew` üretir

Her `config_files` yolu için:

```
mevcut_hash = sha256(diskteki dosya)   # dosya yoksa: "silinmiş" durumu, ayrı ele alınır
kayitli_hash = db.json'daki config_hashes[yol]   # kurulum/son upgrade anındaki hash
yeni_hash = sha256(yeni sürümdeki dosya)

eğer mevcut_hash == kayitli_hash:
    # kullanıcı hiç dokunmamış -> güvenle üzerine yaz
    diskteki dosyayı yeni içerikle değiştir
    config_hashes[yol] = yeni_hash
aksi halde (mevcut_hash != kayitli_hash):
    # kullanıcı değiştirmiş -> kullanıcının dosyasına DOKUNMA
    yeni içeriği "<yol>.alpnew" olarak yaz
    config_hashes[yol] = kayitli_hash   # değişmeden kalır; kullanıcının
                                         # dosyası hâlâ "değiştirilmiş" sayılır
    "<yol>.alpnew oluşturuldu, elle birleştirin" diye kullanıcıya bildir
```

Bu, pacman'ın `.pacnew` mantığıyla birebir aynı karar ağacı — kasıtlı olarak, kullanıcıların zaten bildiği bir davranış yeniden icat edilmiyor.

## 6. `alp remove` ile etkileşim (`.alpsave`)

Mevcut `remove_package` (alp.py) config farkını hiç bilmiyor — tüm `files[]`'i koşulsuz siliyor. Bu tasarımla:

```
remove_package çağrıldığında, config_files içindeki her yol için:
    mevcut_hash = sha256(diskteki dosya)
    kayitli_hash = config_hashes[yol]
    eğer mevcut_hash == kayitli_hash:
        normal sil (mevcut davranış)
    aksi halde:
        "<yol>.alpsave" olarak kopyala, sonra sil
        "<yol>.alpsave olarak saklandı" diye bildir
```

`remove_package`'ın geri kalanı (dosya/dizin temizliği, ters-sıralı silme — bkz. `003-alp-review-fixes.md`'deki dizin düzeltmesi) **değişmeden kalır**; yalnızca config dosyaları için bu ek dal eklenir.

## 7. Test planı (mevcut `tests/test_alp.py` desenine uyar)

Uygulandığında eklenecek testler (şimdiden tanımlanıyor, henüz yazılmadı):

1. `test_upgrade_overwrites_untouched_config` — kurulum sonrası config dosyasına dokunulmadan upgrade; yeni içerik doğrudan yazılır, `.alpnew` oluşmaz.
2. `test_upgrade_preserves_modified_config_as_alpnew` — config dosyası elle değiştirilir, upgrade sonrası orijinal (kullanıcının değiştirdiği) dosya aynen durur, `<yol>.alpnew` yeni içerikle oluşur.
3. `test_remove_untouched_config_deletes_normally`.
4. `test_remove_modified_config_creates_alpsave`.
5. `test_upgrade_removes_files_dropped_in_new_version` (eski sürümde olup yeni sürümde olmayan, config olmayan dosyaların temizlendiği — mevcut dizin-temizliği mantığıyla tutarlı).

## 8. Bu tasarımın bilerek ele almadığı şeyler

- **Üç yönlü birleştirme (merge)** — pacman da bunu yapmaz, kullanıcı elle `.pacnew`'i birleştirir; `alp` aynı sınırı kabul ediyor, daha iyisini vaat etmiyor.
- **Flatpak yöntemi** — config kavramı yok, flatpak kendi veri/config dizinlerini (`~/.var/app/`) kendi yönetir; bu tasarımın kapsamı dışında (proposal §6'da zaten "flatpak'ta yok — kasıtlı" diye işaretli).
- **Bağımlılık/ABI kırılması senaryoları** (ör. bir kütüphane sürüm atlarken uyumsuz hale gelmesi) — proposal §6'nın "sürüm geçişleri ... hiç ele alınmıyor" notuyla aynı, bu tasarım da onu çözmüyor, yalnızca config dosyaları sorununu çözüyor.

## 9. Kabul kriterleri

Bu tasarım koda dönüştürüldüğünde "tamamlandı" sayılır ancak: §7'deki testler (bu tur 12 test olarak `pytest`'te yazılıp **geçti** ✅) VE gerçek bir Linux ortamında en az bir paketin gerçek `upgrade` döngüsü (değiştirilmiş ve değiştirilmemiş config dosyasıyla, gerçek `configure/make` ile) elle doğrulandığında (❌ hâlâ yapılmadı — bu hostta toolchain yok, Codex'in ortamını bekliyor).
