# VAAPI-01: BLFS 13.1 multimedia/intel-media-driver.html for every GPU generation (the book's per-model option is for
# one machine; the image runs on any). Its SSE4.1 copy routines (cm_mem_os_sse4_impl.cpp, built with -msse4.1) are
# chosen at run time from cpuid (cm_mem_os.cpp is_SSE4_available), which D146 allows; see the ISA evidence.
set -e
mkdir build && cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_POLICY_VERSION_MINIMUM=3.5 -D INSTALL_DRIVER_SYSCONF=OFF \
      -D BUILD_TYPE=Release -D MEDIA_BUILD_FATAL_WARNINGS=OFF -G Ninja -W no-author ..
ninja -j "$JOBS"
DESTDIR="$STAGE" ninja install
