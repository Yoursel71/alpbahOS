# Liquid profili — prototip planı (uygulanmadı)

Durum (26 Eylül 2026): **plan.** Kod yok, ölçüm yok. D10 "güçlü cihazlarda liquid glass veya normal cam" der; MASTER_PLAN §7.2 gereği yalnız blur uygulanırsa bu **Glass** sayılır, Liquid değil. Glass profili `bin/alpbah-gorunum glass` ile KWin'in hazır blur/contrast efektlerini kullanır; Liquid ayrı bir KWin efekti gerektirir.

## Neden hazır bileşenle yapılamıyor

KWin 6.4.4'teki `blur` efekti (`src/plugins/blur/`) pencere arkasındaki alanı örnekleyip bulanıklaştırır; ayarları yalnız `BlurStrength` ve `NoiseStrength`'tir (`blur.kcfg`). Cam kenarında kırılma (arka planın kenar bölgesinde yer değiştirerek görünmesi), ışık vurgusu ve kalınlık hissi için arka plan örneğinin bir yer değiştirme (displacement) haritasıyla okunması gerekir; bu, mevcut efektlerin hiçbirinin ayarı değildir.

## Prototip yolu (hazır mekanizmalar)

1. Kaynak: KWin `blur` efektinin kaynak kopyası üzerinde, efekt API'siyle (C++ `KWin::Effect`, `GLShader`) ayrı bir efekt (`alpbah_liquid`). Compositor, panel veya pencere yöneticisi değiştirilmez.
2. Shader: blur'un arka plan dokusu okunurken yalnız pencere/panel kenarından N px içeride normal vektöre göre küçük bir UV kaydırma + ince kenar vurgusu. Merkez bölge Glass ile aynı kalır (okunabilirlik).
3. Kapsam: yalnız Plasma panelleri ve dock (blur isteyen yüzeyler); uygulama pencerelerine uygulanmaz.
4. Kapı: OpenGL compositing ve donanım sürücüsü şart; softpipe/LLVMpipe'ta efekt yüklenmez (`alpbah-gorunum` Glass için aynı kuralı uygular).

## Kabul ölçütü (ölçülmeden "hazır" denmez)

| Ölçüm | Yöntem | Eşik (öneri) |
|---|---|---|
| Kare süresi | Glass ve Liquid'de aynı sahne, 60 sn; PERF-01 yöntemi (`profiles/perf/`) | 1080p/60 Hz'de medyan ≤ 16,7 ms, Glass'a göre p95 artışı ≤ 2 ms |
| Bellek | `profiles/perf/collect_session_metrics.py` ile KWin RSS farkı | Glass'a göre ≤ +30 MiB |
| Okunabilirlik | Panel metni ve simgeler, açık/koyu duvar kâğıdı | Glass ile aynı kontrast (WCAG AA hedefi) |
| Geri dönüş | `alpbah-gorunum solid` sonrası efekt yüklü değil | `/Effects loadedEffects` içinde yok |

## Açık konular

- Efekt C++ olarak derlenir; derleme ve paketleme Codex'in BLFS zincirindedir. Claude kaynak ve shader'ı hazırlar, Codex derler.
- Hedef donanım (RTX sınıfı) Hyper-V'de yok; ölçüm çıplak donanım gerektirir (BETA-01'e kadar ertelenebilir).
- Başarısız olursa alfa Glass ile çıkar ve Liquid "bilinen sınırlama" olarak yazılır (MASTER_PLAN §13).
