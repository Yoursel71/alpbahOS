# Altyapı kapı raporu — 1 Ekim 2026

## 2 Ekim 2026 güncel durum addendum'u

Bu addendum, aşağıdaki eski donanım/disk okumalarının yerini alan tek-anlık ölçümlerdir; ağır derleme veya benchmark yapılmadı. Host `/` 92 GiB boş (%19), SSD 67 GiB (%59) ve data/HDD 262 GiB (%57); tümü %15 stop eşiğinin üzerinde. MemAvailable 18,694,496 KiB (17.83 GiB), Tctl 46.4°C ve CPU scaling frekansı 3.705–4.650 GHz aralığında örneklendi; idle/OC karşılaştırma baseline'ı değildir. `kwin_wayland` PID 2499 ve `plasmashell` PID 2660 canlı; QEMU süreci görünmedi.

Host/synthetic suite v38, 275 test/2 skip/94.031 s PASS: log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-test-suite-v38-20261002.log`, SHA-256 `7fd59767c83dfcd82da9c40330683c4197e1abc618f6cd88d058300f05f155a4`; receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/state/infra-full-test-suite-v38-20261002.json`, SHA-256 `9c8ac9872050761487ea62aeb73bf2f3b399756f1594e994d40f7b095ba5c7fa`. Chapter 8 recipe coverage 76/79, 3 pending. This suite was not a guest build, package acceptance, SBU, or host root audit. `cleanup-root-result.json`, `root-host-audit-after.json`, and `phase1-acceptance.json` remain absent. Latest zlib smoke still reports `FAIL_DB_REPRODUCIBILITY`; the examined raw DB differences were timestamp fields. Faz 1 remains unaccepted.

**Kullanıcı OC onayı (1 Ekim 2026):** Kullanıcı “OC tamam, başla” dedi; daha önceki `b` seçimi m64+m32, x32 yok, olarak geçerlidir. Faz 2 ağır komutu başlatılmadı: `buildctl.py` `phase1_acceptance_guard()` önce güncel iki kurulumun ham Alp DB kanıtı ve kabul makbuzunu zorunlu tutuyor. Bu makbuz mevcut değil (`artifacts/phase1-acceptance.json` yok). Raw DB eşitliği için sabit Alp `_now()` engeli çözülmedi. Root cleanup/host audit sonucu da yok. **Bu stop artık OC/ABI yetkisi eksikliği değil; açık Faz 1 kabul kapılarıdır.** Kanıt ve son preflight: [toolchain byte/ABI raporu](docs/verification/infra-toolchain-byte-abi-2026-10-01.md), `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-toolchain-byte-abi-verification-20261001.json`. VM/derleme başlamadı.

**Güncel Alp tekrar testi (read-only source, 1 Ekim 2026):** `/home/yrslf/Projects/alpbahOS` temiz `main` checkout'u, HEAD `3f6f0f1a3392a5d177ef93fa58c9217e8d70c65f`; Alp source SHA-256 `5acfe856f9a188ea37376e778dad6463bd6bf9c25af0dc959334f2a08cf379b4`. Bu sürümün `_now()` hâlâ `time.strftime(..., time.gmtime())` çağırıyor. Aynı Alp source, zlib arşivi SHA `fd0e3858018f8b66a8a38e936982da7e85969f3f6efa6257007c248c19a2eebd`, index ve `SOURCE_DATE_EPOCH=1756684800` ile iki ayrı geçici köke kurulum yaptı; ikisi de exit 0. Ham DB SHA'ları `7f77d9a720c9cfcac38e5fe0144ca3954e7adee13d7c2918f8416e6ba08d9149` ve `c97fbd0b6de63bbd11499d924d78f03f4b722c6a7c2e84c613ec32462bfd8cf8` olarak farklı. JSON diff yalnız `packages.zlib.installed_at` ve `updated_at` alanlarında ardışık saniyeler gösterdi. Kanıt JSON (mod 0600): `/mnt/alpbahOS-data/alpbahos-infra-rebuild/research/alp-current-source-date-epoch-20261001T173611Z/evidence.json`, SHA-256 `88efd2650b498f440140f9d83f0afe38b52317cbc33e23f14d6965644f50a3ff`. Bu host fixture'ı raw timestamp eşitliği kapısını doğrular; gerçek Builder guest veya ownership acceptance değildir.

**Test/alan doğrulaması (1 Ekim 2026):** Güncel input'la tam host regression suite **273 testte, 2 skip ile geçti**; log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-test-suite-v19-20261001.log`, SHA-256 `da85a11f1996694f945ce6b5d06b27c944cd37a420638889513215b2df7a53b1`; receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/state/infra-full-test-suite-v19-20261001.json`, SHA-256 `4adadb5f26580ff19fd84977a2182a313f06a5fb9cc85b3482dc5113c6dec18b`. State build input `1f0bd923a0a26690ccc9f50eeaa174a3fc22e9d3a340de161b0b666239d17b70`; 45/79 recipe, 34 pending. Fedora’nın geçici fikstürlere eklediği `security.selinux` etiketi test görünümünden süzüldü; gerçek xattr testi `user.m04-test` reddini sınar, üretim xattr denetleyicisi değişmedi. Inventory ayrıntısı [raporda](infra-base-inventory-2026-10-01.md). Son alan ölçümü: NVMe `/` **102 GiB (%21)**, SSD 68 GiB (%60), HDD/data 262 GiB (%57) boş; `%15` alan kapısı açık fakat marj azaldı. Kaynaklar, VM veya root kabulü çalıştırılmadı.

**Güncel envanter (v29):** IPRoute2 6.16.0 tarifi pinned MLFS m32-systemd XML SHA `3011c983412f13c79fdd0290496c3fc8208a423e7051b105829b0320187d1b7b` ve arşiv SHA `5900ccc15f9ac3bf7b7eae81deb5937123df35e99347a7f11a22818482f0a8d0` ile eklendi; kitap çalışır test takımı sunmadığından test başarısı iddia edilmiyor. Coverage 64/79, 15 pending. Tam host suite 274/2 PASS, 117.509 s; log SHA `b166214162e9eda0c3d5b5bb0b96a26909efd17f68fa2b40e4d3fab33c819800`, state SHA `047914abb273b89f41833cd13ba948d2a441392a6e986ef91d6aa74ee694e0b1`, input SHA `d77dcf5be4b8d23d6f7099f6f2f1770bd330057c256da96970f4f979d88afc35`. Guest build, Phase 1 root acceptance ve eşit raw Alp DB kanıtı yok.

**Güncel envanter (v25):** Python build modüllerinden sekizi MLFS XML pinleriyle eklendi; Ninja recipe concurrency cap doğrulaması eklendi. Inventory 60/79 tarif, 19 pending; 11 focused test ve tam suite 274/2 PASS. Log SHA `fa4012c83618fd8dcf2cfbbcdb79b852b257bf89ed15a6dc042dfaa9a47229e`, state SHA `a909aa4052b6e48662d1573cc123a33d7d133fbde395b7e77907e3fdaf4f610a`. Host/synthetic testtir, guest builds/Phase 1 acceptance değildir; root audit ve Alp DB determinism açık.

**Güncel envanter (v24):** GMP, MPFR ve MPC tarifleri eklendi; GMP zorunlu test eşiği 199 PASS olarak bağlandı. Inventory 52/79 tarif, 27 pending. Tam host suite 273 test / 2 skip geçti; log SHA `ce8e4e904ae464b3e9a1031396171a6ca1978c3f3993f8aec3ff3426bc0cf0d7`, state SHA `3125cd0e601fff05a88929aa8790f17937cd9e290e65bf289ada4b9327eb73d5`. Bu host/synthetic ve recipe doğrulamasıdır; guest build, Phase 1 root acceptance ve Alp DB reproducibility hâlâ eksik.

**Güncel envanter (v23):** Vim 9.1.1629 tarifi sabit MLFS XML ile bağlandı; test-user/locale kısıtları ve DESTDIR içi bağlantılar kaydedildi. 49/79 recipe, 30 pending. Tam host suite 273 test / 2 skip PASS; log SHA `8b23140ad16f0af03c49f32c98c4c7beb2cc9c00ca74063da493a63bf5c7c603`, state SHA `350ad77fa8da97a9635b88c991447caf8bda2c8bc37f0188b5792017f0d47d09`. Bu recipe metadata ve host/synthetic testtir. Phase 1 root audit ve Alp DB hash engelleri çözülmedi.

**Güncel envanter (v22):** Man-db 2.13.1 tarifi sabit MLFS XML pinine, systemd seçeneklerine ve erken paket bağımlılıklarına bağlandı. Toplam 48/79 tarif, 31 pending; 273 host testi / 2 skip geçti. Log SHA `bf81597b998046ada06701e6e829ad181900312d0b75007c308f44f567090165`, state SHA `9e47b521f0859c1485ac47faa670511e016ceac49627a2282cc822566f1539ba`. Tarifler guest-built değildir; root cleanup/audit ve Alp DB determinism kapıları açık.

**Güncel envanter (v21):** Inetutils ve procps-ng tarifleri, sabit MLFS Chapter 8 XML pinleriyle eklendi; procps-ng için kitapta gerçek dosya adı `procps.xml` olarak doğrulanıp paket adı eşlemesi tanımlandı. Inventory 47/79 tarif, 32 pending; focused 10 test ve tam host suite 273 test / 2 skip geçti. Log SHA `cf7bcc39176aaf3ddc5553160015536a99a30ca39f0db8a4690a97ccc57bdaf8`, state SHA `7fb7177b6a1b4cc0c92640d17fac6b471f24af12db2f576a10292b7f4f1cc028`. Host/synthetic kapsamı dışında kabul yok; root cleanup/audit ve Alp raw DB determinism kapıları açık.

**Güncel envanter (v20):** Inetutils 2.6 tarifi sabit MLFS XML SHA `3a87a7886dcc4e77f0fd98eb62538c8262145193c77767f17da43f5ed209d557` ile bağlandı. Inventory 46/79 tarif, 33 pending; odaklı 10 test ve tam 273 test/2 skip suite geçti. Log SHA `dab9335b386b18794c74b38275f92250822b8b77ed37e350e93c153fc0dade66`, state SHA `b4ee1aa0949432e4867ec138014d6df185bcc693c5923cf1c4f8de501f72689a`. Bu host/synthetic doğrulamadır. Faz 1 root audit ve raw Alp DB determinism kapıları hâlâ açık.

**Son inventory ilerlemesi:** XML::Parser ile Tcl/Expect/DejaGNU reçeteleri eklendi; recipe coverage 45/79 oldu, 34 paket bekliyor. Runner’ın çalışma dizini desteği build ağacı içinde kalıyor ve tüm symlink bileşenlerini reddediyor. `test_base_plan` 9/9 ve `verify-base-inventory` geçti. Yeni input SHA `b2b649083835e2e3b8a1a58b2cd92fffceb036159ae685f55197eac63cdb2f4c`; receipt SHA `0101106e3c0d68fa6980de25a5f5c686838ebe56fdc41720ca4bed9cc2f300c0`; recipe/build/ownership kabulü veya Faz 1 makbuzu değildir.


**Son toolchain byte/ABI hazırlığı:** canonical7 real bundle bytes/raw DB prefix/observed payload/owner ve C/C++ m64/m32 ELF/raw trace/command/space verifier library eklendi;142 test geçti. Synthetic fixture kabulü, gerçek compiler/VM/root değil. Controller action/collector/root-after/stage acceptance açık; HAZIR kapısı kapalı. [Kanıt/sınırlar](infra-toolchain-byte-abi-2026-10-01.md).

**Son toolchain oturum hazırlığı:** new job/parent/root-before/guest boot ve single-use byte handoff library eklendi;125 host testi geçti. Compiler/action+canonical artifact verifier/after acceptance açık; session verifier yokken FAIL. Actual VM/root/SSH/OC yok, HAZIR kapısı kapalı. [Kanıt/sınırlar](infra-toolchain-session-2026-10-01.md).

**Son checkpoint handoff hazırlığı:** saved/backing byte proof/fresh active pins, pre-launch parent/new job ve host-guest boot/raw SHA kapsülü eklendi.114 host testi geçti. Host toolchain action/new root-before/gerçek boot ölçümü ve SSH aktarımı/after acceptance açık; HAZIR kapısı kapalı. [Kanıt/sınırlar](infra-toolchain-handoff-2026-10-01.md).

**Son sequence hazırlığı:** yedi Chapter4/5 paketine verified resume ve C/C++ m64/m32 sanity kodu eklendi; 52 test geçti. mkheaders önceki borcu yanlış: pinned XML'de yorum, etkin staged limits concat mevcut tarifte. Gerçek compiler/VM/host kabulü yok; [güncel kanıt/sınırlar](infra-toolchain-sequence-2026-10-01.md). HAZIR kapısı kapalıdır.

**Son layout hazırlığı:** protected staged m64+m32 usr-merge ve yerel source hash pini eklendi; 44 test, gerçek yetkisiz pinned Alp fixture 13/13, iki eşit stage bundle geçti. Guest/root/toolchain kabulü yok. [Güncel kanıt](infra-filesystem-layout-2026-10-01.md). HAZIR kapısı kapalı kalır.

**Son kararlılık hazırlığı:** ortak Alp SBU/zlib install, iki yeni ham DB ve host artifact byte/input kabulü hazırlandı; 38 host testi geçti. Gerçek OC/VM/SBU/host kabulü veya toolchain stability makbuzu yok. [Güncel kanıt ve sınırlar](infra-stability-evidence-2026-10-01.md). HAZIR kapısı kapalıdır.

**Son entegrasyon:** ortak staged Alp install/payload/tek sahip/resume kodu smoke'a bağlandı; 31 host testi ve eski gerçek zlib bundle 15/15 arşiv karşılaştırması geçti. Yeni guest smoke/üretim kabulü yok, eski kanıt güncel kod kabulü sayılmadı. [Güncel kurulum kaydı](infra-package-install-2026-10-01.md). HAZIR kapısı kapalı kalır.

**Son tarif hazırlığı:** m64+m32 Chapter 5 için altı cross tarif ve ortak stage desteği eklendi; gerçek GCC source preflight/26 host testi geçti. Guest toolchain ve üretim pipeline kabulü yok; ISL 522/404 nedeniyle henüz dondurulmadı. [Güncel hazırlık/eksik listesi](infra-toolchain-preparation-2026-10-01.md). HAZIR kapısı açılmadı.

**Son izleme ilerlemesi:** sürekli host örnekleme, hata kanıtı/VM poweroff kodu ve manifest epoch aktarımı eklendi; 22 host testi geçti. Gerçek guest kabulü yok. Root-owned kullanıcı journal'ı bozuk bildiriliyor, verify exit 1; dosyaya dokunulmadı. [Güncel izleme kaydı](infra-monitoring-2026-10-01.md). Aşağıdaki izleme eksikleri ve önceki kernel kontrolü tarihsel; bu kayıt güncel durum için önceliklidir.

**HAZIR DEĞİL — kullanıcı hash farkında durma kuralı nedeniyle beklemede.** Faz 0 tamamlandı; Faz 1 kısmen doğrulandı. Ağır derleme, SBU, toolchain, uzun GCC/glibc testleri ve yeni ISO çalıştırılmadı. Builder temiz kapatıldı. Kod commit/push edilmedi.

**Sonraki kullanıcı temizlik isteği uygulandı:** NVMe/HDD/SSD eski imaj ve artık build'lerden net yaklaşık 279 GiB boş alan kazandı; %15 engeli kalktı. Root'a ait kalan snapshot/dizinler için son başarılı D34 ve milestone'ları koruyan kullanıcı komutu hazır, henüz çalıştırılmadı. Altyapı kontrollerine devam edildi; 15 regression/sınır testi geçti, gerçek guest smoke ve üretim tariflerinin kabulü açık. [Güncel temizlik/ilerleme kaydı](infra-cleanup-2026-10-01.md). Aşağıdaki eski alan/audit ve kod durumları ilk duruşun tarihsel kaydıdır; yeni ilerleme için bu bağlantı önceliklidir.

**Önceki 1 Ekim alan ölçümü (yerine güncel ölçüm yukarıdadır):** NVMe `/` **22,33 GiB / %4,71** boşken `%15` kapısı kapanmıştı. Sonraki kullanıcı kapsamındaki eski imaj/artık temizliğinden ve disk durumu değişikliğinden sonra güncel root 132 GiB boş. Eski ölçüm kanıtı `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/blocked-revalidation-1790828244572690064.json`, SHA-256 `9422bf992161b9b1d5dd3a6efb58633c1a88f941c950333e8c10176b18fe627c`; bu artık güncel alan durumunu göstermez. Alp zaman farkı ve root audit dosyaları hâlâ eksik.

## Doğrulananlar ve sınırlar

| Kabul | Sonuç / kanıt |
|---|---|
| Salt okunur keşif | [infra-survey-2026-09-30.md](infra-survey-2026-09-30.md): disk/mount/repo/oturum haritası, 1.595 riskli çağrı satırı. Ana ağaç 342 kirli kayıt; HEAD `a9bac38544955c30c146c175760195ff193a0b76`, dal `main` son kontrolde aynı. Aktif Claude nedeniyle kirli snapshot alınmadı. |
| Eski kayıtların doğruluğu | Ana çalışma ağacı zaten 30 Eylül güncellemeleri içeriyor; D34 NVMe adayında 79/79 kayıt bildiriliyor. Bu aday, eski ISO ve bu sıfırdan VM akışı aynı soy ağacı değil; yeni rebuild kabulü yok. Bu worktree eski HEAD'den açıldığından alttaki tarihsel belgeler güncel kabul yerine geçmez. |
| İzolasyon | QEMU/KVM, 8 vCPU, 12 GiB guest; host paylaşımı/passthrough yok; kaynaklar SSH/rsync ile kopyalandı, smoke ağ çıkışı kapalı. Guest root yalnız seri numarası doğrulanmış ext4 LFS diskine ve Builder diskine yazdı. Host sudo/mount/chroot/paket kurulumu yapılmadı. |
| LFS gereksinimleri | Guest `version-check.sh` geçti: GCC/G++ 12.2, Binutils 2.40, Python 3.11.2, kernel 6.1, Bash/Gawk/Bison alias, PTY ve küçük C++ kontrolü. Provision logu aşağıda. |
| Kaynaklar | LFS/BLFS 12.4-systemd. Resmî listedeki 95 kaydın systemd MD5 listesinde bulunan 90'ı doğrulandı; 5 SysV kaydı açık allowlist ile hariç tutuldu. Yerel doğrulanmış byte'lardan SHA-256 donduruldu; bağımsız imza kanıtı olmayanlar için upstream imza iddiası yok. |
| İmzalar | Binutils, GCC, Glibc, Linux için 4/4 gpgv doğrulaması geçti. Public key'ler resmî HTTPS/WKD kökeni ve sabit fingerprint/hash ile kayıtlı; genel web-of-trust kabulü değildir. |
| Hafif paket testi | zlib 1.3.1 iki gerçek configure/build/test/DESTDIR koşusu; arşiv ve manifest byte hash'leri eşit. Alp ile kur/kaldır/aynı arşivi yeniden kur/dependency-check geçti. 8 dosya/symlink sahibi, kurulum ve geri kurulumda 15/15 manifest eşleşmesi. |
| Koruma testleri | 8 sınır testi geçti: host root, izinli olmayan yol, symlink, kaynak uyuşmazlığı koruması, %15 boş alan kapısı, iki yetkilendirme şartı, guest betiğinin host reddi, sabit epoch manifesti. Son ortak paket/stability değişiklikleri bu kabulden sonra geldi; son kodun tam kabulü yok. |
| Devam noktası | `checkpoint-prepared` iki disk hash'iyle korundu; ilk başarısız smoke'dan buraya dönüş ve yeniden boot çalıştı. Başarısız diskler ayrı overlay dizininde korundu. Son diskler kapalı ve `qemu-img check` ikisinde exit 0. Yeni kabul edilmiş smoke/stability checkpoint'i ilan edilmedi. |
| Host bütünlüğü | Başlangıç/son yetkisiz RPM karşılaştırmasında yeni okunabilir missing veya sistem dosyası bozulması yok; KWin RPM doğrulaması temiz. Tam `rpm -Va` yetki hataları içeriyor: root seviyesinde temiz host kabulü **DOĞRULANMADI**. Tam okunabilir boot kernel journal'ında MCE/ICE/OOM hata bulgusu bulunmadı; TDX unsupported satırı CPU arızası kanıtı değildir. |

## Durduran bulgu

Aynı zlib paketini iki boş guest köküne aynı epoch ile kurmak **ham Alp DB hash'lerini eşitlemedi**:

```text
4270ed3a44ebfc5f10cfc1711730c4b6b7247406ee5ec565109ab3fd24185872
f51cf1c9ba97eab2326afff477871aaabe0e1d9887a7de262881ac39184f33a4
```

Yalnız `installed_at` / `updated_at` değişti. Sabit Alp `_now()` gerçek saati kullanıyor. Bu yazılım kaynaklı fark, OC kararsızlığı kanıtı değildir. DB'yi hash dışında bırakma, zamanı sahteleme veya motor yaması yapılmadı. [Claude düzeltme isteği](../handoffs/claude/infra-source-date-epoch-request-2026-10-01.md) hazır; başka oturuma gönderilmedi.

Paket çıktılarının iki koşudaki ortak hash'leri:

```text
archive  fd0e3858018f8b66a8a38e936982da7e85969f3f6efa6257007c248c19a2eebd
manifest e76130a8486c7aed8ca1f8a9c28cfbee37d2dacbf42aaeffacb8b87ebf5830b2
```

## Donanım ve bütçe

Ryzen 7 5700, 8C/16T; toplam RAM 23,33 GiB. Derleme yokken son örnek: CPU Tctl **32,5°C**, çekirdek saatleri **2,38–4,68 GHz**, MemAvailable **17,76 GiB**. Desktop yükü ve boost nedeniyle bunlar tek anlık ölçüm; OC öncesi standart stres/SBU baseline'ı değil. Kaynak: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/phase1-final-monitor.json`.

Boş alan: NVMe **108,65 GiB / %22,91**; SSD **65,91 GiB / %58,96**; HDD **126,17 GiB / %27,59**. Hiçbiri %15 altında değil. VM OS 12 GiB + LFS 40 GiB sanal kapasite; snapshot/cache gerçek allocated byte'larıyla 300 GB bütçe kontrolü var. Mevcut diskler sonraki tüm ağır aşamalar için kapasite garantisi değildir; aşama öncesi yeniden ölçülmeli.

zlib build/test/stage 2,415 / 2,082 saniye; SBU değildir. Binutils pass 1 toolchain'in parçası olduğundan kısa SBU da çalıştırılmadı; ABI kararı sonradan alındı ve kullanıcı OC sonrası başlama iznini verdi. OC öncesi karşılaştırılabilir SBU baseline'ı olmadığı için **OC kazancı hesaplanamaz**. Faz 2'nin 20–30 dakikalık kararlılık kapısı yalnız root cleanup/audit ve Faz 1 kabul makbuzu tamamlandıktan sonra başlatılabilir.

Kararlılık kapısı kullanıcı planında 20–30 dk. Toolchain, 79 paket, kernel, BLFS ve Plasma için bu makinede SBU/job/bellek ölçümleri yok; savunulabilir saat aralığı verilemiyor. Ölçümden sonra kitap SBU katsayıları ve gerçek paket süreleriyle aralıklar çıkarılmalı. Başlangıç guest 12 GiB; düşük bellekli link işlemleri için 16 job güvenli kabul edilmedi. Son stability/SBU -j16 taslağı çalıştırılmadı.

## 32-bit seçimi — (b) m64+m32 seçildi

Kullanıcı 1 Ekim 2026'da `b` yanıtıyla multilib-hazır **m64+m32** toolchain'i seçti; x32 yok. Bu yanıt ABI tercihini sabitler. Kullanıcı “OC tamam, başla” yetkisini verdi. Faz 2, Alp ve altyapıdaki Faz 1 kapıları açık olduğundan VM/derleme başlatmadan durdu. Aşağıdaki maliyetler araştırma tahminidir.

| Seçenek | Süre / disk / D33 etkisi |
|---|---|
| (a) Saf 64-bit | Resmî LFS/BLFS 12.4 yolu, maliyet tabanı 1,0×. Sonradan multilib temiz toolchain/taban rebuild gerektirir. |
| (b) m64+m32 hazır toolchain | Sabit `ml-12.4` topluluk yolu var; Binutils 2.45 / GCC 15.2 / Glibc 2.42 eşleşmesi korunabilir, ISL 0.27 ek kaynak. Planlama tahmini toolchain/taban +%25–60, workspace/snapshot +10–20 GiB; tam 32-bit grafik/oyun zinciri ayrıca +10–30 GiB. Donanım ölçümü değil; multilib BLFS kapsamı ve ABI testleri ek risk. |

Oyun/Steam hedefi korunuyorsa öneri **(b), yalnız m32**. x32 eklenmez. D32/D35 ve DECISIONS değiştirilmedi; 13.x'e geçilmedi. Her iki seçenekte `CONFIG_IA32_EMULATION=y` gerekliliği kaydedildi, kernel henüz derlenmedi. Sabit tag/commit, kaynaklar ve maliyet sınırlamaları [araştırma raporunda](infra-multilib-2026-09-30.md).

## Yeniden başlamadan önce gerekenler

1. Claude'un Alp deterministik build zamanı düzeltmesi, değişmez commit/hash ve tekrar testleri.
2. Son `package_stage.py` ortak yordamı ve smoke refaktörünün VM'de tekrar kabulü. Son kod, daha önce geçen smoke'un aynısı sayılmaz.
3. Geçerli root host audit çıktısı. Daha önce verilen cleanup plan/komutu değişmedi; root çıktısı hâlâ yok. Yeni stage audit producer pristine RPM/kernel/raw hash/boot/zaman kapsamını doğrular; genel kullanıcı logu veya eski cleanup çıktısı güncel stage kabulü değildir. Codex sudo çalıştırmadı. [Producer sınırları](infra-stage-audit-2026-10-01.md).
4. Uzun test politikasının gerçek suite sonuçlarıyla kabulü; UNRESOLVED/XPASS reddi ve minimum PASS eşikleri gözden geçirilmeli. Gate'te audit dosyasının varlığı yeterli sayılmamalı; içerik/boot/önce-sonra kapsamı doğrulanmalı. Stability boyunca host termal/kernel izleme ve başarısızlıkta VM kapanışı tamamlanmalı.
5. Üretim toolchain → 79 paket → kernel → BLFS → Plasma GL → Claude profilleri → iki ISO akışı tarifleri tamamlanıp incelenmeli. `infra-stages.json` **kabul sözleşmesidir**, yürüyen üretim pipeline'ı değildir. BLFS kaynaklarının tamamı henüz tek manifeste alınmadı.
6. ABI seçimi **(b) m64+m32 olarak alındı**. Kullanıcı “OC tamam, başla” yetkisini verdi; teknik eksikler hâlâ açık. Başlama yanıtı yukarıdaki teknik eksikleri otomatik kapatmaz.

Şu an tüm Faz 2'yi gerçekleştiren kabul edilmiş tek komut yok. Son akış `stage-request --name stability --mode multilib-m32` ile yalnız güncel Phase1 kabulünden sonra benzersiz run_id ve kullanıcı root before denetim isteği hazırlar. `stage-request` başlama/OC yetkisi değildir. Root before denetimi doğrulanmadan VM açılmaz. Gerçek altyapı/Alp/host engelleri kapandıktan ve kullanıcı başlama yetkisi verdikten sonra **yalnız kararlılık aşaması** şu taslakla başlar (yer tutucu; şimdi çalıştırılmamalı):

```bash
python3 /home/yrslf/alpbahOS-infra-rebuild/scripts/infra/buildctl.py phase2 --oc-confirmed --mode multilib-m32 --run-id '<stage-request çıktısındaki run_id>'
```

Koşu sonrası sonuç yalnız `PENDING_PRIVILEGED_POST` olur; kullanıcı root v2 after isteği terminal outcome SHA'sını bağlar. Son producer raw monitor/current guest/disk/root proof'unu tekrar doğrulayıp `accept-stability --run-id … --audit-id … --mode multilib-m32` ile yalnız stability receipt/checkpoint verebilir. Bu yeni yol 105 host testinde synthetic evidence + gerçek küçük qcow2 ile doğrulandı; gerçek stage kabulü yok. Diğer ürün stage producer'ları ve guest receipt/host toolchain handoff açık. [Güncel kanıt ve sınırlar](infra-stage-acceptance-2026-10-01.md). Saf x86_64 seçeneği araştırma olarak korunur; yeni stage preparer kullanıcının seçtiği m64+m32 için uygulanmıştır. OC kazancı ancak eşdeğer ortamda, aynı ABI/recipe/iş sayısı ile **OC öncesi süre / OC sonrası süre − 1** üzerinden ölçülebilir. İki paket/DB hash'i, MCE/ICE, ani reset ve throttle ayrıca değerlendirilir; farklar tarif yamalarıyla örtülmez.

## Kanıt envanteri

Ortak dizin: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/`.

| Dosya | SHA-256 |
|---|---|
| `artifacts/zlib-smoke/db-repro-evidence.json` | `ed378435fffa214da350511f7e0fea7827bdbc871c4ce4a0459b970cf4891c01` |
| `logs/provision-1790799370741440418.log` | `03b44ce36f8347405cb712db4cff748d3485ad0785ee62968e6dbad9d5d56fc0` |
| `logs/builder-python-1790800832512141068.log` | `19e29a3bc4a132466605c06c38b96fd89175a8a701f79804aaec695a0397eb4a` |
| `logs/smoke-1790800957814339216.log` | `7905d5577296b9f5177dc7471984e8e773f35bba6ee8ce6134c8a80dcbc30fdd` |
| `logs/signature-verification.json` | `a5501aa03816015b4c4cb9cba5dc7ca841220d2a76a331bfa7e1154163078188` |
| `logs/host-baseline-1790798945574806584.json` | `3b9fac7ef2e3fc53088bb83e8ba777e09611301e2604325515b7d2d5fd625e9f` |
| `logs/host-compare-1790801062771230478.json` | `911ba963505c1b686df956f9efe2395cb9ee125a5408b1329b567f0b471b9fd9` |
| `logs/phase1-stop-state.json` | `61369fda1352dddfb2b9d055cee87e4b058bc48a3fc2703072ec924937f042e3` |

Diğer kanıtlar: `artifacts/zlib-smoke/summary.json`, iki manifest/arşiv ve ham DB'ler; `logs/infra-boundary-tests.log`; `logs/host-kernel-readable.jsonl`; başarısız smoke `artifacts/failed-zlib-smoke-01/`. Python 3.11 Alp `tarfile.data_filter` eksikliği nedeniyle ilk smoke geçti sayılmadı; motor değiştirilmeden yalnız Builder'a sabit SHA'lı Python 3.13.7 runtime kopyalandı. İlk QEMU boot/provision sorunları ve başarısız çıktılar korunuyor.

İmajlar `/mnt/alpbahOS-ssd/alpbahos-infra-rebuild/`; `checkpoint-prepared`, `preserved-overlays-1790800663020585457`, kapalı aktif diskler korunuyor. Eski kullanıcı imaj/dizinlerine temizlik uygulanmadı. Tüm loglarda gizli anahtar/parola yazdırılmadı.


## Güncel offline smoke tekrar denemesi — 1 Ekim 2026

Önceki stale build/stage dizinleri, canlı VM kapatıldıktan sonra SHA doğrulamalı `checkpoint-prepared` üzerinden yeni overlay açılarak giderildi; eski overlay'ler korundu. Hazırlanmış guest'te `/etc/alp-infra-builder` ve `/srv/lfs/.infra-volume` vardı, eski zlib smoke dizini yoktu. Builder Python 3.13.7 cache'den yüklendi.

Güncel smoke özetinde iki gerçek zlib build/test/stage tekrarında arşiv (`fd0e3858018f8b66a8a38e936982da7e85969f3f6efa6257007c248c19a2eebd`) ve manifest (`e76130a8486c7aed8ca1f8a9c28cfbee37d2dacbf42aaeffacb8b87ebf5830b2`) hash'leri eşit; Alp install/remove/reinstall ve 8 sahiplik yolu geçti. Ham Alp DB hash'leri farklı (`e7d765abc1d25ef390de260de287079bf1deaf1fdbb9c09b735762b425068122`, `74f154119b0e934395bfff23b1b59d21eedf3ff217b52d43fe61227ef5c4eb78`), `db_repeatable=false`, sonuç `FAIL_DB_REPRODUCIBILITY`. Tam guest log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/smoke-1790883748017719784.log`, SHA-256 `abfef16ab354cb8da7e1f56c8bd72339ace6cd59ca4f8d22e7740a63e4a8fb0f`; özet: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/zlib-smoke/summary.json`. Ham zaman alanları normalize edilmedi; smoke kabul edilmedi. Builder kapatıldı ve qcow2 yazarları durdu. Plasma/KWin açık kaldı. Root cleanup receipt/post-audit ve eşit DB kanıtı hâlâ yok; Faz 1 tamamlanmadı.
