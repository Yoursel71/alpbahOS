#!/usr/bin/env bash
# audit-isa.sh -- ISA audit for x86-64 baseline builds. Runs on the HOST (needs objdump, readelf).
# Method: section 6.3 of docs/verification/sigill-cpu-baseline-2026-11-06.md.
#
# Usage:  audit-isa.sh [--report-only] <file-or-dir> [...]
#   A directory is scanned for ELF files (*.so* and executables). Symlinks are
#   resolved and each file is scanned once.
#
# What is counted, per function (objdump -d):
#   - VEX instructions (any v-prefixed mnemonic, system VMX names excluded)
#   - BMI/BMI2 and MOVBE: andn bextr blsi blsmsk blsr bzhi mulx pdep pext rorx sarx shlx shrx movbe
#   - AVX-512 mask ops: kmov/kor/kand/kxor/knot/kadd/kshift/kunpck/ktest with b/w/d/q suffix
# A hit in a function whose name carries an ISA-variant marker (avx, sse4, fat, zen, skx,
# haswell, ...) is runtime-dispatched and is counted as "variant". Any other hit is
# "nonvariant" and fails the audit. Review variant names by hand if the list grows.
#
# Exit: 0 = no nonvariant hits (or --report-only), 1 = nonvariant hits found, 2 = usage/tool error.
set -euo pipefail
export LC_ALL=C

REPORT_ONLY=0
ARGS=()
for a in "$@"; do
  case $a in
    --report-only) REPORT_ONLY=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    -*) echo "unknown option: $a" >&2; exit 2 ;;
    *) ARGS+=("$a") ;;
  esac
done
((${#ARGS[@]})) || { echo "usage: $0 [--report-only] <file-or-dir> [...]" >&2; exit 2; }
command -v objdump >/dev/null || { echo "objdump not found (install binutils)" >&2; exit 2; }
command -v readelf >/dev/null || { echo "readelf not found (install binutils)" >&2; exit 2; }

declare -A SEEN
FILES=()
add_file() {
  local real
  real=$(readlink -f -- "$1") || return 0
  [[ -z ${SEEN[$real]:-} ]] || return 0
  # ELF magic 7f 45 4c 46 only.
  [[ "$(head -c 4 -- "$real" | od -An -tx1 | tr -d ' \n')" == 7f454c46 ]] || return 0
  SEEN[$real]=1
  FILES+=("$real")
}

for a in "${ARGS[@]}"; do
  if [[ -d $a ]]; then
    while IFS= read -r -d '' f; do
      add_file "$f"
    done < <(find "$a" -type f \( -name '*.so*' -o -perm -u+x \) -print0)
  elif [[ -f $a ]]; then
    add_file "$a"
  else
    echo "not a file or directory: $a" >&2
    exit 2
  fi
done

((${#FILES[@]})) || { echo "no ELF files found in the given paths" >&2; exit 2; }

FAILED=0
for f in "${FILES[@]}"; do
  OUT=$(
    { objdump -d --no-show-raw-insn -- "$f" 2>/dev/null || true; } | awk -v file="$f" '
      # Generic ISA-variant name markers (SIMD names, CPU families).
      # GMP fat variants: only __gmpn_* symbols that end in one of the mpn/x86_64/<cpu>
      # directory names of GMP 6.3.0. Nothing else is whitelisted by suffix.
      function variant(n) {
        if (n ~ /avx|sse4|ssse3|sse3|_skx|_knl|_icx|zen[0-9]|_zen|haswell|skylake|fma|bmi|_xop|_v[234]|(^|_)fat(_|$)|evex/) return 1
        if (n ~ /^__gmpn_/ && n ~ /_(alderlake|atom|bd1|bd2|bd4|bt1|bt2|core2|coreibwl|coreihwl|coreinhm|coreisbr|fastavx|fastsse|goldmont|k10|k8|mulx|nano|pentium4|silvermont|skylake|zen|zen2|zen3)$/) return 1
        return 0
      }
      BEGIN { fn = "?"; nv = 0; vr = 0 }
      /^[0-9a-f]+ <.*>:$/ { fn = $0; sub(/^[^<]*</, "", fn); sub(/>:$/, "", fn); next }
      {
        n = split($0, p, "\t")
        if (n < 2) next
        split(p[2], q, /[ \t]+/)
        mn = q[1]
        if (mn ~ /^v(err|erw|mcall|mlaunch|mresume|mxoff|mxon|mread|mwrite|mptrld|mptrst|mclear|mfunc)$/) next
        bad = (mn ~ /^v[a-z0-9]+$/) || \
              (mn ~ /^(andn|bextr|blsi|blsmsk|blsr|bzhi|mulx|pdep|pext|rorx|sarx|shlx|shrx|movbe)$/) || \
              (mn ~ /^k(mov|or|and|xor|not|add|shift|unpck|test)[bwdq]$/)
        if (!bad) next
        if (variant(fn)) { vr++; next }
        nv++
        if (nv <= 20) printf "  NONVARIANT  %s  %s  %s\n", fn, p[1], mn
      }
      END { printf "RESULT\t%s\tnonvariant=%d\tvariant=%d\n", file, nv, vr }
    '
  )
  printf '%s\n' "$OUT" | grep -v '^RESULT' || true
  SUMLINE=$(printf '%s\n' "$OUT" | grep '^RESULT' | tail -n 1)
  NV=$(printf '%s\n' "$SUMLINE" | sed -n 's/.*nonvariant=\([0-9]*\).*/\1/p')
  VR=$(printf '%s\n' "$SUMLINE" | sed -n 's/.*variant=\([0-9]*\)$/\1/p')
  ISA=$({ readelf -n -- "$f" 2>/dev/null || true; } | sed -n 's/.*x86 ISA used: *//p' | sort -u | paste -sd, -)
  printf '%s\tnonvariant=%s\tvariant=%s\tISA used: %s\n' "$f" "$NV" "$VR" "${ISA:-none}"
  if [[ ${NV:-0} -gt 0 ]]; then FAILED=$((FAILED + 1)); fi
done

echo "audit: ${#FILES[@]} file(s) scanned, $FAILED with nonvariant AVX/BMI hits"
if [[ $FAILED -gt 0 && $REPORT_ONLY -eq 0 ]]; then
  exit 1
fi
exit 0
