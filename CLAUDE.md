# alpbahOS — Claude çalışma başlangıcı

> İlk zorunlu belge: `docs/NEW_SESSION_HANDOFF.md`. Builder/guest SSH erişimi, Hyper-V VM adları, disk yolları, `alp` hash riski ve açık M07 kapısı burada günceldir.

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

- Ana plan 1.0 ve M1 LFS temel boot imajı hazır. `alpbahOS-m1-final-v2.vhdx`, Hyper-V Gen2 üzerinde giriş istemi, DHCP/ping ve kontrollü yeniden açılışla doğrulandı. Masaüstü/BLFS ve canlı ISO henüz yok.
- LFS tabanı hazır; BLFS ile hazır açık kaynak masaüstü/uygulamalar özelleştirilecek.
- Kullanıcı Windows'tan geçenler için kolay masaüstü, terminal önerileri, basit paket işlemleri, Windows kısayolları, Atatürk görselleri ve güçlü cihazlarda cam görünümü istiyor.
- Başlangıç stack'i KDE/KWin, Konsole/Zsh ve D31 ile seçilen `alp` paket motorudur. Grafik mağaza entegrasyonunu test geçmeden çalışıyor kabul etme.
- Claude Code kullanılacak; ayrı çalışma ağacı `C:\alpbahOS-claude`, dal `claude/desktop-bootstrap`. Başka hostta clone ve aynı görev sözleşmeleri kullanılır.
- Hyper-V, 300 GB yerel alan, Türkçe Q, düşük RAM ve BIOS+UEFI hedefleri sabittir. Kullanıcı günde 1–2 saat ayırır. D22 Steam/Wine isteği ile D32 multilib'siz 64-bit kararı çatışır; bunu kullanıcı çözmeden Steam uyumluluğu vaat etme.

## Rol ve ilk görev

İş bölümü: Codex LFS/build, ISO ve entegrasyon; Claude masaüstü teması, terminal UX, uygulama profilleri, Windows geçiş deneyimi ve D31'de seçilen `alp` paket motoru. D32 saf 64-bit kararı geçerlidir; D22/D32 uyumsuzluğunu tek başına çözme. Her iki ajan diğerinin kritik değişikliklerini inceleyebilir. İlk görevin ayrıntıları `docs/CLAUDE_START.md`, görev sırası `docs/BACKLOG.md` içindedir. İşe başlama kaydı olmadan görev yürütülüyor sayılmaz.

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
