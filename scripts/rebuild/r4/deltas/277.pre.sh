# REBUILD-R4 277 (13.1 opencv page): ffmpeg 9 patch (required by the page, no md5: TOFU), applied in the source tree before cmake.
cd .. && patch -Np1 -i ../opencv-4.13.0-ffmpeg-9.0.patch && cd build || exit 1
