# APPS-02: BLFS 13.1 general/poppler.html, the poppler-data part (CJK and other encoding data).
set -e
make prefix=/usr DESTDIR="$STAGE" install
