# Claude devir belgesi 007 — 5 yeni gerçek tarif + symlink bug'ı (dangling symlink kopyalama)

Görev ID / durum: (Backlog dışı, kullanıcı talebi — "1000 yaygın/küçük paket ekle") **kasıtlı olarak küçültülmüş, dürüst bir kapsamla** tamamlandı. Kullanıcıya önce bunun neden mümkün olmadığı anlatıldı, "istediğini yap, alp kullanışlı olsun yeter" onayıyla devam edildi.

Çalışılan host: Windows (araştırma/indirme/checksum) + `alpbah-builder` Ubuntu VM (SSH, gerçek derleme testi). Dal: `claude/desktop-bootstrap`.

## Kapsam kararı

Kullanıcı 1000 paket istedi; bunun yerine **9 gerçek, doğrulanmış tarif** (toplamda, önceki 4 + bu turda eklenen 5) teslim edildi. Gerekçe [alpbahOS-alp README](https://github.com/Yoursel71/alpbahOS-alp)'de kayıtlı: `alp` bağımlılık çözümü yapmıyor (çoğu yaygın paket zincirleme kütüphane ister), çoğu yaygın araç configure/make dışı build sistemleri (CMake/Meson/Rust/Go/Node) kullanıyor. 1000 tarif eklemek "doluymuş gibi görünüp çoğu çalışmayan" bir katalog üretirdi.

## Bu turda eklenen 5 paket

| Paket | Gerçek Linux'ta sonuç |
|---|---|
| `figlet` 2.2.5 | ✅ Tam başarılı (indirme→checksum→derleme→kurulum) |
| `socat` 1.8.0.1 | ✅ Tam başarılı (`--disable-openssl` ile) |
| `units` 2.23 | ✅ Tam başarılı — **bu test bir `alp` bug'ını buldu, düzeltildi** |
| `bc` 1.07.1 | ❌ Gerçek derleme denendi, `ed` aracı eksik olduğu için durdu (belgeli) |
| `less` 668 | ❌ Gerçek derleme denendi, ncurses/termcap eksik olduğu için durdu (belgeli) |

`tree` adayı da araştırıldı ama **eklenmedi**: kendi Makefile'ı `DESTDIR` değişkenini `alp`'in beklediğinden farklı anlamda (`DESTDIR=${PREFIX}/bin`) kullanıyor — eklenirse dosyalar yanlış yere (`/` köküne) kurulurdu. Bu çakışma fark edilip paket listeden çıkarıldı, hiçbir zaman repoya eklenmedi.

## Bulunan ve düzeltilen 2. gerçek bug: dangling symlink kopyalama

**Bug:** `units` paketi kasıtlı olarak hedefi olmayan (dangling) symlink'ler içeriyor (`currency.units -> /usr/com/units/currency.units` — admin'in sonradan dolduracağı veri dosyaları için, GNU units'in kendi tasarımı). `_merge_destdir` ve `_config_aware_merge`, staged dosyaları `shutil.copyfile()` ile kopyalıyordu — bu fonksiyon symlink'in **hedefini** açmaya çalışır; hedef yoksa `FileNotFoundError` fırlatır. Kurulum böyle çöktü.

**Düzeltme:** Yeni `_copy_entry(src, dst)` yardımcı fonksiyonu — kaynak bir symlink'se, hedefi açmadan `os.readlink`+`os.symlink` ile symlink'in **kendisini** yeniden oluşturuyor; değilse eskisi gibi `shutil.copyfile`. `_merge_destdir`'deki 1 ve `_config_aware_merge`'deki 3 kopyalama noktası güncellendi.

**Test:** Gerçek Linux'ta `units` kurulumu düzeltmeden önce çöktü, düzeltmeden sonra tam başarılı oldu; symlink'lerin gerçekten (hedefleriyle birlikte, dangling olarak) korunduğu `ls -la` ile doğrulandı. 2 yeni regresyon testi eklendi (`tests/test_alp.py`) — Windows'ta symlink izni olmadığı ortamlarda otomatik atlanıyor (`pytest.skip`), gerçek davranış VM'de elle doğrulandı.

## Çalıştırılan doğrulama ve sonuç

- Yerel test seti: 44 geçti, 2 atlandı (Windows symlink izni yok — beklenen), toplam 46 (`test_packagekit_backend.py` bu turda değiştirilmedi, ayrıca 7 test daha var).
- Gerçek Linux (SSH): `figlet`, `socat`, `units` kurulumları gerçekten tam başarılı; `bc`/`less` gerçek, beklenen eksik-araç hatalarıyla durdu; `units` düzeltme öncesi/sonrası karşılaştırmalı test edildi.
- VM'deki tüm test scratch dizinleri (`~/alp-real-test`, `~/alp-batch2`) temizlendi; gerçek LFS rootfs'e (`/mnt/alpbahos-*`) veya `~/alpbahOS` git deposuna hiç dokunulmadı.

## Bilinen sorun ve açık karar

1. `jq`/`zsh`/`tmux` bu turda gerçek derleme testinden geçirilmedi (yalnızca önceki turda checksum doğrulandı) — sırada.
2. `bc`/`less` gerçek eksiklikleri (`ed`, ncurses-dev) giderilip yeniden test edilmedi — bu, Codex'in BLFS ortamında bu araçlar zaten kuruluysa otomatik çözülür.
3. `tree` için alp'in DESTDIR varsayımına uymayan bu tür "eski tip" Makefile'lar genel bir risk — ileride eklenecek her yeni recipe için bu kontrol elle yapılmalı (otomatik bir doğrulama yok).

## Entegrasyon için gereken

Yok — bu iş tamamen kendi kapsamında bitti. Codex'in gerçek LFS/BLFS ortamında bu 9 tarifi denediğinde `ed` ve `libncurses-dev`'in (BLFS'nin zaten kapsamında olması beklenen paketler) kurulu olup olmadığı önemli.

Sonraki eylem: Yok — kullanıcı isteği tamamlandı.
