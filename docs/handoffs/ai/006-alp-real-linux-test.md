# Claude devir belgesi 006 — `alp`'in ilk gerçek Linux testi (SSH ile)

Görev ID / durum: (Backlog dışı, kullanıcı talebi — "alp'i şuanki Linux'unda deneyelim") tamamlandı. **Bu, `alp`'in kuruluşundan beri ilk kez gerçek bir Linux ortamında çalıştırılmasıdır.**

Çalışılan host: `alpbah-builder` Ubuntu 24.04.5 LTS VM'i (Codex'in build ortamı), SSH ile (`sa@172.28.174.11`, kullanıcı tarafından üretilip yetkilendirilen `claude_alpbahos_m2` anahtarıyla). Dal: `claude/desktop-bootstrap` (Windows worktree'de düzeltme yapıldı, VM'e yalnız test için kopyalandı).

## Erişim ve kapsam sınırı

Kullanıcı, benim için özel bir SSH anahtar çifti (`claude_alpbahos_m2`) ürettirip VM'in `~/.ssh/authorized_keys`'ine ekletti. Test **tamamen izole bir dizinde** (`~/alp-real-test`, iş bitince silindi) yapıldı — `AGENTS.md`'nin "Linux rootfs ve paket deposu tek yazıcı" kuralına uyarak Codex'in gerçek LFS rootfs'üne (`/mnt/alpbahos-*`) veya `~/alpbahOS` git deposuna **hiç dokunulmadı**, hiçbir dosya değiştirilmedi.

Not: VM'in yerel `~/alpbahOS` git deposunda `claude-a/lfs-base` ve `claude-b/desktop-ux` adında, bu oturumdan bağımsız yerel dallar görüldü — bunlara da dokunulmadı, incelenmedi; kullanıcıya bilgi olarak düşülüyor, kaynağı bu ajana bilinmiyor.

## Bulunan gerçek bug ve düzeltme

**Bug:** `install_recipe`/`upgrade_recipe`, bir build adımını çalıştırmadan önce `shutil.which(step[0])` ile aracın var olup olmadığını kontrol ediyordu. `step[0]` genelde `"./configure"` gibi göreli bir yol. `shutil.which()`'in kendi davranışı: yol ayracı (`/`) içeren bir komut için, **yalnızca interpreter'ın kendi `cwd`'sine göre** kontrol eder — `subprocess.run(..., cwd=src_dir)`'in gerçekte çalışacağı dizini bilmez/kullanmaz. Sonuç: `alp.py`'nin çalıştırıldığı dizinde `./configure` yoksa (ki normalde hiç olmaz), gerçekten var ve çalıştırılabilir olsa bile "Gerekli araç bulunamadı" hatası veriliyordu.

Bu hata Windows'ta hiç fark edilmedi çünkü orada zaten `make`/`configure` toolchain'i yoktu — hata her iki durumda da aynı mesajı veriyordu, biri gerçek eksiklik biri yanlış kontrol. **Yalnızca gerçek bir Linux'ta, gerçek bir configure scripti mevcutken** ortaya çıkabilecek bir hataydı — bu da SSH ile gerçek test yapmanın neden değerli olduğunun somut kanıtı.

**Düzeltme:** Yeni `_tool_available(binary, cwd)` yardımcı fonksiyonu — yol ayracı içeren komutları `cwd` parametresine göre (gerçek çalışma dizini) çözer, düz komut adlarını (örn. `"make"`) eskisi gibi PATH üzerinden arar. `install_recipe` ve `upgrade_recipe`'deki iki çağrı noktası güncellendi.

## Çalıştırılan doğrulama ve sonuç

1. **`recipe` yöntemi, gerçek Linux'ta, gerçek `./configure` çağrısıyla:** Düzeltme sonrası `htop` tarifi gerçekten `./configure --prefix=/usr`'ı çalıştırdı (önceden hiç bu noktaya ulaşmıyordu). Gerçek bir bağımlılık hatasıyla durdu: `configure: error: can not find required library libncursesw`. Bu **beklenen ve doğru** davranış — `alp`'in kendi dürüst eksiklik listesinde ("bağımlılık çözümü yok") zaten belgeli; sistemde `libncursesw` geliştirme paketi kurulu değildi, `sudo` şifresi olmadığı için kurulmadı (bilerek denenmedi — VM'in paket durumuna izinsiz müdahale etmemek için).
2. **`core` yöntemi, tam yaşam döngüsü, gerçek Linux'ta:**
   - Kurulum (v1, config dosyası içeren bir tema paketi) → gerçekten çalıştı.
   - Upgrade (v1→v2, config dosyasına hiç dokunulmamış) → config sessizce yeni içerikle değiştirildi (`dark=false`), doğrulandı.
   - Kullanıcı config dosyasını elle değiştirdi (`dark=true\naccent=orange`).
   - Upgrade (v2→v1) → **`.alpnew` üretildi**, kullanıcının dosyası **birebir korundu**, uyarı mesajı doğru yazıldı.
   - `remove` → değiştirilmiş config **`.alpsave` olarak korundu**, silinmedi; config olmayan dosya (`README`) normal silindi.
   - Tüm bu adımlar `design/config-protection.md`'deki tasarımla birebir eşleşti — sıfır sapma.
3. **Yerel test seti:** `_tool_available` için yeni 3 regresyon testi eklendi (toplam 51 test), tamamı geçti. Bir test yazım hatası (Windows'ta `os.chdir()` kullanan bir test, aynı pytest sürecindeki sonraki subprocess çağrılarını bozan bir Windows handle sorununa yol açtı) fark edilip `os.chdir()` kullanmayan bir tasarıma düzeltildi.

## Bilinen sorun ve açık karar

1. `tmux`/`zsh` tarifleri bu turda gerçek Linux'ta denenmedi (yalnızca `htop` denendi) — muhtemelen benzer eksik-kütüphane hatalarıyla karşılaşırlar (tmux: libevent/ncurses; zsh muhtemelen sorunsuz derlenir, ek kütüphane istemez).
2. Gerçek bir `libncursesw`+`make`+full derleme zinciri hâlâ hiç denenmedi (sudo erişimi yok).
3. `flatpak` yöntemi bu VM'de de test edilmedi (`flatpak` kurulu değil, Ubuntu Server minimal).
4. VM'in yerel repo'sunda görülen `claude-a`/`claude-b` dallarının ne olduğu bilinmiyor — kullanıcıya sorulmalı.

## Entegrasyon için gereken

Bu düzeltme (`_tool_available`) `alp.py`'nin gerçek LFS/BLFS sisteminde recipe kurulumu yapabilmesi için **kritik** bir önkoşuldu — düzeltilmeden önce recipe yöntemi gerçek bir Linux'ta bile hiçbir zaman `./configure`'ı çalıştıramazdı. Artık gerçekten çalışıyor (bağımlılıklar sağlandığında).

Sonraki eylem: Yok — kullanıcı isteği tamamlandı, SSH test dizini temizlendi. `alp` gerçek Linux'ta ilk kez fiilen çalıştı ve bunun sayesinde gerçek, kritik bir bug bulundu/düzeltildi.
