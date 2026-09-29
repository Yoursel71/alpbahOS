# Claude devir belgesi 020: mantık ve performans denetimi — 8 düzeltme, kalan bulgular

```text
Görev ID / durum: Kullanıcı isteği (29 Eylül 2026): "mantık ve audit fix yap, bana sorular sor". Önce yalnız rapor verildi; kullanıcı A) betik cleanup, B) alp rollback + commit penceresi, C) alp mantık ve doğrulanmış küçük maddeler için düzeltme, SELinux testlerine dokunmama ve "yeni dal + fix başına commit" dedi. Performans (O(N²)) bilerek kapsam dışı bırakıldı. 8 düzeltme yapıldı (8 commit), hepsi kendi regresyon testiyle.
Çalışılan host ve branch/commit: Fedora 44, Python 3.14.7, pytest 8.4.2. Dal `claude/logic-audit-020`, taban `claude/alp-prefix-metadata` 0d4cb66. Push yapılmadı.
Dosya sınırı: `docs/handoffs/claude/alp-prototype/**`, `scripts/patch-m2-gen2-*.sh` (Codex alanı; kullanıcı açıkça istedi), `profiles/perf/analyze_kwin_perf_csv.py`, yeni testler, README, WORKLOG, bu belge.
Değişen dosyalar: aşağıda §2. `alp.py` yeni SHA-256 `7e566ef487a17e51ac9875e46e78b61f999a3a73ddd54eb665b2dffc808b65ba`; `alp_packagekit_backend.py` `b851d9034b1d014f2e1a1fefaece977dbacecafba87ea2948f3b19b93d4bb23c`.
Çalıştırılan doğrulama ve sonuç: alp paketi 265 geçti (önceden 238); kök `tests/` 147 geçti, 2 atlandı, 13 düştü (M04 transaction testleri, Fedora `security.selinux` xattr'ı; değişiklikten önce de aynıydı, kapsam dışı). shellcheck ve `bash -n` temiz. Python 3.10/3.12 yerelde yok; CI matrisi çalıştırılmadı.
Sonraki eylem: Codex `scripts/patch-m2-gen2-*.sh` cleanup değişikliğini inceler (imajda hiç çalıştırılmadı); entegratör `alp.py`'yi kullanacaksa yeni SHA-256'yı rootfs pin'ine (§5) yansıtır.
```

## 1. Nasıl çalışıldı

Salt okunur tarama: `alp.py` (2868 satır) tam okundu; `scripts/` ve `profiles/` Python/shell dosyaları okundu, `ruff` ve `shellcheck` koşturuldu, şüpheli her bulgu ayrı bir yeniden üretim betiğiyle sınandı (kanıtsız bulgu raporlanmadı). Ardından kullanıcı seçimiyle düzeltildi. Her düzeltme için **önce** eski kodda düşen test yazıldı, sonra düzeltme.

## 2. Düzeltilen hatalar

| # | Hata | Kanıt (yeniden üretim) | Commit / test |
|---|---|---|---|
| 1 | **6 betik `umount` başarısız olsa da `rm -rf "$WORK"` yapıyor.** `patch-m2-gen2-{autoseat,dbus-and-dri,dns-and-admin,efi,login-and-alp,root-partuuid}.sh` EXIT tuzağı, "target is busy" sonrası bağlı misafir dosya sisteminin içeriğini siliyordu. | `unshare -Urm` içinde tmpfs + meşgul umount → `rm -rf` sonrası içerik boş. Testte stub `umount` ile eski kodda misafir dosyası siliniyor. | `9bcccc9` · `tests/test_patch_script_cleanup.py` (5) |
| 2 | **Dosya/symlink dizine dönüşürse rollback yanlış ve "başarılı".** `FileJournal._seen`, `will_remove` sonrası `will_mkdir` kaydını düşürüyordu; undo yeni dizini silmiyor, `os.replace(yedek, dizin)` EISDIR verince `shutil.copy2` yedeği dizinin **içine** koyup "geri alındı" diyordu (`usr/x` dizin, `x/1` eski içerik, journal silinmiş). Symlink'te hata gürültülüydü. | `_transaction` içinde `_merge_staged` + zorlanmış hata (testte). | `335e791` · `tests/test_rollback_type_change.py` (3) |
| 3 | **`save_db` ile `commit` işareti arasında ölen işlem recover'da tutarsız.** `recover` dosyaları siliyor, `db.json` paketi listelemeye devam ediyordu (`alp list` gösterir, `alp check` "sorun yok", `install` "zaten kurulu"). Kaldırmada tersi. Commit yazımında ENOSPC de aynı sonucu veriyordu. | `commit` içinde `os._exit(9)` ile gerçek süreç ölümü; düzeltme sonrası aynı deneme: recover "işlem tamamlanmıştı", list/check/install tutarlı. | `d823619` · `tests/test_recover_commit_window.py` (7) |
| 4 | **`_drop_kept_back` korumalı taban bağımlılığını görmüyordu.** Katalogda `lfs-base` paketle aynı adlı giriş varsa ve başka paket ona sürüm kısıtı koyuyorsa, tüm `alp upgrade` reddediliyordu. | `_drop_kept_back` → `accepted=[app,other] kept=[]` → `_plan_or_refuse` reddi. | `964d858` · `tests/test_upgrade_kept_back.py` (2) |
| 5 | **Arama Türkçe `I`/`ı`'yı ayırıyordu.** `_fold("IŞIK")="işik"`, `_fold("ışık")="ışık"`. | Doğrudan `_fold` çağrısı. | `a29dc81` · `tests/test_search_turkish_fold.py` (3) |
| 6 | **Hata yolları traceback; salt okunur komutlar durum dizini yaratıyordu; mağaza araması bozuk index'te sessizce boş dönüyordu.** `main()` `OSError`/`JSONDecodeError` yakalamıyordu; `list`/`info`/`check` `paths.ensure()` çağırıyordu; `alp_search` "çıkış 1 + boş stdout"u "eşleşme yok" sayıyordu. | Eksik/bozuk index, salt okunur kök; `alp_search(..., NOPE.json)` → `[]`. | `f88c7ac` · `tests/test_cli_errors.py` (9) |
| 7 | `protect/unprotect --dry-run` yapılmamış değişikliği "işaretlendi" diye yazıyordu. | `--dry-run protect foo`. | `3527fae` · `tests/test_protect_dry_run.py` (3) |
| 8 | `analyze_kwin_perf_csv.py`, artmayan pageflip damgasında `StatisticsError` ile çöküyordu. | İki satırlık aynı damgalı CSV. | `4d82f7e` · `tests/test_perf_csv_degenerate.py` (3) |

Ek (3'ün parçası): `alp check` artık kayıtlı ama diskte olmayan dosya/symlink'leri `SORUN` olarak bildiriyor; önceden yalnız bağımlılık tutarlılığına bakıyordu.

**Journal uyumu:** yeni `["db", ad, parmak_izi]` girdisi eski `undo_journal`'da bir daldan geçmez, sessizce atlanır; `db` girdisi olmayan eski journal'lar eski davranışla (commit işareti yoksa geri al) çalışır. Parmak izi yalnız `name/version/method/installed_at/files/symlinks` alanlarından hesaplanır; sonradan `alp protect` kaydı değiştirse recover kararı bozulmaz (testli).

## 3. Düzeltilmeyenler (bilerek) ve açık kararlar

- **O(N²) doğrulayıcılar (kullanıcı kapsam dışı bıraktı).** `scripts/validate-rootfs-ownership-ledger.py` `validate_ledger` içindeki `seen_paths` döngüsü: 5k girdi 1,65 s, 10k 6,6 s, 20k 26,5 s. `scripts/reconcile-m04-final-owners.py` `_reject_overlapping_non_directories` (20k girdi 9,65 s/çağrı; snapshot modunda ~237 çağrı) ve `_reject_overlapping_owned_paths` (40k yol 18 s). Repodaki 40 manifestte toplam 15,8k girdi var (79 paketin yaklaşık yarısı); ledger ≈16 s (şimdilik tolere), reconcile snapshot modu ≈24 dk tahmini, 40k girdide saatler. **Tahmindir, gerçek zincirle çalıştırılmadı.** Çözüm önerisi: `sorted` + `bisect` ya da ata kümesi (O(N log N)); `tests/test_rootfs_ownership_ledger.py` `"overlapping owned paths"` mesajını doğruluyor, mesaj korunmalı.
- **`capture-m04-install-event.py` strace izini 3 kez `read_text().splitlines()` ile belleğe alıyor** (Builder RAM 3–6 GiB). Ölçülmedi.
- **M04 transaction testleri Fedora'da düşüyor** (`security.selinux` xattr'ı, `_require_no_xattrs` sıkı). Kullanıcı: dokunma. Hedef sistem SELinux'suz LFS. Kök `tests/` CI'da hiç çalışmıyor (workflow yalnız `alp-prototype`).
- **Kod okumasıyla bulunan, çalıştırılmamış küçükler (kullanıcı "yalnız doğrulananları düzelt" dedi):** `install-desktop-profile.sh --dry-run --manifest` manifesti yine yazıyor; `apply-m2-rootfs-fixes.sh` alp hash uyuşmazlığını rootfs'e dokunduktan sonra denetliyor (önden yapılmalı; yedek dosya adı da eski değil yeni hash'i taşıyor); `patch-m2-gen2-efi.sh` yorumu "read-only" diyor ama rw bağlıyor; `patch-m2-gen2-login-and-alp.sh` `stat %U:%G` ile host NSS adı kullanıyor (sayısal `%u:%g` daha güvenli); `zshrc.alpbah` `compinit` önbelleksiz (taslak).
- **Hata değil (incelendi):** `vercmp("1.0","1.0.0") == -1` docstring'de tanımlı, rpm/pacman de böyle. `alp` db yükleme/kaydetme (120k girdi, 5 MB, 0,03 s) ve `_preflight_merge` (20k girdi 0,56 s) sorun değil.

## 4. Çalışma ağacı olayı (dikkat)

Oturum sırasında 10:51:57'de **ben yapmadan** ortak çalışma ağacı `claude/logic-audit-020`'den `claude/m08-live-fixes` dalına alındı (başka bir Claude oturumu; M08 VM testi çalışıyordu). O sırada commit'lenmemiş B2 değişikliklerim başkasının dalında kaldı. Onları oraya commit etmedim; yamayı alıp ayrı bir `git worktree`'ye taşıdım ve ortak ağaçtaki kendi değişikliklerimi geri aldım (`claude/m08-live-fixes` dalına ve o oturumun dosyalarına dokunulmadı). Bu belgedeki tüm commit'ler `claude/logic-audit-020` dalında, worktree'de yapıldı. **Aynı dizinde iki ajan çalışmamalı** (`AGENTS.md` "İki ajanla çalışma"); `docs/AGENT_STANDING_RULES.md` §2.13'e uygun olarak bu dal, o oturum işini bitirmeden ortak ağaçta `checkout` edilmemeli.

## 5. Entegrasyon için

- `docs/handoffs/claude/alp-prototype/alp.py` SHA-256 artık `7e566ef4…` (yukarıda tam). Rootfs'teki `alp.py` (`0475ea32…`, `EXPECTED_ALP` `7b2998a5…` pinleri) bu değişikliklerden etkilenmedi; yeni motor rootfs'e kurulacaksa Claude'un testleriyle birlikte koşturulup pin devir belgesinde güncellenmeli (`AGENT_STANDING_RULES.md` §3).
- `scripts/patch-m2-gen2-*.sh` Codex alanı. Değişiklik yalnız `cleanup()`; imaj yamalama mantığına dokunulmadı. **Gerçek `nbd`/Gen2 imajında çalıştırılmadı**; betiklerde `qemu-nbd --disconnect` artık yalnız umount başarılıysa çalışır, başarısızlıkta `nbd0` bağlı kalır ve betik `CLEANUP FAILED` ile çıkar (elle: umount + `qemu-nbd --disconnect /dev/nbd0`).

## 6. Çalıştırılmadı

Builder, Gen2 VM, gerçek PackageKit/Discover, gerçek `nbd` imajı, elektrik kesintisi (yalnız süreç ölümü `os._exit` ile denendi), Python 3.10/3.12 (CI matrisi), O(N²) düzeltmesi.
