# Claude devir belgesi 008 — `alp`'e Seviye 1 bağımlılık ön kontrolü

Görev ID / durum: (Backlog dışı, kullanıcı talebi — "bağımlılık çözümü ne kadar sürer" sorusuna verdiğim 3 seviyeli cevaptan "Seviye 1"i uygulamak, "tamam yap" onayıyla) tamamlandı.

Çalışılan host: Windows (kod/test) + `alpbah-builder` Ubuntu VM (SSH, gerçek doğrulama). Dal: `claude/desktop-bootstrap`.

## Neyin yapıldığı, neyin yapılmadığı

**Yapıldı — Seviye 1 (ön kontrol):** Tariflere isteğe bağlı `requires_commands`/`requires_libraries` alanları eklendi. `install_recipe`/`upgrade_recipe`, herhangi bir ağ isteği veya build adımından ÖNCE bu alanları kontrol ediyor (`_check_recipe_requirements`/`_require_recipe_dependencies`): `requires_commands` → `shutil.which`; `requires_libraries` → `pkg-config --exists`. Eksik varsa net bir Türkçe hatayla, **hiçbir indirme/derleme denemeden** durur.

**Yapılmadı — Seviye 2/3 (kullanıcıya açıkça anlatıldı, istenmedi):** `alp`'in kendi kataloğu içinde otomatik zincirleme kurulum (Seviye 2) veya pacman/apt/dnf seviyesi sürüm kısıtı/çakışma çözücü (Seviye 3) — bunlar bilerek yapılmadı, MASTER_PLAN'ın "sıfırdan bağımlılık çözücü yazma" yasağıyla ve `alp`'in "basit kalsın" felsefesiyle tutarlı.

## Gerçek doğrulama (SSH, `alpbah-builder` VM)

- `bc` (`requires_commands: ["ed"]`, `ed` bu sistemde yok): `install` çağrısı **0.1 saniyede**, hiç ağa çıkmadan, doğru mesajla durdu. Önceden (bu düzeltmeden önce) aynı hata yalnızca gerçek bir indirme+extract+configure+make döngüsünden SONRA ortaya çıkıyordu.
- `htop` (`requires_libraries: ["ncursesw"]`): Bu VM'de `pkg-config`'in kendisi kurulu olmadığı ortaya çıktı (`which pkg-config` boş döndü) — bu durumda kontrol "temkinli" davranıp her kütüphaneyi "eksik" olarak işaretliyor (belgelenmiş, kasıtlı davranış: yanlış "var" asla söylemez, ama `pkg-config` yokken "ncursesw kesin eksik" ile "kontrol edilemedi" ayrımını yapamaz). Yine de doğru sonuca (kurulumu durdurmak) ulaştı, 0.1 saniyede.
- 3 tarif (`htop`, `bc`, `less`) `requires_commands`/`requires_libraries` alanlarıyla güncellendi, gerçek keşfedilen eksiklikleri (sırasıyla `ncursesw`, `ed`, `ncursesw`) yansıtıyor.

## Yerel test seti

10 yeni test eklendi (`_check_recipe_requirements`, `_require_recipe_dependencies`, ve `install_recipe`'in ağa hiç çıkmadan preflight'ta durduğunu doğrulayan uçtan uca bir test — `mock.patch.object(alp, "fetch")` ile `fetch_mock.assert_not_called()`). Toplam: `test_alp.py` 53 geçti + 2 atlandı (Windows symlink izni yok), `test_packagekit_backend.py` 7 geçti (ayrı çalıştırıldığında; birleşik çalıştırmada bilinen Windows subprocess kararsızlığı — zaten belgeli).

## Bilinen sınır (dürüstçe)

- `requires_libraries` kontrolü `pkg-config`'e bağımlı; `pkg-config` kurulu değilse (bu VM'de öyle) her kütüphane "eksik" sayılır — yanlış negatif riski var (aslında kurulu bir kütüphane, `.pc` dosyası yoksa "eksik" görünebilir), ama yanlış pozitif riski yok (asla "var" demediği bir şeyi doğrulamaz).
- Bu hâlâ gerçek bağımlılık çözümü değil — yalnızca "denemeden önce söyle" katmanı. `alp install libfoo-kullanan-paket` hâlâ `libfoo`'yu otomatik kurmuyor, yalnızca eksik olduğunu erkenden bildiriyor.

## Entegrasyon için gereken

Codex'in gerçek BLFS ortamında `pkg-config`'in kurulu olması, `requires_libraries` kontrolünün gerçek anlamda ayırt edici olabilmesi için önemli (şu an test edilen VM'de değildi).

Sonraki eylem: Yok — kullanıcı isteği tamamlandı.
