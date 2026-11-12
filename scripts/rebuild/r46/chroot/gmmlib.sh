# VAAPI-01: BLFS 13.1 general/gmmlib.html, but for the generic x86-64 baseline (D146): upstream compiles the whole
# library with -march=corei7 -mpopcnt -msse3 ... -msse4.2 (Source/GmmLib/Linux.cmake); those flags and the matching
# USE_SSE3/USE_SSSE3 defines are removed and GMMLIB_MARCH is x86-64. The ISA audit checks the result.
set -e
L=Source/GmmLib/Linux.cmake
sed -i -E '/^\s*-m(popcnt|sse|sse2|sse3|ssse3|sse4|sse4\.1|sse4\.2)\s*$/d; /^\s*-DUSE_(SSE3|SSSE3)\s*$/d' "$L"
if grep -nE '^\s*-m(popcnt|sse[0-9.]*|ssse3)\s*$' "$L"; then echo "flags left in $L"; exit 1; fi
# CpuSwizzleBlt.c uses MOVNTDQA (_mm_stream_load_si128, SSE4.1) only when cpuid reports SSE4.1
# (StreamingLoadSupported, both call sites); without -msse4.1 GCC cannot inline the intrinsic. It moves into one helper
# with __attribute__((target("sse4.1"))), so no other code in the file may use SSE4.1.
F=Source/GmmLib/Utility/CpuSwizzleBlt/CpuSwizzleBlt.c
sed -i 's|^\(\s*\)#include <x86intrin.h>$|&\n\1/* alpbahOS (D146): the only SSE4.1 code, called only when cpuid says SSE4.1 */\n\1static __attribute__((target("sse4.1"))) __m128i GmmAlpStreamLoad(__m128i *p) { return _mm_stream_load_si128(p); }|' "$F"
sed -i 's|((Reg) = _mm_stream_load_si128((__m128i \*)(Src)))|((Reg) = GmmAlpStreamLoad((__m128i *)(Src)))|' "$F"
[ "$(grep -c 'GmmAlpStreamLoad' "$F")" -ge 3 ] && ! grep -q '(Reg) = _mm_stream_load_si128' "$F" || { echo "CpuSwizzleBlt.c patch did not apply"; exit 1; }
mkdir build && cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr -D BUILD_TYPE=Release -D GMMLIB_MARCH=x86-64 -G Ninja -W no-author ..
ninja -j "$JOBS"
DESTDIR="$STAGE" ninja install
