# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: ffmpeg-7.1.1   (order.txt row 274, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/multimedia/ffmpeg.html

# --- [BUILD] ---
# First, apply a patch that adds an API necessary for some packages to build:
patch -Np1 -i ../ffmpeg-7.1.1-chromium_method-1.patch

# --- [BUILD] ---
# Install FFmpeg by running the following commands:
./configure --prefix=/usr        \
            --enable-gpl         \
            --enable-version3    \
            --enable-nonfree     \
            --disable-static     \
            --enable-shared      \
            --disable-debug      \
            --enable-libaom      \
            --enable-libass      \
            --enable-libfdk-aac  \
            --enable-libfreetype \
            --enable-libmp3lame  \
            --enable-libopus     \
            --enable-libvorbis   \
            --enable-libvpx      \
            --enable-libx264     \
            --enable-libx265     \
            --enable-openssl     \
            --ignore-tests=enhanced-flv-av1 \
            --docdir=/usr/share/doc/ffmpeg-7.1.1 &&

make &&

gcc tools/qt-faststart.c -o tools/qt-faststart

# --- [BUILD] ---
# HTML documentation was built in the previous step. If you have texlive-20250308 installed and
# wish to build PDF and Postscript versions of the documentation, issue the following commands:
pushd doc &&
for DOCNAME in `basename -s .html *.html`
do
    texi2pdf -b $DOCNAME.texi &&
    texi2dvi -b $DOCNAME.texi &&

    dvips    -o $DOCNAME.ps   \
                $DOCNAME.dvi
done &&
popd &&
unset DOCNAME

# --- [BUILD] ---
# If you have Doxygen-1.14.0 installed and you wish to build (if --disable-doc was used) or
# rebuild the html documentation, issue:
doxygen doc/Doxyfile

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install &&

install -v -m755    tools/qt-faststart /usr/bin &&
install -v -m755 -d           /usr/share/doc/ffmpeg-7.1.1 &&
install -v -m644    doc/*.txt /usr/share/doc/ffmpeg-7.1.1

# --- [INSTALL,ROOT] ---
# If the PDF and Postscript documentation was built, issue the following commands, as the root
# user, to install them:
install -v -m644 doc/*.pdf /usr/share/doc/ffmpeg-7.1.1 &&
install -v -m644 doc/*.ps  /usr/share/doc/ffmpeg-7.1.1

# --- [INSTALL,ROOT] ---
# If you used doxygen to manually create the API documentation, install it by issuing the
# following commands as the root user:
install -v -m755 -d /usr/share/doc/ffmpeg-7.1.1/api                     &&
cp -vr doc/doxy/html/* /usr/share/doc/ffmpeg-7.1.1/api                  &&
find /usr/share/doc/ffmpeg-7.1.1/api -type f -exec chmod -c 0644 \{} \; &&
find /usr/share/doc/ffmpeg-7.1.1/api -type d -exec chmod -c 0755 \{} \;

# --- [BUILD,TEST] ---
# To properly test the installation you must have rsync-3.4.1 installed and follow the
# instructions for the FFmpeg Automated Testing Environment (FATE). First, about 1 GB of sample
# files used to run FATE are downloaded with the command:
make fate-rsync SAMPLES=fate-suite/

# --- [TEST] ---
# The fate-suite directory is created and the files are downloaded there. That command actually
# runs an rsync command to obtain the sample files. You may want to compress and keep this
# directory for testing again, for testing in another system, or for when a new version of ffmpeg
# is released. Then, unpack the sample files in the source directory, and run the make fate-rsync
# ... command above to sync with the upstream repository. The download size and time are
# drastically reduced by doing this. Estimated values in "Package Information" do not include the
# download SBU. Some samples may have been removed in newer versions, so in order to be sure local
# and server fate samples are identical when you use previously saved samples, run the following
# command:
rsync -vrltLW  --delete --timeout=60 --contimeout=60 \
      rsync://fate-suite.ffmpeg.org/fate-suite/ fate-suite/

# --- [BUILD,TEST] ---
# Next, execute FATE with the following commands (there are more than 3800 tests in the suite):
make fate THREADS=N SAMPLES=fate-suite/ | tee ../fate.log &&
grep ^TEST ../fate.log | wc -l
