# 32-bit araştırması — 30 Eylül 2026

Güncelleme — 1 Ekim 2026: Kullanıcı `b` yanıtıyla **multilib-hazır m64+m32 toolchain** seçti; x32 eklenmez. Başlama yetkisi verilmedi. D32/D35 veya DECISIONS.md bu görevde değiştirilmedi.

Resmi LFS 12.4 x86_64 akışı saf 64-bit'tir; GCC'de multilib kapalıdır. Topluluk MLFS yolu var. Eski Thomas HTML adresi artık geliştirme kitabına yönleniyor; onu kullanmak 12.4 sabitlemesi değildir. Resmi Git'te `ml-12.4` etiketi bulundu ve yalnız araştırma için indirildi:

- Tag nesnesi: `cb4e77c4b999450e7f441ca3b3af94bc1b8b19c2`.
- Commit: `d7bc803361f445a649d0ca0832219f75b6e68683`.
- Yerel, değiştirilmemiş araştırma kopyası: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/research/mlfs-12.4`.
- `Makefile`: `REV=systemd ARCH=ml_32`; x32 ABI gerekli değil. GCC `m64,m32`; Glibc `CC=gcc -m32`, `/usr/lib32`, `/lib/ld-linux.so.2`; Pkgconf ayrı i686 personality.
- Kaynak sürümleri: Binutils 2.45, GCC 15.2.0, Glibc 2.42; LFS 12.4 ile eşleşiyor. ISL 0.27 ekleniyor. Genel entity dosyasındaki release makroları eski/geliştirme biçiminde; kitabı başlığa göre değil sabit tag, paket listesi ve mimari koşullarıyla değerlendirmek gerekir.

Komut: `git ls-remote --heads --tags https://git.linuxfromscratch.org/lfs.git '*12.4*' '*multilib*'`; `git -C /mnt/alpbahOS-data/alpbahos-infra-rebuild/research/mlfs-12.4 rev-parse HEAD`.

| Seçenek | Süre | Ek disk | D33 / risk |
|---|---|---|---|
| (a) Saf 64-bit denemesi | Ölçülmüş SBU yok; temel karşılaştırma 1.0×. | Başlangıç VM 12 GiB OS + 40 GiB LFS sanal kapasite; gerçek kullanım ayrı ölçülür. | Resmi LFS/BLFS 12.4 yolu. Sonradan multilib kararı bu görev planında temiz toolchain/taban yeniden üretimini gerektirir. |
| (b) Multilib-hazır toolchain (m64+m32) | Mühendislik tahmini: toolchain/taban için +%25–60; 32-bit testler ve ek grafik kütüphaneleri kapsamına göre artabilir. Donanımda ölçülmedi. | Planlama tahmini: toolchain ve test workspace/snapshot için +10–20 GiB; tam 32-bit grafik/Wine/Steam zinciri için ayrıca +10–30 GiB. Ölçüm değildir. | D33 sürüm eşleşmesi korunabilir; multilib fork sapması ve ISL ek kaynağı kaydedilmeli. BLFS'nin tamamı için aynı kapsamda multilib kitabı yok; GLFS tariflerini 12.4'e bilinçli uyarlama ve ABI testleri gerekir. |

GCC final MLFS kitap değerleri 46 SBU ve 6.6 GB; Glibc final 12 SBU ve 3.3 GB. Bunlar bu makinenin ölçümü veya m32 farkının ölçümü değildir. `packages.ent` bu ayrımı ayrıca vermiyor; yüzden ek maliyet aralıkları tahmin olarak etiketlendi.

Öneri: oyun/Steam hedefi korunacaksa (b), yalnız m32 ile; x32 gereksiz ek kapsam. Henüz toolchain derlenmedi. Her iki seçenek için kernel `CONFIG_IA32_EMULATION=y` gerekliliği yazıldı; derlenmiş kernel kabulü verilmedi.

Birincil kaynaklar: [LFS 12.4 mimarisi](https://www.linuxfromscratch.org/lfs/view/12.4-systemd/prologue/architecture.html), [MLFS haberleri](https://www.linuxfromscratch.org/mlfs/news.html), [MLFS resmi Git](https://git.linuxfromscratch.org/lfs.git), [MLFS kapsamı](https://www.linuxfromscratch.org/mlfs/index.html).

Dosya SHA-256 kanıtları:

```text
packages.ent d7e0cb91b442e6540dd2214053cd777245d977f29eea29a70675ff9840277d26
chapter05/gcc-pass1.xml f96eb75966f0a2abc6aeabfc52410b0cffaa166d9f7791b0b19043d3e95e1f88
chapter05/glibc.xml 54740beed6a506c80d17c9c91c52bd65659886e38effd9ad41887efba4a91123
chapter08/gcc.xml 473f1b6097fe51655d02ac9660d0e9b67d620e35d628e50f3c0925df8becfeff
chapter08/glibc.xml 2e0963fd6ac1a86b623037f1fb778989ba8ec5eba281bf88074a8740e63c9830
chapter08/pkgconf.xml 4eeb2adce2209539f4d11a81ab28a836b309c00c2cc62ccfa2196fead2f1822d
```
