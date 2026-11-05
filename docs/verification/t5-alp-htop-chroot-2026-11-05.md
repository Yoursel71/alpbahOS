# T5 — `alp` htop kur / çalıştır / kaldır (chroot, 5 Kasım 2026)

Kapsam: PKG-01/PKG-02 için `alp install htop` → çalıştır → `alp remove htop` akışı. Ortam: LFS rootfs (`/mnt/lfs`) üzerinde **chroot**, `--root /` (chroot içinde). **QEMU açılmadı**; kabul için QEMU imajında tekrar gerekiyor.

## Kaynak doğrulaması

- Kaynak: `https://github.com/htop-dev/htop/releases/download/3.3.0/htop-3.3.0.tar.xz` (337956 bayt).
- sha256: `a69acf9b42ff592c4861010fce7d8006805f0d6ef0e8ee647a6ee6e59b743d5c`.
- Upstream release'in yayımladığı `htop-3.3.0.tar.xz.sha256` dosyasıyla `sha256sum -c` → **Tamam**.
- Tarif (`recipes/htop.recipe.json`) demo tarifindeki yer tutucu sha256'yı (`REPLACE_WITH_REAL_UPSTREAM_SHA256_BEFORE_USE`) bu değerle değiştirdi. Kaynak `file:///root/alp-src/htop-3.3.0.tar.xz` olarak yerel tutuldu; yani indirme chroot içinde yapılmadı.

## Motor

- `docs/handoffs/claude/alp-prototype/alp.py` → rootfs `/usr/bin/alp`. sha256 (ilk 16 hane) `92d519212d161159`, repo dosyasıyla `cmp` eşleşti.
- Motor `python3` (LFS 3.13) ile çalıştı. `@PREFIX@` yer tutucusu kullanıldı; `--root /` altında önek `/usr`.

## Adımlar ve sonuçlar

| Adım | Komut (chroot içinde) | Sonuç |
|---|---|---|
| Bilgi | `alp --root / --index /root/alp-catalog/index.json info htop` | `status: not-installed`, `version: 3.3.0` |
| Kur | `alp ... install -y htop` | `htop 3.3.0 [recipe]` → `kuruldu`; `INSTALL_RC=0`; derleme tamam |
| Çalıştır | `/usr/bin/htop --version` | `htop 3.3.0` |
| Listele | `alp ... list` | `htop	3.3.0	recipe` |
| Kaldır | `alp ... remove -y htop` | `htop kaldırıldı.`; `REMOVE_RC=0` |
| Kaldırma sonrası | `ls /usr/bin/htop`; `alp list` | Binary yok; `Kurulu paket yok.` |

Not: İlk kurulum denemesinde günlük yönlendirmesi ana makinede yapıldığı için komut başlamadı (`alp list` boştu); ikinci denemede günlük chroot içinde tutuldu ve kurulum tamamlandı. Bu yalnızca test düzeneğiyle ilgili.

## Açık işler

- **QEMU'da aynı akış** (VM sınırı): imaja `alp.py`, `/root/alp-catalog` ve `htop` tarifi eklenmeli.
- Gerçek `alpbahOS-alp` kataloğu bu testte kullanılmadı; yalnızca htop'u içeren yerel katalog kullanıldı.
- `alp update`, `upgrade`, rollback ve `--relocate` ayrı kabul; bu belgede yok.
- Yerel kataloğun bağımlılık çözümü (`htop` ncurses'e bağlı) yalnızca rootfs'te var olan ncurses ile test edildi.
