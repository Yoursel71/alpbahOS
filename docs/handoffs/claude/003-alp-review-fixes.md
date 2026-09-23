# Claude devir belgesi 003 — `alp` prototipine bağımsız inceleme + düzeltme

Görev ID / durum: (Backlog dışı, kullanıcı talebi) `alp` prototipinin (paralel oturumun `51f93b9` commit'i) bağımsız güvenlik/doğruluk incelemesi ve bulunan 3 sorunun düzeltilmesi. Tamamlandı.

Çalışılan host ve branch/commit: Windows host, worktree `C:\alpbahOS-claude`, dal `claude/desktop-bootstrap`. Bu belgenin yazıldığı anda henüz commit atılmadı; commit hash'i bu turun commit'iyle güncellenecek.

Değişen dosyalar:
- `docs/handoffs/claude/alp-prototype/alp.py` (3 düzeltme)
- `docs/handoffs/claude/alp-prototype/README.md` (düzeltme notu)
- `docs/handoffs/claude/001-alp-hybrid-pkg-proposal.md` (güncelleme notu eklendi, orijinal test tablosu tarihsel kayıt olarak korundu)
- `docs/handoffs/claude/003-alp-review-fixes.md` (bu dosya)

Gerçekleştirilen davranış: `alp.py`, `code-review` skill'iyle (medium effort) satır satır incelendi; 3 aday bulundu, kodu izleyerek ve demo tarball'ı elle açarak doğrulandı, `ReportFindings` ile raporlandı. Kullanıcı onayıyla üçü de düzeltildi:

1. **`--dry-run` gerçek ağ/disk I/O yapıyordu.** `install_recipe`/`install_core`, `fetch()`'i (indirme+checksum) `dry_run` kontrolünden önce, koşulsuz çağırıyordu — CLI yardım metninin "touch nothing persistent" sözünü çiğniyordu. Düzeltme: her iki fonksiyon artık `dry_run=True` ise ilk satırda erken dönüyor, hiçbir `fetch()`/`safe_extract()` çağrısı yapmadan yalnızca planlanan URL/adımları yazdırıyor.
2. **`recipe` yöntemiyle kurulan paketler `remove`'da dizinlerini temizlemiyordu.** `_merge_destdir`, `os.walk`'ın döndürdüğü dizinleri hiç `files[]`'e eklemiyordu (yalnız dosyalar ekleniyordu); `core` yöntemi bu sorunu yaşamıyordu çünkü `tarfile.getnames()` arşivdeki açık dizin kayıtlarını da döndürüyor. Düzeltme: `_merge_destdir` artık ziyaret ettiği her dizini de (kök hariç) `files[]`'e ekliyor — `remove_package`'ın var olan ters-sıralı silme mantığı bunu otomatik doğru işliyor (test edildi).
3. **İndirmede zaman aşımı yoktu.** `urllib.request.urlopen(url)` süresiz bekleyebiliyordu. Düzeltme: `timeout=30` eklendi, `OSError` (zaman aşımı dahil) artık `AlpError` olarak kullanıcıya temiz mesajla iletiliyor (önceden ham Python traceback verirdi).

Çalıştırılan doğrulama ve sonuç:
- `python3 -m py_compile alp.py` — sözdizimi hatası yok.
- Gerçek uçtan uca test (bu Windows host'ta, `python3 alp.py`): `search`/`list`/`info` çalıştı; `core` yöntemi kurulum→dosya doğrulama→`remove` döngüsü tekrar çalıştırıldı, **artık `remove` sonrası `usr/` dizini tamamen temiz** (önceden zaten temizdi, `core` etkilenmemişti — regresyon yok, doğrulandı).
- `--dry-run install htop` (recipe), `--dry-run install firefox` (flatpak), `--dry-run install alpbah-theme-solid` (core) çalıştırıldı; **üçünde de `var/lib/alp/cache/` altında sıfır dosya oluştu** (önceden recipe/core gerçek indirme yapardı) — düzeltme doğrulandı.
- Gerçek (dry-run olmayan) `install htop` tekrar çalıştırıldı: gerçek ağdan indirme + checksum uyuşmazlığı + temiz hata mesajı + arşivin silinmesi davranışı **aynen korundu** — checksum reddi regresyonsuz çalışıyor.
- **Çalıştırılmadı:** gerçek `configure/make/make install` (bu hostta `make` yok, önceki durumla aynı); gerçek `flatpak` (kurulu değil); zaman aşımı senaryosunun kendisi (yanıt vermeyen bir sunucu simüle edilmedi, yalnızca kod yolu/parametre eklendi).

Log / ekran görüntüsü / artifact: Komut çıktıları bu belgenin "Çalıştırılan doğrulama" bölümünde özetlendi; ham çıktılar scratch dizininde, repoya girmedi.

Bilinen sorun ve açık karar: Bu düzeltmeler `alp`'i "kabul edilmiş" yapmaz — proposal belgesinin 1. bölümündeki dört onay adımı (D11/P05 revizyonu, Codex koordinasyonu, tek-motor ilkesi, M02 kriterleri) hâlâ bekliyor. Ayrıca ayrı bir `Yoursel71/alpbahOS-alp` private GitHub reposu, kullanıcı talebiyle bu turda oluşturuldu (recipes/index/core barındırma alanı) — bu da `alp`'i otomatik olarak kabul edilmiş yapmaz, yalnızca öneri geliştirmesi için altyapı hazırlar.

Entegrasyon için gereken: Kullanıcı/Codex `alp` önerisini kabul/red ederse buradaki kod ona göre ele alınır; kabul edilirse gerçek recipes/ dosya sınırı Codex ile koordine edilir (BACKLOG.md).

Sonraki eylem: Yok — kullanıcı isteği tamamlandı. Sıradaki gerçek iş yine Codex/Hyper-V ilerlemesine (Cumartesi) veya kullanıcının UI-03 görsel kaynağı kararına bağlı.
