# Eski infra overlay temizliği — 6 Ekim 2026

Temizlikten önce QEMU kapalıydı. Silme hedeflerinin her birinde yalnızca `builder-active.qcow2` ve `lfs-active.qcow2` vardı; `qemu-img info` ile ikisinin de backing kaynağının kabul edilmiş `checkpoint-toolchain` olduğu doğrulandı. Dört dizine açık dosya tanıtıcısı yoktu. Mevcut kabul edilmiş checkpoint dizinlerine dokunulmadı.

Kaldırılan eski, başarısız çalışma kopyaları:

- `preserved-overlays-1791184739684835829`
- `preserved-overlays-1791207400397850271`
- `preserved-overlays-1791213103526691123`
- `preserved-overlays-1791219442639323959`

En yeni üç büyük overlay (`1791225830013344860`, `1791231895373837973`, `1791266475546657684`) ile `checkpoint-toolchain`, `checkpoint-stability`, `checkpoint-smoke` ve `checkpoint-prepared` yerinde bırakıldı.

SSD'de 32.978.186.240 byte (yaklaşık 30,7 GiB) geri kazanıldı. `/mnt/alpbahOS-ssd` boşluğu %16,35'ten %43,83'e yükseldi. `/mnt/alpbahOS-data` %15 eşiğine yakın olduğundan hiçbir dosya HDD'ye taşınmadı. Önce/sonra alan bilgisi, silinen yollar, inode'lar ve backing yolları `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-infra-overlays-20261006.json` içinde; makbuz SHA-256 `857e1e46ed2af5e2395a998740f3954667e767dedc3ec806f456f9797b790df1`.
