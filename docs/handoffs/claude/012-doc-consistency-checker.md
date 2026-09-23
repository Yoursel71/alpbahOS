# Claude devir belgesi 012: belge tutarlılık denetçisi

**Görev ID / durum:** Backlog dışı. Kullanıcı isteği ("belgeler ilerlemeye yetişemiyor, nasıl çözeriz" → "yaz"). Tamamlandı.

**Host / dal:** Windows. Dal: `claude/desktop-bootstrap`.

**Değişen dosya:** `docs/handoffs/claude/tools/check_docs.py` (yeni, yalnız standart kütüphane). `scripts/` Codex'in sahipliğinde olduğu için araç Claude'un kendi alanında duruyor; oraya taşınması entegratörün kararı.

## Ne yapıyor

| Kural | Denetim |
|---|---|
| `stale-term` | Yaşayan belgelerde (AGENTS, CLAUDE, CURRENT, README, MASTER_PLAN, DECISIONS, BACKLOG, HYPERV_PLAN, CLAUDE_START, M2 manifesti) geçersiz kararlara ait ifadeler: 13.1 (D33), pacman/libalpm/Discover (D31), multilib/32-bit (D32). Tarihsel ya da iptal bağlamındaki satırlar sayılmaz. WORKLOG ve devir belgeleri tarih sıralı kayıt olduğu için muaf. |
| `commit-ref` | Backtick içindeki commit/blob hash'leri depoda gerçekten var mı. `alpbahOS-alp` reposuna ait satırlar atlanır. |
| `broken-link` | Göreli Markdown bağlantılarının hedef dosyası var mı. |
| `decision-ref` | Geçen D/P kimlikleri DECISIONS.md'de tanımlı mı. |

Bir satırı bilinçli olarak muaf tutmak için satıra `<!-- doccheck: ok -->` eklenir. Çıkış kodu: bulgu yoksa 0, varsa 1, ortam hatasında 2.

## Doğrulama

- **`C:\alpbahOS` (main):** 19 `stale-term` bulgusu çıktı. `commit-ref`, `broken-link` ve `decision-ref` için bulgu yok. Gerçek bulgulara örnekler:
  - README.md:23 hâlâ "Steam/Wine için 32-bit planlanır" diyor (D32 ile çelişiyor).
  - DECISIONS.md:107–109'daki kaynak bağlantıları 13.1'e gidiyor.
  - HYPERV_PLAN.md:42 hâlâ "multilib manifestlerini sabitle" diyor.
  - MASTER_PLAN.md'nin §4/§5 bölümlerinde pacman ve Discover satırları var.
- **Ayarlama sırasında giderilen yanlış alarmlar:**
  - WORKLOG'daki `2077d1a` bir blob hash'i; commit değil (`a82f872:…/alp.py` için doğru).
  - `f591c97` ve `812cb04` `alpbahOS-alp` reposunun commit'leri.
- **`C:\alpbahOS-claude` dalında:** `decision-ref` D31 ve P13'ü "tanımsız" buldu. Bu gerçek bir kayma: D31–D33 doğrudan main'e yazıldı, bu dalın DECISIONS.md'si eski.
- Git deposu olmayan bir dizinde çıkış kodu 2 döndü.
- **Çalıştırılmadı:** commit öncesi (pre-commit) hook entegrasyonu. Hook kurmak, iki ajanın ortak git yapılandırmasını değiştirir; entegratörün kararı.

## Entegrasyon için gereken (Codex)

1. main'deki 19 `stale-term` bulgusunu düzelt; betik 0 bulgu verene kadar devam et.
2. `AGENTS.md`'ye oturum kapanış kuralını ekle:
   - her oturum sonunda `python docs/handoffs/claude/tools/check_docs.py` çalıştır;
   - bulgu varsa düzelt ya da gerekçeyle `doccheck: ok` işaretle;
   - durum yalnız `CURRENT.md`'de, kararlar yalnız `DECISIONS.md`'de tutulur, diğer belgeler bunlara referans verir.
3. İstenirse aracı `scripts/`'e taşı ve pre-commit hook yap.

**Sonraki eylem:** Yok. Kullanıcı isterse `stale-term` kurallarına yeni kararlar eklenir.
