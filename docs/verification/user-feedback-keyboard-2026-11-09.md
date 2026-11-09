# Kullanıcı geri bildirimi — klavye ve indirme yöneticisi (9 Kasım 2026)

Kullanıcı 0.9 Beta canlı ISO'yu gerçek bilgisayarında denedi. Klavye düzeninin yanlış olduğunu, ayrıca Türkçe Q/F klavye düzeninin otomatik algılanmasını istediğini bildirdi. Hangi tuşların yanlış çıktığı ve kullanılan fiziksel düzen henüz belirtilmedi.

İncelenen beta kayıtlarında sanal konsol `KEYMAP=trq` olarak doğrulanmış; grafik oturumu için X11 düzeni ayarsız görülmüş ve SDDM'de `us` gösterilmişti (`iso-beta-0.9-2026-11-09.md`, bölüm 10.6). Bu kayıtlar kullanıcının cihazındaki hatanın kesin nedenini tek başına kanıtlamaz. Canlı oturum, giriş ekranı ve kurulu oturumda gerçek yazılan karakterler ile kurulumda seçilen düzenin korunması ayrıca doğrulanmalı.

Türkçe Q ve F fiziksel tuş baskısı her klavyeden güvenilir biçimde okunamayabilir. Otomatik algılama tasarlanırken, cihazın bildirdiği bilgi yeterli değilse kullanıcıya tuşla doğrulama ve elle seçim olanağı sunulmalı; belirsiz sonuç kesinmiş gibi uygulanmamalı.

Kullanıcı ayrıca indirme yöneticisini beğenmediğini söyledi. Hangi uygulama ve hangi davranış veya görünümün değiştirilmesi gerektiği henüz netleşmedi.

Bu geri bildirim için yeni ISO tamamlanmadı. Başlatılan ayrı deneme derlemesi kullanıcı isteği üzerine durduruldu; deneme kodu geri alındı.
