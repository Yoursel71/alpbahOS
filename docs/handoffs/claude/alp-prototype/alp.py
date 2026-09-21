#!/usr/bin/env python3
"""alp -- alpbahOS hybrid package manager (DESIGN PROTOTYPE, not the accepted engine).

Status: proposal artifact for docs/handoffs/claude/001-alp-hybrid-pkg-proposal.md.
alpbahOS's currently accepted package engine is pacman/libalpm (DECISIONS.md D11/P05,
MASTER_PLAN.md section 5). This script exists to make that proposal concrete and
testable; it is not wired into the real system and must not be treated as a
replacement for pacman without the sign-off described in the proposal doc.

Three installation methods, dispatched from a local "index" (the thing a real
GitHub-hosted catalog would provide):
  - recipe : download+verify a source tarball, build with configure/make,
             stage into DESTDIR, then copy into --root. Used for small system tools.
  - flatpak: thin wrapper around `flatpak install/uninstall`. Used for heavy
             desktop apps; alp stores zero bytes of the app itself.
  - core   : download+verify a small prebuilt .tar.gz (alpbahOS branding/config)
             and extract it under --root.

Security notes (see proposal doc section 7 for the full discussion):
  - Every downloaded archive is sha256-verified before it is extracted or built.
  - No subprocess call uses shell=True or a shell string; argv lists only.
  - Archive extraction uses tarfile's path-traversal-safe filter.
  - A recipe's build commands ARE trusted code execution by design (this is how
    every source-based package manager works) -- that trust boundary is the repo
    that hosts recipes/, not this script. Flagged explicitly in the proposal doc.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path

SCHEMA_VERSION = 1
ALP_VERSION = "0.1.0-proto"
DEFAULT_STATE_DIR = "var/lib/alp"
DEFAULT_LOG_DIR = "var/log/alp"


class AlpError(RuntimeError):
    """User-facing error. main() prints this without a Python traceback."""


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


# --------------------------------------------------------------------------
# Paths
# --------------------------------------------------------------------------

@dataclass
class Paths:
    root: Path  # DESTROOT: "/" in production, a temp dir for local testing
    state_dir: Path
    log_dir: Path
    db_file: Path
    lock_file: Path
    cache_dir: Path

    @classmethod
    def resolve(cls, root: str | None) -> "Paths":
        r = Path(root).resolve() if root else Path("/")
        state = r / DEFAULT_STATE_DIR
        log = r / DEFAULT_LOG_DIR
        return cls(
            root=r,
            state_dir=state,
            log_dir=log,
            db_file=state / "db.json",
            lock_file=state / "alp.lock",
            cache_dir=state / "cache",
        )

    def ensure(self) -> None:
        for d in (self.state_dir, self.log_dir, self.cache_dir):
            d.mkdir(parents=True, exist_ok=True)


# --------------------------------------------------------------------------
# Single-writer lock.
# AGENTS.md: "Tek paket veri tabanı ve tek yazıcı/işlem kilidi kullan."
# --------------------------------------------------------------------------

class DbLock:
    def __init__(self, lock_file: Path):
        self.lock_file = lock_file
        self._held = False

    def __enter__(self) -> "DbLock":
        self.lock_file.parent.mkdir(parents=True, exist_ok=True)
        try:
            fd = os.open(str(self.lock_file), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError as exc:
            holder = self.lock_file.read_text(encoding="utf-8").strip() if self.lock_file.exists() else "?"
            raise AlpError(
                f"Veritabanı kilitli, başka bir alp/mağaza işlemi sürüyor ({holder}). "
                f"Kilit dosyası: {self.lock_file}"
            ) from exc
        with os.fdopen(fd, "w") as f:
            f.write(f"pid={os.getpid()} ts={_now()}\n")
        self._held = True
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        if self._held and self.lock_file.exists():
            self.lock_file.unlink()
        self._held = False


# --------------------------------------------------------------------------
# Database (installed packages, all three methods share one table+lock)
# --------------------------------------------------------------------------

def load_db(paths: Paths) -> dict:
    if not paths.db_file.exists():
        return {"schema_version": SCHEMA_VERSION, "updated_at": None, "packages": {}}
    with open(paths.db_file, "r", encoding="utf-8") as f:
        data = json.load(f)
    if data.get("schema_version") != SCHEMA_VERSION:
        raise AlpError(f"Beklenmeyen db şema sürümü: {data.get('schema_version')!r}")
    return data


def save_db(paths: Paths, db: dict) -> None:
    db["updated_at"] = _now()
    tmp = paths.db_file.with_suffix(".json.tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2, ensure_ascii=False, sort_keys=True)
    tmp.replace(paths.db_file)  # atomic rename on the same filesystem


# --------------------------------------------------------------------------
# Index: the catalog alp installs from (stand-in for "our GitHub repository").
# --------------------------------------------------------------------------

def load_index(index_path: Path) -> dict:
    with open(index_path, "r", encoding="utf-8") as f:
        return json.load(f)


# --------------------------------------------------------------------------
# Download + mandatory checksum verification.
# AGENTS.md: "Kaynağı doğrulamadan derleme yapma."
# --------------------------------------------------------------------------

def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def resolve_source_url(url: str, base_dir: Path) -> str:
    """http(s) URLs pass through unchanged; local paths resolve against base_dir
    (the index's own directory) so a demo/offline index can reference a fixture
    next to it instead of an absolute path."""
    if url.startswith(("http://", "https://")):
        return url
    local = url[len("file://"):] if url.startswith("file://") else url
    p = Path(local)
    return str(p if p.is_absolute() else (base_dir / p))


def fetch(url: str, dest: Path, expected_sha256: str) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if url.startswith(("http://", "https://")):
        with urllib.request.urlopen(url) as resp, open(dest, "wb") as out:  # noqa: S310
            shutil.copyfileobj(resp, out)
    else:
        shutil.copyfile(url, dest)

    actual = sha256_of(dest)
    if actual.lower() != expected_sha256.lower():
        dest.unlink(missing_ok=True)
        raise AlpError(
            f"Checksum uyuşmadı: {url}\n  beklenen : {expected_sha256}\n  hesaplanan: {actual}\n"
            "Kaynak doğrulanamadı; kurulum durduruldu, dosya silindi."
        )


def safe_extract(archive: Path, dest_dir: Path) -> list[str]:
    """Extract archive under dest_dir, rejecting path-traversal/device members."""
    dest_dir.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive) as tf:
        try:
            tf.extractall(dest_dir, filter="data")  # Python 3.12+: safe by default
        except TypeError:
            resolved_dest = dest_dir.resolve()
            for member in tf.getmembers():
                member_path = (dest_dir / member.name).resolve()
                if not str(member_path).startswith(str(resolved_dest)):
                    raise AlpError(f"Güvensiz arşiv girdisi (path traversal): {member.name}")
            tf.extractall(dest_dir)
        names = tf.getnames()
    return names


def _single_top_level_dir(extract_root: Path) -> Path:
    entries = [p for p in extract_root.iterdir()]
    if len(entries) == 1 and entries[0].is_dir():
        return entries[0]
    return extract_root


def _merge_destdir(destdir: Path, root: Path, dry_run: bool) -> list[str]:
    """Copy a staged DESTDIR install into root, recording every file installed.

    This is the file-ownership-tracking mechanism AGENTS.md requires
    ("Temel paketlerin hangi dosyalara sahip olduğunu izleyecek yöntem ...
    seçilmiş olmalı") for the recipe method.
    """
    installed = []
    for dirpath, _dirnames, filenames in os.walk(destdir):
        for fn in filenames:
            staged = Path(dirpath) / fn
            rel = staged.relative_to(destdir)
            installed.append("/" + str(rel).replace(os.sep, "/"))
            if not dry_run:
                target = root / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(staged, target)
    return sorted(installed)


# --------------------------------------------------------------------------
# Method 1: System Build Recipes
# --------------------------------------------------------------------------

def install_recipe(paths: Paths, entry: dict, index_dir: Path, dry_run: bool) -> dict:
    recipe_path = index_dir / entry["recipe"]
    with open(recipe_path, "r", encoding="utf-8") as f:
        recipe = json.load(f)

    archive = paths.cache_dir / f"{recipe['name']}-{recipe['version']}.src"
    fetch(resolve_source_url(recipe["source_url"], index_dir), archive, recipe["sha256"])

    build_root = paths.cache_dir / f"build-{recipe['name']}-{recipe['version']}"
    if build_root.exists():
        shutil.rmtree(build_root)
    safe_extract(archive, build_root)
    src_dir = _single_top_level_dir(build_root)

    destdir = paths.cache_dir / f"destdir-{recipe['name']}-{recipe['version']}"
    if destdir.exists():
        shutil.rmtree(destdir)
    destdir.mkdir(parents=True)

    log_path = paths.log_dir / f"{recipe['name']}-{recipe['version']}.build.log"
    steps = [
        recipe["build"]["configure"],
        recipe["build"]["make"],
        recipe["build"]["make_install"] + [f"DESTDIR={destdir}"],
    ]

    if dry_run:
        with open(log_path, "a", encoding="utf-8") as log:
            log.write(f"[dry-run {_now()}] adımlar çalıştırılmadı:\n")
            for step in steps:
                log.write("  $ " + " ".join(step) + "\n")
    else:
        for step in steps:
            binary = step[0]
            if shutil.which(binary) is None:
                raise AlpError(
                    f"Gerekli araç bulunamadı: {binary!r}. Bu adım gerçek bir Linux "
                    "build ortamı (configure/make toolchain) gerektirir."
                )
            with open(log_path, "a", encoding="utf-8") as log:
                log.write(f"$ {' '.join(step)}\n")
                subprocess.run(step, cwd=src_dir, check=True, stdout=log, stderr=subprocess.STDOUT)

    installed_files = _merge_destdir(destdir, paths.root, dry_run)

    return {
        "name": recipe["name"],
        "version": recipe["version"],
        "method": "recipe",
        "status": "installed",
        "installed_at": _now(),
        "installed_by": f"alp/{ALP_VERSION}",
        "source": {"url": recipe["source_url"], "sha256": recipe["sha256"], "recipe": entry["recipe"]},
        "build": {"log_path": str(log_path)},
        "files": installed_files,
        "flatpak_ref": None,
    }


# --------------------------------------------------------------------------
# Method 2: Universal Apps (Flatpak wrapper)
# --------------------------------------------------------------------------

def install_flatpak(entry: dict, dry_run: bool) -> dict:
    remote = entry.get("remote", "flathub")
    ref = entry["flatpak_ref"]
    cmd = ["flatpak", "install", "-y", remote, ref]

    if dry_run:
        print(f"[dry-run] $ {' '.join(cmd)}")
    else:
        if shutil.which("flatpak") is None:
            raise AlpError("flatpak bulunamadı; bu adım gerçek bir Linux masaüstü ortamı gerektirir.")
        subprocess.run(cmd, check=True)

    return {
        "name": ref,
        "version": entry.get("version", "unknown"),
        "method": "flatpak",
        "status": "installed",
        "installed_at": _now(),
        "installed_by": f"alp/{ALP_VERSION}",
        "source": {"remote": remote, "ref": ref},
        "files": [],
        "flatpak_ref": ref,
    }


def remove_flatpak(ref: str, dry_run: bool) -> None:
    cmd = ["flatpak", "uninstall", "-y", ref]
    if dry_run:
        print(f"[dry-run] $ {' '.join(cmd)}")
        return
    if shutil.which("flatpak") is None:
        raise AlpError("flatpak bulunamadı; kaldırma adımı çalıştırılamadı.")
    subprocess.run(cmd, check=True)


# --------------------------------------------------------------------------
# Method 3: Core OS Packages (prebuilt alpbahOS tarballs)
# --------------------------------------------------------------------------

def install_core(paths: Paths, entry: dict, index_dir: Path, dry_run: bool) -> dict:
    name, version = entry["name"], entry["version"]
    archive = paths.cache_dir / f"{name}-{version}.tar.gz"
    fetch(resolve_source_url(entry["url"], index_dir), archive, entry["sha256"])

    if dry_run:
        with tarfile.open(archive) as tf:
            names = tf.getnames()
        print(f"[dry-run] {name} arşivi {paths.root} altına açılacaktı ({len(names)} girdi).")
        files = ["/" + n for n in names]
    else:
        names = safe_extract(archive, paths.root)
        files = ["/" + n for n in names]

    return {
        "name": name,
        "version": version,
        "method": "core",
        "status": "installed",
        "installed_at": _now(),
        "installed_by": f"alp/{ALP_VERSION}",
        "source": {"url": entry["url"], "sha256": entry["sha256"]},
        "files": sorted(files),
        "flatpak_ref": None,
    }


# --------------------------------------------------------------------------
# Removal (dispatches on the recorded method, same as install)
# --------------------------------------------------------------------------

def remove_package(paths: Paths, db: dict, name: str, dry_run: bool) -> None:
    pkg = db["packages"].get(name)
    if pkg is None:
        raise AlpError(f"Kurulu değil: {name}")

    if pkg["method"] == "flatpak":
        remove_flatpak(pkg["flatpak_ref"], dry_run)
    else:
        for rel in sorted(pkg.get("files", []), reverse=True):
            target = paths.root / rel.lstrip("/")
            if dry_run:
                print(f"[dry-run] rm {target}")
                continue
            try:
                if target.is_file() or target.is_symlink():
                    target.unlink()
                elif target.is_dir() and not any(target.iterdir()):
                    target.rmdir()
            except OSError as exc:
                print(f"uyarı: {target} kaldırılamadı: {exc}", file=sys.stderr)

    if not dry_run:
        del db["packages"][name]


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def cmd_search(index: dict, term: str) -> int:
    hits = [n for n in index["entries"] if term.lower() in n.lower()]
    if not hits:
        print(f"Eşleşme yok: {term}")
        return 1
    for n in sorted(hits):
        entry = index["entries"][n]
        print(f"{n}\t({entry['method']})")
    return 0


def cmd_info(index: dict, db: dict, name: str) -> int:
    if name in db["packages"]:
        pkg = db["packages"][name]
        print(json.dumps(pkg, indent=2, ensure_ascii=False))
        return 0
    entry = index["entries"].get(name)
    if entry is None:
        print(f"Bilinmeyen paket: {name}", file=sys.stderr)
        return 1
    print(json.dumps({"name": name, **entry, "status": "not-installed"}, indent=2, ensure_ascii=False))
    return 0


def cmd_list(db: dict) -> int:
    if not db["packages"]:
        print("Kurulu paket yok.")
        return 0
    for name, pkg in sorted(db["packages"].items()):
        print(f"{name}\t{pkg['version']}\t{pkg['method']}")
    return 0


def cmd_install(args: argparse.Namespace, paths: Paths, index: dict, index_dir: Path) -> int:
    entry = index["entries"].get(args.name)
    if entry is None:
        raise AlpError(f"Bilinmeyen paket: {args.name!r}. Önce 'alp search {args.name}' ile denetleyin.")

    paths.ensure()
    with DbLock(paths.lock_file):
        db = load_db(paths)
        if args.name in db["packages"] and not args.reinstall:
            print(f"{args.name} zaten kurulu (sürüm {db['packages'][args.name]['version']}).")
            return 0

        method = entry["method"]
        if method == "recipe":
            record = install_recipe(paths, entry, index_dir, args.dry_run)
        elif method == "flatpak":
            record = install_flatpak(entry, args.dry_run)
        elif method == "core":
            record = install_core(paths, entry, index_dir, args.dry_run)
        else:
            raise AlpError(f"Tanımsız kurulum yöntemi: {method!r}")

        if not args.dry_run:
            db["packages"][args.name] = record
            save_db(paths, db)

    tag = "[dry-run] " if args.dry_run else ""
    print(f"{tag}{args.name} ({method}) -> {record.get('version')} kuruldu.")
    return 0


def cmd_remove(args: argparse.Namespace, paths: Paths) -> int:
    paths.ensure()
    with DbLock(paths.lock_file):
        db = load_db(paths)
        remove_package(paths, db, args.name, args.dry_run)
        if not args.dry_run:
            save_db(paths, db)
    tag = "[dry-run] " if args.dry_run else ""
    print(f"{tag}{args.name} kaldırıldı.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="alp", description="alpbahOS hybrid package manager (prototype)")
    p.add_argument("--root", default=None, help="DESTROOT override for testing (default: /)")
    p.add_argument("--index", required=True, help="Path to the local package index.json")
    p.add_argument("--dry-run", action="store_true", help="Print intended actions, touch nothing persistent")

    sub = p.add_subparsers(dest="command", required=True)

    sp = sub.add_parser("search", help="Search the index; installs nothing")
    sp.add_argument("term")

    sp = sub.add_parser("info", help="Show details for a package")
    sp.add_argument("name")

    sp = sub.add_parser("install", help="Install a package via its declared method")
    sp.add_argument("name")
    sp.add_argument("--reinstall", action="store_true")

    sp = sub.add_parser("remove", help="Remove an installed package")
    sp.add_argument("name")

    sub.add_parser("list", help="List installed packages")
    sub.add_parser("update", help="Refresh the local index (no-op in this prototype)")

    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    paths = Paths.resolve(args.root)
    index_path = Path(args.index).resolve()
    index_dir = index_path.parent

    try:
        index = load_index(index_path)
        if args.command == "search":
            return cmd_search(index, args.term)
        if args.command == "info":
            paths.ensure()
            db = load_db(paths)
            return cmd_info(index, db, args.name)
        if args.command == "list":
            paths.ensure()
            return cmd_list(load_db(paths))
        if args.command == "update":
            print("Bu prototipte 'update' yereldeki index.json'ı yeniden okur; gerçek sistemde repo senkronize eder.")
            return 0
        if args.command == "install":
            return cmd_install(args, paths, index, index_dir)
        if args.command == "remove":
            return cmd_remove(args, paths)
        raise AlpError(f"Bilinmeyen komut: {args.command}")
    except AlpError as exc:
        print(f"alp: hata: {exc}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as exc:
        print(f"alp: alt işlem başarısız (çıkış {exc.returncode}): {' '.join(exc.cmd)}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
