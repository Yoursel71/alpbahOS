# Ajanlar için kalıcı kurallar ve erişim kartı

Bu belge, kullanıcının her oturumda tekrar hatırlatmak zorunda kaldığı şeyleri tek yerde tutar. **Her ajan (Codex, Claude, alt ajanlar) işe başlamadan önce okur.** Kullanıcıya bir şeyi ikinci kez sordurmak bu belgedeki bir eksiktir; eksik varsa kullanıcıya değil bu belgeye eklenir.

Ortamın haritası ve "hangi iş nerede yapılır" tablosu için: `docs/AI_ENVIRONMENT_GUIDE.md`.

## 1. Erişim kartı (SSH ve Hyper-V)

Anahtarların **içeriğini** hiçbir yere yazma, yazdırma ve loglama. Aşağıda yalnız dosya adları ve komutlar var.

| Amaç | Komut / alias | Kullanıcı | Anahtar dosyası (`C:\Users\thewo\.ssh\`) |
|---|---|---|---|
| Ubuntu Builder (derleme, `/mnt/lfs`, imaj) | `ssh alp-builder` | `sa` | `claude_alpbahos_m2` |
| Windows Hyper-V yöneticisi (VM aç/kapat, disk, `Get-VM`) | `ssh alp-windows-admin` | `thewo` @ `127.0.0.1` | `claude_alpbahos_m2` (Claude), `codex_alpbahos_m1` (Codex) |
| Gen2 test VM | `ssh alp-m2-gen2` | `sa` | `claude_alpbahos_m2` |

- Test VM'lerde SSH **yalnız anahtarla** açılır (`AllowUsers sa`, parola kapalı). Konsol girişi (tty1) için yalnız test VM'lerinde hesap `admin`, parola `admin`; bunu release imajına, belgeye örnek olarak ya da başka bir yere taşıma.
- `alp-builder` ve VM IP'leri **DHCP ile değişir**. Alias bağlanmazsa önce IP'yi değil VM'in açık olup olmadığını denetle (aşağıda 1.3), sonra IP'yi bul (`docs/AI_ENVIRONMENT_GUIDE.md` §5). Geçici IP için: `ssh -o HostName=<ip> alp-builder`.
- Bir komut Windows'ta SSH ile çalıştırılacaksa uzak kabuk `cmd` olabilir: PowerShell'i **tek satırda** ver: `ssh alp-windows-admin 'powershell -NoProfile -Command "Get-VM"'`. Çok satırlı betik `cmd` üzerinden bozulur.

### 1.1 Windows yönetici SSH'ı: yeni bir anahtarı tanıtmak (SIK UNUTULAN ADIM)

`thewo` Administrators grubunda olduğu için Windows OpenSSH, bu kullanıcının anahtarlarını `~\.ssh\authorized_keys` içinde **aramaz**; `%ProgramData%\ssh\administrators_authorized_keys` dosyasına bakar. Yeni bir ajanın/anahtarın Hyper-V yöneticisine girebilmesi için **yükseltilmiş (Yönetici) PowerShell**'de şu iki komut gerekir:

```powershell
Add-Content -LiteralPath "$env:ProgramData\ssh\administrators_authorized_keys" -Value (Get-Content "$env:USERPROFILE\.ssh\codex_alpbahos_m1.pub")
Restart-Service sshd
```

- Bu, **kullanıcının bir kez yapacağı yönetici adımıdır**; ajanlar bunu kendileri denemez ve sistem/güvenlik ayarı olarak değiştirmez (`AGENTS.md`). Ajan bu adımın eksik olduğunu görürse kullanıcıdan yalnız bu iki komutu ister, başka bir şey istemez.
- Eklenecek dosya **`.pub`** (genel anahtar) olmalı; özel anahtarı asla ekleme.
- Anahtar eklenmesine rağmen giriş hâlâ reddediliyorsa dosya izinleri bozuktur; yönetici PowerShell'de: `icacls "$env:ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"` ve ardından `Restart-Service sshd`.
- Doğrulama: `ssh alp-windows-admin 'powershell -NoProfile -Command "hostname"'` ana bilgisayar adını döndürmeli.

### 1.2 Yetki sınırları

- `Get-VM` "izin yok" derse (kullanıcı `Hyper-V Administrators` grubunda değil ya da yükseltilmemiş oturum): kullanıcıya yalnız bunu söyle. Grup üyeliğini ya da sudoers'ı ajan değiştirmez.
- Builder'da `sudo -n true` başarılıdır. Başarısız olursa dur ve kullanıcıya bildir.

### 1.3 "Bağlanamıyorum" kontrol sırası

1. `ssh alp-windows-admin 'powershell -NoProfile -Command "Get-VM | Select Name,State"'`: VM `Off` mu? Kapalıysa **kimin kapattığını bilmeden açma**; kullanıcıya sor (kullanıcı RAM için kapatmış olabilir).
2. VM açıksa IP değişmiştir: ARP/MAC ile bul (`docs/AI_ENVIRONMENT_GUIDE.md` §5).
3. Hâlâ olmuyorsa anahtar/`administrators_authorized_keys` (1.1).

## 2. Kalıcı kurallar

**Nerede çalışılır**
1. Derleme ve rootfs değişikliği yalnız Builder'daki `/mnt/lfs` chroot'unda yapılır. **Test VM'inde derleme yok.** Her düzeltme önce rootfs'e girer, imaj rootfs'ten üretilir (aksi hâlde yeniden üretimde kaybolur).
2. Her ajan **yalnız kendi çalışma dizininde** yazar. Codex ve alt ajanları `C:\alpbahOS`, Claude `C:\alpbahOS-claude` kullanır. Başka ajanın dizinine dosya bırakma (`C:\alpbahOS-claude\scripts\` altına alt ajan taslağı düşmüştü).
3. Builder `/tmp` altına büyük dosya (VHDX, tarball) bırakma; iş bitince sil. Builder diski paylaşımlıdır ve bir kez %100 dolmuştur. Bir görev kendi bıraktığı geçici dosyaları temizlemeden bitmez.
4. Aynı anda tek yazıcı: `nbd0` ya da bir `/tmp/*.vhdx` üzerinde iş yapmadan önce `/sys/block/nbd0/pid` boş mu bak. Başarısız bir betik bile imajı yazılabilir bağlayıp hash'ini değiştirir; betiklere `trap ... ERR` koy ki sessizce düşmesin.

**Kanıt ve dürüstlük**
5. Kanıtsız "tamam" deme. Çalıştırılmayan testi "çalıştırılmadı" diye yaz. Windows'ta geçen test, Linux davranışının yerine geçmez.
6. Başarısız denemeyi saklama; logu ve nedeni kaydet, düzelt, yeniden dene.
7. Bir işin **kapsamı ve süresi baştan sınırlanır.** Bir milestone'a bir oturumda **en fazla birkaç saat** ayır; sürünce dur, durumu yaz ve kullanıcıdan karar iste (kapsamı daralt / ertele / devam). Yeni denetçi/araç yazarak ölçütü uzatma. Ölçüt karşılanmıyorsa "tamamlandı" yazma; "kısmi kabul" ve ertelenen borç olarak yaz.
8. Alt ajan sayısı sınırlıdır (varsayılan en fazla iki, salt okunur denetim için). Alt ajan bulduğu her boşluk için yeni iş üretmez; boşlukları listeye yazar, kullanıcı/koordinatör öncelik verir.

**Kullanıcıyla çalışma**
9. Kullanıcıdan **terminal komutu çalıştırmasını isteme**; yapabileceğin her şeyi kendin yap. İstisna yalnız fiziksel ya da yönetici adımıdır (bir konsola giriş, 1.1'deki iki komut) ve bunu **bir kez, tam komutlarıyla** iste.
10. Kullanıcıya aynı şeyi ikinci kez sordurma: önce bu belgeye, `CURRENT.md`'ye ve `docs/NEW_SESSION_HANDOFF.md`'ye bak. Bulamazsan sor, cevabı buraya yaz.
11. Raporlar kısa olur: ne yapıldı, kanıt nerede, ne bekleniyor. Uzun günlükler dosyaya gider.
12. Kullanıcının kararı (ör. M04 kısmi kabul) `docs/DECISIONS.md`'ye işlenir ve ilgili belgeler tek seferde güncellenir; eski ifade başka yerde kalmaz (`python docs/handoffs/claude/tools/check_docs.py`).

**Git**
13. Başkasının commit'lenmemiş değişikliğini sıfırlama, stash'leme, üzerine yazma. Push öncesi `git fetch`; ana dala yalnız fast-forward push. Zorla push yok.

## 3. Sahiplik (kısa)

| Alan | Sahibi |
|---|---|
| LFS/BLFS derlemesi, kernel, Hyper-V, imaj/ISO, Builder | Codex |
| Masaüstü teması, terminal UX, uygulama profilleri, `alp` paket motoru (D31) | Claude |

Sahibi olmadığın alanda değişiklik gerekirse değiştirme; devir notuna yaz. Codex'in `alp.py`'ye yaptığı gibi bir değişiklik gerekliyse (M04 için taban paket sahiplenme eklendi), Claude'un testleriyle birlikte koşturulup hash'i devir belgesinde güncellenir; sessizce bırakılmaz.

## Konsolsuz erişim (25 Eylül 2026 eklemesi) — VMConnect'e/kullanıcı ekranına ihtiyaç YOK
- PC yeniden başlayınca VM IP'leri değişir: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\refresh-ssh-hosts.ps1`, sonra `ssh alp-m2-gen2` / `ssh alp-builder`.
- VM'ler PC açılınca kendiliğinden başlar. Ekran görüntüsü: `scripts\vm-screenshot.ps1 -VmName <ad> -Out <png>` (Hyper-V WMI, SSH'tan çalışır).
- Gen2 test imajında (`...autoseat-claude...vhdx` ve türevleri) `sa`/`admin` şifresiz sudo; tty1 `admin` otomatik girişi. Seat-bound test için: `sudo rm /run/alp-plasma-tried; sudo systemctl restart getty@tty1`, log `/var/tmp/alp-plasma-autostart.log`.
- Windows SSH servisi Session 0'dadır: SendKeys/pencere etkinleştirme çalışmaz. computer-use VMConnect'e tuş iletmekte güvenilmezdir; kullanmayın.
- `kwin_wayland` ikilisini yeniden adlandırma/sarma (QPA eklentisi ad kontrolü yapar).
