# Kernel host session hazırlığı — 11 Ekim 2026

## Sonuç ve sınır

`scripts/infra-kernel-session.py` accepted Base → fresh overlay → current host-before → measured guest → single-use authorization teslimini bir internal context manager olarak bağlar. CLI yalnız salt okunur preflight yapar; launch/resume/path bayraklarını reddeder. Gerçek Base acceptance henüz bulunmadığı için actual CLI STOP/exit 1/stdout boş sonucunu verdi. Bu tur production session, root audit capture, SSH transfer, QEMU boot, kernel build veya Alp kurulumu çalıştırılmadı. Host reboot açıklaması bekleyen production koruması sürüyor; pending soru tekrarlanmadı.

Bu modül complete kernel controller değildir. Consumer bulunmadan teslim tamamlanmış olsa bile terminal sonuç FAIL olur. Consumer'ın job/input/source/guest-boot alanları eşleşen candidate evidence vermesi yalnız `PENDING_PRIVILEGED_POST` üretir; bunun içeriğini doğrulama, uzun guest komutlarını sürekli host telemetry ile çalıştırma, kernel Alp phase/install/installed ownership, artifact collection, signal-safe controller kapanışı, fresh root-after, boot ve nihai acceptance/checkpoint kapıları future complete controller'ın açık işidir. Session hiçbir PASS, kernel acceptance veya checkpoint yazmaz. Root production işi yalnız isolated Builder'da kalır; host root build/mount/chroot yok.

## Bağlanan kontroller

Dokuz scripts-kökü dependency'nin owner/type/canonical path/hardlink/write mode ve SHA değerleri, herhangi bir helper import edilmeden doğrulanır. Base parent helper tam stored acceptance, sealed Base/toolchain transaction ve gerçek ancestor byte kontrollerini yeniden hesaplar. Private controller lock preparing/live işi çoğaltmayı engeller. Yeni job nonce Base run'dan farklı olmalı; existing restore accepted Base'den fresh children oluştururken mevcut interrupted overlay çiftini korur. Closed fresh child SHA ve ancestor dizisi launch öncesinde tekrar denetlenir.

Eski historical root audit yeni launch yetkisi sayılmaz: mevcut boot için ayrı fresh root-before request/capture ve core execution guard kullanılır. Session/controller/helper/Base/raw input/source hashleri ve closed child pinleri launch öncesinde bağlanır. Offline QEMU yalnız bu internal API'den açılabilir; CLI açamaz. Accepted Base gerçekten yokken hiçbir restore/root capture/launch yapılmaz.

Core guest sync sonrası altı kernel helper ve pinned Linux kaynağı aktarılır. Guarded read-only SSH ölçümü distinct guest boot UUID, root-owned canonical regular helper/source bytes ve inputs değerlerini doğrular. Raw Base proof, parent capsule ve auth bounded transport içine alınır; existing gerçek codec root-owned exclusive attempt, auth-last ve completed-last kurallarını uygular. stdout completion ayrıca independently read committed receipt ve exact payload SHA ile karşılaştırılır. Ölçüm/delivery/consumer exception'da session kendi guest'ini kapatır, closed disk/repository ve immutable FAIL outcome kanıtını korur. Teslim receipt'i stage acceptance değildir.

Core Base canonical dosyaları, f8f64ce guest runner/test policy, accepted checkpointler ve Claude/alp.py değişmedi. Yeni rootscript ayrı SHA ile bağlanır; canonical input digest `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306` aynı.

## Doğrulama ortamı

Unprivileged Fedora host, branch `codex/infra-rebuild`, boot `473f996d-f872-4b90-8b7d-eda73cfdda70`. 12 odaklı test PASS. Gerçek küçük qcow2 checkpoint/child dosyaları, private lock ve gerçek authorization codec/exclusive filesystem delivery kullanıldı. Root identity/capture, actual accepted Base proof, VM launch/stop ve SSH explicit fixture mocks'tur; bunlar actual production başarı kanıtı değildir. Temporary fixture ağaçları temizlendi.

Negatif kapılar: lock collision/alias, host root/bypass, helper drift, same parent nonce, live controller, modified fresh child, unavailable root-before, wrong guest boot/helper/source, stdout/committed payload mismatch, interrupted delivery, consumer exception ve başka job/boot evidence. Missing consumer FAIL, valid-shaped consumer yalnız pending-post; acceptance/checkpoint hiç üretilmiyor. Bağımsız AI/Claude incelemesi yapılmadı.

Canonical `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v` full suite: 469 test, 2 skip, PASS (507,452 sn), exit 0 ve NUL byte yok. Python compilation ve whitespace kontrolü PASS. Docs checker aynı 31 tarihsel bulguyla exit 1; line numaraları dışında yeni bulgu yok, temiz docs acceptance iddia edilmez. İlk odaklı 11 test logu da korunur. Host sample bu hazırlığın gözlemidir; overall stability acceptance veya kesinti nedeni kanıtı değildir. Artifact cleanup yapılmadı; protected current/691e/Libxcrypt images ve tüm accepted checkpointler korunuyor.

## Kalan tek entegrasyon adımı

Bu session'ı kullanan complete kernel runner'ın guarded producer command → sürekli monitored build → Alp install/ownership → immutable collected artifacts → fresh host-after ve actual boot acceptance akışını bağla. Actual Base ve çözülmüş host kesinti koruması olmadan onu çalıştırma. Tam yeni GCC/Coreutils/Base, kernel, BLFS, Plasma GL/profiles, BIOS+UEFI ISO ve fresh complete repeat-byte verification halen açık.

## Ham kanıtlar

Runtime kökü `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/`. Final host örneği aynı boot içinde errors/faults 0, Tctl 63,375°C ve root/SSD/HDD available [18,834; 20,307; 16,719]% verdi; her volume yüzde 15 üstünde. Başlangıç probe Tctl 60,875°C/errors/faults 0. Bu iki örnek continuous production monitor acceptance değildir.

| Nesne | SHA256 |
|---|---|
| `scripts/infra-kernel-session.py` | `f4c46cbb9b0629b2f17b516ae6ee81e759a9242787410dbeda9b0cd5e70e5a1e` |
| `tests/test_infra_kernel_session.py` | `0553e2275cf0cc8d5aaf36a7ffd050d4c24b2a5c5b16fd18c7b7353d73dddd82` |
| `infra-full-tests-kernel-session-20261011.log` | `f1c491b4f872fa56b9486bb1f53a903f67b119bf2b34b27056c649b64c122df1` |
| `kernel-session-doc-check-20261011.log` | `1c7eebe4a73b719e50b7d762ccff748e854dd2b4fb2d6be9950ead90a97142aa` |
| `kernel-session-focused-final-20261011.log` | `0b46928d84069763616a55e73f03b4240374eddf1b767577eacbafc7e4abdd1d` |
| `kernel-session-focused-initial-20261011.log` | `b90ab39c3d18f8d34c4afbfaba05213cd52788e11bbf1a15370a9b9c533d27b1` |
| `kernel-session-preparation-probe-20261011.json` | `f6e89092b35dea0d9025094a1182c89042db55156ac614247dd715e3a823b3db` |
| `kernel-session-validation-summary-20261011.json` | `b127a27590f89dff37fb2d633ea6d42ff2a9957ebddad8b36ea336dddd9aa663` |
