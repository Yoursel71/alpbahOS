"""`alp upgrade` holds back a package whose dependency is a protected LFS base package.

Found in the 29 Sep 2026 audit (handoff 020): _drop_kept_back() judged candidates
with state_problems() only, so a package needing a newer version of a protected
`lfs-base` package (same name also in the catalog) was accepted, the final plan then
contained a forbidden upgrade of that base package and _plan_or_refuse() refused the
WHOLE `alp upgrade` -- instead of holding just that package back like apt's
"kept back" does for every other unsatisfiable case.
"""

from __future__ import annotations

import io
import json
import sys
import tarfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402


def _core_entry(tmp_path: Path, name: str, version: str, *, depends=()) -> dict:
    archive = tmp_path / f"{name}-{version}.tar.gz"
    with tarfile.open(archive, "w:gz") as tf:
        for d in ("usr", "usr/share", f"usr/share/{name}"):
            info = tarfile.TarInfo(d)
            info.type = tarfile.DIRTYPE
            info.mode = 0o755
            tf.addfile(info)
        data = f"{name} {version}\n".encode()
        info = tarfile.TarInfo(f"usr/share/{name}/version")
        info.size = len(data)
        info.mode = 0o644
        tf.addfile(info, io.BytesIO(data))
    return {"method": "core", "name": name, "version": version, "url": archive.name,
            "sha256": alp.sha256_of(archive), "depends": list(depends)}


def _installed(version: str, method: str = "core", **extra) -> dict:
    return {"version": version, "method": method, "reason": "explicit", "files": [], "symlinks": [], **extra}


def test_dependency_on_a_protected_base_package_holds_only_that_package_back():
    entry = {"method": "core", "name": "x", "version": "2", "url": "x", "sha256": "0" * 64}
    index = {"entries": {
        "app": {**entry, "name": "app", "depends": ["libbase>=2"]},
        "libbase": {**entry, "name": "libbase"},
        "other": {**entry, "name": "other"},
    }}
    installed = {
        "app": _installed("1", depends=["libbase>=1"]),
        "libbase": _installed("1", method="lfs-base", protected=True),
        "other": _installed("1", depends=[]),
    }

    accepted, kept = alp._drop_kept_back(index, Path("."), installed, ["app", "other"])

    assert accepted == ["other"]
    assert kept == ["app"]


def test_full_upgrade_still_upgrades_everything_else(tmp_path, capsys):
    root = tmp_path / "root"
    paths = alp.Paths.resolve(str(root))
    paths.ensure()
    entries = {
        "app": _core_entry(tmp_path, "app", "2", depends=["libbase>=2"]),
        "libbase": _core_entry(tmp_path, "libbase", "2"),
        "other": _core_entry(tmp_path, "other", "2"),
    }
    index = tmp_path / "index.json"
    index.write_text(json.dumps({"entries": entries}), encoding="utf-8")
    db = alp.load_db(paths)
    db["packages"].update({
        "app": _installed("1", depends=["libbase>=1"]),
        "libbase": _installed("1", method="lfs-base", protected=True),
        "other": _installed("1", depends=[]),
    })
    alp.save_db(paths, db)

    rc = alp.main(["--root", str(root), "--index", str(index), "upgrade", "--yes"])

    out = capsys.readouterr()
    assert rc == 0, out.err
    assert "geri tutuldu: app" in out.out
    after = alp.load_db(paths)["packages"]
    assert after["other"]["version"] == "2"
    assert after["app"]["version"] == "1", "held back, not upgraded"
    assert after["libbase"]["version"] == "1" and after["libbase"]["method"] == "lfs-base"
