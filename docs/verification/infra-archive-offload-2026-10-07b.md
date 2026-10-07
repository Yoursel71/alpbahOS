# 7 Ekim 2026 — başarısız Builder overlay arşivi

İki eski, başarısız Base koşusuna ait kapalı qcow2 overlay çiftleri çalışma SSD'sinden root NVMe arşivine taşındı. Amaç, kabul edilmiş toolchain kontrol noktasını korurken SSD'nin %15 boş alan güvenlik tabanının üstünde yeniden derleme alanı açmaktı. QEMU kapalıydı; kaynak dosyalarda açık süreç tanıtıcısı yoktu. Her kaynak/hedef SHA-256 eşleşti; kaynak ve arşiv QCOW'larının tamamı `qemu-img check` ile hatasız çıktı. Backing zincirleri korunmuş kontrol noktalarına bağlı kalıyor.

- `preserved-overlays-1791363044718211083`: builder `153b4ab8d29ecfdd5c1511b812614fba7d7c3bd3857a7ee2c46189882d9d7a3e`; LFS `7384a4035d01e01ec399d4132c13ceba842f7ca91402aee9f2630d81c77905d7`. İkisi de `checkpoint-stability` üzerine bağlı.
- `preserved-overlays-1791370638234806435`: builder `4406b398dd24af9ea897bd2e94cc8e7c949115c523a3af6f272ea2a988dfee2c`; LFS `f551653a6570ff1b85d7ceee91d8bd6620a12d6f468b5087bcfbe5ffa5d7db43`. İkisi de kabul edilmiş `checkpoint-toolchain` üzerine bağlı.
- Arşivler `/home/yrslf/.local/share/alpbahos-archives/infra/` altında. Dosya listesi, boyutlar ve SHA-256 makbuzu: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/archive-offload-preserved-overlays-20261007-b.json`.
- Taşıma sonrası `df -B1`: root 56,375,877,632 bayt boş; SSD 27,911,811,072 bayt boş; HDD 75,976,683,520 bayt boş. `buildctl.space_guard()` PASS (`142217728000`). Her üç disk de %15 sınırının üzerinde. Milestone ISO'lar ve kabul edilmiş checkpoint'ler değiştirilmedi; masaüstü ve kullanıcı uygulamaları çalışır bırakıldı.
