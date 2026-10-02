# m64+m32 cross-toolchain hazırlığı — 1 Ekim 2026

**Somut tarif/ortak yordam ilerlemesi; derleme veya HAZIR kabulü değildir.** Önceki goal turu sürekli host izleme ve epoch aktarımını düzeltti. Bu tur root temizlik/audit sonuçları ve canlı Builder hâlâ yok; Alp sahibi HEAD `c6d98d4bc54ed33a4afca22e30e00ac6b1744714`. CPU/host root ayarı, main/Claude yazımı, commit/push, VM/SBU/ağır derleme yok.

## Eklenen altı tarif

`recipes/toolchain/` altında Binutils 2.45 pass 1, GCC 15.2 pass 1, Linux 6.16.1 headers, Glibc 2.42 m64, Glibc 2.42 m32 ve Libstdc++ cross JSON tarifleri var. MLFS `ml-12.4` commit `d7bc803361f445a649d0ca0832219f75b6e68683`, ilgili XML dosya/hash'i her tarifte kayıtlı. GCC yalnız `m64,m32`; x32 eklenmedi. D32/D35/DECISIONS değiştirilmedi.

Ortak `package_stage.py` artık kaynak hash'i doğrulanmış GMP/MPFR/MPC prerequisite arşivlerini, FHS patch'ini, argv pre/post işlemlerini, config.guess/configparms ve stage içinde limits.h birleştirmesini destekler. Prerequisite/patch hash'leri build/stage yaratmadan önce denetlenir. Komutlar lfs kullanıcısıyla, sabit ortamda çalışır; `make install` ayrı DESTDIR kullanır. Glibc m32 payload'ı yalnız lib32 +iki gnu header +loader link'ini alır; m64 header/programlarını kopyalamaz. Manifest/canonical ABI bilgisi, OC/ABI yetkisi ve güncel kararlılık kabul kaydı olmadan toolchain yordamı çalışmaz. Kaynak manifest SHA'sı değişirse kabul reddedilir.

Guest sync yeni tarif dizinini de taşır; **bu tur sync veya guest çalışma yapılmadı**. Bu tarifler Alp'e kuran üretim runner'ı veya toolchain tamamlandı kabulü değildir. Kararlılık kabul makbuzu üretimi henüz bağlanmadı; mevcut durumda gate kapalı kalır.

## Gerçek kaynak preflight ve test

Sabit GCC arşiv SHA-256 `438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e` kontrol edildi. Yalnız iki source dosyası kullanıcıya ait private state dizinine çıkarıldı; recipe'nin gerçek sed argv'leriyle `m64 -> lib`, `m32 -> lib32` ve 32-bit stack realignment değişiklikleri geçti. Source/compiler kodu çalıştırılmadı, GCC derlenmedi.

- Preflight: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-gcc-m32-source-preflight-20261001.json`, SHA-256 `82d239329ea696b414eac22a29d3fb75a245d9c40d219fe407003d6874b03e42`. Preflight sonrası yalnız recipe provenance alanları eklendi; eski/yeni recipe hash'i ve değişmemiş pre argv kanıtı kayıtta ayrılır.
- **26 host testi geçti:** `logs/infra-toolchain-preparation-tests-20261001.log`, SHA-256 `888f211a60513839a379fb8990e95bac4347aa92ebb3f8b2a3e1c210c3c46ddf`. Eksik/yanlış OC-ABI-stability, girdi pini, prerequisite SHA ve stage symlink/path kaçışı kontrol edildi. Bunlar gerçek toolchain/ABI/ownership kabulü değildir. Bir test fixture'ı guest REPO yolunu yönlendirmediği için ilk kez hata verdi; fixture düzeltildi, hata logu `*.before-fixture-root-fix.log` olarak korundu, gate gevşetilmedi.
- **90 mevcut kaynak +Builder cache SHA geçti:** `logs/infra-toolchain-cache-check-20261001.log`, SHA-256 `8a0fa301570fb40665765f8a85493d0a97c088701c2b4809c55367a133cce378`. ISL bu sayıda yok. Python/Bash/JSON syntax kontrolleri geçti.

## Tek kaynak manifesti ve açık ISL

`manifests/infra-sources.json` kullanıcı m64+m32 seçimini, sabit MLFS kitap input hash'lerini ve henüz dondurulmamış ISL 0.27 gereğini taşır. SHA-256 `2924dfeffb5a597259481f7c2165ccc708396587ff6fd4837395425b959e62b4`. Mevcut 90 doğrulanmış source pini değişmedi. İlk freezer'ın var olan manifesti ezmesi engellendi; koruma exit 1 ile erken reddetti (`logs/infra-freeze-overwrite-guard-20261001.log`).

ISL upstream HTTPS isteği HTTP 522; denenen LFS ayna yolu HTTP 404 verdi. Arşiv/partial oluşmadı, source SHA uydurulmadı ve üçüncü deneme yapılmadı. Pinned `packages.ent` MD5 `11ee9d335b227ea2e8579c4ba6e56138`; canlı 13.x kitap kaynak olarak benimsenmedi. ISL pass 1 için kullanılmaz, final GCC/ISL için açık gerektir. Resmî proje [ISL indirmesi](https://sourceforge.net/projects/libisl/files/isl-0.27.tar.xz/download), [MLFS kapsamı](https://www.linuxfromscratch.org/mlfs/). Hazırlık kanıtı `logs/infra-multilib-preparation-20261001.json`, SHA-256 `a0acfbffda462aef457382a866db76a9890edb8010c9f20255e8a45bf2b9097f`.

## Üretim için hâlâ gerekli

1. Alp zaman düzeltmesi ve yeni guest smoke; root temizlik/audit ile journal bulgusunun çözülmesi. [İzleme bulgusu](infra-monitoring-2026-10-01.md), [root temizlik komutu](infra-cleanup-2026-10-01.md).
2. Kullanıcının “OC tamam, başla” yanıtı; gerçek kararlılık/host kabulü ve bu kabulün değişmez makbuzu.
3. Owned usr-merge başlangıç layout'u; Alp ile her tarifi kuran runner ve bağımlılık/input doğrulaması. **1 Ekim düzeltmesi:** pinned Glibc XML'de `mkheaders` örneği yorum içindedir; ayrı replacement borcu çıkarımı yanlıştı. Etkin GCC pass1 limits.h concat zaten staging'de yapılır. Gerçek limits.h/ABI kabulü bekleniyor; [inceleme ve güncel sıra](infra-toolchain-sequence-2026-10-01.md).
4. m64/m32 C/C++ ELF/interpreter/linker/sysroot sanity; hash tekrarları. MLFS Linux header metnindeki incremental patch yerine sabit resmî LFS linux-6.16.1 arşivi bilinçli kullanılır; kernel sürümü artırılmadı.
5. Chapter 6 temporary tools/pass 2, final 79 paket, uzun suite, kernel/BLFS/Plasma/profiles/iki ISO ve tüm gerçek kabul kanıtları. Bu altı Chapter 5 tarifi bunların yerine geçmez.
