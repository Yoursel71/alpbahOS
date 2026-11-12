# APPS-02: BLFS 13.1 general/7zip.html (Ark's 7z support); installed into the stage with the book's wrapper scripts.
set -e
sed -i 's/-Werror //g' CPP/7zip/7zip_gcc.mak
for i in Bundles/Alone Bundles/Alone7z Bundles/Format7zF Bundles/SFXCon UI/Console; do
    make -C CPP/7zip/$i -f ../../cmpl_gcc.mak || exit 1
done
install -vDm755 CPP/7zip/Bundles/Alone/b/g/7za CPP/7zip/Bundles/Alone7z/b/g/7zr CPP/7zip/Bundles/Format7zF/b/g/7z.so \
    CPP/7zip/UI/Console/b/g/7z -t "$STAGE/usr/lib/7zip/"
install -vm755 CPP/7zip/Bundles/SFXCon/b/g/7zCon "$STAGE/usr/lib/7zip/7zCon.sfx"
install -d "$STAGE/usr/bin"
for i in 7z 7za 7zr; do
    printf '#!/bin/sh\nexec /usr/lib/7zip/%s "$@"\n' "$i" > "$STAGE/usr/bin/$i"
    chmod 755 "$STAGE/usr/bin/$i"
done
