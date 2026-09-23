# Claude devir belgesi 011: `alp` mantık denetimi düzeltmeleri

**Görev ID / durum:** Backlog dışı. Kullanıcı 23 Eylül 2026'da "repoyu oku, mantık hatalarını bul" dedi, ardından `alp` bulgularının düzeltilmesini onayladı. Tamamlandı.

**Host / dal:** Windows'ta kod ve test; Ubuntu Builder'da (`sa@172.28.162.172`, yalnız `/tmp/claude-alp-*` geçici dizinleri) Linux doğrulaması. Dal: `claude/desktop-bootstrap`.

## Bulunan hatalar

Hepsi benim kodumdaydı; mevcut testler bunları yakalamıyordu.

1. **`remove`, LFS'in `/lib`, `/bin`, `/sbin` ve `/var/run` symlink'lerini silebiliyordu.**
   - Kayıtta dizin olarak geçen bir yol hedefte symlink ise `is_symlink()` dalı onu doğrudan siliyordu.
   - `/lib` giderse dinamik yükleyici yolu kırılır ve sistem açılmaz.
2. **`./` önekli core arşivlerde upgrade yeni kurulan dosyaları siliyordu.**
   - `install_core` ham `getnames()` kaydediyordu (`/./usr/...`). Upgrade bunları eskimiş dosya sayıyordu; pathlib `.` bileşenini yuttuğu için silinen, az önce kurulan dosyalardı.
   - Aynı sebeple config hash'leri hiç kaydedilmiyordu.
3. **Dosya sahipliği çakışması hiç kontrol edilmiyordu.**
   - Başka bir paketin dosyası ya da hiçbir pakete ait olmayan bir dosya sessizce eziliyor, `remove` sırasında da siliniyordu.
   - LFS taban sistemi alp db'sinde olmadığı için taban dosyaları tamamen korumasızdı.
4. **Hedefte var olan bir symlink takip ediliyordu.** `shutil.copyfile` symlink'in gösterdiği dosyaya yazıyordu. `--root=/mnt/lfs` ile kurulumda mutlak linkler (`var/run -> /run`) Builder host'unun kendisine yazma yolu açıyordu.
5. **Dizine giden symlink'ler (ncurses `usr/lib/terminfo`) hiç kurulmuyordu.** `os.walk` bunları dizin listesine koyuyor ama içine inmiyor.
6. **`--reinstall`, kullanıcının değiştirdiği config dosyasını eziyordu** ve eski sürümün dosyalarını sahipsiz bırakıyordu.
7. **Upgrade'de artık gelmeyen, kullanıcının değiştirdiği config `.alpsave` bırakılmadan siliniyordu.**
8. **Sonradan config olarak tanımlanan dosya bir daha hiç güncellenmiyordu.** Kayıtlı hash olmadığı için her seferinde "değiştirilmiş" sayılıyordu.
9. **Dosyanın dizine dönüşmesi `FileExistsError` traceback'iyle bitiyordu.** Dosyaların yerinde yazılması çalışan bir ikili dosyada ETXTBSY hatası veriyor, hard link'lerin hepsini değiştiriyordu.
10. **Bayat kilit hiç temizlenmiyordu** (`kill -9` ya da elektrik kesintisinden sonra). Güvenli filtre olmayan Python'da güvensiz bir tar yedek yolu devreye giriyordu.

## Yapılan değişiklik (`alp.py`)

Tek tek yama yerine kök neden düzeltildi. Üç ayrı birleştirme yolu vardı:
- `_merge_destdir`,
- `_config_aware_merge`,
- `install_core`'un arşivi doğrudan köke açması.

Bunların yerine tek bir `_merge_staged()` geldi. Recipe ve core yöntemlerinde kurulum, yükseltme ve `--reinstall` artık bu yoldan geçiyor.

- **Yazmadan önce kontrol (`_preflight_merge`).** Aşağıdakilerden biri varsa işlemin tamamı, tek bayt yazılmadan reddediliyor:
  - başka paketin ya da hiçbir paketin olmayan bir dosyanın üzerine yazma,
  - paketin kendisine ait olmayan dosya↔dizin tür değişimi,
  - symlink üzerinden kök dizinin dışına çıkma.
- **Sahiplik kaydı:**
  - Yalnız bu işlemin oluşturduğu ya da paketin zaten sahip olduğu dizinler kaydediliyor. `/usr/bin` gibi önceden var olan dizinler ve `/lib` gibi `/usr`'e giden symlink'ler hiçbir zaman kaydedilmiyor.
  - Paketin kendi symlink'leri kayıtta `symlinks[]` altında tutuluyor.
- **Silme (`_remove_owned_paths`):**
  - `PROTECTED_PATHS` (temel sistem dizinleri) ve `/var/lib/alp` hiçbir zaman silinmiyor.
  - Dizine giden symlink yalnız paket onu kendi symlink'i olarak kaydettiyse siliniyor.
  - Başka bir pakete ait yollara dokunulmuyor.
  - Değiştirilmiş config dosyası `.alpsave` olarak saklanıyor; upgrade'de artık gelmeyen dosyalar için de aynı kural geçerli.
- **`_copy_entry`:** geçici dosyaya yazıp `os.replace` ile yerine taşıyor. Böylece symlink'in içinden, hard link'ten ya da çalışan ikili dosyaya yazılmıyor.
- **`install_core`:** arşivi önce özel bir ara dizine açıyor, sonra `_merge_staged`'den geçiriyor.
- **`safe_extract`:** arşivdeki adları normalize ediyor. Python'da `data` filtresi yoksa arşivi açmadan hata veriyor.
- **`--reinstall`:** paket kuruluysa upgrade yolunu kullanıyor.
- **`DbLock`:**
  - Kilide `host=` bilgisi de yazılıyor.
  - Aynı host'ta, POSIX sistemde, sahibi olan süreç artık çalışmıyorsa kilit otomatik temizleniyor. Temizlemeden önce içerik yeniden okunup karşılaştırılıyor.
  - Windows'ta hiçbir zaman temizlenmiyor, çünkü orada `os.kill(pid, 0)` süreci öldürür.
- Modülün baş açıklaması D31'e göre güncellendi (eskiden "kabul edilmiş motor pacman" yazıyordu).

## Doğrulama

- **Windows:** `pytest tests/` sonucu 82 geçti, 10 atlandı. Atlananlar symlink, FIFO, POSIX izin biti ve eski kilit testleri; Windows'ta çalıştırılamıyorlar.
- **Linux (Ubuntu Builder, Python 3.12.3):** `test_alp.py` 85/85 geçti, hiç atlanan yok. `test_packagekit_backend.py` 7/7 geçti.
  - pytest, sudo gerekmeden wheel'den geçici dizine açılarak çalıştırıldı.
  - Bu çalıştırma bir test hatasını ortaya çıkardı: kilit çakışması testi ölü bir PID (`999999`) ile yapılıyordu ve yeni kod bu kilidi doğru biçimde bayat sayıp temizliyordu. Test canlı bir PID kullanacak şekilde düzeltildi.
- **Gerçek uçtan uca test (Linux):** Kök dizinde LFS düzeni vardı (`bin->usr/bin`, `lib->usr/lib`, `sbin->usr/sbin`, `var/run->/run`). GNU `units` 2.23 gerçekten indirildi, checksum doğrulandı ve configure/make/DESTDIR ile kuruldu.
  - İkili dosyanın modu `755`, `units --version` çalıştı.
  - Hiçbir sistem dizini sahiplenilmedi. Kasıtlı olarak kırık bırakılan iki symlink korundu ve `symlinks[]`'e kaydedildi.
  - `--reinstall` geçti.
  - Önceden var olan sahipsiz `/usr/bin/units` üzerine kurulum "hiçbir dosyaya dokunulmadı" mesajıyla reddedildi; dosya olduğu gibi kaldı.
  - `remove` sonrasında `bin`, `lib`, `sbin` ve `var/run` symlink'leri yerinde, db boş.
  - Geçici dizin silindi.
- **Çalıştırılmadı:**
  - gerçek `/mnt/lfs` chroot'unda deneme (sahte LFS kökünde test edildi),
  - gerçek bir paketin sürümler arası recipe upgrade'i (aynı sürümle `--reinstall` test edildi),
  - Flatpak yolu.

## Bilinen sınırlar ve açık kararlar

1. **Kaldırmada ters bağımlılık kontrolü yok.** `depends` ile başka bir paketin ihtiyaç duyduğu paket kaldırılabilir. Bir sonraki iş.
2. **Upgrade tam olarak atomik değil.** Yazmadan önceki kontrol hata ihtimalini büyük ölçüde azaltıyor. Ama kopyalamanın ortasında bir G/Ç hatası olursa net bir `AlpError` verilir ve sistem kısmen değişmiş kalır; geri alma (rollback) yok.
3. **LFS taban sistemi alp db'sinde kayıtlı değil** (M04 açık). alp artık taban dosyalarının üzerine yazmayı reddediyor; bu güvenli davranış. Ama bir taban aracını alp ile değiştirmek, taban sistem sahipliği kaydedilene ya da bir `--overwrite` benzeri karar verilene kadar mümkün değil.
4. **Bayat kilit temizliğinde küçük bir yarış kalıyor.** İki süreç aynı anda aynı eski kilidi temizlerse sorun çıkabilir; yalnız POSIX'te geçerli.
5. **Eski formattaki kayıtlarda, paketin kendi oluşturduğu dizine giden symlink kaldırmada geride kalır.** Bilinçli olarak güvenli taraf seçildi.
6. **Recipe'lerin `build-*` ve `destdir-*` ara dizinleri cache'te kalıyor** ve disk kullanıyor.

## Entegrasyon için gereken (Codex)

- **Gerçek rootfs'teki motor eski.** `/mnt/lfs/usr/lib/alp/alp.py` (SHA-256 `d06c72ee…`), WORKLOG'un yazdığı gibi `a82f872` değil; `36f5240` + `copy2` yaması. Bu, bütün geçmiş sürümlerden hash yeniden üretilerek doğrulandı.
- Bu commit'ten kurulmalı ve kurulum hash ile doğrulanmalı:
  `git show <commit>:docs/handoffs/claude/alp-prototype/alp.py | sha256sum`
- O zamana kadar gerçek rootfs'te `alp remove` ve `alp upgrade` çalıştırılmamalı.
- main'deki `docs/handoffs/claude/004-alp-real-lfs-file-mode-fix.patch` artık gereksiz (aynı sorun `a82f872`'de çözüldü) ve bu dizindeki `004` numaralı belgeyle çakışıyor.

**Sonraki eylem:** Kaldırmada ters bağımlılık kontrolü (sınır 1), kullanıcı onay verirse.
