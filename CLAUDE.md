# alpbahOS — Claude çalışma başlangıcı

> İlk zorunlu belge: `docs/NEW_SESSION_HANDOFF.md`. Builder/guest SSH erişimi, Hyper-V VM adları ve disk yolları orada **24 Eylül 2026** durumuyla kayıtlıdır (ortam sonradan Fedora + QEMU/KVM oldu, D36; kullanmadan önce doğrula). Güncel aşama durumu için `CURRENT.md`.

Önce kökteki `AGENTS.md` dosyasını oku ve uygula. Ortak ürün ve çalışma kuralları oradadır; burada ikinci, çelişen bir kural seti oluşturma.

## Okuma sırası

1. `docs/NEW_SESSION_HANDOFF.md`
2. `AGENTS.md`
3. `CURRENT.md`
4. `docs/DECISIONS.md`
5. `docs/MASTER_PLAN.md`
6. `docs/WORKLOG.md`
7. Görsel bir görev için `docs/alpbahOS-design-mockups.md` ve `docs/assets/alpbahOS-logo.png`

## Güncel bağlam

- Ana plan 1.0. M1 LFS temel boot imajı ve Gen2/UEFI boot (M05) doğrulandı. M07'de Gen2 test imajında gerçek Plasma Wayland masaüstü ve paneli görsel olarak doğrulandı (25 Eylül 2026). M08 ilk dilimleri (look-and-feel, Atatürk duvar kâğıdı, Windows kısayolları, Glass, uygulama profili, PERF/OFFICE araçları) dosya düzeyinde hazır; gerçek oturum düzeltmeleri `claude/m08-live-fixes` dalında sürüyor. M09 için önyüklenebilir M-ISO test adayı üretildi (QEMU BIOS/UEFI'de login istemine kadar; kabul açık). M10 başladı; "M08 kurulum/kaldırma" `@PREFIX@` hatasıyla BLOCKED idi, alp tarafı düzeltildi ama rootfs'e kurulmadı (019/020). Kurucu (Calamares) yok. Ayrıntı ve kanıt sınırları: `CURRENT.md`.
- LFS tabanı hazır; BLFS ile hazır açık kaynak masaüstü/uygulamalar özelleştirilecek.
- Kullanıcı Windows'tan geçenler için kolay masaüstü, terminal önerileri, basit paket işlemleri, Windows kısayolları, Atatürk görselleri ve güçlü cihazlarda cam görünümü istiyor.
- Başlangıç stack'i KDE/KWin, Konsole/Zsh ve D31 ile seçilen `alp` paket motorudur. Grafik mağaza entegrasyonunu test geçmeden çalışıyor kabul etme.
- Claude Code kullanılır. Windows hostunda çalışma ağacı `C:\alpbahOS-claude` idi (24–26 Eylül); 28 Eylül 2026'dan itibaren Fedora hostunda `~/alpbahOS-claude` klonu kullanılır (D36). Dal göreve göre değişir (`git branch --show-current`). Ortak dizini başka oturumlar da kullanır: `checkout`/`stash`/`reset` yapma, çok commit'li işi ayrı `git worktree`'de yap (`AGENTS.md`).
- Hyper-V, 300 GB yerel alan, Türkçe Q, düşük RAM ve BIOS+UEFI hedefleri sabittir (Hyper-V'nin hedef olarak sürüp sürmediği D36 sonrası açık karardır, `docs/DECISIONS.md`). Kullanıcı günde 1–2 saat ayırır. Sistem yalnız 64-bit'tir (D32, D35): multilib yok, Steam istemcisi kapsam dışı, Wine yalnız WoW64; Steam uyumluluğu vaat etme.

## Rol ve ilk görev

İş bölümü: Codex LFS/build, ISO ve entegrasyon; Claude masaüstü teması, terminal UX, uygulama profilleri, Windows geçiş deneyimi ve D31'de seçilen `alp` paket motoru. D32 saf 64-bit kararı geçerlidir; D22/D32 uyumsuzluğu kullanıcı kararıyla (D35) bu yönde kapandı. Her iki ajan diğerinin kritik değişikliklerini inceleyebilir. İlk görevin ayrıntıları `docs/CLAUDE_START.md`, görev sırası `docs/BACKLOG.md` içindedir. İşe başlama kaydı olmadan görev yürütülüyor sayılmaz.

Bir görev üstlenildiğinde yalnız o görevin dosya sınırında çalış. Ortak kernel, paket manifesti, build sürümleri, rootfs veya mount işlemlerini koordinasyonsuz değiştirme.

## Claude için çalışma biçimi

- Claude Code kullanılıyorsa önce gerçek çalışma dizinini ve değişiklikleri kontrol et; buradaki `C:\alpbahOS` yolu başka hostta mevcutmuş gibi davranma.
- Sohbet üzerinden çalışılıyorsa erişmediğin dosyaları okumuş, komutları çalıştırmış veya testleri geçmiş sayma. Öneriyi patch/metin ve doğrulama adımlarıyla teslim et.
- Tasarım uygulamasında hazır KDE/Qt/GTK mekanizmalarını araştır; sırf mockup özel görünüyor diye yeni masaüstü kabuğu icat etme.
- Paket motorunun API'si netleşmeden mağaza işlem mantığı yazma. Önce entegrasyon sözleşmesini belirle.
- CLI önerisini kabul etmek ile komutu çalıştırmayı ayır. Bulut/LLM tabanlı terminal tahmini onaylanmış gereksinim değil.
- Liquid glass'ı sıradan saydamlık olarak sunma; deneysel prototip ve ölçüm gerekliliğini koru.
- Varsayılan masaüstü ve kilit ekranının Atatürk temalı olacağı kabul edildi. Boot ekranını ayrıca kesinleştirilmeden bu kapsama katma.

## Görev devri şablonu

```text
Görev ID / durum:
Çalışılan host ve branch/commit (varsa):
Değişen dosyalar:
Gerçekleştirilen davranış:
Çalıştırılan doğrulama ve sonuç:
Log / ekran görüntüsü / artifact:
Bilinen sorun ve açık karar:
Entegrasyon için gereken:
Sonraki eylem:
```

Son raporu Türkçe yaz. Yapılmamış testleri açıkça “çalıştırılmadı” olarak işaretle.
