# Claude devir belgesi 013 — `alp` Seviye 3 bağımlılık denetimi

```text
Görev ID / durum: Backlog dışı. Kullanıcı 23 Eylül 2026'da "seviye 3 bağımlılık kontrolüne başla, alp'i kullanışlı yap" dedi. Tamamlandı. Rootfs'ye kurulmadı.
Çalışılan host ve branch/commit: Windows (kod ve test) + Builder `yrsk` (Ubuntu 24.04.5, sa@172.28.162.172; yalnız /tmp/claude-alp-s3). Dal claude/desktop-bootstrap. Commit bu belgeyle birlikte atılıyor; test edilen alp.py SHA-256'sı a34b796d64d14ea20d8228708f1add135e37e2328eac96efbca448b2b95f510e (Windows ve Builder kopyası aynı).
Değişen dosyalar: alp-prototype/alp.py, alp-prototype/alp_packagekit_backend.py, alp-prototype/tests/test_alp.py, alp-prototype/tests/test_packagekit_backend.py, alp-prototype/tests/test_seviye3.py (yeni), alp-prototype/README.md, bu belge.
Gerçekleştirilen davranış: aşağıda.
Çalıştırılan doğrulama ve sonuç: Windows 126 geçti, 10 atlandı (10 ardışık koşuda kararlı); Builder 136 geçti, 0 atlandı; 10 mutasyonun hepsi testlerce yakalandı; gerçek pty'de CLI demosu beklenen çıktıyı verdi.
Log / ekran görüntüsü / artifact: Builder'da /tmp/claude-alp-s3/s3demo.log (geçici). Önemli kısmı aşağıda.
Bilinen sorun ve açık karar: MASTER_PLAN'daki "sıfırdan bağımlılık çözücü" yasağı karşısında kullanıcı kararı karar kaydına işlenmeli (öneri aşağıda). Gerçek katalogdaki (alpbahOS-alp) 4 tarifte hâlâ hiç depends yok.
Entegrasyon için gereken: Entegratörün aşağıdaki karar önerisini DECISIONS.md'ye yeni D numarasıyla işlemesi ve main'e birleştirmesi. Rootfs'deki eski motorun (d06c72…) değiştirilmesi ayrı iş; bu turda yapılmadı.
Sonraki eylem: alpbahOS-alp kataloğuna gerçek bağımlılık zinciri eklemek (ncurses → htop) ve bunu Builder'da gerçek derlemeyle denemek.
```

## Kapsam kararı

Önceki devirler (008, 009) Seviye 3'ü "sürüm kısıtları + çakışma çözümü" olarak tanımlayıp MASTER_PLAN'ın "sıfırdan bağımlılık çözücü" yasağı yüzünden bilerek yapmamıştı. Kullanıcı bu turda açıkça istedi. Uygulama bu yasağın kaygısını, yani karmaşık ve kanıtlanamaz bir çözücü riskini, şöyle sınırlıyor:

- Katalogda her paketin **tek** sürümü var, dolayısıyla seçim ve geri izleme (backtracking) yok. Bu bir SAT çözücü değil, deterministik bir kısıt denetleyicisi.
- Yalnız `index.json` içindeki paketlere bakıyor. Sistem kütüphaneleri Seviye 1'de kalıyor.
- Tutarsız sonuç çıkacaksa işlem başlamadan reddediliyor. "En iyi tahmin" üretmiyor.

**Karar kaydı önerisi** (entegratör DECISIONS.md'ye yeni D numarasıyla işlemeli):

> Kabul — `alp` paket motorunda katalog içi sürüm kısıtları (`depends` içinde `>=, <=, ==, !=, <, >`), `conflicts`, ters bağımlılık koruması, `autoremove` ve onaylı işlem planı uygulanır. Katalogda paket başına tek sürüm olduğundan seçim/geri izleme yapan bir çözücü değildir. MASTER_PLAN'daki "sıfırdan bağımlılık çözücü" sınırının kullanıcı talimatıyla, bu kapsamla daraltılmış istisnasıdır. Kaynak: kullanıcı talimatı, 23 Eylül 2026; ayrıntı bu belge.

## Ne yapıldı (`alp.py`)

**Katalog biçimi:** geriye uyumlu. Eski `"depends": ["libfoo"]` aynen çalışıyor.

```json
"editor":     {"method": "core", "...": "...", "depends": ["libalp>=1.0,<3"]},
"neo-editor": {"method": "core", "...": "...", "conflicts": ["editor"]}
```

**Yeni parçalar:**
- `vercmp()`: sayısal bölümler tam sayı olarak karşılaştırılıyor (1.10 > 1.9). Sonda harf varsa ön sürüm sayılıyor (1.0rc1 < 1.0). Recipe paketlerinde sürüm tarif dosyasından okunuyor.
- `parse_spec()` / `Spec.allows()`: kısıt sözdizimi. Hatalı yazım anlaşılır bir hata veriyor.
- `plan_transaction()`: bağımlılık grafiğini geziyor. Kurulu ve kısıtı karşılayan bağımlılığa dokunmuyor. Karşılamayanı, katalog sürümü karşılıyorsa yükseltme adımı olarak plana ekliyor. Karşılanamıyorsa neden karşılanamadığını zincirle birlikte söylüyor.
- `state_problems()`: planın bırakacağı son durumu denetliyor. Planın yükselttiği bir paket, dokunulmayan kurulu bir paketin kısıtını bozuyorsa (örnek: `legacy-tool libalp<2 gerektiriyor, libalp 2.0 olur`) ya da iki taraftan biri `conflicts` tanımlamışsa işlem reddediliyor.
- `db.json` kaydına `depends`, `conflicts` ve `reason` (`explicit`/`dependency`) yazılıyor. Bu alanlar olmayan eski kayıtlar katalog girdisine düşüyor ve `explicit` sayılıyor, yani autoremove onlara hiç dokunmuyor.
- `plan_remove()`: başka kurulu paketin ihtiyaç duyduğu paketi kaldırmayı reddediyor. `--cascade` ile bağımlıları önce kaldırıyor.
- `find_orphans()` + `alp autoremove`. Kaldırma sonrası sahipsiz kalanlar için ipucu da basılıyor.
- `alp upgrade` (ad vermeden): tüm sistemi yükseltiyor. Takılan paket, gerekçesiyle "geri tutuldu" diye bildiriliyor, geri kalan yükseltmeler yapılıyor.
- `alp check`: tüm kurulu sistemin tutarlılığını, güncellemeleri ve sahipsizleri gösteriyor. Sorun varsa çıkış kodu 1.
- `alp install` zaten bağımlılık olarak kurulmuş bir pakete verilirse paket "açıkça kurulmuş" olarak işaretleniyor.
- Onay: plan gösteriliyor. Yalnız etkileşimli terminalde `[E/h]` soruluyor; boş Enter "evet" sayılıyor. `-y/--yes` soruyu atlıyor. İşlem yarıda kalırsa tamamlanan ve yapılmayan adımlar ayrı ayrı yazılıyor.
- Eski `_resolve_install_order` kaldırıldı. Testleri `plan_transaction` üzerine taşındı.

**`alp_packagekit_backend.py`:** install, remove ve upgrade artık `--yes` geçiyor, çünkü PackageKit/polkit kullanıcıya zaten sordu. Alt süreç `stdin=DEVNULL` ile başlatılıyor. Test sırasında iki gerçek sorun çıktı:
1. Windows'ta miras alınan geçersiz stdin handle'ı `CreateProcess`'i ara ara `WinError 6` ile düşürüyordu.
2. Windows'ta `NUL` aygıtı `isatty() == True` döndürdüğü için, `--yes` olmadan alp soru sorup EOF alıyor ve işlemi iptal ediyordu.

## Doğrulama

- **Windows:** `python -m pytest tests/ -q` → 126 geçti, 10 atlandı (symlink/mod/stale-lock testleri bu hostta yapılamıyor). Önbellek silinip 10 kez ardışık çalıştırıldı, kararlı.
- **Builder:** kod `/tmp/claude-alp-s3` altına kopyalandı. pytest sistem Python'una kurulmadı; saf-Python paketleri Windows'ta bir dizine indirilip `PYTHONPATH` ile kullanıldı. Sonuç 136 geçti, 0 atlandı.
- **Mutasyon kontrolü:** 10 ayrı bozma denendi: `state_problems` hep boş, remove engeli yok, orphan yok, `need()` hiç yükseltmiyor, `vercmp` metin karşılaştırması, onay hep evet, reason hep explicit, conflicts yok sayılıyor, cascade sırası ters, kept-back yok. Her birinde 1 ile 7 arası test düştü. Testler süs değil.
- **Gerçek pty'de CLI demosu** (Builder, `script` ile):
  - `h` cevabı → "İptal edildi, hiçbir şey değişmedi", `list` boş.
  - Boş Enter → libalp (bağımlılık) + editor kuruldu.
  - `neo-editor` → `neo-editor ile editor 1.0 çakışıyor`, reddedildi.
  - `remove libalp` → `şu kurulu paketler ona bağımlı: editor, legacy-tool`, reddedildi.
  - Katalog libalp 2.0 yayınladığında:
    - `install new-app` reddedildi.
    - `upgrade` → `geri tutuldu: libalp (legacy-tool libalp<2 gerektiriyor, libalp 2.0 olur)`, dosya hâlâ 1.0.
  - `legacy-tool` kaldırıldıktan sonra `install new-app` → libalp 1.0 → 2.0 yükseltildi, new-app kuruldu, dosya 2.0.
  - `remove --cascade libalp` → editor, new-app, libalp sırasıyla kaldırıldı.
  - `check` → sorun yok.

**Çalıştırılmadı:**
- Gerçek `configure/make` ile bağımlılık zinciri derlemesi. Katalogda henüz birbirine bağlı gerçek tarif yok; demo yalnız `core` paketleriyle yapıldı.
- Gerçek `flatpak`.
- LFS rootfs üzerinde kurulum. Rootfs'deki motor hâlâ eski (`d06c72…`).
- Discover GUI.
