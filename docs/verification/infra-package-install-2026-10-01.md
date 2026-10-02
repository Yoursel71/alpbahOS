# Staged paket → Alp ortak kurulum entegrasyonu — 1 Ekim 2026

**1 Ekim sonraki düzeltme:** mkheaders ayrı replacement borcu hatalıydı; pinned kitapta yalnız yorum, etkin GCC limits concat mevcut staging tarifinde. [Güncel sequence/ABI kaydı](infra-toolchain-sequence-2026-10-01.md).


**Kod/fixture ve mevcut artifact doğrulaması; yeni guest kabulü değildir.** Önceki goal turu altı cross tarif/staging desteğiyle somut ilerlemeydi. Bu tur root temizlik/audit dosyaları ve canlı QEMU/temizlik yok; doğrulanmış canlı bekleme sayılmadı. Main/Claude HEAD aynı, Alp pini aynı. VM/SBU/derleme, host sudo/paket/CPU ayarı, commit/push yapılmadı.

## Ne değişti

`scripts/infra/package_install.py` ortak staged core kurulumunu **mevcut, hash-pinned Alp CLI** üzerinden yapar; DB veya motor kodunu değiştirmez. Arşiv/manifest byte hash'i, paket/source kimliği, canonical manifest source pini, arşivdeki her yol/tür/mode/uid/gid ve dosya hash'i kontrol edilir. Eksik/fazla/duplicate girdiler ve kaçan yollar/linkler reddedilir. Core modelin desteklemediği cihaz/FIFO/socket payload'ları kabul edilmez.

Mutasyon guest root, KVM/QEMU, ALP_LFS_V1 disk/mount/ext4 marker ve devralınmış guest writer lock gerektirir; allowlist dışında kurulum/root/artifact yolu yoktur. Toolchain OC/ABI+stability kapısı korunur. Şu anda smoke/toolchain kurulumu kapsanır; diğer üretim fazları henüz entegre değil.

Arşiv guest'te `/srv/lfs/packages/<name>-<version>-<sha256>.tar.gz` altında saklanır. Böylece Alp DB'ye yazılan source URL, run etiketine bağlı olmaz. Paket kurulumundan önce root/cache/log yol ebeveynleri ve `/lib`–`/usr/lib` gibi alias'larda canonical sahiplik çakışması denetlenir. Gerçek kurulum ve dependency/check işlemi Alp'e bırakılır. Sonra payload manifesti ve dosya/symlink'lerin tek sahibi doğrulanır; yalnız başarılı sonuç için input/recipe/Alp/epoch/archive/manifest/index/package-record bağlı makbuz yazılır.

`verify_installed` devam için stamp yerine güncel paket record/tek sahip/payload byte'larını ve girdi pinlerini denetler. Tüm DB eski hash'inin aynı olması istenmez: başka meşru paket eklenince değişir; kurulan paketin record hash'i aynı olmalıdır. Eski tam DB hash'i kanıt olarak saklanır. Check başarısızlığında makbuz oluşturulmaz; Alp'ten sonra bir postcheck başarısızsa dışarıdan DB düzeltmesi yapılmaz, caller'ın checkpoint kurtarması gerekir.

`guest-smoke.py` ilk install için ortak yardımcıyı kullanır; ardından aynı canonical index ile remove/restore ve iki ham DB koşusu sürer. Alp saat kusuru düzeltilmedi/normalize edilmedi. Yeni code-input digest eski kabul yerine geçmez.

## Kanıt

- **31 host testi geçti:** `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-package-install-tests-20261001.log`, SHA-256 `af379b13fde568d555fd8ff61e0203ad7da0cfa1f9344174ebb3e57846150a08`. Bundle değişikliği/fazla yol/traversal/duplicate, alias çift sahipliği, host invocation reddi, kurulum ve sonradan payload bozulduğunda resume reddi kapsanır. Son fixture'da yalnız Alp CLI taklit edilir; gerçek capture/tar/payload compare araçları yetkisiz private test dizininde çalışır. Gerçek Alp transaction/guest guard kapanışı veya VM kabulü değildir.
- **Gerçek eski guest artifact'ı salt okunur geçti:** zlib core arşivi `fd0e3858018f8b66a8a38e936982da7e85969f3f6efa6257007c248c19a2eebd`, manifest `e76130a8486c7aed8ca1f8a9c28cfbee37d2dacbf42aaeffacb8b87ebf5830b2`, **15/15** girdinin arşiv/path/type/mode/owner/hash kontrolü. Yeni build/kurulum değildir. Kanıt `logs/infra-existing-zlib-bundle-check-20261001.json`, SHA-256 `e85a7cac7293e2f2ab72ccc08ce7d7c1b5ef3a6775a21e194e28f8b36fc99013`.
- Python AST/Bash syntax geçti. Helper SHA-256 `debfb8205116aa26a312a72a1e6c111b164f20d158339080a95d6aea1af692ef`, smoke SHA-256 `723c0899624ad7f80a6e42085018a6b33b47397c8b5be5ebe029a91ff8c2c2c1`. Frozen root temizliği kodu SHA-256 `b5939acdfbb2b1334e582f0555839900e2f43f3691e2b40bd7f2a1c8c7e2a279` değişmedi.

## Açık kabul

Alp deterministik zaman düzeltmesi, root temizlik/audit, journal bulgusu ve sonra bu **güncel** smoke'un gerçek VM kabulü açık. Canonical package cache build verisidir; final image kapsamı/alan bütçesi ve temizlik/resume politikası üretim runner'ında uygulanmalıdır. Owned layout, staged limits.h gerçek kabulü, dependency receipt'lerinin build öncesi doğrulanması, ABI sanity ve stability makbuzu/host sonrası audit hâlâ açık. Altı tarifi sırayla yürüten üretim runner'ı veya 79 paket/BLFS/Plasma/ISO pipeline tamamlandı kabulü verilmedi. ISL pending; m64+m32 seçili, “OC tamam, başla” yok.

Önceki kanıtlar: [toolchain hazırlığı](infra-toolchain-preparation-2026-10-01.md), [host izleme/journal](infra-monitoring-2026-10-01.md), [root temizlik komutu](infra-cleanup-2026-10-01.md).
