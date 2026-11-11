# BETA-01: gerçek bilgisayarda USB testi (kontrol listesi)

Bu listeyi kullanıcı kendi bilgisayarında uygular; Claude gerçek donanıma erişemez. Sonuçlar bu dosyanın sonundaki
tabloya ya da yeni bir `docs/verification/beta-01-real-pc-<tarih>.md` dosyasına yazılır. BACKLOG: BETA-01 (D106).

Önce okuyun:

- **Kurulum diske yazar ve geri alınamaz.** Kurulum adımlarını (bölüm 4) yalnızca boş bir diskte, boş bir bölümde ya
  da yedeği alınmış bir bilgisayarda yapın. Windows'un yanına kurmadan önce Windows'ta önemli dosyaların yedeğini alın.
- Canlı oturum (bölüm 2-3) diske hiçbir şey yazmaz; önce yalnızca onu deneyin.
- Hangi ISO'yu denediğinizi yazın: dosya adı ve sha256 (ISO'nun yanındaki `.sha256` dosyası).

## 1. Hazırlık

| # | Adım | Not |
|---|---|---|
| 1.1 | ISO'nun sha256'sını denetleyin. Windows: `certutil -hashfile alpbahos-....iso SHA256`; Linux: `sha256sum -c alpbahos-....iso.sha256` | `.sha256` dosyasındaki değerle aynı olmalı |
| 1.2 | En az 8 GB'lık bir USB belleği ISO ile yazın: Windows'ta Rufus (**DD kipi**), Linux'ta `dd if=ISO of=/dev/sdX bs=4M status=progress oflag=sync` | USB'deki her şey silinir. `sdX`'in USB olduğundan emin olun |
| 1.3 | BIOS/UEFI ayarlarında **Secure Boot'u kapatın** | alpbahOS önyükleyicisi Microsoft anahtarıyla imzalı değil; Secure Boot açıkken açılmaz |
| 1.4 | Bilgisayarı yazın: marka/model, işlemci, ekran kartı, Wi-Fi kartı, RAM, disk türü (NVMe/SATA), BIOS mu UEFI mi | Linux'ta canlı oturumda `lspci -nn` ve `lsblk` çıktısı yeterli |

## 2. Canlı oturum: açılış

| # | Adım | Beklenen |
|---|---|---|
| 2.1 | USB'den açın (önyükleme menüsü genelde F12/F11/Esc) | alpbahOS GRUB menüsü, logo ve geri sayım |
| 2.2 | Varsayılan girişle açın | Açılış ekranı (logo), sonra masaüstü; oturum kendiliğinden açılır |
| 2.3 | Açılış süresini kabaca ölçün (menüden masaüstüne) | Yazın |
| 2.4 | Ekran çözünürlüğü doğru mu, yazılar keskin mi | Yanlışsa ekran kartını yazın |

## 3. Canlı oturum: donanım

| # | Adım | Beklenen |
|---|---|---|
| 3.1 | **Klavye:** masaüstündeki "Klavye düzeni" ile Türkçe Q ya da F'yi seçin; sonra "Klavye doğrulama"yı çalıştırın ve sorulan tuşa basın | Araç ekranda çıkan harfi gösterir; klavyenizdeki harfle aynıysa "Tamam" der. Yanlışsa ne çıktığını yazın |
| 3.2 | Klavyede `ğüşiöç ĞÜŞİÖÇ` yazın (Konsole ya da metin düzenleyici) | Hepsi doğru çıkmalı |
| 3.3 | **Wi-Fi:** sağ alttaki ağ simgesinden ağınıza bağlanın | Bağlanır, tarayıcı/`curl https://www.kernel.org` çalışır |
| 3.4 | Kablolu ağ varsa takın | Kendiliğinden bağlanır |
| 3.5 | **Ses:** ses simgesinden bir ses çalın (ya da Konsole'da `speaker-test -c 2 -l 1`) | Hoparlör/kulaklıktan ses gelir |
| 3.6 | Dokunmatik yüzey, Bluetooth, web kamerası, parlaklık tuşları (dizüstüyse) | Çalışanları ve çalışmayanları yazın |
| 3.7 | Konsole'da: `systemctl --failed` | `0 loaded units listed` beklenir; değilse çıktıyı yazın |
| 3.8 | Konsole'da: `journalctl -b -p err --no-pager \| tail -30` | Çıktıyı saklayın (fotoğraf yeterli) |
| 3.9 | Konsole'da: `free -m` (masaüstü boştayken 2-3 dakika sonra) | "used" değerini yazın (hedef: 4 GB'lık makinede 1 GB altı) |
| 3.10 | Konsole'da: `alp list \| head`, `alp check` | Paketler listelenir, "sorun yok" |

## 4. Kurulum (diske yazar: yalnızca yedekten sonra)

| # | Adım | Beklenen |
|---|---|---|
| 4.1 | "alpbahOS'u Kur"u açın; dil, konum (Europe/Istanbul), klavye | Varsayılanlar Türkçe ve İstanbul |
| 4.2 | Disk bölümleme: boş diske diski silme seçeneği, ya da Windows'un yanına kurma seçeneği | Windows varsa algılanıp gösterilir. Hangi seçeneği kullandığınızı yazın |
| 4.3 | Kullanıcı adı ve parola | |
| 4.4 | Kurulumu bitirin, USB'yi çıkarıp yeniden başlatın | "Her şey tamam", sonra GRUB menüsü |
| 4.5 | Windows'un yanına kurduysanız: GRUB menüsünde Windows girişi var mı, Windows açılıyor mu | İkisi de açılmalı |
| 4.6 | Kurulu sistemde giriş yapın | Giriş ekranında logo, Türkçe saat; parola ile giriş |
| 4.7 | İlk girişte "Hoş Geldin" penceresi | Tema seçimi çalışır |
| 4.8 | Kurulu sistemde 3.1-3.10'u tekrar edin | Seçtiğiniz klavye düzeni kurulu sistemde de geçerli olmalı |
| 4.9 | Konsole'da `sudo -v` (kendi parolanızla) | Kabul eder |
| 4.10 | Flatpak: `flatpak install flathub org.gnome.Calculator`, sonra açın | Kurulur ve açılır |
| 4.11 | Kapat menüsünden kapatın; sonra açıp Yeniden Başlat'ı deneyin | Takılmadan kapanır ve yeniden açılır |
| 4.12 | Uyku (suspend): kapağı kapatın ya da menüden Uyut, sonra uyandırın | Uyanır, Wi-Fi ve ses geri gelir |

## 5. Kurtarma (isteğe bağlı)

| # | Adım | Beklenen |
|---|---|---|
| 5.1 | Kurulu sistem açılmazsa: USB'den canlı oturumu açın, Konsole'da `pkexec /usr/local/sbin/alpbahos-recover` | Kurulu sistemi bulur, önyükleyiciyi ve initramfs'i onarır, "recovery done" der |

## 6. Ne gönderilecek

- Bilgisayar bilgileri (1.4), ISO adı ve sha256.
- Her adım için: çalıştı / çalışmadı / denenmedi; çalışmayanlar için ekran fotoğrafı.
- `systemctl --failed`, `journalctl -b -p err` (3.7, 3.8) çıktıları, `free -m` değeri.
- Takılma, donma ya da siyah ekran varsa: hangi adımda, ne kadar beklendi.

## 7. Sonuç tablosu

| Adım | Sonuç | Not |
|---|---|---|
| | | |
