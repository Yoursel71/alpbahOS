#!/usr/bin/env python3
"""Maintainer-side helper for the signed alp catalog (design/trust-model.md).

Two steps, kept apart on purpose:

  stamp  writes the signed fields into index.json: `catalog_version`,
         `valid_until`, `signed_keyring_version`, and `recipe_sha256` for
         every recipe entry (sha256 of the recipe file as it is on disk).
         Needs no key.
  sign   runs `gpg --detach-sign` on index.json and writes index.json.sig.
         The private key is whatever the gpg home given here holds; this
         tool never creates, copies or stores a key.

alp itself never signs anything and does not import this file. The test
suite uses both steps with a throwaway key made in a temp dir.

  python3 alp_catalog_tool.py stamp index.json --catalog-version 12 --keyring-version 1
  python3 alp_catalog_tool.py sign  index.json --local-user <fingerprint>
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import subprocess
import sys
from pathlib import Path

DEFAULT_VALID_DAYS = 90  # DECISIONS D172


def stamp(index_path: Path, *, catalog_version: int, keyring_version: int,
          valid_until: str | None = None, valid_days: int = DEFAULT_VALID_DAYS,
          recipe_bases: list | None = None) -> dict:
    """Write the signed fields into index.json and return the new index.

    recipe_sha256 is written for every entry that has a `recipe` field (alp
    requires it for all of them, whatever the method). The recipe file is
    looked up in `recipe_bases` in order (default: the index's directory);
    the first directory that has it wins. A recipe found nowhere is an error.
    """
    index_path = Path(index_path)
    index = json.loads(index_path.read_text(encoding="utf-8"))
    if not isinstance(index, dict) or not isinstance(index.get("entries"), dict):
        raise SystemExit(f"{index_path}: 'entries' tablosu yok")
    if valid_until is None:
        today = datetime.datetime.now(datetime.timezone.utc).date()
        valid_until = (today + datetime.timedelta(days=valid_days)).isoformat()
    datetime.date.fromisoformat(valid_until)
    bases = [Path(b) for b in (recipe_bases or [index_path.parent])]
    for name, entry in index["entries"].items():
        if isinstance(entry, dict) and ("recipe" in entry or entry.get("method") == "recipe"):
            found = [b / entry["recipe"] for b in bases if (b / entry["recipe"]).is_file()]
            if not found:
                raise SystemExit(f"{name}: tarif dosyası bulunamadı: {entry.get('recipe')!r} ({', '.join(map(str, bases))})")
            entry["recipe_sha256"] = hashlib.sha256(found[0].read_bytes()).hexdigest()
    index["catalog_version"] = int(catalog_version)
    index["valid_until"] = valid_until
    index["signed_keyring_version"] = int(keyring_version)
    index_path.write_text(json.dumps(index, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return index


def sign(index_path: Path, *, gpg: str = "gpg", homedir: str | None = None,
         local_user: str | None = None) -> Path:
    """Detached binary signature next to index.json. Returns its path."""
    index_path = Path(index_path)
    sig = index_path.with_name(index_path.name + ".sig")
    cmd = [gpg, "--batch", "--yes", "--no-tty", "--digest-algo", "SHA512"]
    if homedir:
        cmd += ["--homedir", str(homedir)]
    if local_user:
        cmd += ["--local-user", local_user]
    cmd += ["--output", str(sig), "--detach-sign", str(index_path)]
    done = subprocess.run(cmd, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if done.returncode != 0:
        raise SystemExit(f"gpg imzalayamadı ({done.returncode}): {done.stderr.strip()}")
    return sig


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="alp_catalog_tool", description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sp = sub.add_parser("stamp", help="imzalanacak alanları index.json'a yaz")
    sp.add_argument("index")
    sp.add_argument("--catalog-version", type=int, required=True)
    sp.add_argument("--keyring-version", type=int, required=True)
    sp.add_argument("--valid-until", help="YYYY-AA-GG (varsayılan: bugünden %d gün sonra)" % DEFAULT_VALID_DAYS)
    sp.add_argument("--valid-days", type=int, default=DEFAULT_VALID_DAYS)
    sp = sub.add_parser("sign", help="index.json.sig üret (gpg --detach-sign)")
    sp.add_argument("index")
    sp.add_argument("--gpg", default="gpg")
    sp.add_argument("--homedir")
    sp.add_argument("--local-user")
    args = parser.parse_args(argv)
    if args.command == "stamp":
        index = stamp(Path(args.index), catalog_version=args.catalog_version,
                      keyring_version=args.keyring_version, valid_until=args.valid_until,
                      valid_days=args.valid_days)
        print(f"catalog_version={index['catalog_version']} valid_until={index['valid_until']} "
              f"signed_keyring_version={index['signed_keyring_version']}")
    else:
        print(sign(Path(args.index), gpg=args.gpg, homedir=args.homedir, local_user=args.local_user))
    return 0


if __name__ == "__main__":
    sys.exit(main())
