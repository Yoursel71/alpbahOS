# Kernel DESTDIR payload kapısı — 11 Ekim 2026

Sahip Codex; dosya sınırı `scripts/infra-kernel-payload.py`, odaklı testler ve durum/kanıt kayıtları. Mevcut Base canonical girdileri/checkpointleri korunuyor. Canlı controller/VM yok; host kesintisi açıklaması beklenirken yeni uzun üretim build başlatılmadı.

## Uygulanan kontrol

Yardımcı yalnız salt okunur `--stage <absolute-path> --manifest <absolute-path>` denetimi yapar. Package identity `linux-kernel` 6.16.1 ve mevcut kaynak SHA/URL pini zorunlu. Stage'deki **tam** yol/mod/uid/gid/hash envanteri ortak capture koduyla yeniden üretilir; manifest ile birebir eşleşmeli. Baştan ve sondan tekrar okunur. Numeric owner aynı olmalı; ayrıcalıklı/world-writable mode ve special file reddedilir. Symlink izin bitleri normal dosya gibi yorumlanmaz; contained documentation alias desteklenir, escape/dangling/cycle ve bütün module/build/source symlinkleri reddedilir.

İlk payload biçimi: `/boot/{vmlinuz-6.16.1-alpbahOS,System.map-6.16.1,config-6.16.1}`, `/usr/lib/modules/6.16.1`, isteğe bağlı `/usr/share/doc/linux-6.16.1`. Config 62 zorunlu seçeneği korumalı; initial plan boş LOCALVERSION ve uncompressed modules ister. x86 boot signature/protocol, 64-bit/bzImage bitleri, payload sınırları ve release, EFI PE32+ x86_64 header denetlenir. Bunlar boot başarısı değildir. [Upstream boot protokolü](https://docs.kernel.org/arch/x86/boot.html).

Her `.ko` gerçek ELF64/little-endian/x86_64 ET_REL olmalı; bounded section table içinden tek `.modinfo` ve pinned-release vermagic okunur. `modules.order`/`modules.dep` her actual modülü tam bir kez kapsamalı, dependency path payload içinde kalmalı. Gerekli depmod metadata dosyaları bulunmalı. Binary depmod trie veya gerçek module loadability burada kabul edilmez; gelecekte producer actual depmod komutu/loglarını ayrıca bağlamalı. System.map biçimi ve temel semboller denetlenir.

Sonuç `VERIFIED_CANDIDATE_BYTES`; stage acceptance veya installed ownership PASS değildir. Numeric owner raporlanır: fixture'da 1000:1000; üretici gerçek guest stage'i 0:0 normalleştirmeden production kabulü verilemez. Manifest source pini, gerçek source/build provenance yerine geçmez. Helper güvenli boot, kabul edilmiş Base veya Alp kurulumu iddia etmez.

## Gerçek kaynak hookları ve yetkisiz fixture probe'u

Linux 6.16.1 archive tamamı tekrar SHA-doğrulandı. Actual Makefile default MODLIB yolu `INSTALL_MOD_PATH` altında `/lib/modules/<release>`; actual module install order `.o` adlarını `kernel/*.ko` yollarına dönüştürüyor ve `build` bağlantısını CURDIR'e kuruyor. Actual depmod wrapper staged prefix'i `-b` ile iletiyor. Gelecek producer bu source hooks'u pinlemeli; `/lib/modules` DESTDIR çıktısını usr-merge payload'a kontrollü taşımalı veya açıkça doğrulanmış MODLIB/depmod yolu kullanmalı; build alias'ı sahiplik arşivine taşımamalı. Bu işlemler henüz yürütülmedi. [Upstream Kbuild variables](https://docs.kernel.org/kbuild/kbuild.html).

`/usr/bin/gcc -c` ile yalnız küçük host C fixture'ı üretildi; bir Linux modülü veya kernel derlemesi değildir. `readelf -h` gerçek ET_REL/ELF64, `readelf -p .modinfo` fixture vermagic'i bağımsız gösterdi. Sentetik x86/EFI header, önceki gerçek olddefconfig çıktısı ve ortak capture CLI üzerinden üretilmiş manifest ile yeni helper CLI çalıştırıldı; dört komut exit 0, stderr boş. Bir fixture module count 1; temporary ağaç kaldırıldı. Sahte/sentetik inputların production kanıtı olduğu söylenmez. Bağımsız ajan incelemesi yapılmadı.

Receipt/log kökü `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/`:

| Nesne | SHA256 |
|---|---|
| `kernel-payload-source-fixture-probe-20261011.json` | `56a7bfacdfe23409203632c98e7f5f2c8fcb61270050ea8f80c888cd9c2e74b6` |
| Son payload helper | `d8d3101eccdbb70c2686e3015b6733db64430ebd075600ef6f8fbfb037a383f0` |
| Source archive | `ea43491bc7ace1e414b3b2d957f8cf96e7049155123f0acce798accf8da1acba` |
| Actual Makefile | `803380a08254402342d4953c68845b4ed57183f527fd1d798249cbf10e71eaa1` |
| Actual scripts/Makefile.modinst | `d7f7efd72c780532b4d6ae481946bf32af7771954d359284d805088b2a7f47d1` |
| Actual scripts/depmod.sh | `90723b3a92b8b86b8990c7a1a415e51a19d6e2e1c3b5c83edc6e1bcbe7425ee4` |
| Actual arch/x86/boot/header.S | `285bf5bda95d48912b284529fcb5bcede1287780a95897cb95f6fe5a37000b2f` |
| Gerçek olddefconfig çıktısı | `e92e59baa353e9afab82a7f410fa82ee7fe6a194cbb909b02dbe1a8d9d8750a9` |
| `kernel-payload-focused-tests-20261011.log` | `40cb82169d4e6e58b30cb73419dbdd524f40e54c2acbdbabea90b0212c5b6a87` |

## Test ve kalan iş

10 odaklı test PASS (0,065 saniye); gerçek küçük ELF fixture yanında wrong ELF class/machine/type, truncated section table, farklı image/module release, bozuk image bounds/EFI header, ownership/mode/special file, coverage drift, config drift, invalid dependency ve document link cycle reddedildi. İlk symlink mode varsayımı düzeltildi; cycle çözümleme hatası fail-closed RuntimeError'a bağlandı. Bunlar test sırasında düzeltilen verifier hatalarıdır.

`PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v`: final sürümde 421 test, 2 skip, PASS (91,378 saniye). Log `infra-full-tests-kernel-payload-final-20261011.log`, SHA256 `b344b8d9b98c8758606359825c717a75a419d57d13a53a9e2d6b4f965988abaf`. Önceki full çalışması da PASS idi; document-cycle guard/test değiştiği için final sürüm ayrıca sınandı. Docs checker exit 1, aynı 31 tarihsel bulgu; yeni payload işi bulgusu yok. Log `kernel-payload-doc-check-20261011.log`, SHA256 `dc73ac2438951adfaedeeda06e20e1ff11fd30292759dc6e27ea92fa92d25198`. Python compilation ve whitespace kontrolü PASS. Base input digest hâlâ `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`; helper scripts kökünde ve gelecekteki kernel controller tarafından ayrıca SHA-bound olmalı. Managed allocated bytes 142.425.403.392, 300 GB altında.

Tam kernel runner/accepted-Base handoff, guest build, staged archive/Alp installation, controlled boot ve host after acceptance hâlâ eksik. Sonraki uygulama bu kapıyı gerçek guest producer'a bağlamak; üretim kabulü parent Base ve host güvenliği kanıtlanmadan başlatılmaz. Yeni tam GCC/Coreutils/Base, BLFS/Plasma/GL/ISO ve complete fresh repeat-byte kabulü de açık.
