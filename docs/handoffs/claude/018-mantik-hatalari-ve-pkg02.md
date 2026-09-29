# Claude devir belgesi 018: mantık hataları düzeltmeleri ve PKG-02 mağaza sözleşmesi

```text
Görev ID / durum: Kullanıcı isteği (28 Eylül 2026): "repoyu oku, mantık hatalarını bul, bildir ve düzelt; sonra Claude'a atanmış işlere başla". 5 hata düzeltildi; PKG-02'nin alp tarafı (plan JSON + ilerleme kanalı) uygulandı.
Çalışılan host ve branch/commit: YRSLF dışında Windows makinesi; dal claude/logic-fixes, taban main 9c26ecf. Ana makineye SSH (yrslf@100.124.192.28) anahtar eklenmediği için kullanılamadı; parola ile giriş yapılmadı.
Değişen dosyalar: aşağıda.
Çalıştırılan doğrulama ve sonuç: alp test paketi 205 geçti / 18 atlandı (Windows, Python 3.14.4, pytest 9.1.1, geçici venv). Betik düzeltmeleri bash -n ve stub'lı yeniden üretimle denendi; Builder/Gen2'de çalıştırılmadı.
Sonraki eylem: SSH erişimi açılınca M07/M09'un repoda olmayan dört dosyasını ana makinede bulup commit'lemek (017 §1); Gen2'de 015/016 doğrulamaları.
```

## Bulunan ve düzeltilen mantık hataları

| # | Hata | Etki | Kanıt | Commit |
|---|---|---|---|---|
| 1 | `alp`: `adopt-base` yolları `usr/bin/x`, tarif/core kayıtları `/usr/bin/x` olarak tutuyor; sahiplik karşılaştırmaları ham dizge | `adopt-base` alp ile kurulmuş dosyayı da sahipleniyor (çift sahiplik). O alp paketi kaldırılınca **korumalı taban paketinin dosyası siliniyor**. `_other_owners` taban symlink'lerini saymıyordu | Yeniden üretim: `/usr/bin/htop` iki pakette; `alp remove htop` sonrası dosya yok. Yeni 3 testten 2'si eski kodda kalıyor | `8ee52e0` |
| 2 | `scripts/apply-m2-rootfs-fixes.sh` hash farklıysa rootfs `alp.py`'yi e8b0376 kopyasıyla değiştiriyor | Her test imajı üretimi, entegratörün kurduğu daha yeni `alp`'i sessizce geri döndürürdü | Sahte rootfs: eski davranışta değişiyordu; şimdi `ALP_REPLACE=1` olmadan exit 1 | `8e88ff0` |
| 3 | 8 betikte `set -e` altında `! komut` denetimleri (M04 chroot bağlama koruması, D-Bus şablon yer tutucusu) | Bash `!` ile tersine çevrilen komutta errexit/ERR trap uygulamaz; korumalar hiç durdurmuyordu | `set -Eeuo pipefail; ! true; echo devam` devam ediyor; düzeltilmiş koruma stub ile exit 1 | `c8888cd` |
| 4 | `scripts/patch-m2-gen2-autoseat.sh`: işaret dosyası `/run/alp-plasma-tried` (admin yazamaz) | Yazma hatası sessiz; `startplasma-wayland` her tty1 girişinde yeniden başlar. Runtimefix imajındaki elle düzeltme repoya yansımamıştı | Simülasyon: yeni sürüm açılışta bir kez başlatıyor, yazılamazsa başlatmıyor | `ba73709` |
| 5 | `alp --relocate`: kök denetimi `Path("/")` ile | `//` (POSIX) ya da `C:\` kökte önek `//usr` / `C:\/usr` oluyordu; main'de Windows'ta 1 test kalıyordu | `test_relocate_is_noop_for_real_root` artık geçiyor | `866030c` |

Ek olarak betik 4 artık `*/artifacts/*` altındaki bir imajı yerinde yamalamayı reddediyor. `docs/AGENT_STANDING_RULES.md`'deki yeniden deneme komutu yeni işaret yoluna göre güncellendi.

**Geri çekilen bulgu:** 017 §7'deki (`refresh-ssh-hosts.ps1` ANSI kodlaması) Türkçe Windows'ta yeniden üretilemedi. Okuma ve yazma aynı ANSI kod sayfasını kullandığı için UTF-8 içerik bozulmadan geri yazıldı. Betik değiştirilmedi.

**Düzeltilmeyen, raporlanan:** `docs/handoffs/claude/tools/check_docs.py` repoda olmayan betik/kanıt atıflarını yakalamıyor. Bir kural prototiplendi ama 11 bulgunun çoğu yanlış pozitif çıktı (belgeye göreli yollar, önek örnekleri), bu yüzden eklenmedi. Asıl eksik dört M07/M09 dosyasının commit'lenmesi (017 §1) ana makineye erişim ister.

## PKG-02: alp ↔ mağaza işlem sözleşmesi (alp tarafı)

- `alp --json --dry-run install|upgrade|remove <ad>`: onaydan önce gösterilecek plan tek JSON nesnesi olarak döner. İçeriği: `steps[]` (action, name, old/new_version, method, reason, download_size), `problems[]`, `download_size_total`, install'da `already_installed`, upgrade'de `kept_back`, remove'da `orphans_after`. Reddedilecek işlemde çıkış 1'dir, hiçbir şey değişmez. Boyut yalnız katalogda `size` (bayt) varsa verilir; yoksa `null` döner ve toplam da `null` olur, kısmi toplam gösterilmez.
- `--progress-fd N`: satır başına JSON olaylar (`plan`, `step` start/done + `percentage`, `phase` download/build/merge, `error` + `completed`, `done`). İnsan mesajları stdout/stderr'de kalır.
- `alp_packagekit_backend.py`: `alp_plan`, `alp_updates` (test edildi). `AlpPackageKitBackend.get_updates` yazıldı, gerçek PackageKit daemon'unda denenmedi.
- Kalan (tasarım §7): gerçek PackageKit daemon ve Discover uçtan uca testi, polkit action testi, ilerleme olaylarının `Percentage`/`Status` sinyallerine bağlanması, grafik mağaza arayüzü. Bunlar Linux oturumu ister.

## Değişen dosyalar

`docs/handoffs/claude/alp-prototype/{alp.py,alp_packagekit_backend.py,README.md,design/packagekit-integration.md,tests/test_base_adoption.py,tests/test_packagekit_backend.py,tests/test_store_contract.py}`, `scripts/{apply-m2-rootfs-fixes.sh,build-m2-gen2-test-image.sh,patch-m2-gen2-autoseat.sh,build-m04-{bc,dejagnu,flex,iana-etc,man-pages,sed,tcl}-stage.sh}`, `docs/AGENT_STANDING_RULES.md`, `docs/WORKLOG.md`, bu belge.

## Sahiplik notu

`scripts/` Codex'in alanıdır; kullanıcı 28 Eylül'de hataların düzeltilmesini açıkça istediği için düzeltildi. Değişiklikler küçük ve ayrı commit'lerdedir, Codex incelemesine açıktır. `alp.py` rootfs'te kurulu değil; rootfs'teki e8b0376 hash pin'i bu değişikliklerden etkilenmez.
