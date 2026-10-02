# Kararlılık paket ve ham DB kabulü hazırlığı — 1 Ekim 2026

**1 Ekim sonraki düzeltme:** mkheaders ayrı replacement borcu hatalıydı; pinned kitapta yalnız yorum, etkin GCC limits concat mevcut staging tarifinde. [Güncel sequence/ABI kaydı](infra-toolchain-sequence-2026-10-01.md).


**Kod/fixture doğrulaması; gerçek OC/VM/SBU kabulü değildir.** Önceki goal turu ortak Alp kurulum kodu ve eski gerçek bundle doğrulamasıyla ilerlemeydi. Bu tur canlı QEMU yok, root temizlik/audit ve Phase 1 kabul dosyaları yok. VM/derleme/host sudo/paket/CPU ayarı, commit/push yapılmadı. Ana ve Claude HEAD korunur; Alp motoruna dokunulmadı.

## Değişiklik ve davranış

Eski kararlılık taslağı SBU paketini doğrudan Alp CLI'ye veriyor, sonrasında iki zlib arşivini karşılaştırıyordu. Zlib'in iki temiz kurulumunun ham Alp DB karşılaştırması ve toplanan dosyaların host'ta kabulü yoktu. Yeni akışta:

- `package_stage.phase2_authorization_guard` stability tarifleri için de mevcut OC/ABI yetkisi, input/source manifest hash'leri ve seçili ABI'yi kontrol eder. Toolchain ayrıca mevcut stability makbuzunu gerektirir. Stability tarifini doğrudan ortak build yordamına vermek bu kapıyı atlamaz.
- `package_install` yalnız yeni allowlist kökleri `sbu-root`, `stability-db-a/b` ve stability fazını ekler; guest root/disk/writer lock/alan, bundle/source/Alp pini, payload ve tek sahip kontrolleri korunur. DB'ye doğrudan yazılmaz; gerçek işlemler mevcut pinned Alp üzerinden gider.
- Guest'te j1/j16 SBU staged paketlerinin her biri ortak kurulum/postcheck yolundan geçer; her kurulumun o andaki ham DB'si ayrı kanıt dizinine kopyalanır. j16 aynı SBU köküne açık reinstall'dir; iki zlib kurulumu ise farklı, önceden var olmayan köklerdedir.
- İki zlib build/test/stage arşivi ve manifesti eşit olmalıdır. Ortak yardımcıyla iki yeni köke kurulur; arada **1,2 saniye gerçek bekleme** vardır. Her ham DB byte-for-byte kaydedilir. Hash farkında iki dosya, makbuzlar, evidence ve FAIL summary korunur; süreç başarısız çıkar. Zaman/DB normalize edilmez.
- Guest summary 20–30 dakika, 16 başarılı/pozitif compute döngüsü, kaynak/input/epoch/ABI/Alp bağları ve artifact adlarını taşır. Zaman penceresi dışı veya hiç döngü yapmayan worker kabul edilmez. Bu kod bu tur çalıştırılmadı; SBU ya da OC kazancı ölçülmedi.
- Yeni `stability_evidence.py`, rsync ile toplanmış gerçek arşiv/manifest/makbuz/index/ham DB dosyalarını okur. Ortak bundle denetimi kullanılır; yalnız `PASS`/`equal` metnine güvenilmez. Her dosya yolu güvenli ve ayrı koşulara bağlı, kaynak canonical manifesttekiyle aynı, makbuz input/recipe/Alp/epoch/root/package'e bağlı olmalıdır. Raw DB kaynak/record/ownership ve makbuz hash'leri de karşılaştırılır. Son olarak iki raw DB hash'i eşit olmalıdır.
- Controller yalnız monitored komut ve artifact doğrulaması başarılıysa sonraki aşamaya döner. Kanıt eksik/farklıysa hata kaydedilir, VM kapatma yine denenir; stability checkpoint oluşturulmaz. Başarısız guest'in log/artifact toplama davranışı korunur. Sonuç kaydındaki guest kanıtları tam host veya üretim kabulü olarak etiketlenmez.

**Toolchain stability makbuzu bu tur üretilmedi.** Host sonrası privileged audit, journal/izleme kabulü ve makbuzun guest'e güvenli aktarılması hâlâ tasarlanıp gerçek akışta doğrulanmalıdır. Checkpoint veya bu helper'ın fixture sonucu toolchain yetkisi yerine geçmez. Üretim runner/layout/gerçek limits.h/ABI sanity ve sonraki 79 paket/BLFS/Plasma/ISO gereksinimleri açık.

## Kanıt

Komut: `python3 -m unittest discover -s tests -p test_infra_rebuild.py -v` — **38 test geçti**, 1,243 saniye. Log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-stability-evidence-tests-20261001.log`, SHA-256 `2462e9f8ab58109fbff2c76ae19b295e9389d68f906423dcb6e4f4d86b87628d`. Önceki 37 test geçişinin logu `infra-stability-evidence-tests-20261001-first37.log` adıyla korundu; ardından timestamp-only fark testi eklenip suite yeniden çalıştırıldı.

Yedi yeni test: gerçek tar/manifest bytes ile simulated Alp makbuz/DB kabulü; değişmiş raw DB/arşiv reddi; süre/compute/aynı build alias reddi; iki raw DB kanıtının saat beklemesiyle korunması; eksik artifact'ta kapanış/no checkpoint; mevcut OC/input olmadan SBU build'in başlamaması; yalnız zaman damgası değişmiş DB'nin `equal=true` iddiasına rağmen reddi. **Bu fixture'lar gerçek Alp/VM/CPU yükü değildir.** Önceki gerçek zlib artifact kabulü bu yeni stability akışının kabulü sayılmadı.

Python AST, bütün infra shell dosyalarında `bash -n`, tracked `git diff --check` geçti. Toplu kanıt: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-stability-evidence-verification-20261001.json`, SHA-256 `5e5b7bdcd39668ab4abadc90222701992854db7a4c5c74d1e583c4413731a78b`.

| Dosya | SHA-256 |
|---|---|
| guest-stability.py | `db65ad528de5e77f8c9dfb5822cf3007ef0f5d93b0a2ab0dd56688fe1f1fc81f` |
| stability_evidence.py | `3ffcb5836e3ca78dba2d48b15e048fd0c76207bfba9f9add2df4bdb76e072f31` |
| package_stage.py | `aff641a409165de550c0085d4fd8cdaf6dfcf004729203b2e7d38293e12b1a02` |
| package_install.py | `5db1862f9ba0743c4e299f1a6559b414037f1290117e2b242483529eb6c8035a` |
| buildctl.py | `69318a634847e79c49ea5b8bc161c4a56f27ba560fb816311df66f9455f3939f` |
| test_infra_rebuild.py | `96a46b98d6fdab0728f29f381651cb65625a289149704da42fda4cbfcc10d1e8` |

Güncel input digest `0cdcd04b566433d7955f1d5361f4697953be4bf7fb0d1fca4acd6e157868f8fd`; eski guest kanıtı güncel kod kabulüne çevrilmedi. Source manifest ve Alp pini öncekiyle aynı. Frozen root cleanup script SHA `b5939acdfbb2b1334e582f0555839900e2f43f3691e2b40bd7f2a1c8c7e2a279` değişmedi; root temizliği bu tur yapılmadı.

## Açık kapılar

Alp sabit zaman düzeltmesi, kullanıcı root cleanup/audit ve journal değerlendirmesi bekleniyor. Sonrasında güncel Phase 1 smoke gerçek VM'de tekrar kabul edilmeli. Kullanıcı m64+m32 seçti; **“OC tamam, başla” yok**. HAZIR/goal complete ilan edilmedi. [Önceki kurulum kaydı](infra-package-install-2026-10-01.md), [host izleme](infra-monitoring-2026-10-01.md), [temizlik/root komutu](infra-cleanup-2026-10-01.md).
