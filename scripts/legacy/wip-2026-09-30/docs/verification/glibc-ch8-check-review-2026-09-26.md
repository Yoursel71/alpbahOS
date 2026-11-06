# Glibc 2.42 Chapter 8 check review — 26 Eylül 2026

LFS 12.4-systemd Glibc 2.42 serial `make check` tamamlandı. Tüm 51 test alt dizini sonuç verdi; birleşik `complete-tests.sum`: 6,563 PASS, 4 FAIL, 521 UNSUPPORTED, 16 XFAIL, 4 XPASS, sıfır ERROR/UNRESOLVED. Genel exit code 2 idi.

Üç FAIL LFS'nin belgelediği chroot/kernel farklarıdır: `io/tst-lchmod` ve iki `misc/tst-preadvwritev2*`. Dördüncü `misc/tst-rseq`, Glibc 2.42 testinin 33 baytlık rseq kaydını 64 bayt olarak yinelerken host kernel'in uzunluk farkında `EINVAL` dönmesinden kaynaklandı. Dört `elf/tst-ifunc-isa-*` XPASS kaydında gerçek test exit code'u 0; `with-lld=no` koşulundaki xfail sınıflandırması bunları XPASS saydı. Test sonuçları değiştirilmedi.

Kanıt dosyaları HDD `/mnt/alpbahOS-data/alpbahOS-build/logs/lfs-12.4-systemd/` içinde:

- `glibc-ch8-check-resume-20260926T201852Z.analysis.txt`
- `glibc-ch8-check-resume-20260926T201852Z.log`
- `glibc-ch8-check-resume-20260926T201852Z.status`

Tam test özeti `/mnt/lfs/sources/glibc-2.42-ch8-20260926T183002Z/glibc-2.42/build/complete-tests.sum` dosyasındadır. Bu değerlendirme LFS paket test sonucunu kaydeder; yeni bir test çalıştırmaz ve bilinen FAIL'leri gizlemez.

## D34 clean-candidate replay — 30 Eylül 2026

NVMe D34 candidate replay'de aynı Glibc 2.42 build tree'si tekrar kontrol edildi: 51 alt dizinin tamamı sonuç verdi, `make check` exit 2 ile döndü; birleşik `tests.sum` 6,565 PASS, 2 FAIL, 521 UNSUPPORTED, 16 XFAIL, 4 XPASS ve 0 ERROR/UNRESOLVED içeriyor. Bu candidate/kernel koşusunda `misc/tst-preadvwritev2` PASS oldu; önceki LFS rootfs koşusunda raporlanan preadv/writev FAIL'leri tekrarlanmadı. Bu değişiklik testleri gizlemez: continuation betiği yalnızca tam olarak gözlenen iki FAIL (`io/tst-lchmod`, `misc/tst-rseq`), tam dört XPASS ve kategori sayılarını kabul edecek şekilde daraltıldı; yeni/ek hata sonucu kurulum kapısını kapatır.

- `io/tst-lchmod` test çıktısı, aynı açık dosya tanımlayıcısının beklenen `/sources/...` yolu yerine chroot bind hedefi `/mnt/lfs/sources/...` olarak gözlenmesini gösteriyor.
- `misc/tst-rseq` test çıktısında kernel tekrar kayıt çağrısına `EBUSY` yerine `EINVAL` veriyor; kaydedilen rseq feature size 33, alignment 64.
- Candidate evidence tree: `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/glibc-20260929T212202Z-021c081f/working-root/sources/glibc-2.42-ch8-20260926T183002Z/glibc-2.42/build/` (`tests.sum`, tüm 51 `subdir-tests.sum` ve iki FAIL'in `.out`/`.test-result` dosyaları).
- İlk D34 builder durumu exit 2 olarak saklandı. Install continuation, bu test outcomes'larını yeniden birleştirip exact allowlist/count guard'ını geçince Glibc'i kuracak; `make check` sonucu değiştirilmez.
