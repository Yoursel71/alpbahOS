# Codex → Claude: Alp veritabanı tekrarlanabilirlik engeli

Durum: **Alp kodu düzeltildi; guest smoke kabulü bekliyor.** Kullanıcının 2 Ekim'deki “fix it” talimatıyla Alp zaman semantiği ayrı worktree/branch üzerinde düzeltildi; ana Alp çalışma ağacındaki değişikliklere dokunulmadı. `codex/alp-source-date-epoch` commit `e7db520a5e2b513b355dbd58b77a49a45170ec46`, Alp kaynak SHA-256 `055a416a14fbdf0bfdbe25f16ffbd563b3a47071f33a1fb8861d806cd9b4fa1a`; Alp suite 192/192 geçti. Source pin `freeze-sources.py` içine alındı; `buildctl prepare` artık o pini Codex repo Git nesnesinden okuyor. Runner ve ham DB smoke çağrıları `ALP_REPRODUCIBLE_BUILD=1` ile sabit epoch modunu açıkça etkinleştiriyor. Kalan kabul: güncel kaynakla iki temiz guest DB kurulumu ve raw byte eşitliği, sonra gerçek `phase1-acceptance.json` üretimi.

Test edilen değişmez kaynak: `c6d98d4bc54ed33a4afca22e30e00ac6b1744714:docs/handoffs/claude/alp-prototype/alp.py`; SHA-256 `92d519212d161159f6f083008b14c7b5b22c2d3e7e60f49fe17d493538fe25b2`. `_now()` satır 63 gerçek UTC saatini kullanıyor; `save_db()` ve kurulum kayıtları bu yardımcıyı çağırıyor.

QEMU/KVM guest'te Python 3.13.7 ile, aynı doğrulanmış zlib core arşivi/index'i iki yeni boş köke `SOURCE_DATE_EPOCH=1756684800` ile kuruldu. 1,2 saniye aralıklı kurulumların ham `/var/lib/alp/db.json` SHA-256 değerleri:

```text
4270ed3a44ebfc5f10cfc1711730c4b6b7247406ee5ec565109ab3fd24185872
f51cf1c9ba97eab2326afff477871aaabe0e1d9887a7de262881ac39184f33a4
```

JSON farkı yalnız `/packages/zlib/installed_at` ve `/updated_at`: `2026-09-30T21:02:28Z` / `2026-09-30T21:02:30Z`. Paket arşivi ve manifest iki derlemede aynı; İlk deney sırasında kullanıcı henüz OC tamam bildirimini vermemişti. Bulgu yazılım zaman damgası kaynaklıdır, OC kararsızlığı kanıtı değildir.

Kanıtlar: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/zlib-smoke/db-repro-{a,b}.json`, `db-repro-diff.json`, `db-repro-evidence.json`. Sonuncunun SHA-256'sı `ed378435fffa214da350511f7e0fea7827bdbc871c4ce4a0459b970cf4891c01`.

İstek: Claude, build sırasında sabit zaman seçimini destekleyen Alp semantiğini tasarlayıp uygulasın. `SOURCE_DATE_EPOCH` veya açık bir build modu kullanılabilir; seçim Claude'a aittir. Sabit zamanın DB'deki tüm üretilen alanları ve imaja giren diğer Alp metadata/loglarını kapsaması değerlendirilmeli. Normal kullanıcı işlemlerinin gerçek saat davranışı ve geçersiz epoch'un reddi korunmalı/test edilmeli. Kod zamanı dışarıdan sahtelemek, DB'yi elle normalize etmek veya hash kapsamından çıkarmak kabul değildir.

Kabul: sabit epoch ile iki temiz kökün **ham DB byte'ları** eşit; sahiplik/kur/kaldır/geri kur testleri geçer; normal saat ve hatalı epoch için anlamlı regression testleri; değişmez commit + kaynak SHA-256. Codex bundan sonra yeni pini alıp son ortak paket yordamıyla VM duman testini yeniden doğrulayacak. SBU/toolchain ve ağır derleme kullanıcı kapısı arkasında kalır.

## Güncel temiz Builder smoke — 1 Ekim 2026

Temiz `checkpoint-prepared` guest'te Builder Python 3.13.7 kurulup güncel input hash'i `d77dcf5be4b8d23d6f7099f6f2f1770bd330057c256da96970f4f979d88afc35` ile smoke tekrarlandı. zlib build/test/stage arşiv ve manifest hash'leri iki koşuda aynı; Alp install/remove/reinstall ve sahiplik testi geçti. Ham DB SHA-256 yine farklı: `e7d765abc1d25ef390de260de287079bf1deaf1fdbb9c09b735762b425068122` ve `74f154119b0e934395bfff23b1b59d21eedf3ff217b52d43fe61227ef5c4eb78`. JSON incelemesi farkın yalnız `/packages/zlib/installed_at` (`2026-10-01T19:42:36Z` vs `2026-10-01T19:42:38Z`) ve `/updated_at` alanlarında olduğunu doğruladı. Bu temiz guest tekrarı aynı kök nedeni yeniden üretir; hash normalize edilmedi ve tekrar kabul edilmedi.

Üretim guest logu `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/smoke-1790883748017719784.log`, SHA-256 `abfef16ab354cb8da7e1f56c8bd72339ace6cd59ca4f8d22e7740a63e4a8fb0f`; güncel `summary.json` SHA-256 `22fff5335e7be024091f30e95b51ba2250db47e4605b5b2183aa56ba5f671039`; `db-repro-evidence.json` SHA-256 `93e9be702036dda67c83414c7b84d445f59f0a2e9da0d4dd9aa15db05e34613f`. Sonuç `FAIL_DB_REPRODUCIBILITY`; Faz 1 makbuzu oluşturulmadı. Builder kapalı.

## Güncel Alp kaynağıyla yeniden doğrulama — 1 Ekim 2026

Codex bu notu taşınabilir kopya ~/Projects/alpbahOS üzerinde yeniden denedi. Checkout temiz main, HEAD 3f6f0f1a3392a5d177ef93fa58c9217e8d70c65f; Alp dosya SHA-256 5acfe856f9a188ea37376e778dad6463bd6bf9c25af0dc959334f2a08cf379b4. Güncel _now() da time.gmtime() üzerinden gerçek UTC'yi verir.

Aynı SOURCE_DATE_EPOCH=1756684800, aynı zlib arşivi SHA-256 fd0e3858018f8b66a8a38e936982da7e85969f3f6efa6257007c248c19a2eebd, güncel kaynak ve iki yeni boş kök ile host CLI'da iki kurulum exit 0 verdi. Ham DB SHA-256 değerleri yine farklı: 7f77d9a720c9cfcac38e5fe0144ca3954e7adee13d7c2918f8416e6ba08d9149 ve c97fbd0b6de63bbd11499d924d78f03f4b722c6a7c2e84c613ec32462bfd8cf8. Yapısal JSON diff yalnız packages.zlib.installed_at ve updated_at saniye alanlarında; fark normal build metadata'yı elle düzenleyerek giderilmedi.

Güncel tekrarın salt kanıtı /mnt/alpbahOS-data/alpbahos-infra-rebuild/research/alp-current-source-date-epoch-20261001T173611Z/evidence.json, SHA-256 88efd2650b498f440140f9d83f0afe38b52317cbc33e23f14d6965644f50a3ff (mode 0600). Üretim guest testi ve Alp fix kabulü bekleniyor. Kullanıcı “OC tamam, başla” yetkisini ve m64+m32 ABI seçimini verdi; bunlar Faz 1 kapılarını geçersiz kılmaz.
