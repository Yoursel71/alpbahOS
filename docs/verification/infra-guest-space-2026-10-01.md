# Guest komutları sırasında alan koruması — 1 Ekim 2026

**63 yetkisiz host testi geçti; gerçek guest/derleme kabulü yok.** Builder kapalı. Bu tur yalnız Codex'in kendi worktree'sindeki komut izleme kodu, testler ve durum belgeleri değişti. Host root/mount/chroot/paket/CPU ayarı, Alp motor değişikliği, main/Claude'a yazma, commit/push veya ağır derleme yapılmadı.

## Korumanın kapsamı

`scripts/infra/guest_process.py`, komut başlamadan, çalışırken en fazla beş saniyede bir ve çıktıktan sonra `/` ile `/srv/lfs` boş alanını kaydeder. Tam %15 kabul edilir; daha azı durdurur. Eksik/geçersiz örnek, ölçüm hatası ve filesystem device/inode değişimi de durdurur. Her örnek karar verilmeden önce `.space.jsonl` dosyasına yazılıp flush edilir. Log yazma hatası child başladıktan sonra gerçekleşirse de süreç grubu temizlenir.

Komut yeni session/process group içinde açılır. Başarısızlık veya çıkışta yalnız bu gruba TERM gönderilir; beş saniye sonunda grup hâlâ varsa KILL gönderilir. Grup lideri bitmiş olsa da alt süreçler kontrol edilir. Bu bekleme derleme süresine konmuş bir sınır değildir. Küçük açık stdin girdisi en fazla 4096 byte'tır. Disk örnekleme aralığı ve TERM beklemesi nedeniyle durdurma anlık değildir; kesilemeyen kernel I/O için kesin sonlanma garantisi verilmez.

Üretim `package_stage.run` root çağrısında guest/dedicated disk/writer lock/result yolu denetimi **komut logu veya child açılmadan** yapılır. Derleme/stage, manifest/arşiv, ortak Alp install/check/compare ve smoke lifecycle komutları aynı yoldan geçer. ABI probe komutları da aynı izleyiciyi kullanır; stdout/stderr ve alan sidecar hash'leri summary'ye alınır. Yetkisiz host fixture paketleme yolu üretim guest kabulü değildir.

Tar/gzip, sabit ve gözden geçirilmiş `bash -c` kodunda `set -euo pipefail` ile tek gruptadır. Yol/epoch/uid/gid değerleri quoted positional argv olarak geçer. Tar hatasını başarılı gzip bastıramaz; kısmi kanıtlar korunur. Payload metadata veya ham Alp DB normalize edilmedi.

`guest-test.sh` background dispatch öncesine mevcut OC/ABI ve stability acceptance denetimi eklendi. **Uzun suite worker'ının doğrudan `make -j2 -k check` komutu bu izleyiciye henüz bağlanmadı.** Native/chroot/background suite, host toolchain controller, stability makbuzu aktarımı ve stage checkpoint entegrasyonu açık; bu değişiklik bütün pipeline'ın sürekli korunduğu anlamına gelmez.

## Doğrulama

Komut: `python3 -m unittest discover -s tests -p test_infra_rebuild.py -v`. Sonuç: **63 test, 2,167 saniye, OK**. [Test logu](/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-guest-space-tests-20261001.log), SHA-256 `cbb5f2d2c5573467f4defe229348be9c4a53ce6f04ff1d3a1c135a3290f71a2f`.

Önceki 52 teste ek 11 test: düşük baseline'da child/log açmama, tam %15 ve identity/telemetry reddi, başarıdan sonraki düşük alanın veto etmesi, ölçüm ve log yazma hatasında temizleme, gerçek kısa stdin/exit komutu, gerçek parent+descendant durdurma, host root çağrısının yazmadan reddi, bitmiş liderden sonra KILL yolu, tırnak/boşluk/dolar içeren yollarla iki gerçek eşit tar/manifest ve tar failure'ın gzip tarafından gizlenmemesi. Alan örnekleri simüledir; gerçek disk doldurulmadı. Süreç testi yalnız iki uyuyan yetkisiz Python sürecidir. Manifest/tar/gzip/byte doğrulaması gerçektir; compiler, guest veya Alp kurulumu bu tur çalışmadı. İlk 60 ve sonra 62 test de geçti; son eklenen exited-leader testiyle 63'e ulaşıldı. Başarısız test koşusu yok.

17 Python AST okuması, dokuz `bash -n`, tracked `git diff --check`, değişen kodlarda whitespace denetimi ve gerçek host runtime alan/symlink/bütçe koruması geçti. [Kod ve durum kanıtı](/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-guest-space-verification-20261001.json), SHA-256 `fb915e2cc224afd15ee9fbc74aac826654ec212c03d9d448e4189c4606ee55e9`. Kod dosyalarının tam SHA'ları bu kayıttadır. Yeni input digest `993f48ab549d40a75bc943079cf35e36bc1f6181dd4ebe2aa0dc4aea33246d46`; eski guest kanıtı yeni kodun kabulü sayılamaz.

Source manifest SHA `0df6f8614ba0b4c335561f69c9458e972be5a738bd3ffa3c6f955ca12b6c8027`, frozen root cleanup betiği SHA `b5939acdfbb2b1334e582f0555839900e2f43f3691e2b40bd7f2a1c8c7e2a279` ve pinned Alp SHA `92d519212d161159f6f083008b14c7b5b22c2d3e7e60f49fe17d493538fe25b2` değişmedi. Main `a9bac385…`/main, own `a9bac385…`/codex/infra-rebuild ve Claude `c6d98d4b…`/claude/m08-live-fixes aynı. Canlı QEMU yok.

## Temizlik ve kalan kapılar

Güncel boş alan: NVMe `176056561664` byte / %34,57; SSD `72201052160` / %60,15; HDD `281104330752` / %57,24. Önceki yetkisiz temizlikte major milestone'lar korunarak yaklaşık 279 GiB net alan açıldı. Bu tur ek eski imaj/root ağacı silinmedi. Kullanıcı tarafından uygulanacak frozen root planının `cleanup-root-result.json` ve `root-host-audit-after.json` dosyaları hâlâ yok; root'a ait 1117 snapshot +199 dizin bekliyor. [Temizlik kapsamı ve mevcut kullanıcı komutu](/home/yrslf/alpbahOS-infra-rebuild/docs/verification/infra-cleanup-2026-10-01.md).

Alp ham DB zamanı/determinism düzeltmesi, yeni gerçek smoke kabulü, root host denetimi/journal değerlendirmesi ve açık “OC tamam, başla” kapısı sürüyor. ABI seçimi m64+m32, x32 yok; D32/D35/DECISIONS değişmedi. Phase1 acceptance dosyası yok; **HAZIR/goal complete verilmedi**. Sonraki bağımsız kod işi uzun suite izleyicisi ve host aşama/acceptance/checkpoint bağlantısıdır; bunların gerçek derleme kabulü kapılardan sonra yapılır. Full Chapter6/79 paket/kernel/BLFS/Plasma GL/profiles/iki aynı ISO kapsamı devam ediyor.
