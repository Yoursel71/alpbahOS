#!/usr/bin/env python3
"""ALP-TRUST-01: re-sign a freshly generated alp catalog when, and only when, the root uses signed catalogs.

The one place that decides and signs. Every path that writes a catalog for a root calls this at its end
(today: scripts/rebuild/r8/make-catalog-r8.py, scripts/rebuild/trust/integrate-trust.sh).

Usage: resign-catalog.py <ROOT> <INDEX> [--signing DIR]
  ROOT   the root the catalog is for (read only here)
  INDEX  the new index.json (normally a stage copy, <STAGE>/usr/share/alp/index.json); index.json.sig is written
         next to it
  DIR    signing directory from make-temp-signing-key.sh (default scratch-lfs-bench/alp-signing; TEMPORARY keys)

Decision, the same rule as `iso-gate.sh --auto`, from the root's own files (no environment variable):
  ALP-TRUST-01 applied  = the root's alp database has an `alp-keyring` record, or its /usr/lib/alp/alp.py is the
                          signed-catalog version.
  not applied           -> nothing is done, exit 0 (the catalog stays unsigned, as before). A stale
                           index.json.sig next to INDEX is removed, so the pair is never "old signature, new data".
  applied               -> stamp (recipe hashes, catalog_version, valid_until = today + 90 days,
                           signed_keyring_version), sign with the primary key, then verify the result with the ROOT's
                           own keyring/allowed.txt and the repo alp.py, rollback floor included. Any failure: exit 1,
                           and the signed fields and the signature are not left half-written.
catalog_version = 1 + the highest of: catalog_version of the root's current /usr/share/alp/index.json, the
version stored in the root's alp database (db["catalog"]["version"]), catalog_version already in INDEX.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
WT = HERE.parents[2]
PROTO = WT / "docs/handoffs/claude/alp-prototype"
DEFAULT_SIGNING = "/home/yrslf/alpbahOS/scratch-lfs-bench/alp-signing"
sys.path.insert(0, str(PROTO))
import alp  # noqa: E402
import alp_catalog_tool  # noqa: E402


def fail(msg: str) -> None:
    print(f"resign-catalog: HATA / ERROR: {msg}", file=sys.stderr)
    raise SystemExit(1)


def trust_applied(root: Path) -> tuple[bool, str]:
    db_file = root / "var/lib/alp/db.json"
    try:
        packages = json.loads(db_file.read_text(encoding="utf-8"))["packages"]
    except (OSError, ValueError, KeyError) as exc:
        fail(f"kökün alp veritabanı okunamadı / cannot read the root's alp database ({db_file}): {exc}")
    keyring = "alp-keyring" in packages
    try:
        new_alp = "verify_catalog_signature" in (root / "usr/lib/alp/alp.py").read_text(encoding="utf-8", errors="replace")
    except OSError:
        new_alp = False
    return keyring or new_alp, f"alp-keyring record: {int(keyring)}, signed-catalog alp.py: {int(new_alp)}"


def _version_of(path: Path) -> int:
    try:
        value = json.loads(path.read_text(encoding="utf-8")).get("catalog_version")
    except (OSError, ValueError, AttributeError):
        return 0
    return value if type(value) is int and value >= 0 else 0


def next_version(root: Path, index: Path) -> int:
    db = json.loads((root / "var/lib/alp/db.json").read_text(encoding="utf-8"))
    stored = alp.stored_catalog_version(db) or 0
    return 1 + max(_version_of(root / "usr/share/alp/index.json"), stored, _version_of(index))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="resign-catalog")
    ap.add_argument("root")
    ap.add_argument("index")
    ap.add_argument("--signing", default=DEFAULT_SIGNING)
    args = ap.parse_args(argv)
    root, index = Path(args.root).resolve(), Path(args.index).resolve()
    sig = index.with_name(index.name + ".sig")
    if not index.is_file():
        fail(f"katalog yok / no catalog: {index}")
    applied, why = trust_applied(root)
    if not applied:
        if sig.exists():
            sig.unlink()
            print(f"resign-catalog: removed stale {sig}")
        print(f"resign-catalog: ALP-TRUST-01 not applied to {root} ({why}): catalog left unsigned, as before")
        return 0

    signing = Path(args.signing)
    fpr_file = signing / "FINGERPRINTS"
    if not (signing / "primary").is_dir() or not fpr_file.is_file():
        fail(f"kök imzalı katalog kullanıyor ama imza anahtarı yok / the root uses signed catalogs but there is no "
             f"signing key in {signing} (scripts/rebuild/trust/make-temp-signing-key.sh); katalog imzalanmadı, üretim durduruldu")
    primary = next((line.split()[1] for line in fpr_file.read_text().splitlines()
                    if line.startswith("primary ")), None)
    if not primary:
        fail(f"{fpr_file} has no 'primary' line")
    keyring = root / "usr/share/alp/keys/alpbahos-catalog.gpg"
    allowed = root / "usr/share/alp/keys/allowed.txt"
    if not keyring.is_file() or not allowed.is_file():
        fail(f"kökte anahtarlık yok / the root has no keyring ({keyring}, {allowed}); run integrate-trust.sh")
    keys = alp.parse_allowed_keys(allowed.read_bytes(), str(allowed))
    if primary not in keys.allowed or primary in keys.revoked:
        fail(f"imza anahtarı {primary} kökün allowed.txt dosyasında izinli değil / not allowed by the root's allowed.txt")

    version = next_version(root, index)
    original = index.read_bytes()
    work = Path(tempfile.mkdtemp(prefix="alp-resign-"))
    try:
        new_index = work / "index.json"
        new_index.write_bytes(original)
        alp_catalog_tool.stamp(new_index, catalog_version=version, keyring_version=keys.keyring_version or 1,
                               recipe_bases=[index.parent, root / "usr/share/alp"])
        try:
            new_sig = alp_catalog_tool.sign(new_index, gpg=shutil.which("gpg") or "gpg",
                                            homedir=str(signing / "primary"), local_user=primary)
        except SystemExit as exc:
            fail(f"imzalama başarısız / signing failed: {exc}")
        finally:
            subprocess.run(["gpgconf", "--homedir", str(signing / "primary"), "--kill", "all"], capture_output=True)
        data, signature = new_index.read_bytes(), new_sig.read_bytes()
        # The image must accept it: its own keyring, the repo alp.py's rules, the root's rollback floor.
        db = json.loads((root / "var/lib/alp/db.json").read_text(encoding="utf-8"))
        floor = max(alp.stored_catalog_version(db) or 0, _version_of(root / "usr/share/alp/index.json"))
        try:
            accepted = alp.accept_catalog_bytes(
                data, signature, alp.TrustPolicy(keyring=str(keyring), allowed_keys=str(allowed)),
                origin=str(index), at_update=True, floor=floor)
        except alp.AlpError as exc:
            fail(f"yeni imzalı katalog kökün anahtarlarıyla doğrulanamadı / the new signed catalog does not verify "
                 f"with the root's keys: {exc}")
        # sig first, index last (same order as alp update)
        tmp_sig = sig.with_name(sig.name + ".tmp")
        tmp_sig.write_bytes(signature)
        os.chmod(tmp_sig, 0o644)
        os.replace(tmp_sig, sig)
        tmp_idx = index.with_name(index.name + ".tmp")
        tmp_idx.write_bytes(data)
        os.chmod(tmp_idx, 0o644)
        os.replace(tmp_idx, index)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print(f"resign-catalog: signed {index} catalog_version={accepted.catalog_version} "
          f"valid_until={accepted.valid_until} by {primary} ({why})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
