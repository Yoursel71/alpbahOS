# PRINT-01: BLFS 13.1 pst/mupdf.html, library and mutool only (libcupsfilters needs libmupdf; no viewer: no X11/GLUT
# viewer, so freeglut is not needed); brotli is not in the image, so the bundled one is used.
set -e
cat > user.make << 'MK'
USE_SYSTEM_BROTLI := no
USE_SYSTEM_FREETYPE := yes
USE_SYSTEM_HARFBUZZ := yes
USE_SYSTEM_JBIG2DEC := no
USE_SYSTEM_JPEGXR := no
USE_SYSTEM_LCMS2 := no
USE_SYSTEM_LIBJPEG := yes
USE_SYSTEM_MUJS := no
USE_SYSTEM_OPENJPEG := yes
USE_SYSTEM_ZLIB := yes
USE_SYSTEM_CURL := yes
USE_SYSTEM_GUMBO := no
HAVE_X11 := no
HAVE_GLUT := no
MK
export XCFLAGS="-fPIC -march=x86-64 -mtune=generic"
make build=release shared=yes verbose=yes HAVE_X11=no HAVE_GLUT=no
make build=release prefix=/usr shared=yes HAVE_X11=no HAVE_GLUT=no DESTDIR="$STAGE" docdir=/usr/share/doc/mupdf-1.26.12 install
cd "$STAGE/usr/lib" && ln -sfv libmupdf.so.26.12 libmupdf.so.26 && ln -sfv libmupdf.so.26 libmupdf.so && chmod 755 libmupdf.so.26.12
