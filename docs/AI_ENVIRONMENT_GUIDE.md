# alpbahOS — Yapay zekâ ajanları için ortam rehberi

> **Bu belge ne için?** "Bu komutu nerede çalıştırmalıyım?" sorusunun tek cevabı burada. Kurallar `AGENTS.md`'de, güncel durum `CURRENT.md`'de. Bu belge makineleri, dizinleri ve iş akışlarını anlatır. Bir işe başlamadan önce **§1 haritasına** ve **§3 tablosuna** bak.
>
> **Neden yazıldı?** 23 Eylül 2026'da bir ajan, alpbahOS'u **test VM'inin içinde** (Gen1 guest) yeniden derlemeye kalktı. Oysa bütün derleme altyapısı Builder'da hazırdı. Test VM'i bir *ürün*dür, *atölye* değil.

> **Güncel VM durumu (24 Eylül 2026):** Kullanıcı Gen1 test VM'inin silindiğini doğruladı. Gen1 test sonuçları tarihsel kanıt olarak kalır; güncel canlı test hedefi Gen2'dir. İki eski Gen1 VHDX dosyası F: üzerinde duruyor; silme veya yeni VM'ye bağlama talimatı verilmedi.

---

## 1. Harita: dört ayrı yer, dört ayrı görev

```text
┌──────────────────────────── Windows host (kullanıcının PC'si) ────────────────────────────┐
│  C:\alpbahOS          → Git ana çalışma ağacı (main, Codex)   — BELGE/KOD, derleme YOK      │
│  C:\alpbahOS-claude   → Git çalışma ağacı (claude/desktop-bootstrap, Claude)               │
│  F:\alpbahOS-build\   → Büyük dosyalar: artifacts\ (VHDX release), vms\ (VM çalışma diski) │
│  Hyper-V Manager      → VM'leri açar/kapatır (yönetici yetkisi gerekir)                    │
│                                                                                            │
│   ┌──────────── Builder VM (Ubuntu 24.04, hostname "yrsk", kullanıcı "sa") ────────────┐   │
│   │  ATÖLYE. Bütün derlemeler burada.                                                  │   │
│   │  /mnt/lfs   → alpbahOS'un kök dosya sistemi (rootfs) = TEK DOĞRULUK KAYNAĞI        │   │
│   │               chroot ile içine girilir; paketler burada derlenir ve kurulur        │   │
│   │  /mnt/lfs/sources        → doğrulanmış kaynak arşivleri                            │   │
│   │  /mnt/lfs/tmp/alp-logs/  → derleme logları                                         │   │
│   └────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                            │
│   ┌──────────── Test VM'leri (Gen1 = BIOS, Gen2 = UEFI) — ör. alpbahOS-M2-SSH-Gen1 ─────┐  │
│   │  ÜRÜN. Rootfs'ten üretilmiş imajı açıp DENER. Derleme YAPILMAZ.                    │  │
│   │  2 vCPU / 2 GiB RAM; derleyici yükü taşıyacak şekilde tasarlanmadı.                │  │
│   └────────────────────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Tek cümlelik kural:** *Derleme Builder'da (`/mnt/lfs` chroot'unda), belge Windows'taki Git ağacında, deneme test VM'inde yapılır.*

---

## 2. Altın kurallar

1. **Test VM'inde asla derleme yapma, paket kurma, `alp install` çalıştırma.** Bir şey eksikse Builder rootfs'inde kur, yeni imaj üret, VM'i o imajla tekrar dene.
2. **Rootfs tek doğruluk kaynağıdır.** Çalışan VM diskine elle dosya kopyalamak yasak. Yaptığın her düzeltme `/mnt/lfs`'e girmeli; yoksa bir sonraki imajda kaybolur (23 Eylül'de PAM login ve `plasma_session` düzeltmeleri bu yüzden kayboldu).
3. **Release VHDX'e dokunma.** `F:\alpbahOS-build\artifacts\*.vhdx` sabittir; hash'i kayıtlıdır. Test için `F:\alpbahOS-build\vms\` altına ayrı bir kopya ya da differencing disk kullan.
4. **Tek yazıcı.** Aynı anda yalnız bir ajan `/mnt/lfs`'e yazar. Başlamadan önce Builder'da çalışan bir derleme var mı bak (§6).
5. **IP adresleri değişir.** Builder ve test VM'leri her açılışta DHCP'den yeni adres alabilir. Eski IP'ye bağlanamıyorsan önce IP'yi yeniden öğren (§5); "sistem bozuk" sonucuna atlama.
6. **Kanıtsız "tamamlandı" yok.** Komut, ortam, sonuç ve log yolu yazılmadan hiçbir iş bitmiş sayılmaz (`AGENTS.md`).
7. **Yetki yoksa dur ve söyle.** sudo parolası, Hyper-V yönetici yetkisi, fiziksel disk gibi engellerde etrafından dolaşma. Kullanıcıya **tam olarak ne gerektiğini** yaz (§7).

---

## 3. "X'i yapmak istiyorum, nerede yaparım?"

| Yapmak istediğin | Nerede | Nasıl / not |
|---|---|---|
| Bir BLFS paketini derlemek ya da kurmak | **Builder → `/mnt/lfs` chroot** | Kaynağı `/mnt/lfs/sources`'a indir, checksum doğrula, chroot'ta derle. Logu `/mnt/lfs/tmp/alp-logs/`'e yaz (§4.1). |
| Kernel derlemek | **Builder → `/mnt/lfs` chroot** | Aynı kaynak ağacı; config değişikliğini WORKLOG'a yaz. |
| `alp`'i sisteme yerleştirmek | **Builder → `/mnt/lfs/usr/lib/alp/alp.py`** | Kaynak: `docs/handoffs/claude/alp-prototype/alp.py` (belirli bir commit'ten). Kurulumdan sonra hash karşılaştır (§4.3). |
| `alp` kodunu değiştirmek | **Windows → `C:\alpbahOS-claude`** | Claude'un sahipliğinde. Codex bulguyu raporlar, kodu değiştirmez. |
| `alp`'in testlerini Linux'ta koşmak | **Builder → `/tmp/<ajan>-<iş>-XXXX`** | Geçici dizin kullan. `/mnt/lfs`'e ve Builder'daki Git reposuna dokunma; iş bitince dizini sil. |
| Yeni VHDX imajı üretmek | **Builder** (rootfs'ten) → **F:\alpbahOS-build\artifacts** | Rootfs'ten üret, SHA-256 al, `.sha256` ve `.txt` manifestini yanına koy (§4.2). |
| Kullanıcı hesabı, parola, SSH anahtarı eklemek | **Builder → rootfs'e provisioning betiğiyle** | M1 imajından kopyalama yok; tekrarlanabilir betik kullan (`docs/IMAGE_PROVISIONING.md`). |
| Açılışı, ağı, reboot'u denemek | **Test VM** (Gen1 ve Gen2 ayrı ayrı) | login → `networkctl status` → hosttan ping → kontrollü reboot → tekrar. |
| Plasma oturumunu denemek | **Test VM, VMConnect konsolu (tty1)** | SSH oturumu DRM seat vermez; SSH'den Plasma testi geçersizdir. |
| Belge, karar, backlog güncellemek | **Windows → Git ağacı** | Durum → `CURRENT.md`, karar → `DECISIONS.md`, kanıt → `WORKLOG.md`. Başka yerde tekrarlama. |
| Belge tutarlılığını kontrol etmek | **Windows → Git ağacı** | `python docs/handoffs/claude/tools/check_docs.py` → 0 bulgu olmalı. |
| VM oluşturmak, açmak, kapatmak, disk bağlamak | **Windows → Hyper-V** (yönetici) | Yetki yoksa kullanıcıdan iste (§7). |

---

## 4. Standart iş akışları

### 4.1 Bir paketi derleyip rootfs'e kurmak

1. Builder'a bağlan (§5). Başka derleme var mı bak (§6).
2. Kaynağı indir: `/mnt/lfs/sources/`. **BLFS 12.4 kitabındaki** MD5/SHA ile doğrula (D33: 12.4'te kalıyoruz, 13.1 değil).
3. Chroot'a gir. Standart yöntem LFS kitabındaki gibidir: `/dev`, `/dev/pts`, `/proc`, `/sys` ve `/run` bağlanır, ardından `chroot /mnt/lfs /usr/bin/env -i ... /bin/bash --login`. Mevcut uygulama: derleme `lfs` kullanıcısı (UID 1001) ile `chroot --userspec` altında, kurulum root ile.
4. Derle, testleri çalıştır, kur. Bütün çıktıyı `/mnt/lfs/tmp/alp-logs/<paket>-build.log`'a yönlendir.
5. İşin bitince bağlamaları ayır (`umount`), geçici dosyaları temizle.
6. `WORKLOG.md`'ye yaz: paket, sürüm, checksum, yapılandırma bayrakları, test sonucu, log yolu ve log SHA-256'sı. Paketi `M2_BLFS_MANIFEST.md`'ye ekle.

### 4.2 Rootfs'ten yeni imaj üretmek

1. Rootfs'in kullanıma hazır olduğundan emin ol: hesap, PAM, `alp`, gerekli drop-in'ler **rootfs'te** mi?
2. Builder'da rootfs'ten VHDX üret. SHA-256 al.
3. `F:\alpbahOS-build\artifacts\`'e kopyala; hash'i iki tarafta da karşılaştır. `.sha256` ve kapsamını anlatan `.txt` dosyasını yanına koy.
4. Test VM'ini **ayrı bir çalışma kopyasıyla** aç; release dosyası değişmemeli.
5. Dağıtılacak (public) bir imajsa: `/etc/machine-id` boş olmalı, SSH host anahtarları ilk açılışta üretilmeli, geliştirici anahtarı ya da parolası imajda bulunmamalı.

### 4.3 `alp`'i gerçek rootfs'e yerleştirmek

```text
# Windows'ta: kurulacak dosyanın beklenen hash'i
git show <commit>:docs/handoffs/claude/alp-prototype/alp.py | sha256sum
# Builder'da: kurulumdan sonra
sha256sum /mnt/lfs/usr/lib/alp/alp.py        # iki hash aynı olmalı
```

WORKLOG'a **commit'i ve hash'i** yaz. Hash eşleşmeden "şu commit kuruldu" yazma (23 Eylül'de `a82f872` yazıldı, kurulan aslında `36f5240` + yamaydı).

### 4.4 Test VM'inde kabul testi

Gen1 **ve** Gen2 için ayrı ayrı:
1. Konsolda `alpbahos login:` istemi.
2. Giriş → `networkctl status eth0` → DHCP adresi.
3. Hosttan `ping` (4/4).
4. `sudo systemctl reboot` → aynı adımlar tekrar (IP değişebilir).
5. Masaüstü testi yalnız VMConnect konsolunda (tty1/seat0).

Sonuçları ekran görüntüsü, komut çıktısı ya da hash ile WORKLOG'a yaz.

---

## 5. Bağlantı ve IP bulma

- **Builder:** SSH ile `sa` kullanıcısı. IP değişir (bilinen adresler: `172.28.174.11`, `172.28.162.172`). Bağlanamazsan Hyper-V Manager'da VM'in "Networking" sekmesinden ya da yönetici PowerShell'de `Get-VMNetworkAdapter -VMName <ad>` ile güncel IP'yi al.
- **Test VM:** MAC adresi sabittir (ör. `00-15-5D-00-02-08`). Hostta `arp -a` ile o MAC'in güncel IP'sini bul.
- SSH yapılandırmasında (`~/.ssh/config`) eski IP kalmış olabilir. Tek seferlik geçersiz kılmak için `ssh -o HostName=<yeni-ip> <alias>` kullan.
- **Özel anahtar içeriği asla mesaja, loga ya da belgeye yazılmaz;** yalnız dosya yolu belirtilir.

---

## 6. Başlamadan önce 30 saniyelik kontrol

```text
[ ] Hangi makinedeyim? (Windows / Builder / test VM) → hostname, whoami
[ ] Bu iş §3 tablosuna göre burada mı yapılır?
[ ] Builder'da başka derleme var mı?   → ps aux | grep -E 'make|ninja|cmake|chroot'
[ ] /mnt/lfs'te yer var mı?              → df -h /mnt/lfs   (Qt/KDE büyük alan ister)
[ ] Git ağacında commit'lenmemiş iş var mı? → git status --short
[ ] Dokunacağım dosya benim sahipliğimde mi? (AGENTS.md / BACKLOG.md sözleşmesi)
```

Bitirirken: commit'le, gerekiyorsa push'la, `CURRENT.md`'yi güncelle, `check_docs.py`'yi çalıştır. **Saatlerce commit'siz çalışma**, iş kaybı ve diğer ajanla çakışma demektir.

---

## 7. Engele takılınca: yetki gerektiren şeyler

Bu adımları ajan kendi başına yapamaz ya da yapmamalı. Kullanıcıdan tam olarak şunu iste:

| Engel | Belirti | Kullanıcıdan istenecek |
|---|---|---|
| Hyper-V yönetimi | `Get-VM` → yetki hatası | Ajanı yönetici olarak çalıştırma ya da kullanıcıyı "Hyper-V Administrators" grubuna ekleme |
| Builder root işlemleri | `sudo -n` → "a password is required" | O komut için sudo parolasını girme ya da **dar kapsamlı** bir sudoers kuralı |
| Test VM'i açılmıyor ya da IP yok | ping/SSH zaman aşımı | VMConnect ekran görüntüsü, VM'i başlatma |
| Fiziksel disk, bootloader, Windows boot | — | Açık, yazılı kullanıcı onayı (`AGENTS.md`) |

Engeli WORKLOG'a "bloklandı: <sebep>, gereken: <yetki>" diye yaz ve **başka bir makinede ya da başka bir yolla aynı işi yapmaya çalışma**. Test VM'inde derleme denemesi tam olarak bu hataydı.

---

## 8. Gerçek hatalardan çıkan dersler (23 Eylül 2026)

| Olan | Neden yanlış | Doğrusu |
|---|---|---|
| Test VM'inde (Gen1) alpbahOS derlenmeye çalışıldı | Test VM'i ürün; 2 GiB RAM, derleme ortamı yok, değişiklik rootfs'e dönmez | Builder `/mnt/lfs` chroot'u |
| Login ve Plasma düzeltmeleri yalnız çalışan VM diskine kondu | Rootfs'ten üretilen bir sonraki imajda kaybolur | Önce rootfs, sonra yeni imaj |
| Rootfs'teki `alp` sürümü yanlış kaydedildi | Hash doğrulanmadan commit adı yazıldı | §4.3: hash eşleşmeden yazma |
| Eski IP'ye bağlanılamayınca iş durdu | IP değişmişti | §5: güncel IP'yi bul |
| Bozuk yama dosyası (hunk başlığı yanlış) repoya girdi | `git apply --check` çalıştırılmamıştı | Yamayı `diff -u` ile üret; `git apply --check` ve `patch --dry-run --fuzz=0` ile doğrula |
| Belgeler eski kararları söylemeye devam etti | Aynı bilgi birçok belgeye kopyalanmıştı | Tek kaynak + `check_docs.py` |
| Saatlerce commit'siz çalışıldı | İş kaybı ve çakışma riski | Her anlamlı adımda commit |

---

## 9. Hızlı sözlük

- **Builder:** Ubuntu VM; alpbahOS'un derlendiği atölye.
- **rootfs / `/mnt/lfs`:** alpbahOS'un dosya sisteminin kendisi; Builder içinde bir dizin.
- **chroot:** Builder'da `/mnt/lfs`'i kök dizinmiş gibi göstererek içinde komut çalıştırma. Host'un kütüphaneleri görünmez.
- **Test VM / guest:** Üretilen imajı açan Hyper-V VM'i. Gen1 = BIOS, Gen2 = UEFI.
- **Release VHDX:** `F:\alpbahOS-build\artifacts` altındaki, hash'i kayıtlı, değiştirilmeyen imaj.
- **Çalışma kopyası:** Test VM'inin açtığı, değişebilen disk kopyası.
- **`alp`:** alpbahOS paket yöneticisi (Claude'un sahipliğinde); rootfs'te `/usr/lib/alp/alp.py`.
