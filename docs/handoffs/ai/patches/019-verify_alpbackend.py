#!/usr/bin/env python3
"""Offline check of scripts/packagekit/alpBackend.py against a real alp + catalog.

Runs the helper's search-name / resolve / get-details in-process with
PackageKit's own Python module (read from a rootfs, read-only) and prints the
exact wire lines PackageKit would parse, for the original and the patched
helper side by side. Nothing is written outside a temp root.

  verify_alpbackend.py ROOTFS_SITE_PACKAGES ALP_PY CATALOG_INDEX HELPER_ORIG HELPER_PATCHED [--lifecycle]

--lifecycle also drives what the M10 gate runs, in-process, against a temp root:
install_packages -> get_updates (catalog bumped to a newer version) -> search
-> remove_packages. It builds the real htop from the catalog (network, ~15 s).
"""
from __future__ import annotations

import contextlib
import importlib.machinery
import importlib.util
import io
import json
import shutil
import sys
import tempfile
from pathlib import Path


def load(path: Path, name: str, site: str, alp: Path, root: Path, index: Path):
    sys.path.insert(0, site)
    # explicit loader: the original is named *.orig, which has no known suffix
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_file_location(name, path, loader=loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.ALP, mod.ROOT, mod.INDEX = alp, root, index
    return mod


def capture(fn, *args) -> list[str]:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        fn(*args)
    return buf.getvalue().splitlines()


def lifecycle(site: str, alp: Path, index: Path, helper: str) -> int:
    """install -> updates -> search -> remove through the helper, temp root only."""
    failures = 0
    with tempfile.TemporaryDirectory() as tmp:
        root, cat = Path(tmp) / "root", Path(tmp) / "catalog"
        shutil.copytree(index.parent, cat, ignore=shutil.ignore_patterns(".git"))
        mod = load(Path(helper), "helper_lifecycle", site, alp, root, cat / "index.json")
        be = mod.AlpBackend([])

        def step(title, fn, *args):
            nonlocal failures
            try:
                lines = capture(fn, *args)
            except SystemExit as exc:  # PackageKit's error() exits the helper
                failures += 1
                lines = [f"!! helper çıktı (SystemExit {exc.code})"]
            print(f"[{title}]")
            for line in lines:
                print("   ", line.replace("\t", " | "))
            return lines

        step("install htop", be.install_packages, None, ["htop;3.3.0;all;alp"])
        installed = be._installed()
        print("    installed:", [(i["name"], i["version"]) for i in installed])
        failures += [i["name"] for i in installed] != ["htop"]

        recipe = cat / "recipes" / "htop.recipe.json"
        data = json.loads(recipe.read_text(encoding="utf-8"))
        data["version"] = "3.3.1"  # catalog moves ahead of what is installed
        recipe.write_text(json.dumps(data), encoding="utf-8")
        updates = step("get-updates (catalog now 3.3.1)", be.get_updates, ["none"])
        failures += not any("htop;3.3.1;all;alp" in line for line in updates)
        step("search-name htop (installed shows installed version)", be.search_name, ["A"], ["htop"])

        step("remove htop", be.remove_packages, None, ["htop;3.3.0;all;alp"], False, False)
        left = be._installed()
        print("    installed after remove:", [i["name"] for i in left])
        failures += bool(left)
    print("LIFECYCLE:", "PASS" if not failures else f"FAIL ({failures})")
    return failures


def main() -> int:
    site, alp, index, orig, patched = sys.argv[1:6]
    alp, index = Path(alp), Path(index)
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / "root"
        # A second catalog where htop states a download size, to check pass-through.
        sized = Path(tmp) / "sized"
        shutil.copytree(index.parent, sized, ignore=shutil.ignore_patterns(".git"))
        data = json.loads((sized / "index.json").read_text(encoding="utf-8"))
        data["entries"]["htop"]["size"] = 1_600_000
        (sized / "index.json").write_text(json.dumps(data), encoding="utf-8")

        failures = 0
        for label, helper, idx in (("ORIGINAL", orig, index), ("PATCHED ", patched, index), ("PATCHED+size", patched, sized / "index.json")):
            mod = load(Path(helper), f"helper_{label.strip()}", site, alp, root, idx)
            be = mod.AlpBackend([])
            print(f"--- {label}")
            for title, fn, arg in (("search-name htop", be.search_name, (["A"], ["htop"])),
                                   ("resolve jq", be.resolve, (["A"], ["jq"])),
                                   ("get-details htop", be.get_details, (["htop;0;all;alp"],))):
                lines = capture(fn, *arg)
                print(f"[{title}]")
                for line in lines:
                    print("   ", line.replace("\t", " | "))
            sys.modules.pop("packagekit", None)
        if "--lifecycle" in sys.argv[6:]:
            print("--- LIFECYCLE (patched helper + engine under test)")
            failures += lifecycle(site, alp, index, patched)
        return failures


if __name__ == "__main__":
    raise SystemExit(main())
