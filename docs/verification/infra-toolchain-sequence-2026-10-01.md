# Toolchain paket sırası, devam ve ABI hazırlığı — 1 Ekim 2026

**Kod ve izole fixture kabulü; gerçek guest/toolchain/ABI derlemesi yapılmadı.** Önceki goal turu 44 test ve gerçek yetkisiz Alp layout fixture ile ilerlemeydi. Bu tur paket sırası/resume, ABI doğrulama kodu, yanlış mkheaders borcunun düzeltilmesi ve kendi fixture ağaçlarının kanıt korunarak temizlenmesiyle ilerledi. Canlı bekleme yok; QEMU yok. Main/Claude HEAD ve dalı, Alp motor pini aynı. Host root/mount/chroot/paket/CPU değişikliği, guest/derleme/SBU/OC, commit/push yok.

## mkheaders kaydındaki düzeltme

Önceki notlarda Glibc sonrasında GCC `mkheaders` için ayrı ownership-safe replacement gerektiğini yazmıştım; **bu sabit kitap için yanlıştı**. `ml-12.4` commit `d7bc803361f445a649d0ca0832219f75b6e68683` içindeki Glibc Chapter 5 XML'inde `mkheaders` yalnız yorum bloğundadır; etkin GCC pass1 talimatı üç kaynak başlığını (`limitx.h`, `glimits.h`, `limity.h`) GCC `include/limits.h` içine birleştirir. Mevcut GCC tarifindeki `post_stage_concat` bu etkin talimatı **staging içinde, Alp capture öncesinde** uygular. Kurulu GCC dosyasına ayrı doğrudan yazma adımı eklenmedi. Gerçek derlenmiş limits.h/ABI kabulü hâlâ bekleniyor.

Kaynaklar: [pinned Glibc XML](/mnt/alpbahOS-data/alpbahos-infra-rebuild/research/mlfs-12.4/chapter05/glibc.xml), SHA `54740beed6a506c80d17c9c91c52bd65659886e38effd9ad41887efba4a91123`; [pinned GCC pass1 XML](/mnt/alpbahOS-data/alpbahos-infra-rebuild/research/mlfs-12.4/chapter05/gcc-pass1.xml), SHA `f96eb75966f0a2abc6aeabfc52410b0cffaa166d9f7791b0b19043d3e95e1f88`. Etkin userinput/comment ayrımının [kanıtı](/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-mlfs-mkheaders-inspection-20261001.json), SHA `f70ede73e053c4d2d4e49c88ffdf7638c8fa094126f3d7023d6ae19106cf30e3`. İlk ElementTree okuması dış book entity'sini çözemedi; kaynak değiştirilmeden literal entity'leri koruyan HTMLParser ile userinput/comment ayrımı yapıldı. Yalnız metin incelendi, kitaptaki komutlar çalıştırılmadı. Glibc tarif notu ve aktif durum/önceki borç kayıtları düzeltildi.

## Paket akışı

`guest_toolchain.py` ve `guest-toolchain.sh` yalnız şu Chapter 4/5 sırasını çalıştırabilecek şekilde hazırlandı:

1. filesystem-layout
2. binutils-pass1
3. gcc-pass1
4. linux-headers
5. glibc-cross-m64
6. glibc-cross-m32
7. libstdcxx-cross

Root/guest/disk/writer lock/alan ve mevcut OC/ABI+stability kapıları korunur. Kütüphane çağrısında bile plan canonical recipe dosyalarıyla aynı olmalı; phase'i smoke olarak değiştirmek kabul edilmez. Girdi/source/plan hash'leri sonuç dizinine bağlanır. Bilinmeyen kurulu paket veya sıralı bir prefix oluşturmayan eski/eksik Alp kaydı durdurur.

Her build yeni alana gider; doğrulanmış archive/manifest/source bilgisi `built.json` ile saklanır. `build-started.json` olup doğrulanmış bundle yoksa checkpoint recovery gerekir. İki build artifact'ının yol/byte hash'leri devamda tekrar kontrol edilir. Daha önce kurulu bütün paketler **yeni build/install öncesinde** ortak `verify_installed` ile doğrulanır; sonra tüketilecek prefix yine kontrol edilir. Resume mevcut paketi yeniden derlemez/kurmaz. Doğrulanmış bundle henüz hiç kurulmadıysa kurulum aşamasına devam edilebilir.

Kurulum girişimi önce `install-started.json` bırakır. Alp girişimi kesildi, kabul makbuzu yazılamadı veya DB'de paket yoksa **otomatik yeniden deneme/reinstall yapılmaz**; checkpoint'e dönülmelidir. Algoritma root DB'yi doğrudan düzenlemez, engine recovery'yi dışarıdan yamalamaz. Her paket ortak staged Alp adapter'ı ile kurulur. Guest özetindeki PASS yalnız Chapter 4/5 paket/ABI kapsamını taşır; host/stage/ISO kabulü değildir ve runner qcow2 checkpoint üretmez.

## ABI kodu

`toolchain_sanity.py`, m64 Glibc sonrası C/m64; m32 sonrası C/m64+m32; Libstdc++ sonrası C++/m64+m32 compile/link kontrolü hazırladı. Bunlar aynı etaplara devam edildiğinde de **yeni** diagnostic çalışmasıdır; eski sanity stamp'iyle geçilmez. Target programlar çalıştırılmaz. Paket payload'ı yazılmaz; guest build/result dizinlerinde diagnostic dosyaları üretilir.

- Compiler multilib seçenekleri tam default m64 ve m32 olmalı; x32 yok. Sysroot dedicated LFS ile aynı olmalı; compiler/linker dosyaları doğru Alp paketlerinin sahibi olduğu tools altından gelmeli.
- Scrt1.o/crti.o/crtn.o, libc ve loader ilgili ABI'nin hedef lib/lib32 dizininde, doğru tek Alp sahibine bağlı olmalı. C++ kütüphanesi de Libstdc++ paketine bağlı olmalı.
- Çocuk süreç `lfs` kullanıcısında temiz `env -i`, sabit locale/UTC/epoch ve açık PATH ile çalışır. Inherited CPATH/LIBRARY_PATH gibi host arama ayarları taşınmaz.
- Gerçek probe ELF byte'larının class/machine/program-header/PT_INTERP alanları okunur. m32 ELF32+EM_386; m64 ELF64+EM_X86_64 gerekir. ELF32+EM_X86_64 (x32), sysroot öneki eklenmiş loader, bozuk/truncated header reddedilir. ELF tanımları salt okunur `/usr/include/elf.h` ile de kontrol edildi.
- Verbose header ve linker kayıtları hedef kökü dışındaki aramayı/başarılı girdiyi reddeder; linker SEARCH_DIR'ler sysroot-relative olmalı. Gerçek link trace hedef CRT/libc girdilerini seçmeli. RPATH/RUNPATH kabul edilmez.
- Tüm komutlar/stdout/stderr, probe ELF hash'leri ve input/source bağlı summary saklanır. Gerçek GCC/ld çıktılarıyla **henüz sınanmadı**; fixture parser testi gerçek ABI/link kabulü değildir.

**Host controller'a toolchain çalıştırma action'ı bu tur bağlanmadı.** Mevcut `phase2` hâlâ kararlılık taslağıdır. Gerçek host sonrası privileged audit, stability receipt üretimi/guest aktarımı, sürekli host/guest alan-izleme entegrasyonu ve stage checkpoint kabulü bitmeden runner'ın varlığı çalıştırma izni değildir. Yeni çalıştırma komutu verilmedi; kullanıcı “OC tamam, başla” demedi.

## Test ve fixture temizliği

Komut `python3 -m unittest discover -s tests -p test_infra_rebuild.py -v`: **52 test geçti**, 1,864 saniye. [Log](/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-toolchain-sequence-tests-20261001.log), SHA `955bb7063d111f5368ff46bdce1c08cc90582d9464dc44f254568d5dc4337c9a`. Sekiz yeni test paket sırası/staged limits, host invocation reddi, değişmiş bundle/input, resume'da rebuild/reinstall olmaması, kesik Alp işleminin tekrar edilmemesi, canonical phase korunması ve ELF/header/linker kaçışlarını kapsar. Sequence testinde build/install/probe ve guest boundary **simüle edilir**; gerçek tar/capture/hash doğrulaması çalışır. Gerçek C/C++ compiler çalışmadı.

İlk 51-test koşusunda eski checksum testi runtime symlink guard'ına takıldı: önceki gerçek host layout fixture'ın `stage-a/b` ve `alp-root` ağaçlarını artifact dizininde bırakmıştım. [Başarısız log](/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-toolchain-sequence-tests-20261001-before-fixture-compaction.log), SHA `598a5ce8bfa4893a9bcf7d312e7d1e551d1e3f90384b3729a9639d3611187bbf` korunur. Guard değiştirilmedi/maskelenmedi. Yalnız bu üç yeni, uid1000 test ağacı; inode/device/owner ve dört beklenen symlink hedefi doğrulandıktan sonra arşivlenip temizlendi. Önceki root/milestone veya kullanıcı verileri silinmedi.

Gerçek fixture kanıtları, iki stage core arşivi/manifest, engine logu ve original summary korunur. Raw DB `db-post-install.json` olarak byte-for-byte saklandı; root snapshot içindeki DB'nin de aynı SHA olduğu doğrulandı: `d5f72bd1823de88b87f62fd3373094df249728e2680473a1d98af1aefc168391`. Diagnostic tar'da yalnız archive metadata zamanı normalize edildi; **DB byte'ları değiştirilmedi**, iki DB karşılaştırması veya guest kabulü yapılmadı. Root snapshot SHA `ea94f169bbebd6014b16b56cc75705315a185d8f4e35dc7e1666d00fa0faccb3`; [tree-compaction.json](/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/filesystem-layout-host-fixture-20261001/tree-compaction.json), SHA `48d95935b893da98870287cfa5410fbb7262fc4bf774e9ab9810573d209346ee`. Ardından 51 test geçti; canonical phase testi eklenip son 52-test koşusu geçti. Bütün geçiş logları korunur.

AST/bütün infra shell `bash -n`, tracked diff-check ve **gerçek, değişmemiş runtime alan/symlink guard** geçti. [Kod/durum kanıtı](/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-toolchain-sequence-verification-20261001.json), SHA `6f30c1ec19a830e39783539bbea04d7f4f353d1698b44fcd8563a9f2e204e17e`.

| Kod | SHA-256 |
|---|---|
| guest_toolchain.py | `77c707688294cdd56a8c1b978ea558d69f4c4ecb76528a43527b8e44aa0ee92b` |
| guest-toolchain.sh | `87d084c6201f125738aa7e95e0d35b10b8fe71978feb371cc6c309cb3f9ce6b1` |
| toolchain_sanity.py | `3f9adefd75138a83b80b2b5ac15176dcd8f64ef5ba42290bf29ca1cc8aacecab` |
| glibc-cross-m64.json | `ac5fbaf8862cd832c6413ad9ab9b2e884e83f2d1b06294f7affbcfc09fbc53fd` |

Input digest `1be96d6e3c5185a79d0c30193c325f9c17c38cea19300c32da71106dcd220cb4`. Source manifest `0df6f8614ba0b4c335561f69c9458e972be5a738bd3ffa3c6f955ca12b6c8027` ve Alp `92d519...` aynı; eski smoke güncel input kabulüne çevrilmedi. Frozen root cleanup script `b5939acd...` değişmedi.

## Açık kapsam

Alp deterministik-zaman düzeltmesi, kullanıcı root cleanup/audit, journal değerlendirmesi ve güncel gerçek Phase 1 smoke kabulü hâlâ yok. Root sonuç dosyaları yok, QEMU yok; NVMe/SSD/HDD boş alan %34,57/%60,15/%57,24. OC/başla yetkisi yok. Gerçek Chapter 4/5, iki toolchain run hash karşılaştırması ve host kabulü kanıtlanmadı. Chapter 6/pass2, final 79 paket/uzun testler, kernel/BLFS/Plasma GL/profiles ve iki ISO kapsamı açık. HAZIR/goal complete ilan edilmedi. [Root komutu/temizlik](infra-cleanup-2026-10-01.md), [önceki layout kanıtı](infra-filesystem-layout-2026-10-01.md).
