import re, sys

log_path, status_text = sys.argv[1:]
status = int(status_text)
with open(log_path, encoding="utf-8", errors="replace") as f:
    lines = f.read().splitlines()
keys = ("TOTAL", "PASS", "SKIP", "XFAIL", "FAIL", "XPASS", "ERROR")
summary = {}
for line in lines:
    if line.startswith("# "):
        match = re.fullmatch(r"# ([A-Z]+): ([0-9]+)", line)
        if not match or match.group(1) not in keys or match.group(1) in summary:
            raise SystemExit(f"unexpected or duplicate Automake summary row: {line}")
        summary[match.group(1)] = int(match.group(2))
missing = set(keys) - summary.keys()
if missing:
    raise SystemExit(f"missing Automake summary fields: {sorted(missing)}")
if summary["TOTAL"] != sum(summary[k] for k in keys[1:]):
    raise SystemExit("Automake summary total is inconsistent")
diagnostics = [line for line in lines if re.match(r"^(FAIL:|ERROR:|XPASS:|UNRESOLVED:|UNTESTED:)", line)]
if status == 0:
    if summary["SKIP"] or summary["XFAIL"] or summary["FAIL"] or summary["ERROR"] or summary["XPASS"] or diagnostics:
        raise SystemExit("make check returned 0 with skip/failure summary or diagnostics")
    print("ACL_MAKE_CHECK_EXIT=0; summary validated")
elif (summary["FAIL"] == 1 and summary["ERROR"] == 0 and summary["XPASS"] == 0
      and summary["SKIP"] == 0 and summary["XFAIL"] == 0 and diagnostics == ["FAIL: test/cp.test"]):
    print("ACL_KNOWN_FAILURE_ONLY=FAIL: test/cp.test; summary validated")
else:
    raise SystemExit(f"make check status {status} not limited to documented test/cp.test failure")
