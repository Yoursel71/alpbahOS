# Kullanıcı geri bildirimi — klavye ve indirme yöneticisi (9 Kasım 2026)

Kullanıcı 0.9 Beta canlı ISO'yu gerçek bilgisayarında denedi. Klavye düzeninin yanlış olduğunu, ayrıca Türkçe Q/F klavye düzeninin otomatik algılanmasını istediğini bildirdi. Hangi tuşların yanlış çıktığı ve kullanılan fiziksel düzen henüz belirtilmedi.

İncelenen beta kayıtlarında sanal konsol `KEYMAP=trq` olarak doğrulanmış; grafik oturumu için X11 düzeni ayarsız görülmüş ve SDDM'de `us` gösterilmişti (`iso-beta-0.9-2026-11-09.md`, bölüm 10.6). Bu kayıtlar kullanıcının cihazındaki hatanın kesin nedenini tek başına kanıtlamaz. Canlı oturum, giriş ekranı ve kurulu oturumda gerçek yazılan karakterler ile kurulumda seçilen düzenin korunması ayrıca doğrulanmalı.

Türkçe Q ve F fiziksel tuş baskısı her klavyeden güvenilir biçimde okunamayabilir. Otomatik algılama tasarlanırken, cihazın bildirdiği bilgi yeterli değilse kullanıcıya tuşla doğrulama ve elle seçim olanağı sunulmalı; belirsiz sonuç kesinmiş gibi uygulanmamalı.

Kullanıcı ayrıca indirme yöneticisini beğenmediğini söyledi. Hangi uygulama ve hangi davranış veya görünümün değiştirilmesi gerektiği henüz netleşmedi.

Bu geri bildirim için yeni ISO tamamlanmadı. Başlatılan ayrı deneme derlemesi kullanıcı isteği üzerine durduruldu; deneme kodu geri alındı.

## Design note (round 13, not implemented): keyboard layout after the installer

Status: design only. Nothing in this section is built or tested. Round 13 made the installed system take the layout the installer wrote (`/etc/X11/xorg.conf.d/00-keyboard.conf` XkbLayout tr, vconsole KEYMAP trq was already there) and added the KDE default `/etc/xdg/kxkbrc` (LayoutList=tr, Use=true; record `alpbahos-keyboard` 0.9-r13).

Open questions for the user's real-PC test, before any automatic detection:
- The user types on a Turkish-Q keyboard. Turkish-Q and Turkish-F differ on the position of the `-`, `*` and `.` keys; a wrong choice shows up as a wrong character in the password or the terminal, not as a boot failure.
- Q/F auto detection idea: ask the user once at the first login (a short test line: "type these keys"), and write the answer to kxkbrc and 00-keyboard.conf. Option B: keep Turkish-Q as the only default and offer Turkish-F in System Settings. The brief's design choice is still the user's.
- Any detection must not change the layout while the user is typing a password (greeter first, then the session).
