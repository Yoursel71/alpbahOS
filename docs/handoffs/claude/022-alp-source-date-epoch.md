# Claude devir belgesi 022: `alp` sabit build zamanı (`SOURCE_DATE_EPOCH`)

**Görev ID / durum:** INFRA-PKG-TIME (Codex isteği: `infra-source-date-epoch-request-2026-10-01.md`, Codex'in `codex/infra-rebuild` worktree'sinde). Kod ve testler tamam; Codex'in yeni pini alıp VM duman testini yeniden koşması bekleniyor.

**Host / dal:** Fedora 44, Python 3.14.7. Dal **`claude/alp-source-date-epoch`**; taban Codex'in test ettiği pin `c6d98d4` (yalnız bu değişiklik, başka alp düzeltmesi karışmadı). Yerel commit, push yok. Paylaşılan `~/alpbahOS-claude` ağacına dokunulmadı (ayrı git worktree).

## Yeni pin

| | |
|---|---|
| Kod commit'i | `cac0a7c109e8a51533648f26197742c77446872d` |
| `docs/handoffs/claude/alp-prototype/alp.py` SHA-256 | `d478ef1c6203160c1f36dff1ea6904d189d28923cb99f25b5058a528d95ad786` |
| Önceki pin (`c6d98d4`) `alp.py` SHA-256 | `92d519212d161159f6f083008b14c7b5b22c2d3e7e60f49fe17d493538fe25b2` |

Bu belgeyi ekleyen sonraki commit `alp.py`'yi değiştirmez; hangisini pinlerseniz pinleyin kaynak aynıdır.

## Tasarım

`SOURCE_DATE_EPOCH` ortam değişkeni (reproducible-builds kuralı) seçildi; ayrı bir "build modu" bayrağı eklenmedi, çünkü Codex'in harness'i değişkeni zaten ayarlıyor ve başka bir şalter tek kaynak ilkesini bozardı.

- **Tanımsız:** gerçek saat, davranış değişmedi.
- **Tanımlı ve geçerli:** db'ye yazılan her zaman damgası (`installed_at`, `updated_at`; core, recipe, flatpak, adopt-base, upgrade, protect yolları) o saniyedir. Tek geçit `_now()`.
- **Tanımlı ve geçersiz:** komut reddedilir, çıkış 1, hiçbir şey yazılmaz. Gerçek saate **sessizce düşülmez**; bu tekrarlanabilirliği sessizce bozardı. Doğrulama `main()` başında, kilit/db/dosya öncesi (yoksa saat sonda okunduğu için bir saatlik recipe derlemesi bittikten sonra patlardı). Geçerli: yalnız ASCII rakam, 1–12 hane, ≤ 253402300799 (9999-12-31T23:59:59Z). Reddedilen: boş, boşluklu, `1\n`, `-1`, `+1`, `1.5`, `1e9`, `0x10`, harf, Arapça-Hint rakamları, aralık dışı. `help` komutları doğrulanmadan çalışır.
- **Kasıtlı olarak gerçek saatte kalanlar:** kilit dosyasındaki `ts=` (çıkışta silinen tanı satırı; dondurulmuş zaman yanıltır) ve geri alma günlüğü dizin adındaki milisaniye (benzersizlik anahtarı; epoch'a sabitlenirse çakışır). İkisi için de regresyon testi var.
- **Komşu düzeltme (isteğin kabulü için gerekli):** `build.log_path` recipe/upgrade kayıtlarında `--root` önekini taşıyordu; farklı yoldaki iki kök (Codex'in `db-repro-a`/`db-repro-b` düzeni) recipe kaydında farklı bayt verirdi. Artık kök-bağıl (`/var/log/alp/<ad>-<sürüm>.build.log`); `--root /` ile eski değerle aynı. Alanın bu repoda okuyucusu yok (kodda ve testlerde yalnız yazılıyor); ayrı `alpbahOS-alp` reposuna bakılmadı.

## Değişen dosyalar

- `docs/handoffs/claude/alp-prototype/alp.py` (+56/−4)
- `docs/handoffs/claude/alp-prototype/tests/test_source_date_epoch.py` (yeni, 29 test)
- `docs/handoffs/claude/alp-prototype/README.md` (kullanım bölümü)
- bu belge

`BACKLOG.md`/`WORKLOG.md`/`CURRENT.md` entegratör sahipliğinde olduğu için değiştirilmedi; `INFRA-PKG-TIME` satırı entegratörün güncellemesini bekliyor.

## Doğrulama (Fedora 44, Python 3.14.7)

1. **Mevcut takım:** önce 238 geçti; sonra **267 geçti** (238 + 29 yeni). Python 3.10 yok bu makinede; yazılan kod yalnız dosyada zaten kullanılan yapıları kullanıyor, CI matrisi (3.10/3.12/3.14) çalıştırılmadı.
2. **Negatif kontrol:** yeni testler eski `alp.py` ile koşuldu, 26'sı düştü (3'ü zaten "değişmemeli" regresyonu).
3. **Codex'in senaryosu birebir:** `zlib-smoke/zlib-1.tar.gz` (SHA-256 `fd0e3858…2eebd`) iki yeni kök, `SOURCE_DATE_EPOCH=1756684800`, 1,3 sn arayla, süreç sınırı ayrı `python3 alp.py` çağrısı. Geçici index yalnız `url` alanını yerel `file://` yoluna çevirdi.

   ```text
   pin c6d98d4 (eski alp.py), kök a  71ec8ec36b7c3fafd774c6273f4c1b75e6442c0333e49eb5ef2d6763a380b4c4
   pin c6d98d4 (eski alp.py), kök b  d8188d5fe6eeb230fa123e069db91a3bf1f4c8b28d1f8084d0834694192600c5   -> farklı (Codex'in bulgusu yeniden üretildi)
   cac0a7c (yeni alp.py),     kök a  84b00ada8c6f05c526b40456a5827f2ac160f6156dbb0d969d4b8db0615cf8a0
   cac0a7c (yeni alp.py),     kök b  84b00ada8c6f05c526b40456a5827f2ac160f6156dbb0d969d4b8db0615cf8a0   -> bayt bayt aynı
   ```

   Yeni kodda `installed_at` ve `updated_at` = `2025-09-01T00:00:00Z`.
4. **İki kökün tamamı:** `var/` altı (`db.json`, `cache/zlib-1.3.1.tar.gz`, boş `rollback/`, boş `var/log/alp`; `alp.lock` kalmıyor) ve kurulan tüm dosyalar `diff -r` ile içerikçe aynı; yol/tür/mod/sahip/boyut/symlink hedefi listesinin SHA-256'sı (`find -printf '%y %m %u:%g %s %l %P\n' | sort`) iki kökte de `6370ffac2c4f361a087ab9e7f84a384e22a6b17e2dcf7686a35e5182bf780aa5`.
5. Ham komut çıktısı ayrı bir kanıt dosyasına yazılmadı; yukarıdaki sonuçlar bu belgeden alınır. Çalışma dizini geçicidir (oturum scratch'i).

## Değerlendirilip kapsam dışı bırakılanlar

- **Kurulan dosya ve dizinlerin mtime'ı.** Ölçüldü: iki kökte kurulan her girdinin (dosya, dizin, symlink, `db.json` dahil) mtime'ı kurulum saniyesidir ve kökler arasında farklıdır; arşivdeki mtime korunmuyor (`_copy_entry` yalnız `copymode`). `db.json` ve (yol, mod, sahip, boyut, hash) manifestini etkilemez. İmaj düzeyinde hash mtime içeriyorsa (squashfs/ext4/tar) imaj aşamasında kıstırılması (`mksquashfs -all-time`, `tar --clamp-mtime`) olağan çözümdür; yine de `alp`'in `SOURCE_DATE_EPOCH` varken oluşturduğu girdilerin mtime'ını `min(mtime, epoch)` yapması istenirse bu ayrı bir değişikliktir (üst dizin mtime'ına da dokunur), karar sizin.
- **Recipe derleme günlüğünün içeriği** (`var/log/alp/*.build.log`): alt işlem çıktısı ve `$ komut` satırları (cache yollarını içerir). `alp` bunu denetleyemez. Toolchain/79 paket akışı core arşiv yolunu kullandığı için etkilenmiyor.
- **`ALP_VERSION`** değiştirilmedi: `installed_by: alp/0.1.0-proto` db'ye giriyor, sürümü oynatmak her kaydı değiştirirdi.

## Bilinen davranış (hata değil)

`remove` sonrası `/usr` ve `/usr/share` diskte kalır (korumalı); aynı paketi yeniden kurunca bu dizinler "önceden var" sayılır ve `files` listesine girmez. Yani temiz köke tek kurulum ile kur→kaldır→yeniden kur **aynı db'yi vermez**; bu sahiplik anlamıdır, zamanla ilgisi yok. Tekrarlanabilirlik aynı işlem dizisinin iki kökte aynı baytı vermesidir, test bunu doğruluyor.

## Entegrasyon için gereken

- Codex yeni pini alır, son ortak paket yordamıyla VM duman testini yeniden koşar (iki ham db hash'i eşit olmalı).
- `claude/logic-audit-020` ile birleştirme: `git merge-tree` ile denendi, `alp.py` ve `README.md` kendiliğinden birleşiyor. (`WORKLOG.md` çakışması o iki eski dal arasında, bu commit'ten bağımsız.)
- Üretim imajında `SOURCE_DATE_EPOCH` yalnız imaj üretimi sırasında tanımlı olmalı; kullanıcı oturumuna sızarsa kayıt zamanları donar.

## Sonraki eylem

Codex: yeni pinle zlib duman testini iki kökte tekrarla, `INFRA-PKG-TIME` satırını kapat; mtime kararını (yukarı) ver.
