# alpbahOS oturum hazırlığı -- kurulum hedefi: /etc/xdg/plasma-workspace/env/alpbahos-oturum.sh
# startplasma bu dosyayı KWin/kglobalacceld başlamadan önce /bin/sh ile kaynaklar
# (plasma-workspace v6.4.4 startplasma.cpp runEnvironmentScripts). Kaynaklama çıktısı
# ortam değişkeni olarak okunduğu için stdout'a hiçbir şey yazılmaz; exit ve set -e kullanılmaz.
# Ayrıntı ve günlük: alpbah-oturum-hazirla --help, ~/.config/alpbahos/oturum-hazirla.log
if command -v alpbah-oturum-hazirla >/dev/null 2>&1; then
    alpbah-oturum-hazirla >/dev/null 2>&1 || :
fi
