# D34 BLFS Polkit replay — 30 Eylül 2026

## Sonuç

Polkit 126, Duktape 2.7.0 ve açık PAM hizmet politikası NVMe D34 adayında ayrı incremental replay'lerle kuruldu. Başarılı son Polkit replay'i `polkit-20260930T080623Z-cf13f925`; başlangıç snapshot'ı `pam-stack-config-20260930T080545Z-e8552f54/after-ro`, bitiş snapshot UUID'si `e8e437fa-7404-774a-87e8-d7317afc2b4b`, subvolume ID 658. Polkit delta'sı 4,904 olay ve 5,860,710 byte.

Son sahiplik ledger'ı `COMPLETE`: 79 resmi LFS Chapter 8 paketi ve 19 supplemental, 4,895,104 yol olayı ve 57,930 final system-path owner. Root yetkili salt-okunur denetim, ledger'daki 57,930 yolun tamamını son snapshot'ta buldu. `/usr/lib/polkit-1/polkitd`, `/usr/bin/pkexec`, Polkit GObject/agent pkg-config modülleri, Duktape kütüphanesi ve başlık dosyaları ile `/etc/pam.d/polkit-1`, `system-auth` ve `system-session` doğrulandı. `pkexec --version` 126 verdi.

## Yapılanlar

- Polkit host builder ortak D34 target identity ve devralınmış writer-lock guard'ını kullanacak şekilde güncellendi.
- Replay runner'da Polkit ve D34 PAM config adımları için açık package/script eşleşmeleri eklendi.
- Ownership reconciler, Polkit'in GLib, Duktape ve PAM policy adımlarından sonra supplemental olarak eklenmesini tanıyor.
- Candidate'daki `pkg-config --exists` komutu segfault etti; builder dependency kontrolü doğrulanmış `--modversion` sorgularına çevrildi.
- İlk Polkit denemesi `polkit-20260930T080228Z-59d3bf81` PAM policy dosyaları mevcut olmadığı için preflight aşamasında başarısız oldu. Başarısız run korundu ve ledger'a alınmadı.

## Kontroller ve sınırlar

28 hedefli D34 testi, `bash -n`, `py_compile` ve `git diff --check` geçti. Polkit upstream test suite'i ve checksum çalıştırılmadı. Bu sonuç yalnız NVMe D34 snapshot'ı içindir: aktif HDD `/mnt/lfs`, masaüstü kimlik doğrulama akışı, live ISO ve Ventoy değiştirilmedi. Kullanıcı oturumu içinden Polkit yetkilendirmesi henüz uçtan uca test edilmedi.
