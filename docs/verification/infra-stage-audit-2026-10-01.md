# Aşama bağlı host denetim üreticisi — 1 Ekim 2026

**87 yetkisiz test geçti. Root denetimi, VM veya gerçek aşama kabulü çalıştırılmadı.** Yeni `scripts/infra/host_stage_audit.py` kullanıcı tarafından çalıştırılacak root kayıt üreticisini ve yetkisiz kayıt doğrulamasını hazırlar. Controller/guest/monitor/checkpoint bağlantısı açık; ürün aşamalarının checkpoint kapısı kapalıdır.

## Bağlama ve kayıt koruması

İstek sabit kullanıcı state dizininde mode0600/EXCL ile oluşturulur. Aynı stage/run/input/source/boot ve before/after fazı, 24 saatlik tazelik ve benzersiz audit_id taşır. Yeni denetim kimliği eski başarısız kaydı koruyarak yeniden istek oluşturmayı sağlar; aynı dosyanın üstüne yazılmaz. İstek CLI'si kullanıcıya root komutunu argv verisi olarak verir; sudo çağırmaz.

Root producer yalnız stdlib kullanır ve `python3 -I` ile çalıştırılmak üzere hazırlanmıştır. Gerçek root UID, kendi kaynak SHA'sı, isteğin tam byte SHA'sı, sabit parent/filename ve geçerli schema kontrol edilir. İstek verisi komut veya çıktı yolunu belirleyemez. Root store `/var/lib/alpbahos-infra-audits` ve tüm ataları root-owned, symlink içermeyen, group/world-write kapalı olmalıdır; çıktı dizinleri root:1000/0750, dosyalar0640/EXCL olur. Her capture ayrı run/phase/audit_id altında raw stdout/stderr, komut exit/zaman/hash ve audit.json kaydeder. Bu store yalnız insan root capture yapınca oluşturulur; şu an yoktur.

Yetkisiz verifier gerçek root-owned dosyaları ve ataları yeniden denetler; CAPTURED/coverage yazısına güvenmez. Sabit komutların argv/kapsam/sıralı zamanı ve raw çıktı SHA'ları tekrar kontrol edilir. Ön denetimin bitişi stage başlangıcından geç olamaz; son denetimin başlangıcı stage bitişinden erken olamaz. verify_pair farklı stage/run/boot/input/source çiftini reddeder. Bu yalnız host uç noktalarının kanıtıdır; aradaki sürekli izleme, güncel guest artifacts, git status ve stage kabulü ayrıca bağlanmalıdır.

## Salt okunur RPM kapsamı

RPM verify modu paket `%verifyscript` betiğini çalıştırabilir; bunu engelleyen seçenek resmi [RPM verify belgesinde](https://rpm.org/docs/4.20.x/man/rpm.8) açıklanır. Bu host'un CLI help'i doğrulama için `--noscript` biçimini bildiriyor; gerçek yetkisiz `rpm -V --noscript rpm` exit0/boş çıktı verdi. Bu yalnız rpm paketini denetledi; tüm host'un root kabulü değildir.

Yeni producer sabit sırayla: kurulu verifier-script envanteri → `rpm -Va --noscript` → aynı envanter → `journalctl -k -b --no-pager -o json`. İki envanterden biri betik içerirse veya okunamazsa audit reddedilir; script atlamak temiz kabulün kapsamını daraltmaz. Bugünkü gerçek yetkisiz envanter exit0 ve boştu; gelecekteki capture'da tekrar ölçülür. Pristine RPM için exit0, boş stdout ve stderr gerekir; config farkı da reddedilir. Kernel için exit0, boş stderr, en az bir JSON cursor ve fault-free mesaj kapsamı gerekir. Zaman aşımı124, journal uyarısı veya MCE/I/O/Btrfs/OOM hatası kabul edilmez. Producer inspection sonuç hatasını FAIL olarak raw byte'larla korur; başarısız/incomplete capture kabul edilemez.

Önceden kullanıcıya verilen frozen cleanup script/plan bu tur değiştirilmedi. Yeni producer ayrı bir yordamdır; eski cleanup root çıktısını yeni stage audit yerine geçirmez. Hiç root komutu çalıştırılmadı.

## Kanıt ve sınırlar

`python3 -m unittest discover -s tests -p test_infra_rebuild.py -v`: **87 test, 8,570 saniye, OK**. [Test logu](/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-stage-audit-tests-20261001.log), SHA `c1f13ec4015e5db697c0b6f1a9b54e663bb372dfdcdb6c47dcda5822bf91ff1e`. Dokuz yeni test: gerçek yetkisiz root capture reddi; kullanıcı dosyasının root certificate sayılmaması; private request/EXCL/yeni audit_id; symlink reddi; zaman sınırları ve raw hash; root/producer/request/boot/command değişikliği; RPM/config/script/journal hataları; stale/future request; karışık audit çiftinin reddi. Önceki86 ve87 koşuları da geçti. Pozitif certificate fixture'ları root dosya okuma/ownership taşımayı mock eder; gerçek privileged capture yolu çalıştırılmadı. Önceki gerçek küçük qemu-img testleri bu koşuda da çalıştı; QEMU VM açılmadı.

21 Python AST, dokuz bash syntax, tracked diff-check, gerçek runtime alan/symlink guard ve isolated CLI help geçti. [Kod/durum kaydı](/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-stage-audit-verification-20261001.json), SHA `9735afabb2c93b398decb1e735ea249bdf9840cb6cf82116c2d7d99bb0c922cf`. Yeni producer SHA `ac6b0febb03f8ca3b98694570d3f1a1fc238929b511fc44625f69d11b0fbe46f`; inputs SHA `39737ad101f7f191d629a2a295a4039dd87a02cc6980195fb037114fcc8ac1d3`. Source `0df6f861…`, Alp `92d51921…`, frozen cleanup `b5939acd…` ve plan `67c3b0c8…` aynı; tam SHA'lar kayıt dosyasında.

Main/own HEAD ve dal, Claude HEAD/dal aynı. NVMe %34,51, SSD %60,15, HDD %57,24 boş; runtime allocated yaklaşık4,38GB. QEMU, root cleanup/audit sonuçları, privileged stage store ve Phase1 acceptance yok. Bu tur ek eski imaj silme, host root/mount/chroot/paket/CPU, derleme, main/Claude/Alp/DECISIONS'a yazma veya commit/push yapılmadı. Kullanıcının b=m64+m32 seçimi sürüyor; “OC tamam, başla” verilmedi. Alp ham DB zamanı/yeni smoke, journal değerlendirmesi, gerçek stability/SBU/host çift denetimi ve stage receipt producer açık. Native/79 paket/kernel/BLFS/Plasma GL/profiles/iki eşit ISO kapsamı devam ediyor; HAZIR/goal complete ilan edilmedi.

Sonraki bağımsız altyapı işi: gerçek stage run kimliği ve başlangıç/bitiş zamanı, mevcut guest artifacts/host monitor/disk hash'leri ile bu root denetim çiftini bağlamak; yalnız doğrulanmış aşamaya receipt/checkpoint vermek. Şimdiki helper bu kabulü üretmez.
