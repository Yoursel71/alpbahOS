#!/bin/bash
# CPU-BASELINE-02 (g), 2026-11-12: audit-isa.sh does not count these (it counts VEX, BMI and AVX-512 only); usage: sse-scan.sh <elf>
# Report functions in an ELF that contain SSE3/SSSE3/SSE4.1/SSE4.2/POPCNT/CRC32 instructions (objdump -d).
f=$1
objdump -d --no-show-raw-insn "$f" | awk '
/^[0-9a-f]+ <.*>:$/ { fn=$2; next }
{ m=$2 }
m ~ /^(addsubp[sd]|haddp[sd]|hsubp[sd]|lddqu|movddup|movshdup|movsldup)$/ { h[fn" sse3:"m]++ }
m ~ /^(pshufb|phadd[wd]|phaddsw|phsub[wd]|phsubsw|pmaddubsw|pmulhrsw|psign[bwd]|pabs[bwd]|palignr)$/ { h[fn" ssse3:"m]++ }
m ~ /^(pblendvb|blendvp[sd]|blendp[sd]|pblendw|ptest|pmovzx..|pmovsx..|pinsr[bdq]|pextr[bdq]|roundp[sd]|rounds[sd]|pmulld|pmuldq|pmin[us][bwd]|pmax[us][bwd]|pminsd|packusdw|pcmpeqq|dpp[sd]|mpsadbw|phminposuw|movntdqa|insertps|extractps)$/ { h[fn" sse4.1:"m]++ }
m ~ /^(pcmp[ei]str[im]|pcmpgtq|crc32[bwlq]?)$/ { h[fn" sse4.2:"m]++ }
m ~ /^popcnt/ { h[fn" popcnt"]++ }
END { for (k in h) print k, h[k] }' | sort
