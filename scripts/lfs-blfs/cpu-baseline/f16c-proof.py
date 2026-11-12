#!/usr/bin/env python3
"""Source-level F16C proof for Mesa NONVARIANT audit hits (method of r4-ledger/audit/350-evidence.txt, section I).

Mesa's only F16C source is the inline asm in src/util/half_float.h (vcvtps2ph $0 at line 69 and $3 at line 110,
vcvtph2ps at line 84), each inside `if (util_get_cpu_caps()->has_f16c)`; GCC keeps volatile asm under its controlling
condition. This script checks, for one audit result, that the claim holds for every unallowed site:
  1. no translation unit of the build is compiled with -mf16c, -mavx*, -mfma, -mbmi*, -mlzcnt, -mmovbe or -march=
     (compile_commands.json of a build with the same meson options);
  2. no F16C intrinsic or target attribute exists in the source tree;
  3. half_float.h has the asm lines under the has_f16c blocks (69 under 64, 84 under 80, 110 under 105);
  4. in every NONVARIANT function of the audit, every AVX/BMI instruction (objdump of the staged library) is
     vcvtph2ps, or vcvtps2ph with immediate $0x0 or $0x3, and their number equals the audit's hit count.
Writes a per-site TSV and the allowlist lines (path suffix, symbol, reason, reviewer). Exit 1 if any check fails.
Usage: f16c-proof.py <audit.txt> <stage-root> <compile_commands.json> <mesa-src> <out-prefix> <evidence-name>
"""
import json
import re
import subprocess
import sys
from pathlib import Path

audit, stage, ccj, src, out, evid = sys.argv[1:7]
BAD_FLAG = re.compile(r"(^|\s)-(mf16c|mavx\S*|mfma|mbmi\S*|mlzcnt|mmovbe|march=\S+)(\s|$)")
# the audit's list (audit-isa.sh): tzcnt is the baseline-compatible "rep bsf" that GCC emits for ctz
BMI = {"andn", "bextr", "blsi", "blsmsk", "blsr", "bzhi", "mulx", "pdep", "pext", "rorx", "sarx", "shlx", "shrx",
       "movbe"}
ok = True

# 1. per-TU flags
tus = json.load(open(ccj))
bad = [t["file"] for t in tus if BAD_FLAG.search(t.get("command", " ".join(t.get("arguments", []))))]
print(f"1. TUs: {len(tus)}, with a forbidden -m flag: {len(bad)}")
ok &= not bad
# 2. intrinsics or target attributes
g = subprocess.run(["grep", "-rnE", r"_cvtss_sh|_cvtsh_ss|_mm(256)?_cvtp[hs]_p[hs]|__builtin_ia32_vcvtp|target\(\"[^\"]*f16c",
                    f"{src}/src", f"{src}/include"], capture_output=True, text=True).stdout.splitlines()
# comment lines only name the instructions (gallivm documents the LLVM intrinsics it emits into JIT code)
code = [l for l in g if not re.match(r"^[^:]+:\d+:\s*(\*|//|/\*)", l)]
print(f"2. F16C intrinsics/attributes in the source: {len(code)} in code ({len(g) - len(code)} in comments)")
for l in g:
    print("   " + l.split(src + "/", 1)[-1][:160])
ok &= not code
# 3. half_float.h
hf = Path(src, "src/util/half_float.h").read_text().splitlines()
need = {64: "has_f16c", 69: "vcvtps2ph", 80: "has_f16c", 84: "vcvtph2ps", 105: "has_f16c", 110: "vcvtps2ph"}
miss = [n for n, w in need.items() if w not in hf[n - 1]]
print(f"3. half_float.h lines 64/69, 80/84, 105/110: {'as expected' if not miss else 'MISMATCH at ' + str(miss)}")
ok &= not miss
# 4. sites
pending: list = []
want: dict = {}
for line in open(audit):  # a file's detail lines come before its summary line
    if line.startswith("/"):
        if pending:  # one entry per name: the audit lists each copy of a same-named static function separately
            agg: dict = {}
            for fn, hits in pending:
                agg[fn] = agg.get(fn, 0) + hits
            want[line.split("\t")[0]] = list(agg.items())
        pending = []
        continue
    m = re.match(r"^\s+NONVARIANT\s+(\S+)\s+(\d+) hit", line)
    if m:
        pending.append((m.group(1), int(m.group(2))))
rows = ["library\tfunction\taddress\tmnemonic\toperands\tasm_line\tstatus"]
allow = []
for lib, funcs in want.items():
    rel = lib.split(stage.rstrip("/") + "/", 1)[1]
    nm = subprocess.run(["nm", "-S", "--defined-only", lib], capture_output=True, text=True).stdout.splitlines()
    rng: dict = {}
    for l in nm:
        p = l.split()
        if len(p) == 4 and p[2] in "tTwWiI":  # a static function can exist once per TU (crocus genX copies)
            if (int(p[0], 16), int(p[1], 16)) not in rng.setdefault(p[3], []):
                rng[p[3]].append((int(p[0], 16), int(p[1], 16)))
    for fn, hits in funcs:
        if fn not in rng:
            print(f"   {rel} {fn}: not in nm"); ok = False; continue
        sites = []
        dis = "".join(subprocess.run(["objdump", "-d", "--no-show-raw-insn", f"--start-address={a:#x}",
                                      f"--stop-address={a + size:#x}", lib], capture_output=True, text=True).stdout
                      for a, size in rng[fn])
        for l in dis.splitlines():
            m = re.match(r"^\s*([0-9a-f]+):\t(\S+)\s*(.*)$", l)
            if not m:
                continue
            mn = m.group(2)
            if mn.startswith("v") or mn in BMI:
                sites.append((m.group(1), mn, m.group(3).split("#")[0].strip()))
        good = True
        for addr, mn, ops in sites:
            if mn == "vcvtph2ps":
                line, st = 84, "PROVEN_SOURCE"
            elif mn == "vcvtps2ph" and ops.startswith("$0x0,"):
                line, st = 69, "PROVEN_SOURCE"
            elif mn == "vcvtps2ph" and ops.startswith("$0x3,"):
                line, st = 110, "PROVEN_SOURCE"
            else:
                line, st, good = "-", "NOT_F16C_ASM", False
            rows.append(f"{rel}\t{fn}\t{addr}\t{mn}\t{ops}\t{line}\t{st}")
        if len(sites) != hits:
            good = False
            print(f"   {rel} {fn}: {len(sites)} sites, audit says {hits}")
        if good:
            allow.append(f"{rel}\t{fn}\tF16C asm function: every site is vcvtph2ps or vcvtps2ph emitted from "
                         "src/util/half_float.h asm (lines 69 or 110 under has_f16c at 64 or 105; line 84 under has_f16c "
                         "at 80), the only F16C source in the tree; GCC keeps volatile asm under its controlling "
                         f"condition (GCC manual, Extended Asm, Volatile). Evidence r4-ledger/audit/{evid}")
        else:
            ok = False
n_sites = len(rows) - 1
print(f"4. functions: {sum(len(v) for v in want.values())}, sites: {n_sites}, allowlisted functions: {len(allow)}")
Path(out + "-sites.tsv").write_text("\n".join(rows) + "\n")
Path(out + "-allow.lines").write_text("\n".join(allow) + "\n")
print("RESULT:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
