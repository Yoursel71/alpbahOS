# Kısayol çakışma listesi — UI-02

Durum: **taslak**, gerçek Plasma oturumunda çalıştırılmadı. Kaynak: [`shortcuts.json`](shortcuts.json), [docs/MASTER_PLAN.md](../../docs/MASTER_PLAN.md) §6, [docs/HYPERV_PLAN.md](../../docs/HYPERV_PLAN.md).

## 1. İç tutarlılık kontrolü

`shortcuts.json` içindeki 16 satırın birincil tuş kombinasyonları karşılaştırıldı: **çakışma yok**, her kombinasyon tek bir satıra ait. (Elle kontrol edildi; gerçek bir `kglobalaccel` kayıt denetimi değildir.)

## 2. Bilinen KWin/Plasma varsayılanlarıyla olası çakışma

| Kısayol | Risk | Not |
|---|---|---|
| Alt+Tab / Alt+Shift+Tab | Düşük | Zaten stok varsayılan (`Walk Through Windows`). |
| Win+D | Düşük–Orta | Bazı Plasma sürümlerinde varsayılan farklı (`Ctrl+F12`) olabilir; Meta+D boşsa sorun yok, doluysa üzerine yazma onayı gerekir. |
| Win+E | Düşük | Özel binding; stokta karşılığı yok. |
| Win+L | Orta | Stok varsayılan genelde `Ctrl+Alt+L`'dir; Meta+L'e **taşıma** gerekiyor — eski binding'in silinip silinmeyeceği açık karar (ikisi birden de kalabilir). |
| Win+R | Düşük | KRunner'ın mevcut `Alt+F2`/`Alt+Space` kısayolu **korunur**, Win+R ek/ikinci binding olarak eklenir; ikinci bir eylemin aynı işlevi çağırması yeniden test edilmeli. |
| Win (tek başına) | **Orta-Yüksek** | "Modifier-only shortcut" davranışı dağıtım/sürüme göre çok değişir; bazı spin'ler bare-Meta'yı zaten başka bir eyleme (ör. Overview) bağlamış olabilir. En riskli satır. |
| Win+I | Düşük | Stokta karşılığı yok, özel binding. |
| Win+Left / Win+Right | Düşük | Bunlar zaten KWin'in **Quick Tile** varsayılanıdır (`Meta+Left/Right`) — muhtemelen ek işlem gerekmez, yalnız doğrulama. |
| Win+Up | Düşük | `Maximize Window` genelde `Meta+Up` varsayılanı. |
| Win+Down | **Orta** | KWin'de "büyütülmüşse geri yükle" davranışı var ama Windows'taki "ikinci basışta küçült" sıralı davranışı **yerleşik değil**; istenirse khotkeys/kwinscript ile taklit gerekir — kapsam dışı bırakılabilir, açık karar. |
| Win+Tab | **Yüksek** | Plasma 5.24+ Overview efektinin varsayılanı `Meta+W`'dir, `Meta+Tab` değil. Bazı dağıtım spin'leri `Meta+Tab`'ı zaten "Present Windows (alternatif)" gibi bir eyleme bağlamış olabilir — aktif doğrulama ve olası üzerine yazma onayı gerekir. |
| Alt+F4 | Yok | Stok varsayılan, değişmiyor. |
| Ctrl+Shift+Esc | Yok | Plasma'da stok karşılığı yok (Windows'a özgü), eklemek serbest. |
| Win+Shift+S | Düşük | Yeni Spectacle sürümlerinde bölgesel yakalama zaten bu tuşa atanmış olabilir — çakışma değil, olası **çakışan aynı davranış** (zararsız, doğrulanmalı). |
| Ctrl+C/V/X/Z | Yok | Sistem kısayolu değil, uygulama katmanı; terminal istisnası `profiles/shell/README.md`'de. |

## 3. VM/Windows host seviyesinde yakalama riski

Bu proje Hyper-V üzerinde geliştiriliyor ve builder/test VM'leri **aynı Windows host'ta** çalışıyor. Bu, geliştirme sırasında ekstra bir katman çakışma yaratır:

- **Hyper-V Basic Session** (klasik `vmconnect.exe` penceresi): `Win+L`, `Win+D`, `Win+Tab` gibi kombinasyonların çoğu **host Windows tarafından yakalanır**, VM'e hiç ulaşmaz — `Win+L` host oturumunu kilitler, `Win+D` host masaüstünü gösterir.
- **Enhanced Session Mode** (RDP tabanlı): daha fazla kombinasyon guest'e geçebilir ama garanti değildir; `Win+L` güvenlik nedeniyle neredeyse her zaman host tarafından yakalanır.
- **Sonuç:** alpbahOS'un kendi `Win+L`/`Win+D`/`Win+Tab` kısayolları, Hyper-V üzerinden geliştirme döngüsünde **güvenilir şekilde test edilemez**. Gerçek doğrulama ya (a) çıplak donanımda, ya (b) Win tuşunu host'a kaptırmayan bir erişim yöntemiyle (VNC/SPICE konsolu gibi), ya da (c) BETA-01 gerçek donanım aşamasına ertelenerek yapılabilir.
- Bu not, MASTER_PLAN §6'daki *"VM hostunun yakaladığı Win kısayolları ile misafir sistemin davranışı ayrı kaydedilir"* cümlesinin somutlaştırılmasıdır — yeni bir karar değil, mevcut uyarının test planına çevrilmesidir.

## 4. Açık kararlar

1. Win+L'de eski `Ctrl+Alt+L` binding'i silinsin mi, yoksa ikisi de mi aktif kalsın?
2. Win+Down "ikinci basışta küçült" davranışı hedef kapsamda mı, yoksa yalnızca "geri yükle" mi yeterli?
3. Bare-Meta (`Win` tek başına) davranışı için seçilecek Plasma sürümünde gerçek varsayılan ne — bu doğrulanmadan üzerine yazma güvenli değil.

## Sonraki adım

Gerçek doğrulama, Codex'in M07/M08'i tamamlayıp çalışan bir Plasma oturumu (tercihen çıplak donanım veya VNC/SPICE erişimli bir VM) kurmasını bekliyor. O zamana kadar bu liste "taslak" kalır.
