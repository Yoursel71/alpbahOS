#!/usr/bin/env python3
"""REBUILD-R8 S3: the image catalog (usr/share/alp/index.json) built from the installed-package database.

Reads <R4>/var/lib/alp/db.json (the packages alp knows on the root) and writes STAGE/usr/share/alp/index.json with one
entry per installed package: method "lfs-base" (the alp method of the adopted base packages), version, and the upstream
source url and sha256 as recorded by alp. No artifact is shipped for these entries (the base packages are on the
image as files; the catalog only describes them). Entries of the round 8 records use the same method. The catalog
package itself is not listed. Usage: make-catalog-r8.py <R4_ROOT> <STAGE_DIR> [SIGNING_DIR]

ALP-TRUST-01: at the end scripts/rebuild/trust/resign-catalog.py is called on the written file. It signs the catalog
only when the root uses signed catalogs (alp-keyring record or the signed-catalog alp.py) and does nothing otherwise;
when the root needs a signature and signing fails, this script fails too (no unsigned catalog is left for such a root).
"""
import json
import os
import subprocess
import sys
R4, STAGE = sys.argv[1], sys.argv[2]
SIGNING = sys.argv[3] if len(sys.argv) > 3 else None
db = json.load(open(os.path.join(R4, "var/lib/alp/db.json"), encoding="utf-8"))
entries = {}
for name, rec in sorted(db["packages"].items()):
    if rec.get("status") != "installed":
        continue
    e = {"method": rec.get("method", "lfs-base"), "name": name, "version": rec["version"]}
    src = rec.get("source") or {}
    if src.get("url"):
        e["source"] = {"url": src["url"], "sha256": src.get("sha256", "")}
    entries[name] = e
# D165 (round 41): entries offered for installation from profiles/alp-catalog/offers.json (the nvidia recipe). Each
# recipe file is copied next to index.json and pinned by recipe_sha256 (alp trust rule 4) before signing. An offer
# replaces the database entry of the same name, so an installed recipe package keeps its recipe for reinstall/upgrade.
import hashlib
import shutil
OFFERS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "profiles", "alp-catalog")
offers_file = os.path.join(OFFERS, "offers.json")
if os.path.isfile(offers_file):
    offers = json.load(open(offers_file, encoding="utf-8"))
    for name, offer in sorted(offers.items()):
        if name.startswith("_"):
            continue
        rel = offer["recipe"]
        src = os.path.join(OFFERS, rel)
        dst = os.path.join(STAGE, "usr/share/alp", rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
        os.chmod(dst, 0o644)
        e = dict(offer)
        e["recipe_sha256"] = hashlib.sha256(open(dst, "rb").read()).hexdigest()
        entries[name] = e
        print("offer", name, e["version"], rel, e["recipe_sha256"][:16])
index = {"schema_version": 1, "catalog": "AlpbahOS 0.9 Beta installed set", "entries": entries}
p = os.path.join(STAGE, "usr/share/alp/index.json")
os.makedirs(os.path.dirname(p), exist_ok=True)
with open(p, "w", encoding="utf-8") as f:
    json.dump(index, f, indent=1, sort_keys=True, ensure_ascii=False)
    f.write("\n")
print("entries", len(entries), "bytes", os.path.getsize(p))
resign = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "trust", "resign-catalog.py")
rc = subprocess.run([sys.executable, resign, R4, p] + (["--signing", SIGNING] if SIGNING else [])).returncode
if rc != 0:
    raise SystemExit(f"make-catalog-r8: re-signing failed (rc {rc}); the catalog in {STAGE} must not be recorded")
