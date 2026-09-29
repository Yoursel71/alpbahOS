# PERF-01 — RAM, kare süresi ve efekt ölçüm yöntemi

Durum (26 Eylül 2026): **yöntem ve araçlar hazır, hiçbir ölçüm yapılmadı.** PERF-01 sahibi Claude + Codex; önkoşul DESKTOP-01 (çalışan Plasma oturumu). Araçların kendisi Windows'ta sahte verilerle test edildi (`tests/test_m08_desktop_profile.py`); gerçek Gen2 ya da çıplak donanım verisi yok.

## Hedefler (ölçülmeden karşılandı denmez)

| Ölçüt | Hedef | Kaynak |
|---|---|---|
| Boşta kullanılan bellek (MemTotal − MemAvailable) | ≤ 1024 MiB, 4 GiB x86_64 sınıfında | DECISIONS P08 |
| Kare süresi (medyan, 1080p/60 Hz, hareketli sahne) | ≤ 16,7 ms | MASTER_PLAN §7.3 |
| Glass − Solid farkı | Bellek, medyan ve p95 kare süresi ayrı ayrı kaydedilir | MASTER_PLAN §7.3 |
| Liquid | Glass'a göre p95 artışı ≤ 2 ms, KWin PSS ≤ +30 MiB (öneri) | [liquid-prototype.md](../desktop/liquid-prototype.md) |

Hyper-V sonucu gerçek donanım sonucunun yerine geçmez (MASTER_PLAN §11.1). Mevcut Gen2 imajı softpipe/VGEM ile çizer; oradaki kare süreleri "sanal/yazılım renderer" satırı olarak kaydedilir, eski PC hedefi için kanıt sayılmaz.

## Araçlar

- [`collect_session_metrics.py`](collect_session_metrics.py): salt okunur anlık görüntü; `/proc/meminfo`, izlenen masaüstü süreçlerinin PSS/RSS değerleri, kullanıcının toplam PSS'i, KWin compositing türü/renderer/sürücü, etkin efektler ve `alpbah-gorunum` profili. JSON yazar.
- [`analyze_kwin_perf_csv.py`](analyze_kwin_perf_csv.py): KWin 6.4.4'ün `KWIN_LOG_PERFORMANCE_DATA=1` ile yazdığı `kwin perf statistics <çıkış>.csv` dosyasından kare süresi (ardışık pageflip farkı), render süresi, geç kare ve bütçe aşımı oranı üretir. Kaynak: kwin `src/core/renderloop.cpp`.

## Yöntem (Gen2 test VM ya da çıplak donanım)

1. **Ortam kaydı:** CPU/RAM/GPU, çözünürlük/yenileme, kernel, renderer (`collect_session_metrics.py` çıktısındaki `kwin`), profil.
2. **KWin ölçümünü aç (yalnız test oturumu):** `~/.config/systemd/user/plasma-kwin_wayland.service.d/perf.conf` içine `[Service]` + `Environment=KWIN_LOG_PERFORMANCE_DATA=1`; oturumu yeniden başlat. CSV, KWin sürecinin çalışma dizinine yazılır (`/proc/$(pidof kwin_wayland)/cwd` ile bul). Ölçümden sonra drop-in'i kaldır; dosya sürekli büyür.
3. **Boşta bellek:** girişten sonra 5 dakika bekle, `collect_session_metrics.py --label <profil>-idle`.
4. **Hareketli sahneler (her biri 60 sn, aynı sırayla):** (a) bir pencereyi sürükleme, (b) Win+Tab ile Overview aç/kapa, (c) Konsole'da sürekli çıktı. Her sahneden önce CSV'yi sıfırla (dosyayı taşı), sonra `analyze_kwin_perf_csv.py <csv> --json --budget-ms 16.7`.
5. **Profiller:** her sahne `alpbah-gorunum solid` ve `alpbah-gorunum glass` altında tekrarlanır. Glass yazılım renderer'da reddedilir; `--zorla` ile alınan sonuç ayrı işaretlenir.
6. **Kayıt:** JSON ve özetler `docs/verification/perf01-<ortam>-<tarih>/` altına; tablo PERF-01 satırına bağlanır. Başarısız ölçüm de kaydedilir.

## Bilinen sınırlar

- KWin CSV'si yalnız çizilen kareleri kaydeder; boştaki masaüstünde kare yoktur, kare süresi hareketli sahnede ölçülür.
- Uygulama içi (istemci) kare süresi ölçülmez; compositor tarafı ölçülür.
- PSS paylaşılan belleği süreçlere böler; tek bir sürecin "kendi" belleği değildir. Karşılaştırma aynı ölçütle yapılır.
