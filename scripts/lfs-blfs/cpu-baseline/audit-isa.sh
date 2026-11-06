#!/usr/bin/env bash
# audit-isa.sh -- ISA audit for x86-64 baseline builds. Runs on the HOST (needs objdump, readelf, gawk).
# Method: section 6.3 of docs/verification/sigill-cpu-baseline-2026-11-06.md, extended on
# 2026-11-06 (REBUILD-R2) with the rules below. Decisions: D146, CLAUDE.md section 5.
#
# Usage:  audit-isa.sh [--report-only] [--allowlist FILE] <file-or-dir> [...]
#   A directory is scanned for ELF files (*.so* and executables). Symlinks are
#   resolved and each file is scanned once.
#   Default allowlist: audit-isa.allow next to this script.
#
# What is counted, per function (objdump -d):
#   - VEX instructions (any v-prefixed mnemonic, system VMX names excluded)
#   - BMI/BMI2 and MOVBE: andn bextr blsi blsmsk blsr bzhi mulx pdep pext rorx sarx shlx shrx movbe
#   - AVX-512 mask ops: kmov/kor/kand/kxor/knot/kadd/kshift/kunpck/ktest with b/w/d/q suffix
#
# A hit is NOT a violation when the enclosing function (identified by its start address,
# so static copies with the same name are separate) is one of:
#   1. Variant by name: the name carries an ISA-variant marker (avx, sse4, fma, pclmul,
#      zen, skx, haswell, GMP fat names, ...), or is a vector-ABI entry point (_ZGV[cde]*).
#   2. Variant by call graph: a local (not exported, not address-taken) function whose
#      every direct reference inside this file comes from a variant function, transitively.
#      Baseline code cannot reach it. Exported symbols and any address that appears in a
#      relocation are never treated this way.
#   3. Listed in the allowlist (audit-isa.allow): file path suffix + symbol glob + reason +
#      reviewer and date. Used only for reviewed cases the rules above cannot express.
# Any other hit is "nonvariant" and fails the audit. Stale allowlist entries only warn.
#
# Known limits: a reference that exists only as data without a relocation is not seen by
# rule 2 (PIC shared objects always carry relocations for stored code addresses).
#
# Exit: 0 = no unallowed nonvariant hits (or --report-only), 1 = unallowed nonvariant hits
#       found, 2 = usage, allowlist or tool error.
set -euo pipefail
export LC_ALL=C

HERE=$(cd "$(dirname "$0")" && pwd)
REPORT_ONLY=0
ALLOWLIST=$HERE/audit-isa.allow
ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --report-only) REPORT_ONLY=1 ;;
    --allowlist) shift; ALLOWLIST=${1:?--allowlist needs a file} ;;
    -h|--help) sed -n '2,38p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done
((${#ARGS[@]})) || { echo "usage: $0 [--report-only] [--allowlist FILE] <file-or-dir> [...]" >&2; exit 2; }
command -v objdump >/dev/null || { echo "objdump not found (install binutils)" >&2; exit 2; }
command -v readelf >/dev/null || { echo "readelf not found (install binutils)" >&2; exit 2; }
command -v gawk >/dev/null || { echo "gawk not found (needed for strtonum)" >&2; exit 2; }
[[ -f $ALLOWLIST ]] || { echo "allowlist not found: $ALLOWLIST" >&2; exit 2; }

# ---- allowlist -------------------------------------------------------------
AL_FILE=(); AL_SYM=(); AL_LINE=(); AL_USED=(); AL_SCANNED=()
lineno=0
while IFS= read -r line || [[ -n $line ]]; do
  lineno=$((lineno + 1))
  [[ -z $line || $line == \#* ]] && continue
  IFS=$'\t' read -r e_file e_sym e_reason e_rev <<< "$line" || true
  if [[ -z ${e_file:-} || -z ${e_sym:-} || -z ${e_reason:-} || -z ${e_rev:-} ]]; then
    echo "allowlist $ALLOWLIST:$lineno: need 4 TAB-separated fields (file, symbol, reason, reviewer and date)" >&2
    exit 2
  fi
  AL_FILE+=("$e_file"); AL_SYM+=("$e_sym"); AL_LINE+=("$lineno")
  AL_USED+=(0); AL_SCANNED+=(0)
done < "$ALLOWLIST"

# ---- files -----------------------------------------------------------------
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

TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT
EXP=$TMPD/exported
RELS=$TMPD/relocs

FAILED=0
TOTAL_NV=0
TOTAL_ALLOWED=0
for f in "${FILES[@]}"; do
  # Exported (dynamic, defined) symbol names, and relocation addends (addresses that
  # are stored as pointers, i.e. address-taken).
  readelf --dyn-syms -W -- "$f" 2>/dev/null \
    | awk '$1 ~ /^[0-9]+:$/ && $7 != "UND" && NF >= 8 { n = $8; sub(/@.*/, "", n); print n }' > "$EXP"
  readelf -rW -- "$f" 2>/dev/null \
    | awk '$3 ~ /^R_X86_64/ { a = $NF; sub(/^0+/, "", a); print a }' > "$RELS"

  OUT=$(
    { objdump -d --no-show-raw-insn -- "$f" 2>/dev/null || true; } | gawk -v EXP="$EXP" -v RELS="$RELS" '
      # Generic ISA-variant name markers (SIMD names, CPU families, pclmul CRC paths).
      # GMP fat variants: only __gmpn_* symbols that end in one of the mpn/x86_64/<cpu>
      # directory names of GMP 6.3.0. Nothing else is whitelisted by suffix.
      # _ZGV[cde]: vector-ABI entry points (libmvec, AVX/AVX2/AVX-512 ABI).
      function variant(n) {
        if (n ~ /^_ZGV[cde]/) return 1
        if (n ~ /avx|sse4|ssse3|sse3|_skx|_knl|_icx|zen[0-9]|_zen|haswell|skylake|fma|bmi|_xop|_v[234]|(^|_)fat(_|$)|evex|pclmul/) return 1
        if (n ~ /^__gmpn_/ && n ~ /_(alderlake|atom|bd1|bd2|bd4|bt1|bt2|core2|coreibwl|coreihwl|coreinhm|coreisbr|fastavx|fastsse|goldmont|k10|k8|mulx|nano|pentium4|silvermont|skylake|zen|zen2|zen3)$/) return 1
        return 0
      }
      BEGIN {
        while ((getline l < EXP) > 0) exported[l] = 1
        close(EXP)
        while ((getline l < RELS) > 0) addrtaken[l] = 1
        close(RELS)
        cur = "?"; fname["?"] = "?"; nfn = 0; nh = 0
      }
      # Function header: "<hex addr> <name>:". Functions are keyed by start address.
      /^[0-9a-f]+ <.*>:$/ {
        k = $1; sub(/^0+/, "", k)
        nm = $0; sub(/^[^<]*</, "", nm); sub(/>:$/, "", nm)
        cur = k
        if (!(k in fname)) { nfn++; fnlist[nfn] = k; fname[k] = nm }
        next
      }
      {
        # Direct references to other functions: objdump prints "<target-addr> <name[+0xoff]>".
        # Target start = target address minus the offset (a jump into the middle of a copy).
        rest = $0
        while (match(rest, /[0-9a-f]+ <[^<>]+>/)) {
          tok = substr(rest, RSTART, RLENGTH)
          rest = substr(rest, RSTART + RLENGTH)
          split(tok, tt, " <")
          t = tt[1]; ref = tt[2]; sub(/>$/, "", ref)
          offs = ""
          if (match(ref, /\+0x[0-9a-f]+$/)) { offs = substr(ref, RSTART + 3); ref = substr(ref, 1, RSTART - 1) }
          s = t
          if (offs != "") s = sprintf("%x", strtonum("0x" t) - strtonum("0x" offs))
          sub(/^0+/, "", s)
          if (s != "" && s != cur) {
            if (!((s SUBSEP cur) in edge)) {
              edge[s SUBSEP cur] = 1
              cl[s] = cl[s] "\034" cur
            }
          }
        }
        n = split($0, p, "\t")
        if (n < 2) next
        split(p[2], q, /[ \t]+/)
        mn = q[1]
        if (mn ~ /^v(err|erw|mcall|mlaunch|mresume|mxoff|mxon|mread|mwrite|mptrld|mptrst|mclear|mfunc)$/) next
        bad = (mn ~ /^v[a-z0-9]+$/) || \
              (mn ~ /^(andn|bextr|blsi|blsmsk|blsr|bzhi|mulx|pdep|pext|rorx|sarx|shlx|shrx|movbe)$/) || \
              (mn ~ /^k(mov|or|and|xor|not|add|shift|unpck|test)[bwdq]$/)
        if (!bad) next
        nh++; hkey[nh] = cur; hmn[nh] = mn; hadr[nh] = p[1]
      }
      END {
        # Call-graph rule: a local, non-address-taken function is variant when it has
        # callers and every caller is variant (by name or by this rule). Least fixpoint.
        changed = 1
        while (changed) {
          changed = 0
          for (i = 1; i <= nfn; i++) {
            k = fnlist[i]; nm = fname[k]
            if (vr[k] || variant(nm) || (nm in exported) || (k in addrtaken)) continue
            if (!(k in cl)) continue
            m = split(cl[k], cs, "\034")
            ok = 1
            for (j = 1; j <= m; j++) {
              g = cs[j]
              if (g != "" && !(variant(fname[g]) || vr[g])) { ok = 0; break }
            }
            if (ok) { vr[k] = 1; changed = 1 }
          }
        }
        for (i = 1; i <= nh; i++) {
          k = hkey[i]
          if (variant(fname[k])) { nvar++ }
          else if (vr[k]) { nreach++ }
          else {
            nn++
            if (!(k in fcount)) { nf2++; fords[nf2] = k; fcount[k] = 0; fadr[k] = hadr[i]; fmn[k] = "" }
            fcount[k]++
            if (index(" " fmn[k] " ", " " hmn[i] " ") == 0) fmn[k] = fmn[k] " " hmn[i]
          }
        }
        for (x = 1; x <= nf2; x++) {
          k = fords[x]
          printf "FN\t%s\t%d\t%s\t%s\n", fname[k], fcount[k], fadr[k], substr(fmn[k], 2)
        }
        printf "COUNTS\tnonvariant=%d\tvariant=%d\treached=%d\n", nn, nvar, nreach
      }
    '
  )

  # Mark allowlist entries whose file this run scanned (for the stale-entry check).
  for i in "${!AL_FILE[@]}"; do
    if [[ $f == */"${AL_FILE[i]}" ]]; then AL_SCANNED[i]=1; fi
  done

  NV=0; ALLOWED=0; VR=0; RS=0
  while IFS=$'\t' read -r tag c1 c2 c3 c4; do
    case $tag in
      FN)
        fn=$c1; cnt=$c2; adr=$c3; mns=$c4
        hit=-1
        for i in "${!AL_FILE[@]}"; do
          if [[ $f == */"${AL_FILE[i]}" ]]; then
            AL_SCANNED[i]=1
            if [[ $fn == ${AL_SYM[i]} && $hit -lt 0 ]]; then hit=$i; fi
          fi
        done
        if (( hit >= 0 )); then
          AL_USED[hit]=1
          ALLOWED=$((ALLOWED + cnt))
          printf '  ALLOWED     %s  %s hit(s)  (allowlist line %s)\n' "$fn" "$cnt" "${AL_LINE[hit]}"
        else
          NV=$((NV + cnt))
          printf '  NONVARIANT  %s  %s hit(s)  at %s  %s\n' "$fn" "$cnt" "$adr" "$mns"
        fi
        ;;
      COUNTS)
        VR=$(printf '%s\n' "$c2" | sed -n 's/^variant=//p')
        RS=$(printf '%s\n' "$c3" | sed -n 's/^reached=//p')
        ;;
    esac
  done <<< "$OUT"

  ISA=$({ readelf -n -- "$f" 2>/dev/null || true; } | sed -n 's/.*x86 ISA used: *//p' | sort -u | paste -sd, -)
  printf '%s\tnonvariant=%s\tallowed=%s\tvariant=%s\treached=%s\tISA used: %s\n' \
    "$f" "$NV" "$ALLOWED" "${VR:-0}" "${RS:-0}" "${ISA:-none}"
  TOTAL_NV=$((TOTAL_NV + NV))
  TOTAL_ALLOWED=$((TOTAL_ALLOWED + ALLOWED))
  if [[ $NV -gt 0 ]]; then FAILED=$((FAILED + 1)); fi
done

for i in "${!AL_FILE[@]}"; do
  if [[ ${AL_SCANNED[i]} -eq 1 && ${AL_USED[i]} -eq 0 ]]; then
    echo "WARN stale allowlist entry $ALLOWLIST:${AL_LINE[i]} (${AL_FILE[i]} ${AL_SYM[i]}): no matching hit in this run"
  fi
done

echo "audit: ${#FILES[@]} file(s) scanned, $FAILED with nonvariant AVX/BMI hits ($TOTAL_ALLOWED hit(s) allowlisted, $TOTAL_NV unallowed)"
if [[ $FAILED -gt 0 && $REPORT_ONLY -eq 0 ]]; then
  exit 1
fi
exit 0
