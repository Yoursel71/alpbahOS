# LFS/BLFS derleme betikleri (2026-11-05)

Bu klasör, yerel `~/alpbahOS/scratch-lfs-bench` çalışma alanındaki BLFS 12.4 / KDE Plasma 6.4.4 derleme düzeneğinin **kaynak metnidir**. Derleme kaynakları (tarball'lar), ISO/VHDX/img dosyaları ve build logları Git'e eklenmez.

- `order.txt` — paket sırası (340 satır; 017/018/020/191 kaynak eksikliği nedeniyle atlanır).
- `src-meta/packages.tsv` — paket adı, sürüm, tarball, URL, md5/sha256 ve notlar.
- `build-cmds/packages/*.sh` — kitaptan veya (kitapta yoksa) resmi upstream'den alınan derleme komutları. Eklenen paketler: 279a lm-sensors, 279b PyCairo, 279c lcms2, 279d libva, 279e libei, 336 Konsole, 337 Zsh.
- `gen_blfs_chroot.py` — her paket için chroot betiği üretir (bloklar, `BLOK-FAIL` kontrolü, grup döngüleri, sapma yamaları).
- `run_blfs.sh` — sıralı çalıştırıcı (root). Yolları sabit: `/home/yrslf/alpbahOS/scratch-lfs-bench/blfs-plan`.
- `post_blfs_test_config.sh` — test imajı kök yapılandırması (idempotent). Şifre betikte yok; yalnızca `ALPBAH_TEST_PASSWORD` ortam değişkeninden alınır.
- `build_image7.sh`, `mount_lfs.sh`, `umount_lfs.sh` — disk imajı oluşturma ve chroot bağlama.

Kitap sayfası önbelleği (`build-cmds/raw/`) ve `extract_blocks.py` burada yoktur; önbellek kitabın kendi HTML'sinden türetilmiştir ve yeniden dağıtılmaz.

Sapmaların tam listesi: `docs/verification/evidence-2026-11-05/DEVIATIONS.md`.
