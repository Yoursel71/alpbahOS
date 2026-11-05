# T3 §4.3 madde 4 — alp paket adı tamamlama (5 Kasım 2026)

Kaynak: `profiles/shell/zshrc.alpbah` (`_alp`, `_alp_index_names`). Katalog: `ALP_INDEX` ortam değişkeni, yoksa `/usr/share/alp/index.json`. Yalnız yerel dosyayı okur; root ve ağ gerekmez.

## Test (chroot pty, uid 1000 `alpbah`, `/mnt/lfs`)

Betik: `scripts/lfs-blfs/tests/alp_completion_pty_test.py`. Enter'a basılmaz; tampon `zle` widget'ı ile dosyaya yazılır.

| Girdi | Tab sonrası tampon | Sonuç |
|---|---|---|
| `alp inst<TAB>` | `alp install ` | GEÇTİ (alt komut) |
| `alp install ht<TAB>` | `alp install htop` | GEÇTİ (paket adı) |

Kurulum tetiklenmedi; `htop` kurulu değil. Test imajına katalog `index.json` kopyalandı (yalnız ad listesi için).

## Sınır

- VM'de test edilmedi (bu test chroot pty'de).
- Kurulu sistemde katalog konumu `/usr/share/alp/index.json` bir sözleşmedir; alp'ın kendisi `--index` gerektirir ve varsayılan vermez. Katalog kurulum yolu build planında henüz sabitlenmedi.
