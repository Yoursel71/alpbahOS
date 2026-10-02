# Sahiplikli minimal m64+m32 dosya sistemi — 1 Ekim 2026

**1 Ekim sonraki düzeltme:** mkheaders ayrı replacement borcu hatalıydı; pinned kitapta yalnız yorum, etkin GCC limits concat mevcut staging tarifinde. [Güncel sequence/ABI kaydı](infra-toolchain-sequence-2026-10-01.md).


**Kod, host fixture ve gerçek pinned Alp testi; guest/root/toolchain kabulü değildir.** Önceki goal turu kararlılık paket/ham DB kabulü ve 38 testle somut ilerlemeydi. Bu tur da staging, paketleme, sahiplik ve gerçek Alp fixture kanıtı üretti; canlı bekleme sayılmadı. Ana/Claude ağaçlarına, Alp motoruna, profiles/branding veya karar metinlerine yazılmadı. VM/derleme/SBU/OC, host root/mount/chroot/paket/CPU ayarı, commit/push yok.

## Kaynak ve düzen

[LFS 12.4-systemd §4.2](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter04/creatingminlayout.html) minimal dizinleri ve usr-merge bağlantılarını tarif eder. Multilib farkı sabit `ml-12.4` commit `d7bc803361f445a649d0ca0832219f75b6e68683` içindeki [chapter04/creatingminlayout.xml](/mnt/alpbahOS-data/alpbahos-infra-rebuild/research/mlfs-12.4/chapter04/creatingminlayout.xml) dosyasından okundu; SHA-256 `022e533f42e8c5a92de5941b300aba731220bd8b34ff774b54cd79dcda0228ea`. `ml_32` eklemesi `/usr/lib32` ve `/lib32 → usr/lib32`; x32 eklenmedi.

`recipes/toolchain/filesystem-layout.json`, `filesystem-layout 12.4-ml32.1` için dokuz 0755 dizin (`etc`, `var`, `usr`, `usr/bin`, `usr/lib`, `usr/sbin`, `usr/lib32`, `lib64`, `tools`) ve dört bağlantı (`bin`, `lib`, `sbin`, `lib32` → karşılık gelen `usr/...`) tanımlar. `/usr/lib64`, `/usr/libx32`, `/libx32` reddedilir. Bu minimal Chapter 4 düzenidir; tam final FHS ağacı/konfigürasyon paketi değildir.

Yerel tarifin byte hash'i aynı canonical source manifestinin `local_sources` bölümünde, `kind=repository-file`, açık repo yolu ve yerel provenance URI'si `urn:alpbahOS:source:filesystem-layout:12.4-ml32.1` ile kayıtlıdır. Uzakta yayınlanmış arşiv veya HTTP indirmesi varmış gibi gösterilmez; kaynak byte'ları recipe dosyasıdır. Kaynak pini `4033d93e5cc2ef175e8191ce0bbe55ae7a92e599de5b20865b2f4501183e97da`. Host/guest ortak helper bu kaynağın gerçek dosyasını, yolu, symlink olmamasını ve hash'ini doğrular. Eksik/duplicate kaynak adı veya değişmiş yerel byte'lar reddedilir. Controller verify-cache yerel pinleri de doğrular; sync mevcut toolchain recipe diziniyle dosyayı taşır.

**90 indirilen kaynak ve mevcut Builder/tool/key/signature pinleri değişmedi.** Yeni yerel kaynak ve Chapter 4 book hash'i çıkarılınca önceki manifest byte'ları yeniden elde edildi: SHA-256 `2924dfeffb5a597259481f7c2165ccc708396587ff6fd4837395425b959e62b4`. Bu kontrol metadata değişmemesi kanıtıdır; bu tur 90 cache dosyasının tamamı yeniden hash'lenmedi. Güncel manifest SHA `0df6f8614ba0b4c335561f69c9458e972be5a738bd3ffa3c6f955ca12b6c8027`.

## Entegrasyon

Yeni `filesystem_layout.py` yalnız **yeni staging dizinini** oluşturur. Sabit yol whitelist'i dışında girdi, mevcut staging veya symlink ebeveyn kabul edilmez. Üretim `build_layout` yolu guest/disk/writer lock/alan ve OC/ABI+stability receipt kapılarından geçer; tarif canonical yerel kaynakla aynı olmalıdır. Ürün köküne doğrudan mkdir/ln yapılmaz; kurulum ortak `install_staged` ile mevcut Alp core transaction'ından geçer.

Manifest ve normalize tar/gzip oluşturma, compiled ve generated stage'ler için ortak `pack_staged` yordamına taşındı. Önceki artifact'ların üstüne yazılmaz. Stage sahibinin uid/gid'si ile tüm girdiler aynı olmalıdır; arşiv aynı gerçek uid/gid'yi taşır. Üretim stage'leri guest root ile root sahibi olur; host fixture kendi uid/gid'sini taşır. Böylece host fixture'ı kök sahibi release paketi gibi etiketlenmez ve capture metadata'sı ile tar arasında sahiplik farkı gizlenmez.

Binutils pass 1, `filesystem-layout` Alp paketine bağımlıdır. Diğer cross build'ler başlamadan gerçek minimal dizin türleri/mode, dört alias hedefi, yasak ABI yollarının yokluğu ve **protected Alp paketinin tek alias sahibi olması** denetlenir. Production install/resume yalnız dedicated LFS kökünde yapılır. Layout install sonrası aynı kontrol gerekir. Layout resume, ortak input/recipe/source/Alp/payload/archive/DB-record makbuz kontrolüne de tabidir. Yanlış bağlantı veya sahipsiz yol sessizce devralınmaz/düzeltilmez. Tam bağımlılık receipt'lerini sırayla doğrulayan üretim runner'ı henüz bağlanmadı.

## Kanıt

**44 test geçti**, 1,430 saniye: `python3 -m unittest discover -s tests -p test_infra_rebuild.py -v`. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-filesystem-layout-tests-20261001.log`, SHA `3b03d562488f2ddd1804924ff96bfc55d636683fd547b5d33d65b10186066e08`. Yeni testler değişmiş/alias/duplicate yerel kaynak, iki gerçek staging bundle byte eşitliği, path escape, host production generator reddi, yanlış dir/link/foreign owner ve ortak adapter kurulum/resume davranışını kapsar. Adapter fixture'ında Alp CLI ve guest boundary simüle edilir; gerçek capture/tar/payload compare çalışır.

Ek olarak **mevcut Alp gerçekten çalıştırıldı**, host Python 3.14.7 ile, uid/gid 1000 özel artifact dizininde. Motor hash'i `92d519212d161159f6f083008b14c7b5b22c2d3e7e60f49fe17d493538fe25b2` doğrulandı; CLI `--root` özel fixture kökü, tek kayıtlı yerel index ile `install -y filesystem-layout` ve `check` çalıştı. Gerçek compare **13/13** geçti; dört alias tek Alp sahibine bağlı, `protected=true`. Bu test engine/DB'yi yamalamaz; QEMU/root guard veya guest uid0 kurulumu kanıtı değildir. İki gerçek stage paketi eşit; **yalnız bir gerçek Alp kurulumu** yapıldı, iki DB eşitliği kabulü verilmedi.

- İki host-fixture arşiv SHA: `d96f09438c27da1c7a0d710e9132e855c24b4334cdd2e330a1ba2acce180c06c`.
- İki host-fixture manifest SHA: `1270f6a9ef0a2995555264db712f2f54eb4013e334515ae202b43a46c0788f57`.
- Gerçek engine logu: `artifacts/filesystem-layout-host-fixture-20261001/alp-core-install.log`, SHA `49d0a597f01bcbbaf7bc2d54b9d7a62873b5153da921a9232cd908886dc9bb77`.
- Ayrıntılı gerçek fixture kanıtı: [summary.json](/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/filesystem-layout-host-fixture-20261001/summary.json), SHA `3fc1cca137c705565940e89f4ba7da691e8a4ab29aaaa22c4c5882a1d7720324`. Host fixture kanıtları korunur; sonradan stage-a/b ve alp-root geçici ağaçları ham DB/root snapshot arşivi korunduktan sonra temizlendi. [Compaction kaydı](/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/filesystem-layout-host-fixture-20261001/tree-compaction.json). Guest kaynak/paket cache'ine aktarılmadı.
- Python AST/bütün infra shell `bash -n` ve tracked diff-check geçti. Güncel kod hash'leri/başlık-dal/alan/pending gözlemi: [verification.json](/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-filesystem-layout-verification-20261001.json), SHA `0ff05857be8b14ff798090117561881e01ca22421cc3f56694ae4b918d9f8b2a`.

Güncel input digest `7edc648f592087b794cd5254e3d10123dd3eeba8dfa87ba4baf33eafda0efa8f`. Eski smoke/acceptance güncel digest kabulüne çevrilmedi. Frozen root cleanup kodu SHA `b5939acdfbb2b1334e582f0555839900e2f43f3691e2b40bd7f2a1c8c7e2a279` aynı.

## Açık kabul ve sonraki iş

Alp sabit-zaman düzeltmesi, kullanıcı root cleanup/audit ve journal değerlendirmesi; güncel Phase 1 gerçek VM smoke kabulü; “OC tamam, başla”; gerçek stability/host sonrası receipt aktarımı hâlâ açık. m64+m32 seçimi korunur. Layout artık hazırlanan somut staged paket yoludur, **guest'e kuruldu kabulü yoktur**. gerçek staged limits.h kabulü, cross ABI sanity ve paket sırası/resume runner'ı; Chapter 6 ve 79 final paket/uzun testler; kernel/BLFS/Plasma GL/profiles/iki ISO gereksinimleri bitmedi. HAZIR/goal complete ilan edilmedi. [Önceki stability kanıtı](infra-stability-evidence-2026-10-01.md), [temizlik ve root komutu](infra-cleanup-2026-10-01.md).
