# Claude devir belgesi 004 — `alp` güçlendirme turu: gerçek paketler, test seti, eksik tasarımlar

Görev ID / durum: (Backlog dışı, kullanıcı talebi — "daha fazla tarif", "test seti", "eksik tasarımlar") üçü de tamamlandı.

Çalışılan host ve branch/commit: Windows host, worktree `C:\alpbahOS-claude`, dal `claude/desktop-bootstrap`; `alpbahOS-alp` reposu ayrı bir yerel checkout üzerinden (`main` dalı). Bu belgenin yazıldığı anda henüz commit atılmadı; hash bu turun commit'iyle güncellenecek.

Değişen dosyalar:
- `Yoursel71/alpbahOS-alp` (ayrı repo): `recipes/htop.recipe.json`, `recipes/jq.recipe.json`, `recipes/zsh.recipe.json`, `recipes/tmux.recipe.json`, `index.json`, `README.md`.
- `docs/handoffs/claude/alp-prototype/tests/test_alp.py` (yeni)
- `docs/handoffs/claude/alp-prototype/design/packagekit-integration.md` (yeni)
- `docs/handoffs/claude/alp-prototype/design/config-protection.md` (yeni)
- `docs/handoffs/claude/alp-prototype/README.md` (test bölümü eklendi)
- `docs/handoffs/claude/001-alp-hybrid-pkg-proposal.md` (gap tablosu, yeni tasarım belgelerine bağlandı)
- `docs/handoffs/claude/004-alp-hardening.md` (bu dosya)

Gerçekleştirilen davranış:

**1. Gerçek tarifler (4 paket):** `htop` 3.3.0, `jq` 1.7.1, `zsh` 5.9, `tmux` 3.4. Her birinin `sha256`'ı gerçek yayın arşivi `curl` ile indirilip `sha256sum`/Python `hashlib` ile hesaplandı — placeholder yok. `zsh`, projenin kendi `profiles/shell/` (SHELL-01) taslağının varsaydığı shell olduğu için kasıtlı seçildi.

**2. Otomatik test seti:** `tests/test_alp.py`, 29 test, pytest 8.4.2 ile bu ortamda çalıştırıldı, **hepsi geçti**. Network tamamen mock'lu (gerçek ağa çıkmaz — hız/tekrarlanabilirlik). `DbLock`, `db.json` load/save, `resolve_source_url`, `fetch()` (checksum + timeout), `safe_extract` (path-traversal reddi), `_merge_destdir` (dizin kaydı), `remove_package` (dizin temizliği), `install_recipe`/`install_core` (dry-run sıfır I/O + gerçek uçtan uca + eksik toolchain + kötü checksum) ve CLI `cmd_*` fonksiyonları kapsandı.

**3. Eksik tasarım parçaları:** `design/packagekit-integration.md` (PackageKit backend yaklaşımı, `--json` çıktı ön koşulu, yöntem eşlemesi, ilerleme protokolü, polkit yetkilendirme, kilit etkileşimi) ve `design/config-protection.md` (`.alpnew`/`.alpsave` — pacman'ın pacnew/pacsave'iyle aynı karar ağacı, manifest/db şema genişletmesi, `alp upgrade` akışı, test planı).

Çalıştırılan doğrulama ve sonuç:
- **Tarifler:** `alp install htop/jq/zsh/tmux` (gerçek, dry-run olmayan) bu host üzerinde 4/4 çalıştırıldı — hepsi gerçek ağdan indirip checksum'ı doğruladı (başarılı), yalnızca (beklendiği gibi) `./configure` yokluğunda durdu. Checksum reddi **değil**, checksum **kabulü** test edildi (önceki turdaki htop testi kasıtlı kötü checksum'la reddi test etmişti — bu farklı, tamamlayıcı bir doğrulama).
- **Test seti:** `python3 -m pytest tests/ -v` → 29/29 geçti. Ayrıca testlerin gerçekten anlamlı olduğu, düzeltme öncesi `alp.py`'ye (`51f93b9`) karşı çalıştırılarak kanıtlandı: **tam olarak 7 test, 3 düzeltmenin her birine karşılık gelerek** başarısız oldu, diğer 22'si zaten geçiyordu. Kozmetik testler değil, gerçek regresyon koruması.
- **Tasarım belgeleri:** Kod içermiyor, bu nedenle "çalıştırıldı" anlamında bir doğrulama yok — bunlar MASTER_PLAN §5.2/§5.3'ün kendi kabul kriterlerine göre yazıldı, her ikisi de kendi "Kabul kriterleri" bölümünde neyin hâlâ eksik olduğunu (gerçek PackageKit daemon testi, gerçek upgrade testi) açıkça listeliyor.

Log / ekran görüntüsü / artifact: pytest çıktısı ve checksum hesaplama komutları bu belgenin "Çalıştırılan doğrulama" bölümünde özetlendi; ham çıktı scratch dizininde.

Bilinen sorun ve açık karar:
1. `design/packagekit-integration.md`'nin §2'sinde önerilen `alp --json` bayrağı henüz `alp.py`'ye eklenmedi — sonraki adım.
2. `design/config-protection.md`'deki `alp upgrade` komutu henüz `alp.py`'ye eklenmedi — bu iki tasarım da kod değil.
3. 4 tarifin `configure/make/make install` adımları hâlâ hiçbir Linux ortamında gerçekten çalıştırılmadı; yalnızca indirme+checksum doğrulandı.
4. `core/` klasörü (alpbahOS-özel tema/branding paketleri) hâlâ boş — UI-03 kararına bağlı.

Entegrasyon için gereken: Codex'in LFS/BLFS ilerlemesi (gerçek `configure/make` testi ve `alp`'in temel sisteme yerleştirilmesi için), kullanıcının hangi tasarımın (PackageKit backend'i mi, `upgrade` komutu mu) önce koda dönüştürüleceğine karar vermesi.

Sonraki eylem: Yok — kullanıcı isteği (3 madde) tamamlandı. Sıradaki gerçek iş yine Codex/Hyper-V ilerlemesine (Cumartesi) veya kullanıcının UI-03/PackageKit/upgrade önceliklendirmesine bağlı.
