# ADR 0002 — Steam için multilib

Durum: İlke kabul edildi; kesin kaynak revizyonu araştırılıyor. Tarih: 21 Eylül 2026.

## Sorun

Standart LFS x86_64 yapısı saf 64-bit kullanıcı alanıdır. Steam istemcisi ve bazı oyun bileşenleri 32-bit glibc ile 32-bit grafik kullanıcı alanı ister. Multilib kararı nihai toolchain tamamlandıktan sonraya bırakılamaz.

## Karar

alpbahOS x86_64 kernel ve ana 64-bit kullanıcı alanını koruyacak; seçilmiş i686 kütüphaneler için multilib toolchain ve `/usr/lib32` sınıfı ayrı manifestle üretilecek. Ayrı bir 32-bit dağıtım kurulmayacak.

## Uygulama kapısı

1. LFS 13.1 ile uyumlu, izlenebilir multilib kitap/revizyonu sabitlenir.
2. GCC/binutils/glibc dizilimi ve dynamic loader yolları yazılı olarak doğrulanır.
3. Basit ELF32 ve ELF64 programlar derlenip hedef rootfs içinde çalıştırılır.
4. Mesa/Vulkan/OpenGL ve NVIDIA için 32/64-bit kullanıcı alanı paketleri aynı sürüm ailesiyle üretilir.
5. Steam runtime ve bir test oyunu ile doğrulama yapılır.

Kaynak revizyonu LFS 13.1 ile güvenilir biçimde eşleşmezse uyumlu sabit LFS/BLFS/multilib üçlüsüne geçiş ayrı ADR ile kaydedilir. Başarısız veya yarım multilib tabanı ana build'e birleştirilmez.
