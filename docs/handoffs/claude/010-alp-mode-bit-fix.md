# Claude devir belgesi 010 — `alp`'te executable-mod kaybı düzeltildi

Görev ID / durum: (Backlog dışı, Codex'in M2 çalışmasında bulduğu bug) tamamlandı.

Çalışılan host: Windows (kod/test). Dal: `claude/desktop-bootstrap`.

## Ne oldu

Codex, M2 sprintinde gerçek LFS chroot'unda `alp install htop` denedi (Builder VM, `docs/WORKLOG.md` satır 15-18). `htop` recipe'i configure/make/DESTDIR install ile tamamlandı ama kurulan `/usr/bin/htop` ELF dosyasının modu `0644` çıktı — çalıştırılamadı. Codex, motor dosyasının Claude sahipliğinde olduğunu doğru şekilde tespit edip kodu değiştirmeden bulguyu `WORKLOG.md`'ye kaydetti ve gerçek rootfs'ye `alp` recipe paketi kurmayı bu düzeltme gelene kadar durdurdu.

## Kök neden

`alp.py`'deki `_copy_entry()` düzenli dosyalar için `shutil.copyfile(src, dst)` kullanıyordu. `shutil.copyfile` yalnızca dosya **içeriğini** kopyalar, izin bitlerini kopyalamaz (Python stdlib dokümantasyonunda açıkça belirtilir — izin için `shutil.copymode`/`copystat`/`copy`/`copy2` gerekir). Staged DESTDIR'daki `htop` dosyası `0755` idi ama hedefe kopyalanınca `umask`'a bağlı varsayılan mod (`0644`) ile oluştu.

## Düzeltme

`_copy_entry()`'nin düzenli-dosya dalına `shutil.copymode(src, dst)` eklendi (kopyadan hemen sonra):

```python
else:
    shutil.copyfile(src, dst)
    shutil.copymode(src, dst)
```

Bu fonksiyon `_merge_destdir` (recipe kurulumu) ve `_config_aware_merge`'deki (recipe upgrade) tüm kopyalama yolları tarafından zaten ortak kullanıldığı için tek noktadan düzeltme her iki akışı da kapsıyor.

## Test

Yeni regresyon testi `test_copy_entry_preserves_executable_mode` eklendi (`tests/test_alp.py`): `0o755` modlu sahte bir ELF dosyası kopyalanıp hedefte hem `os.access(X_OK)` hem tam mod (`0o755`) doğrulanıyor. Windows'ta gerçek POSIX izin bitleri desteklenmediği için (`chmod` orada anlamlı bir ayrım yapmıyor) `_posix_mode_bits_supported()` probe'u ile bu ortamda otomatik `skip` ediliyor — sembolik link testleriyle aynı desen.

Yerel sonuç: `test_alp.py` **63 geçti + 3 atlandı** (yeni mod testi dahil, hepsi Windows kısıtı).

**Çalıştırılmadı:** gerçek Linux/LFS chroot üzerinde uçtan uca doğrulama (htop'un gerçekten `0755` ile kurulup çalıştığı) — bu turda SSH erişimi kullanılmadı. Codex'in bir sonraki `alp` denemesinde veya benim SSH ile tekrar test etmemde doğrulanmalı.

## Entegrasyon için gereken

Codex'e haber: `alp.py` düzeltildi, `htop` recipe'i artık executable modunu koruyor olmalı; gerçek rootfs'ye recipe kurulumunu tekrar denemeden önce Builder VM'de yeniden doğrulama önerilir.

## Sonraki eylem

Yok (kullanıcı isterse gerçek SSH doğrulaması yapılabilir).
