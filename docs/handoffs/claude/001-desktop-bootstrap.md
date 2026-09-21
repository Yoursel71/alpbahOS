# Claude devir belgesi 001 — Desktop bootstrap (UI-01, SHELL-01)

Görev ID / durum: UI-01 + SHELL-01, ilk taslak paketi tamamlandı. Statik taslak; gerçek oturum testi **yapılmadı**.

Çalışılan host ve branch/commit: Windows host, çalışma ağacı `C:\alpbahOS-claude`, dal `claude/desktop-bootstrap`. Bu belgenin yazıldığı anda henüz commit atılmadı; commit hash'i bu turun commit'iyle birlikte güncellenecek.

Değişen dosyalar:
- `profiles/desktop/README.md`
- `profiles/desktop/tokens.json`
- `profiles/desktop/colorscheme/alpbah-dark.colors`
- `profiles/shortcuts/shortcuts.json`
- `profiles/shell/README.md`
- `profiles/shell/zshrc.alpbah`
- `profiles/shell/konsole/alpbah-dark.colorscheme`
- `profiles/shell/konsole/alpbahOS.profile`
- `docs/WORKLOG.md` (öneri niteliğinde ekleme — bkz. aşağıdaki "Codex/Hyper-V" bölümü)
- `docs/handoffs/claude/001-desktop-bootstrap.md` (bu dosya)

Gerçekleştirilen davranış:
- Mevcut tasarım dokümanı ve ana plandaki (§4, §6, §7) renk/tipografi/kısayol/terminal gereksinimleri, uygulanabilir dosya taslaklarına dönüştürüldü: Plasma tema eşleme planı + KDE `.colors` dosyası, kısayol→eylem JSON'u (her satır durum kodlu: `kwin_varsayilani` / `yeniden_esleme_gerekli` / `ozel_binding_gerekli` / `dogrulanmamis`), Zsh/Konsole yapılandırma taslağı.
- Açık teknik kararlar (ikon teması: Breeze-tint vs Papirus; dock: yerel panel vs Latte Dock) kod olarak dayatılmadı, ilgili README'lerde artı/eksileriyle "açık karar" olarak işaretlendi.

Çalıştırılan doğrulama ve sonuç:
- **Yalnızca statik inceleme.** Dosyaların biçimi (JSON söz dizimi, INI bölüm adları) elle gözden geçirildi.
- Gerçek bir KDE Plasma, Zsh veya Konsole oturumu bu ortamda **çalıştırılmadı** — bu makinede Linux çalışma ortamı yok. Renk şemasının System Settings'e doğru yüklendiği, kısayolların çakışmadığı, autosuggestion davranışının belgede yazıldığı gibi çalıştığı **doğrulanmadı**.
- pytest/npm test gibi bir otomatik test seti bu görevin kapsamında yok; kabul kriterleri MASTER_PLAN §4.3 ve §6'daki manuel/gerçek-oturum kriterleridir.

Log / ekran görüntüsü / artifact: Yok. Gerçek oturum olmadığı için üretilecek log/ekran görüntüsü yok.

Bilinen sorun ve açık karar:
1. İkon teması kararı açık (Breeze-tint vs Papirus) — `profiles/desktop/README.md` §3.
2. Dock kararı açık (yerel Plasma paneli vs Latte Dock) — PERF-01 ölçümü bekliyor.
3. `shortcuts.json` içindeki `dogrulanmamis` ve `ozel_binding_gerekli` işaretli satırlar gerçek kurulu Plasma sürümünde tek tek doğrulanmalı (UI-02 kapsamı).
4. **Codex/Hyper-V build durumu (doğrulanmamış, bu ajanın kapsamı dışı):** Kullanıcı bu oturumda, ayrı bir Codex/GPT oturumunun Hyper-V'deki `alpbah-builder` VM'i içinde LFS derlemesini sürdürdüğünü anlatan uzun bir sohbet dökümü paylaştı ve o oturum token limitine takıldığı için devam istedi. Özetlenen iddialar: Chapter 7 ek geçici araçları (Python 3.13.7, Texinfo 7.2, util-linux 2.41.1) tamamlandı; ~2,8 GB'lık yerel bir yedek (build klasörü hariç) alındı; Chapter 8 (Systemd temel sistem) kurulumuna başlandı; VM'in `/dev/pts` aygıtı bozulduğu için SSH üzerinden `sudo` çalışmıyor, bu yüzden Codex kullanıcıdan VM'i Hyper-V'de yeniden başlatmasını istedi ve bu noktada oturum token limitine takıldı.
   - Bu ilerlemenin **hiçbir kaydı** repoda yok: `docs/WORKLOG.md`'nin bu turdan önceki hâli hâlâ "BUILD-01: Başlamadı" diyordu; dökümde bahsedilen `current.md` dosyası repoda mevcut değil.
   - Bu iş `AGENTS.md`/`BACKLOG.md` uyarınca tamamen Codex'in sorumluluk alanı (rootfs/chroot/toolchain/Hyper-V); bu ajan (Claude) VM'e, SSH'a veya Hyper-V konsoluna **erişmedi ve müdahale etmedi** — bilinçli bir kapsam kararı (bkz. kullanıcı onayı: "Durumu kayda geçir, kendi görevime devam et").
   - Aşağıdaki WORKLOG.md eklemesi bu durumu entegratör/Codex görebilsin diye kayda geçirir; **doğrulanmadı**, yalnızca aktarılan bilgidir.

Entegrasyon için gereken:
- Codex tarafında M06/M07 (BLFS grafik+oturum, hazır masaüstü) tamamlanıp çalışan bir Plasma oturumu kurulduktan sonra bu taslaklar gerçek ortamda test edilmeli.
- PKG-01/PKG-02 tamamlanınca `zshrc.alpbah` içindeki `pkg` tamamlama iskeleti doldurulmalı.
- Kullanıcının `alpbah-builder` VM'ini Hyper-V'de yeniden başlatıp yeni bir Codex oturumuyla Chapter 8'e devam etmesi; o oturumun bu kez ilerlemeyi `docs/WORKLOG.md` ve/veya `docs/handoffs/codex/` altına yazması (aksi halde ilerleme tekrar kaybolabilir).

Sonraki eylem: Kullanıcı VM'i yeniden başlatıp Codex ile Chapter 8'e devam ettiğinde, bu dal (`claude/desktop-bootstrap`) UI-02 (kısayol çakışma testi) ile devam eder; gerçek test için Codex'in M07 bildirimini bekler.
