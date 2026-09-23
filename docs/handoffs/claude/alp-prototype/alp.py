#!/usr/bin/env python3
"""alp -- alpbahOS hybrid package manager (prototype).

Status: accepted package engine since DECISIONS.md D31 (21 Sep 2026); still a
prototype -- see docs/handoffs/claude/001-alp-hybrid-pkg-proposal.md for the
honest list of what is and isn't implemented/tested.

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
import posixpath
import re
import shutil
import socket
import stat
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
DOWNLOAD_TIMEOUT_S = 30


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

def _lock_holder_is_dead(holder: str) -> bool:
    """True only when the lock provably belongs to a process that no longer
    exists on this machine (e.g. after kill -9 or a power cut). Anything
    uncertain -- another host, unparsable content, a non-POSIX OS where
    os.kill(pid, 0) would actually terminate the process -- counts as alive."""
    if os.name != "posix":
        return False
    fields = dict(part.split("=", 1) for part in holder.split() if "=" in part)
    if fields.get("host") not in (None, socket.gethostname()):
        return False
    try:
        pid = int(fields["pid"])
    except (KeyError, ValueError):
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return True
    except PermissionError:
        return False
    return False


class DbLock:
    def __init__(self, lock_file: Path):
        self.lock_file = lock_file
        self._held = False

    def __enter__(self) -> "DbLock":
        self.lock_file.parent.mkdir(parents=True, exist_ok=True)
        for attempt in (1, 2):
            try:
                fd = os.open(str(self.lock_file), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                break
            except FileExistsError as exc:
                holder = self._read_holder()
                if attempt == 1 and _lock_holder_is_dead(holder):
                    # Only remove the lock if it still holds the exact content
                    # we judged stale, so a lock another process just took over
                    # is not deleted.
                    if self._read_holder() == holder:
                        print(f"uyarı: sahibi çalışmayan eski kilit temizlendi ({holder})", file=sys.stderr)
                        self.lock_file.unlink(missing_ok=True)
                    continue
                raise AlpError(
                    f"Veritabanı kilitli, başka bir alp/mağaza işlemi sürüyor ({holder}). "
                    f"Kilit dosyası: {self.lock_file}"
                ) from exc
        with os.fdopen(fd, "w") as f:
            f.write(f"pid={os.getpid()} host={socket.gethostname()} ts={_now()}\n")
        self._held = True
        return self

    def _read_holder(self) -> str:
        try:
            return self.lock_file.read_text(encoding="utf-8").strip()
        except OSError:
            return "?"

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
        try:
            with urllib.request.urlopen(url, timeout=DOWNLOAD_TIMEOUT_S) as resp, open(dest, "wb") as out:  # noqa: S310
                shutil.copyfileobj(resp, out)
        except OSError as exc:
            raise AlpError(f"İndirme başarısız ({DOWNLOAD_TIMEOUT_S}s zaman aşımı dahil): {url}\n  {exc}") from exc
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
    """Extract archive under dest_dir with tarfile's "data" filter (rejects
    path traversal, absolute/escaping links and device files). Fails closed
    on a Python without that filter instead of extracting unchecked.

    Returns member names normalized to plain relative form ("./usr/x" and
    "usr/x" both become "usr/x"; the "." entry is dropped)."""
    if not hasattr(tarfile, "data_filter"):
        raise AlpError(
            "Bu Python sürümü tarfile güvenli çıkarma filtresini desteklemiyor "
            "(3.12+ ya da güvenlik yamalı 3.8–3.11 gerekir); arşiv açılmadı."
        )
    dest_dir.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive) as tf:
        try:
            tf.extractall(dest_dir, filter="data")
        except tarfile.FilterError as exc:
            raise AlpError(f"Güvensiz arşiv girdisi reddedildi: {exc}") from exc
        raw_names = tf.getnames()
    names = []
    for raw in raw_names:
        norm = posixpath.normpath(raw.lstrip("/"))
        if norm != ".":
            names.append(norm)
    return names


def _single_top_level_dir(extract_root: Path) -> Path:
    entries = [p for p in extract_root.iterdir()]
    if len(entries) == 1 and entries[0].is_dir():
        return entries[0]
    return extract_root


def _file_sha256_or_none(path: Path) -> str | None:
    return sha256_of(path) if path.is_file() else None


def _copy_entry(src: Path, dst: Path) -> None:
    """Copy a staged filesystem entry to its target, preserving symlinks as
    symlinks instead of dereferencing them, and preserving the source file's
    permission bits (mode) on regular files.

    Found via real end-to-end testing on Ubuntu (GNU units 2.23): its
    staged tree includes intentionally dangling symlinks (e.g.
    currency.units -> /usr/com/units/currency.units, a convention for
    admin-supplied data that legitimately may not exist at install time).
    shutil.copyfile() opens the symlink's *target* for reading and raises
    FileNotFoundError on a dangling link -- even though recreating the
    symlink itself (not its target's content) is the only correct action.

    Also found via real end-to-end testing on Ubuntu (htop 3.3.0, LFS
    chroot, Codex): shutil.copyfile() copies file *content* only, never
    permission bits -- the installed /usr/bin/htop ELF came out mode 0644
    (not executable) even though the staged binary was 0755. Every regular
    file must have its mode explicitly carried over with shutil.copymode().

    Regular files are written to a temporary sibling and renamed over dst,
    never written in place: in-place writes follow an existing symlink at
    dst (overwriting whatever it points to), modify every hard link of dst,
    and fail with ETXTBSY on a running executable during upgrades.
    """
    if src.is_symlink():
        if os.path.lexists(dst):
            dst.unlink()
        os.symlink(os.readlink(src), dst)
        return
    tmp = dst.with_name(f".{dst.name}.alp-tmp")
    if os.path.lexists(tmp):
        tmp.unlink()
    shutil.copyfile(src, tmp)
    shutil.copymode(src, tmp)
    os.replace(tmp, dst)


def _tool_available(binary: str, cwd: Path) -> bool:
    """Like shutil.which(), but path-relative binaries (./configure,
    ../foo/build.sh) are resolved against `cwd` -- the directory the build
    step actually runs in (subprocess.run(..., cwd=cwd)) -- not the
    interpreter's own working directory, which is what shutil.which()
    checks and is usually a different place (wherever alp.py itself was
    invoked from). Found via real end-to-end testing on Ubuntu: a real,
    executable ./configure was reported "not found" because it happened to
    not exist relative to alp.py's own cwd, even though it existed and was
    executable at the real build location."""
    if os.path.isabs(binary) or binary.startswith(("./", "../")) or os.sep in binary:
        candidate = Path(binary) if os.path.isabs(binary) else (cwd / binary)
        return candidate.is_file() and os.access(candidate, os.X_OK)
    return shutil.which(binary) is not None


# Directories alp never removes, even if a (possibly old-format) db record
# lists them and they are empty or are symlinks. On LFS, /bin, /lib, /sbin
# are symlinks into /usr and /var/run -> /run: deleting any of them breaks
# the system (e.g. the dynamic loader path goes through /lib).
PROTECTED_PATHS = frozenset({
    "/", "/bin", "/boot", "/dev", "/etc", "/home", "/lib", "/lib32", "/lib64",
    "/media", "/mnt", "/opt", "/proc", "/root", "/run", "/sbin", "/srv", "/sys",
    "/tmp", "/usr", "/usr/bin", "/usr/include", "/usr/lib", "/usr/lib64",
    "/usr/libexec", "/usr/local", "/usr/sbin", "/usr/share", "/usr/share/doc",
    "/usr/share/info", "/usr/share/locale", "/usr/share/man", "/usr/src",
    "/var", "/var/cache", "/var/lib", "/var/lock", "/var/log", "/var/mail",
    "/var/opt", "/var/run", "/var/spool", "/var/tmp",
})
STATE_PREFIX = "/" + DEFAULT_STATE_DIR


def _is_protected(rel: str) -> bool:
    return rel in PROTECTED_PATHS or rel == STATE_PREFIX or rel.startswith(STATE_PREFIX + "/")


def _walk_staged(staged_root: Path) -> list[tuple[str, str]]:
    """Every entry of a staged tree as ("/rel/path", kind), parents before
    children. kind is "dir", "file" or "symlink". Symlinks -- including ones
    pointing at directories, which os.walk lists under dirnames but never
    descends into -- are entries of their own and are not followed."""
    entries: list[tuple[str, str]] = []
    for dirpath, dirnames, filenames in os.walk(staged_root):
        base = Path(dirpath)
        for name in [*dirnames, *filenames]:
            full = base / name
            mode = os.lstat(full).st_mode
            rel = "/" + full.relative_to(staged_root).as_posix()
            if stat.S_ISLNK(mode):
                kind = "symlink"
            elif stat.S_ISDIR(mode):
                kind = "dir"
            elif stat.S_ISREG(mode):
                kind = "file"
            else:
                raise AlpError(f"Desteklenmeyen dosya türü (FIFO/soket/aygıt): {rel}")
            entries.append((rel, kind))
    return sorted(entries)


def _other_owners(db: dict, exclude: str) -> dict[str, str]:
    """path -> owning package, for every installed package except `exclude`."""
    owners: dict[str, str] = {}
    for pkg_name, record in db["packages"].items():
        if pkg_name == exclude:
            continue
        for rel in record.get("files", []):
            owners.setdefault(rel, pkg_name)
    return owners


def _inside(real_root: str, path: str) -> bool:
    return os.path.commonpath([real_root, path]) == real_root


def _preflight_merge(
    entries: list[tuple[str, str]],
    root: Path,
    self_owned: set[str],
    other_owners: dict[str, str],
) -> None:
    """Refuse the whole merge -- before a single byte is written -- if any
    entry would overwrite a file owned by another package or by nobody
    (e.g. the LFS base system, whose files are not in the alp db), change a
    file into a directory or vice versa where that isn't ours to change, or
    land outside root through a symlink (e.g. --root=/mnt/lfs with the LFS
    absolute link var/run -> /run would otherwise write into the build
    host's /run)."""
    real_root = os.path.realpath(root)
    problems: list[str] = []
    for rel, kind in entries:
        target = root / rel.lstrip("/")
        if not _inside(real_root, os.path.realpath(target.parent)):
            problems.append(f"{rel}: symlink üzerinden kök dizinin dışına çıkıyor ({os.path.realpath(target.parent)})")
            continue
        if not os.path.lexists(target):
            continue
        if kind == "dir":
            if target.is_dir():
                if target.is_symlink() and not _inside(real_root, os.path.realpath(target)):
                    problems.append(f"{rel}: symlink üzerinden kök dizinin dışına çıkıyor ({os.path.realpath(target)})")
                continue
            if rel not in self_owned:
                problems.append(f"{rel}: pakette dizin, sistemde dosya")
            continue
        if target.is_dir() and not target.is_symlink():
            problems.append(f"{rel}: pakette dosya, sistemde dizin")
            continue
        owner = other_owners.get(rel)
        if owner is not None:
            problems.append(f"{rel}: '{owner}' paketine ait")
        elif rel not in self_owned:
            problems.append(f"{rel}: sistemde zaten var ve hiçbir alp paketine ait değil")
    if problems:
        shown = "\n  ".join(problems[:20])
        more = f"\n  ... ve {len(problems) - 20} çakışma daha" if len(problems) > 20 else ""
        raise AlpError("Kurulum çakışması, hiçbir dosyaya dokunulmadı:\n  " + shown + more)


@dataclass
class MergeResult:
    installed: list[str]
    symlinks: list[str]
    config_hashes: dict[str, str]
    alpnew: list[str]


def _merge_staged(
    staged_root: Path,
    root: Path,
    *,
    config_files: set[str],
    old_record: dict | None,
    other_owners: dict[str, str],
) -> MergeResult:
    """The single path every recipe/core install, upgrade and reinstall uses
    to copy a staged tree (a recipe's DESTDIR or an extracted core archive)
    into root.

    Ownership recorded (the files[] list remove/upgrade act on):
      - every file and symlink copied;
      - a directory only if this merge created it, or the package already
        owned it. Pre-existing directories such as /usr/bin, or /lib when it
        is a symlink into /usr, are shared and never recorded, so removal
        can never take them away.

    Config files (config_files) follow pacman's pacnew decision tree (see
    design/config-protection.md): absent, untouched since install (hash
    matches the recorded one), or never hashed before (newly declared as
    config) -> replaced and hashed; modified by the user -> left alone, new
    version written as "<path>.alpnew", old recorded hash kept.
    """
    entries = _walk_staged(staged_root)
    old_record = old_record or {}
    self_owned = set(old_record.get("files", []))
    old_hashes = old_record.get("config_hashes", {})
    _preflight_merge(entries, root, self_owned, other_owners)

    owned: list[str] = []
    symlinks: list[str] = []
    new_hashes: dict[str, str] = {}
    alpnew: list[str] = []
    try:
        for rel, kind in entries:
            src = staged_root / rel.lstrip("/")
            dst = root / rel.lstrip("/")
            if kind == "dir":
                if os.path.lexists(dst) and rel in self_owned and (dst.is_symlink() or not dst.is_dir()):
                    dst.unlink()  # our own file/symlink becoming a real directory
                if not dst.is_dir():
                    dst.mkdir()
                    shutil.copymode(src, dst)
                    owned.append(rel)
                elif rel in self_owned:
                    owned.append(rel)
                continue

            owned.append(rel)
            if kind == "symlink":
                symlinks.append(rel)
                _copy_entry(src, dst)
            elif rel in config_files:
                current = _file_sha256_or_none(dst)
                recorded = old_hashes.get(rel)
                if current is None or recorded is None or current == recorded:
                    _copy_entry(src, dst)
                    new_hashes[rel] = sha256_of(src)
                else:
                    _copy_entry(src, dst.with_name(dst.name + ".alpnew"))
                    new_hashes[rel] = recorded  # still "user-modified" next time
                    alpnew.append(rel)
            else:
                _copy_entry(src, dst)
    except OSError as exc:
        raise AlpError(
            f"Dosya kopyalanırken hata: {exc}. İşlem yarıda kaldı; veritabanı "
            "güncellenmedi, sistemde bu paketin dosyalarının bir kısmı yazılmış olabilir."
        ) from exc
    return MergeResult(installed=sorted(owned), symlinks=sorted(symlinks), config_hashes=new_hashes, alpnew=sorted(alpnew))


def _remove_owned_paths(root: Path, rel_paths, record: dict, dry_run: bool) -> None:
    """Delete paths a package owns, deepest-first (reverse string sort: an
    ancestor is always a string prefix of its descendants). Shared by
    remove_package() and upgrade's dropped-file cleanup.

      - Protected system directories and alp's own state are never touched.
      - A symlink that points to a directory is only removed if the package
        recorded it as its own symlink (old-format records listed every
        directory, including e.g. /lib on LFS).
      - A user-modified config file is kept as "<path>.alpsave" (pacman's
        .pacsave, see design/config-protection.md §6).
      - Directories are removed only when empty.
    """
    config_files = set(record.get("config_files", []))
    config_hashes = record.get("config_hashes", {})
    own_symlinks = set(record.get("symlinks", []))
    for rel in sorted(rel_paths, reverse=True):
        if _is_protected(rel):
            continue
        target = root / rel.lstrip("/")
        if not os.path.lexists(target):
            continue
        if target.is_symlink() and target.is_dir() and rel not in own_symlinks:
            continue
        if rel in config_files and target.is_file() and not target.is_symlink():
            if sha256_of(target) != config_hashes.get(rel):
                save_path = target.with_name(target.name + ".alpsave")
                if dry_run:
                    print(f"[dry-run] {target} -> {save_path} (değiştirilmiş, kaydediliyor)")
                else:
                    os.replace(target, save_path)
                    print(f"Değiştirilmiş yapılandırma korundu: {save_path}")
                continue
        if dry_run:
            print(f"[dry-run] rm {target}")
            continue
        try:
            if target.is_symlink() or target.is_file():
                target.unlink()
            elif target.is_dir() and not any(target.iterdir()):
                target.rmdir()
        except OSError as exc:
            print(f"uyarı: {target} kaldırılamadı: {exc}", file=sys.stderr)


def _check_recipe_requirements(recipe: dict) -> list[str]:
    """Preflight check for a recipe's optional `requires_commands` /
    `requires_libraries` fields, run before any network/build activity so
    a missing system dependency fails fast with a clear message instead
    of partway through a real ./configure or make (as htop/bc/less did
    during real-Linux testing: ncursesw, ed, and ncurses/termcap were
    each only discovered as missing after a real download + extract).

    This is explicitly NOT dependency resolution (see
    design/config-protection.md and the proposal's own gap list) -- it
    never installs anything, and it can only report what it can detect:
    - requires_commands: shutil.which(), exact match.
    - requires_libraries: `pkg-config --exists <name>`. This can produce
      a false "missing" for a library that's genuinely installed but
      ships no .pc file (some older/minimal systems) -- it cannot
      produce a false "present", since pkg-config only reports what it
      can actually resolve. If pkg-config itself isn't installed, every
      requires_libraries entry is conservatively reported missing.
    """
    missing: list[str] = []
    for cmd in recipe.get("requires_commands", []):
        if shutil.which(cmd) is None:
            missing.append(f"komut: {cmd!r}")
    for lib in recipe.get("requires_libraries", []):
        try:
            result = subprocess.run(
                ["pkg-config", "--exists", lib],
                capture_output=True, timeout=5,
            )
            found = result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            found = False
        if not found:
            missing.append(f"kütüphane (pkg-config): {lib!r}")
    return missing


def _require_recipe_dependencies(recipe: dict) -> None:
    missing = _check_recipe_requirements(recipe)
    if missing:
        raise AlpError(
            "Eksik sistem gereksinimleri (indirme/derleme denenmeden ÖNCE tespit edildi): "
            + ", ".join(missing)
            + ". alp bağımlılık çözümü yapmaz (bkz. design/config-protection.md ve "
            "proposal §6); bu araç/kütüphaneleri sisteminize kurduktan sonra tekrar deneyin."
        )


# --------------------------------------------------------------------------
# Method 1: System Build Recipes
# --------------------------------------------------------------------------

def install_recipe(
    paths: Paths, entry: dict, index_dir: Path, dry_run: bool,
    db: dict | None = None, pkg_name: str | None = None,
) -> dict:
    recipe_path = index_dir / entry["recipe"]
    with open(recipe_path, "r", encoding="utf-8") as f:
        recipe = json.load(f)

    _require_recipe_dependencies(recipe)

    source_url = resolve_source_url(recipe["source_url"], index_dir)
    log_path = paths.log_dir / f"{recipe['name']}-{recipe['version']}.build.log"
    steps = [
        recipe["build"]["configure"],
        recipe["build"]["make"],
        recipe["build"]["make_install"] + ["DESTDIR=<destdir>"],
    ]

    if dry_run:
        # No network request, no disk write below this point: --dry-run must
        # "touch nothing persistent" (see build_parser()'s help text). The
        # previous version called fetch()/safe_extract() unconditionally
        # before this check, which silently downloaded the real source
        # archive and extracted it to disk even in dry-run mode.
        print(f"[dry-run] indirilecekti: {source_url} (sha256={recipe['sha256']})")
        for step in steps:
            print("[dry-run] $ " + " ".join(step))
        return {
            "name": recipe["name"],
            "version": recipe["version"],
            "method": "recipe",
            "status": "would-install",
            "installed_at": None,
            "installed_by": f"alp/{ALP_VERSION}",
            "source": {"url": recipe["source_url"], "sha256": recipe["sha256"], "recipe": entry["recipe"]},
            "build": {"log_path": None},
            "files": [],
            "flatpak_ref": None,
        }

    archive = paths.cache_dir / f"{recipe['name']}-{recipe['version']}.src"
    fetch(source_url, archive, recipe["sha256"])

    build_root = paths.cache_dir / f"build-{recipe['name']}-{recipe['version']}"
    if build_root.exists():
        shutil.rmtree(build_root)
    safe_extract(archive, build_root)
    src_dir = _single_top_level_dir(build_root)

    destdir = paths.cache_dir / f"destdir-{recipe['name']}-{recipe['version']}"
    if destdir.exists():
        shutil.rmtree(destdir)
    destdir.mkdir(parents=True)

    real_steps = [
        recipe["build"]["configure"],
        recipe["build"]["make"],
        recipe["build"]["make_install"] + [f"DESTDIR={destdir}"],
    ]
    for step in real_steps:
        binary = step[0]
        if not _tool_available(binary, src_dir):
            raise AlpError(
                f"Gerekli araç bulunamadı: {binary!r}. Bu adım gerçek bir Linux "
                "build ortamı (configure/make toolchain) gerektirir."
            )
        with open(log_path, "a", encoding="utf-8") as log:
            log.write(f"$ {' '.join(step)}\n")
            subprocess.run(step, cwd=src_dir, check=True, stdout=log, stderr=subprocess.STDOUT)

    config_files = set(recipe.get("config_files", []))
    db = db if db is not None else load_db(paths)
    merged = _merge_staged(
        destdir, paths.root,
        config_files=config_files, old_record=None,
        other_owners=_other_owners(db, exclude=pkg_name or recipe["name"]),
    )

    return {
        "name": recipe["name"],
        "version": recipe["version"],
        "method": "recipe",
        "status": "installed",
        "installed_at": _now(),
        "installed_by": f"alp/{ALP_VERSION}",
        "source": {"url": recipe["source_url"], "sha256": recipe["sha256"], "recipe": entry["recipe"]},
        "build": {"log_path": str(log_path)},
        "files": merged.installed,
        "symlinks": merged.symlinks,
        "config_files": sorted(config_files),
        "config_hashes": merged.config_hashes,
        "flatpak_ref": None,
    }


# --------------------------------------------------------------------------
# Upgrade: recipe/core only (flatpak manages its own updates, see
# design/config-protection.md §8). Config-aware -- see _merge_staged().
# --------------------------------------------------------------------------

def upgrade_recipe(
    paths: Paths, entry: dict, index_dir: Path, old_record: dict, dry_run: bool,
    db: dict | None = None, pkg_name: str | None = None,
) -> dict:
    recipe_path = index_dir / entry["recipe"]
    with open(recipe_path, "r", encoding="utf-8") as f:
        recipe = json.load(f)

    _require_recipe_dependencies(recipe)

    source_url = resolve_source_url(recipe["source_url"], index_dir)
    config_files = set(recipe.get("config_files", []))

    if dry_run:
        print(f"[dry-run] yükseltilecekti: {old_record.get('version')} -> {recipe['version']} ({source_url})")
        return {**old_record, "version": recipe["version"], "status": "would-upgrade"}

    archive = paths.cache_dir / f"{recipe['name']}-{recipe['version']}.src"
    fetch(source_url, archive, recipe["sha256"])

    build_root = paths.cache_dir / f"upgrade-build-{recipe['name']}-{recipe['version']}"
    if build_root.exists():
        shutil.rmtree(build_root)
    safe_extract(archive, build_root)
    src_dir = _single_top_level_dir(build_root)

    destdir = paths.cache_dir / f"upgrade-destdir-{recipe['name']}-{recipe['version']}"
    if destdir.exists():
        shutil.rmtree(destdir)
    destdir.mkdir(parents=True)

    log_path = paths.log_dir / f"{recipe['name']}-{recipe['version']}.upgrade.log"
    steps = [
        recipe["build"]["configure"],
        recipe["build"]["make"],
        recipe["build"]["make_install"] + [f"DESTDIR={destdir}"],
    ]
    for step in steps:
        binary = step[0]
        if not _tool_available(binary, src_dir):
            raise AlpError(
                f"Gerekli araç bulunamadı: {binary!r}. Bu adım gerçek bir Linux "
                "build ortamı (configure/make toolchain) gerektirir."
            )
        with open(log_path, "a", encoding="utf-8") as log:
            log.write(f"$ {' '.join(step)}\n")
            subprocess.run(step, cwd=src_dir, check=True, stdout=log, stderr=subprocess.STDOUT)

    db = db if db is not None else load_db(paths)
    other_owners = _other_owners(db, exclude=pkg_name or recipe["name"])
    merged = _merge_staged(
        destdir, paths.root,
        config_files=config_files, old_record=old_record, other_owners=other_owners,
    )
    _drop_stale_files(paths.root, old_record, merged.installed, other_owners)
    _warn_about_alpnew(merged.alpnew)

    return {
        "name": recipe["name"],
        "version": recipe["version"],
        "method": "recipe",
        "status": "installed",
        "installed_at": _now(),
        "installed_by": f"alp/{ALP_VERSION}",
        "source": {"url": recipe["source_url"], "sha256": recipe["sha256"], "recipe": entry["recipe"]},
        "build": {"log_path": str(log_path)},
        "files": merged.installed,
        "symlinks": merged.symlinks,
        "config_files": sorted(config_files),
        "config_hashes": merged.config_hashes,
        "flatpak_ref": None,
    }


def _drop_stale_files(root: Path, old_record: dict, new_files: list[str], other_owners: dict[str, str]) -> None:
    """Remove what the old version owned that the new version no longer
    ships (a renamed binary, a dropped doc file), with the same safety rules
    as removal -- including .alpsave for a user-modified config file the new
    version dropped. Paths another package owns are left alone."""
    dropped = set(old_record.get("files", [])) - set(new_files) - set(other_owners)
    if dropped:
        _remove_owned_paths(root, dropped, old_record, dry_run=False)


def _warn_about_alpnew(alpnew: list[str]) -> None:
    if not alpnew:
        return
    print(f"Uyarı: {len(alpnew)} yapılandırma dosyası elle değiştirilmiş; yeni sürüm yanına yazıldı:")
    for rel in alpnew:
        print(f"  {rel}.alpnew  (elle birleştirin; orijinal dosyanız değiştirilmedi)")


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

def _stage_core_archive(paths: Paths, entry: dict, index_dir: Path, prefix: str) -> Path:
    """Download + verify a core archive and extract it into a private
    staging dir (never straight into root, so a conflicting or half-read
    archive can't leave untracked files in the system)."""
    name, version = entry["name"], entry["version"]
    archive = paths.cache_dir / f"{name}-{version}.tar.gz"
    fetch(resolve_source_url(entry["url"], index_dir), archive, entry["sha256"])
    staged = paths.cache_dir / f"{prefix}-stage-{name}-{version}"
    if staged.exists():
        shutil.rmtree(staged)
    safe_extract(archive, staged)
    return staged


def install_core(
    paths: Paths, entry: dict, index_dir: Path, dry_run: bool,
    db: dict | None = None, pkg_name: str | None = None,
) -> dict:
    name, version = entry["name"], entry["version"]
    source_url = resolve_source_url(entry["url"], index_dir)

    if dry_run:
        # See install_recipe()'s comment: --dry-run must not touch the
        # network or disk. The previous version fetched the real archive
        # unconditionally before this check.
        print(f"[dry-run] {name} indirilip {paths.root} altına açılacaktı: {source_url} (sha256={entry['sha256']})")
        return {
            "name": name,
            "version": version,
            "method": "core",
            "status": "would-install",
            "installed_at": None,
            "installed_by": f"alp/{ALP_VERSION}",
            "source": {"url": entry["url"], "sha256": entry["sha256"]},
            "files": [],
            "flatpak_ref": None,
        }

    config_files = set(entry.get("config_files", []))
    db = db if db is not None else load_db(paths)
    staged = _stage_core_archive(paths, entry, index_dir, "install")
    try:
        merged = _merge_staged(
            staged, paths.root,
            config_files=config_files, old_record=None,
            other_owners=_other_owners(db, exclude=pkg_name or name),
        )
    finally:
        shutil.rmtree(staged, ignore_errors=True)

    return {
        "name": name,
        "version": version,
        "method": "core",
        "status": "installed",
        "installed_at": _now(),
        "installed_by": f"alp/{ALP_VERSION}",
        "source": {"url": entry["url"], "sha256": entry["sha256"]},
        "files": merged.installed,
        "symlinks": merged.symlinks,
        "config_files": sorted(config_files),
        "config_hashes": merged.config_hashes,
        "flatpak_ref": None,
    }


def upgrade_core(
    paths: Paths, entry: dict, index_dir: Path, old_record: dict, dry_run: bool,
    db: dict | None = None, pkg_name: str | None = None,
) -> dict:
    name, version = entry["name"], entry["version"]
    config_files = set(entry.get("config_files", []))

    if dry_run:
        source_url = resolve_source_url(entry["url"], index_dir)
        print(f"[dry-run] {name} yükseltilecekti: {old_record.get('version')} -> {version} ({source_url})")
        return {**old_record, "version": version, "status": "would-upgrade"}

    db = db if db is not None else load_db(paths)
    other_owners = _other_owners(db, exclude=pkg_name or name)
    staged = _stage_core_archive(paths, entry, index_dir, "upgrade")
    try:
        merged = _merge_staged(
            staged, paths.root,
            config_files=config_files, old_record=old_record, other_owners=other_owners,
        )
    finally:
        shutil.rmtree(staged, ignore_errors=True)
    _drop_stale_files(paths.root, old_record, merged.installed, other_owners)
    _warn_about_alpnew(merged.alpnew)

    return {
        "name": name,
        "version": version,
        "method": "core",
        "status": "installed",
        "installed_at": _now(),
        "installed_by": f"alp/{ALP_VERSION}",
        "source": {"url": entry["url"], "sha256": entry["sha256"]},
        "files": merged.installed,
        "symlinks": merged.symlinks,
        "config_files": sorted(config_files),
        "config_hashes": merged.config_hashes,
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
        other_owners = _other_owners(db, exclude=name)
        ours = [rel for rel in pkg.get("files", []) if rel not in other_owners]
        _remove_owned_paths(paths.root, ours, pkg, dry_run)

    if not dry_run:
        del db["packages"][name]


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def cmd_search(index: dict, term: str, as_json: bool = False) -> int:
    hits = sorted(n for n in index["entries"] if term.lower() in n.lower())
    if as_json:
        # Machine-readable mode for callers like a PackageKit backend (see
        # design/packagekit-integration.md §2) that must not scrape the
        # human-readable text format below.
        print(json.dumps([{"name": n, "method": index["entries"][n]["method"]} for n in hits], ensure_ascii=False))
        return 0 if hits else 1
    if not hits:
        print(f"Eşleşme yok: {term}")
        return 1
    for n in hits:
        entry = index["entries"][n]
        print(f"{n}\t({entry['method']})")
    return 0


def cmd_info(index: dict, db: dict, name: str) -> int:
    if name in db["packages"]:
        pkg = dict(db["packages"][name])
        pkg["required_by"] = reverse_dependents(index, db["packages"], name)
        print(json.dumps(pkg, indent=2, ensure_ascii=False))
        return 0
    entry = index["entries"].get(name)
    if entry is None:
        print(f"Bilinmeyen paket: {name}", file=sys.stderr)
        return 1
    print(json.dumps({"name": name, **entry, "status": "not-installed"}, indent=2, ensure_ascii=False))
    return 0


def cmd_list(db: dict, as_json: bool = False) -> int:
    if as_json:
        rows = [
            {"name": name, "version": pkg["version"], "method": pkg["method"],
             "status": pkg.get("status", "installed"), "reason": pkg.get("reason", "explicit")}
            for name, pkg in sorted(db["packages"].items())
        ]
        print(json.dumps(rows, ensure_ascii=False))
        return 0
    if not db["packages"]:
        print("Kurulu paket yok.")
        return 0
    for name, pkg in sorted(db["packages"].items()):
        suffix = "\t(bağımlılık)" if pkg.get("reason") == "dependency" else ""
        print(f"{name}\t{pkg['version']}\t{pkg['method']}{suffix}")
    return 0


# --------------------------------------------------------------------------
# Seviye 3: version constraints, conflicts, reverse dependencies, orphans.
#
# Scope, on purpose: the catalog carries exactly ONE version of each package,
# so there is never a choice between candidates and nothing to backtrack
# over. "Resolution" here means: walk the `depends` graph, check every
# constraint against what is installed or what the catalog offers, upgrade a
# dependency only when its installed version fails a constraint, and refuse
# the whole transaction -- before touching anything -- if the end state would
# break a constraint or a `conflicts` rule. This is not a SAT solver and does
# not reach outside index.json; system libraries stay Seviye 1
# (requires_commands / requires_libraries).
# --------------------------------------------------------------------------

_VERSION_TOKEN = re.compile(r"\d+|[A-Za-z]+")


def vercmp(a: str, b: str) -> int:
    """Compare two version strings; returns -1, 0 or 1.

    Numeric segments compare as integers, letter segments as text, and a
    number beats letters at the same position (1.0.1 > 1.0a). When one side
    runs out, a remaining letter segment marks a pre-release (1.0rc1 < 1.0)
    and a remaining number marks a newer release (1.0.1 > 1.0). Separators
    (. - _ +) are ignored.
    """
    ta, tb = _VERSION_TOKEN.findall(a), _VERSION_TOKEN.findall(b)
    for x, y in zip(ta, tb):
        xd, yd = x.isdigit(), y.isdigit()
        if xd and yd:
            if int(x) != int(y):
                return 1 if int(x) > int(y) else -1
        elif xd != yd:
            return 1 if xd else -1
        elif x != y:
            return 1 if x > y else -1
    if len(ta) == len(tb):
        return 0
    if len(ta) > len(tb):
        return -1 if ta[len(tb)].isalpha() else 1
    return 1 if tb[len(ta)].isalpha() else -1


_SPEC_NAME = re.compile(r"\s*([A-Za-z0-9][A-Za-z0-9._+-]*?)\s*((?:[<>=!].*)?)$")
_SPEC_CLAUSE = re.compile(r"\s*(>=|<=|==|!=|=|<|>)\s*([A-Za-z0-9._+~-]+)\s*$")
_OPS = {
    ">=": lambda c: c >= 0,
    "<=": lambda c: c <= 0,
    "==": lambda c: c == 0,
    "=": lambda c: c == 0,
    "!=": lambda c: c != 0,
    ">": lambda c: c > 0,
    "<": lambda c: c < 0,
}


@dataclass(frozen=True)
class Spec:
    name: str
    clauses: tuple[tuple[str, str], ...]
    raw: str

    def allows(self, version: str) -> bool:
        return all(_OPS[op](vercmp(version, want)) for op, want in self.clauses)

    def __str__(self) -> str:
        return self.raw


def parse_spec(raw: str) -> Spec:
    """'name', 'name>=1.2' or 'name>=1.2,<2' (comma = AND)."""
    m = _SPEC_NAME.fullmatch(raw)
    if not m:
        raise AlpError(f"Geçersiz bağımlılık tanımı: {raw!r}")
    name, rest = m.group(1), m.group(2)
    clauses = []
    if rest:
        for part in rest.split(","):
            cm = _SPEC_CLAUSE.fullmatch(part)
            if not cm:
                raise AlpError(f"Geçersiz sürüm kısıtı {part.strip()!r} ({raw!r} içinde)")
            clauses.append((cm.group(1), cm.group(2)))
    return Spec(name, tuple(clauses), raw.strip())


def catalog_version(index: dict, index_dir: Path, name: str) -> str:
    entry = index["entries"][name]
    if "version" in entry:
        return str(entry["version"])
    if entry.get("method") == "recipe":
        with open(index_dir / entry["recipe"], "r", encoding="utf-8") as f:
            return str(json.load(f)["version"])
    return "unknown"


def _declared(record: dict | None, entry: dict | None, field: str) -> list[str]:
    """What an installed package requires/conflicts with. Recorded at install
    time since Seviye 3; records written before that fall back to the
    current catalog entry."""
    if record is not None and field in record:
        return record[field]
    return (entry or {}).get(field, [])


@dataclass
class PlanStep:
    action: str  # "install" | "upgrade" | "reinstall"
    name: str
    old_version: str | None
    new_version: str
    reason: str  # "explicit" | "dependency"


def plan_transaction(
    index: dict, index_dir: Path, installed: dict, targets: list[str],
    mode: str = "install", reinstall: bool = False,
) -> list[PlanStep]:
    """Ordered steps (dependencies first) that bring `targets` in.

    mode="install": install missing targets (or reinstall them).
    mode="upgrade": move targets to the catalog version when it is newer.
    A dependency that is already installed and satisfies every constraint
    placed on it is left alone; one that does not is upgraded, if the
    catalog version satisfies the constraint, otherwise the plan fails.
    """
    state = {n: r["version"] for n, r in installed.items()}
    steps: list[PlanStep] = []
    planned: set[str] = set()
    visiting: list[str] = []

    def chain(name: str) -> str:
        return " -> ".join(visiting + [name])

    def add(name: str, action: str, reason: str) -> None:
        if name in planned:
            return
        if name in visiting:
            cycle = " -> ".join(visiting[visiting.index(name):] + [name])
            raise AlpError(f"Bağımlılık döngüsü tespit edildi: {cycle}")
        entry = index["entries"][name]
        new_version = catalog_version(index, index_dir, name)
        visiting.append(name)
        for raw in entry.get("depends", []):
            need(parse_spec(raw))
        visiting.pop()
        old = installed.get(name)
        steps.append(PlanStep(
            action, name, old["version"] if old else None, new_version,
            reason if old is None else old.get("reason", "explicit"),
        ))
        planned.add(name)
        state[name] = new_version

    def need(spec: Spec) -> None:
        requester = visiting[-1]
        current = state.get(spec.name)
        if current is not None and spec.allows(current):
            return
        if spec.name not in index["entries"]:
            if current is None:
                raise AlpError(f"Bilinmeyen bağımlılık: {spec.name!r} ({chain(spec.name)} zincirinde)")
            raise AlpError(
                f"{requester} şunu gerektiriyor: {spec}; kurulu {spec.name} {current} bunu "
                "karşılamıyor ve katalogda yenisi yok."
            )
        if spec.name in planned:
            raise AlpError(
                f"{requester} şunu gerektiriyor: {spec}; ama bu işlemde {spec.name} "
                f"{state[spec.name]} kurulacak. İkisi aynı anda karşılanamaz."
            )
        offered = catalog_version(index, index_dir, spec.name)
        if not spec.allows(offered):
            have = f"kurulu {current}, " if current is not None else ""
            raise AlpError(
                f"{requester} şunu gerektiriyor: {spec}; {have}katalogdaki {spec.name} {offered}. "
                "Hiçbiri kısıtı karşılamıyor."
            )
        add(spec.name, "upgrade" if spec.name in installed else "install", "dependency")

    for target in targets:
        if target not in index["entries"]:
            raise AlpError(f"Bilinmeyen paket: {target!r}. Önce 'alp search {target}' ile denetleyin.")
        if mode == "install":
            if target in installed and not reinstall:
                continue
            add(target, "reinstall" if target in installed else "install", "explicit")
        else:
            if target in planned:
                continue
            offered = catalog_version(index, index_dir, target)
            if vercmp(offered, installed[target]["version"]) > 0:
                add(target, "upgrade", "explicit")
    return steps


def state_problems(index: dict, installed: dict, steps: list[PlanStep], only_touched: bool = True) -> list[str]:
    """Broken constraints and conflicts in the state `steps` would leave.

    With only_touched, pre-existing problems between packages this
    transaction does not touch are ignored (they are `alp check`'s job).
    """
    touched = {s.name for s in steps}
    final = {n: r["version"] for n, r in installed.items()}
    final.update({s.name: s.new_version for s in steps})

    def declared(name: str, field: str) -> list[str]:
        entry = index["entries"].get(name)
        if name in touched:
            return (entry or {}).get(field, [])
        return _declared(installed.get(name), entry, field)

    problems: list[str] = []
    for name in sorted(final):
        for raw in declared(name, "depends"):
            spec = parse_spec(raw)
            if only_touched and name not in touched and spec.name not in touched:
                continue
            have = final.get(spec.name)
            if have is None:
                problems.append(f"{name} {spec} gerektiriyor, {spec.name} kurulu değil")
            elif not spec.allows(have):
                problems.append(f"{name} {spec} gerektiriyor, {spec.name} {have} olur")
        for raw in declared(name, "conflicts"):
            spec = parse_spec(raw)
            if spec.name == name or (only_touched and name not in touched and spec.name not in touched):
                continue
            have = final.get(spec.name)
            if have is not None and spec.allows(have):
                problems.append(f"{name} ile {spec.name} {have} çakışıyor ({spec})")
    return problems


def reverse_dependents(index: dict, installed: dict, name: str) -> list[str]:
    return sorted(
        other for other, record in installed.items()
        if other != name and any(
            parse_spec(raw).name == name
            for raw in _declared(record, index["entries"].get(other), "depends")
        )
    )


def plan_remove(index: dict, installed: dict, targets: list[str], cascade: bool) -> list[str]:
    """Removal order, dependents before what they depend on. Without
    cascade, refuses when an installed package outside `targets` still
    needs one of them."""
    removing = set(targets)
    if cascade:
        frontier = list(targets)
        while frontier:
            for dep in reverse_dependents(index, installed, frontier.pop()):
                if dep not in removing:
                    removing.add(dep)
                    frontier.append(dep)
    else:
        for target in targets:
            blockers = [d for d in reverse_dependents(index, installed, target) if d not in removing]
            if blockers:
                raise AlpError(
                    f"{target} kaldırılamaz, şu kurulu paketler ona bağımlı: {', '.join(blockers)}. "
                    f"Onlarla birlikte kaldırmak için: alp remove --cascade {target}"
                )

    order: list[str] = []
    seen: set[str] = set()

    def visit(name: str) -> None:
        if name in seen:
            return
        seen.add(name)
        for dep in reverse_dependents(index, installed, name):
            if dep in removing:
                visit(dep)
        order.append(name)

    for name in sorted(removing):
        visit(name)
    return order


def find_orphans(index: dict, installed: dict, removing: set[str] = frozenset()) -> list[str]:
    """Packages pulled in as dependencies that nothing left needs anymore.
    Records without a `reason` (pre-Seviye 3) count as explicit and are
    never auto-removed."""
    alive = set(installed) - set(removing)
    orphans: set[str] = set()
    while True:
        needed = {
            parse_spec(raw).name
            for name in alive - orphans
            for raw in _declared(installed[name], index["entries"].get(name), "depends")
        }
        new = {
            name for name in alive - orphans
            if installed[name].get("reason") == "dependency" and name not in needed
        }
        if not new:
            return sorted(orphans)
        orphans |= new


def _confirm(question: str, assume_yes: bool) -> bool:
    """Asks only on an interactive terminal; scripts and the PackageKit
    backend (stdin is not a tty) proceed as before."""
    if assume_yes or sys.stdin is None or not sys.stdin.isatty():
        return True
    try:
        answer = input(f"{question} [E/h] ").strip().lower()
    except EOFError:
        return False
    return answer in ("", "e", "evet", "y", "yes")


_FLATPAK_UPGRADE_MSG = (
    "flatpak yöntemi 'alp upgrade' ile yükseltilmez; flatpak kendi güncellemesini "
    "yönetir (bkz. design/config-protection.md §8). 'flatpak update' kullanın."
)
_ACTION_LABEL = {"install": "kur", "upgrade": "yükselt", "reinstall": "yeniden kur"}
_ACTION_DONE = {"install": "kuruldu", "upgrade": "yükseltildi", "reinstall": "yeniden kuruldu"}


def _print_plan(steps: list[PlanStep], index: dict) -> None:
    print("İşlem planı:")
    for s in steps:
        version = f"{s.old_version} -> {s.new_version}" if s.action == "upgrade" else s.new_version
        note = "  (bağımlılık)" if s.action == "install" and s.reason == "dependency" else ""
        method = index["entries"][s.name]["method"]
        print(f"  {_ACTION_LABEL[s.action]:<12}{s.name} {version} [{method}]{note}")


def _install_one(paths: Paths, name: str, entry: dict, index_dir: Path, dry_run: bool, db: dict) -> dict:
    method = entry["method"]
    if method == "recipe":
        return install_recipe(paths, entry, index_dir, dry_run, db=db, pkg_name=name)
    if method == "flatpak":
        return install_flatpak(entry, dry_run)
    if method == "core":
        return install_core(paths, entry, index_dir, dry_run, db=db, pkg_name=name)
    raise AlpError(f"Tanımsız kurulum yöntemi: {method!r}")


def _upgrade_one(paths: Paths, name: str, entry: dict, index_dir: Path, old: dict, dry_run: bool, db: dict) -> dict:
    method = entry["method"]
    if method == "recipe":
        return upgrade_recipe(paths, entry, index_dir, old, dry_run, db=db, pkg_name=name)
    if method == "core":
        return upgrade_core(paths, entry, index_dir, old, dry_run, db=db, pkg_name=name)
    if method == "flatpak":
        raise AlpError(_FLATPAK_UPGRADE_MSG)
    raise AlpError(f"Tanımsız yöntem: {method!r}")


def _run_plan(
    steps: list[PlanStep], paths: Paths, index: dict, index_dir: Path, db: dict,
    dry_run: bool, explicit: set[str],
) -> None:
    tag = "[dry-run] " if dry_run else ""
    done: list[str] = []
    for step in steps:
        entry = index["entries"][step.name]
        old = db["packages"].get(step.name)
        try:
            if old is not None and entry["method"] in ("recipe", "core"):
                # upgrade and --reinstall share the config-aware path, so
                # modified configs get .alpnew and dropped files are removed.
                record = _upgrade_one(paths, step.name, entry, index_dir, old, dry_run, db)
            else:
                record = _install_one(paths, step.name, entry, index_dir, dry_run, db)
        except Exception:
            if done:
                remaining = [s.name for s in steps[len(done):]]
                print(
                    f"alp: işlem yarıda kaldı. Tamamlanan ve kaydedilen: {', '.join(done)}; "
                    f"yapılmayan: {', '.join(remaining)}",
                    file=sys.stderr,
                )
            raise
        record["depends"] = list(entry.get("depends", []))
        record["conflicts"] = list(entry.get("conflicts", []))
        if step.name in explicit:
            record["reason"] = "explicit"
        elif old is not None:
            record["reason"] = old.get("reason", "explicit")
        else:
            record["reason"] = step.reason
        if not dry_run:
            db["packages"][step.name] = record
            save_db(paths, db)
        done.append(step.name)
        print(f"{tag}{step.name} ({entry['method']}) -> {record.get('version')} {_ACTION_DONE[step.action]}.")


def _plan_or_refuse(index: dict, installed: dict, steps: list[PlanStep]) -> None:
    problems = state_problems(index, installed, steps)
    if problems:
        raise AlpError(
            "Bu işlem sistemi tutarsız bırakırdı; hiçbir şey yapılmadı:\n  - " + "\n  - ".join(problems)
        )


def _hint_orphans(index: dict, installed: dict, removing: set[str] = frozenset()) -> None:
    orphans = find_orphans(index, installed, removing)
    if orphans:
        print(f"Artık hiçbir paketin ihtiyaç duymadığı bağımlılıklar: {', '.join(orphans)}. "
              "Kaldırmak için: alp autoremove")


def cmd_install(args: argparse.Namespace, paths: Paths, index: dict, index_dir: Path) -> int:
    if args.name not in index["entries"]:
        raise AlpError(f"Bilinmeyen paket: {args.name!r}. Önce 'alp search {args.name}' ile denetleyin.")

    paths.ensure()
    with DbLock(paths.lock_file):
        db = load_db(paths)
        installed = db["packages"]
        steps = plan_transaction(
            index, index_dir, installed, [args.name],
            mode="install", reinstall=getattr(args, "reinstall", False),
        )

        if not steps:
            record = installed[args.name]
            if record.get("reason") == "dependency" and not args.dry_run:
                record["reason"] = "explicit"
                save_db(paths, db)
                print(f"{args.name} zaten kurulu (sürüm {record['version']}); artık açıkça kurulmuş "
                      "olarak işaretlendi, autoremove onu kaldırmaz.")
            else:
                print(f"{args.name} zaten kurulu (sürüm {record['version']}).")
            return 0

        _plan_or_refuse(index, installed, steps)
        _print_plan(steps, index)
        if len(steps) > 1:
            print("Bağımlılık zinciri: " + " -> ".join(s.name for s in steps))
        if not args.dry_run and not _confirm("Devam edilsin mi?", getattr(args, "yes", False)):
            print("İptal edildi, hiçbir şey değişmedi.")
            return 1
        _run_plan(steps, paths, index, index_dir, db, args.dry_run, explicit={args.name})
    return 0


def _drop_kept_back(index: dict, index_dir: Path, installed: dict, targets: list[str]) -> tuple[list[str], list[str]]:
    """Full-system upgrade: one package that cannot move (its new version
    would break an installed dependent, or needs something the catalog
    cannot give) is held back with its reason instead of blocking every
    other update -- apt's "kept back"."""
    accepted: list[str] = []
    kept: list[str] = []
    for target in targets:
        try:
            steps = plan_transaction(index, index_dir, installed, accepted + [target], mode="upgrade")
            problems = state_problems(index, installed, steps)
        except AlpError as exc:
            problems = [str(exc)]
        if problems:
            print(f"geri tutuldu: {target} ({'; '.join(problems)})")
            kept.append(target)
        else:
            accepted.append(target)
    return accepted, kept


def cmd_upgrade(args: argparse.Namespace, paths: Paths, index: dict, index_dir: Path) -> int:
    paths.ensure()
    with DbLock(paths.lock_file):
        db = load_db(paths)
        installed = db["packages"]
        name = getattr(args, "name", None)

        if name:
            if name not in installed:
                raise AlpError(f"Kurulu değil: {name}. 'alp upgrade' yalnız kurulu paketler içindir.")
            if name not in index["entries"]:
                raise AlpError(f"Bilinmeyen paket: {name!r}")
            if index["entries"][name]["method"] == "flatpak":
                raise AlpError(_FLATPAK_UPGRADE_MSG)
            targets = [name]
        else:
            targets, flatpaks, kept = [], [], []
            for pkg in sorted(installed):
                entry = index["entries"].get(pkg)
                if entry is None:
                    continue
                if entry["method"] == "flatpak":
                    flatpaks.append(pkg)
                elif vercmp(catalog_version(index, index_dir, pkg), installed[pkg]["version"]) > 0:
                    targets.append(pkg)
            if flatpaks:
                print(f"flatpak paketleri ({', '.join(flatpaks)}) için 'flatpak update' kullanın.")
            targets, kept = _drop_kept_back(index, index_dir, installed, targets)

        steps = plan_transaction(index, index_dir, installed, targets, mode="upgrade")
        if not steps:
            if name:
                print(f"{name} zaten güncel ({installed[name]['version']}).")
            else:
                print("Yükseltilebilecek başka paket yok." if kept else "Her şey güncel.")
            return 0

        _plan_or_refuse(index, installed, steps)
        _print_plan(steps, index)
        if not args.dry_run and not _confirm("Devam edilsin mi?", getattr(args, "yes", False)):
            print("İptal edildi, hiçbir şey değişmedi.")
            return 1
        _run_plan(steps, paths, index, index_dir, db, args.dry_run, explicit=set())
    return 0


def _remove_many(order: list[str], paths: Paths, db: dict, dry_run: bool) -> None:
    tag = "[dry-run] " if dry_run else ""
    for name in order:
        remove_package(paths, db, name, dry_run)
        if not dry_run:
            save_db(paths, db)
        print(f"{tag}{name} kaldırıldı.")


def cmd_remove(args: argparse.Namespace, paths: Paths, index: dict | None = None) -> int:
    index = index or {"entries": {}}
    paths.ensure()
    with DbLock(paths.lock_file):
        db = load_db(paths)
        installed = db["packages"]
        if args.name not in installed:
            raise AlpError(f"Kurulu değil: {args.name}")
        order = plan_remove(index, installed, [args.name], cascade=getattr(args, "cascade", False))
        if len(order) > 1:
            print("Birlikte kaldırılacak (önce bağımlı olanlar): " + ", ".join(order))
            if not args.dry_run and not _confirm("Devam edilsin mi?", getattr(args, "yes", False)):
                print("İptal edildi, hiçbir şey değişmedi.")
                return 1
        snapshot = dict(installed)
        _remove_many(order, paths, db, args.dry_run)
        _hint_orphans(index, snapshot if args.dry_run else db["packages"], set(order) if args.dry_run else set())
    return 0


def cmd_autoremove(args: argparse.Namespace, paths: Paths, index: dict) -> int:
    paths.ensure()
    with DbLock(paths.lock_file):
        db = load_db(paths)
        installed = db["packages"]
        orphans = find_orphans(index, installed)
        if not orphans:
            print("Kaldırılacak sahipsiz bağımlılık yok.")
            return 0
        order = plan_remove(index, installed, orphans, cascade=False)
        print("Sahipsiz bağımlılıklar kaldırılacak: " + ", ".join(order))
        if not args.dry_run and not _confirm("Devam edilsin mi?", getattr(args, "yes", False)):
            print("İptal edildi, hiçbir şey değişmedi.")
            return 1
        _remove_many(order, paths, db, args.dry_run)
    return 0


def cmd_check(paths: Paths, index: dict, index_dir: Path) -> int:
    installed = load_db(paths)["packages"]
    problems = state_problems(index, installed, [], only_touched=False)
    for name in sorted(installed):
        if name in index["entries"] and index["entries"][name]["method"] != "flatpak":
            offered = catalog_version(index, index_dir, name)
            if vercmp(offered, installed[name]["version"]) > 0:
                print(f"güncelleme var: {name} {installed[name]['version']} -> {offered}")
    orphans = find_orphans(index, installed)
    if orphans:
        print(f"sahipsiz bağımlılık: {', '.join(orphans)} (alp autoremove)")
    if problems:
        for p in problems:
            print(f"SORUN: {p}")
        return 1
    print(f"Bağımlılık tutarlılığı: sorun yok ({len(installed)} kurulu paket).")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="alp", description="alpbahOS hybrid package manager (prototype)")
    p.add_argument("--root", default=None, help="DESTROOT override for testing (default: /)")
    p.add_argument("--index", required=True, help="Path to the local package index.json")
    p.add_argument("--dry-run", action="store_true", help="Print intended actions, touch nothing persistent")
    p.add_argument("--json", action="store_true", help="Machine-readable JSON output for search/list (info is always JSON)")

    sub = p.add_subparsers(dest="command", required=True)

    sp = sub.add_parser("search", help="Search the index; installs nothing")
    sp.add_argument("term")

    sp = sub.add_parser("info", help="Show details for a package")
    sp.add_argument("name")

    yes = argparse.ArgumentParser(add_help=False)
    yes.add_argument("-y", "--yes", action="store_true", help="Do not ask for confirmation")

    sp = sub.add_parser("install", parents=[yes], help="Install a package and the catalog packages it depends on")
    sp.add_argument("name")
    sp.add_argument("--reinstall", action="store_true")

    sp = sub.add_parser("upgrade", parents=[yes],
                        help="Upgrade one installed package, or every outdated recipe/core package when no name is given")
    sp.add_argument("name", nargs="?")

    sp = sub.add_parser("remove", parents=[yes], help="Remove an installed package (refuses if others depend on it)")
    sp.add_argument("name")
    sp.add_argument("--cascade", action="store_true", help="Also remove installed packages that depend on it")

    sub.add_parser("autoremove", parents=[yes], help="Remove dependencies nothing needs anymore")
    sub.add_parser("check", help="Verify installed dependency constraints and conflicts")
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
            return cmd_search(index, args.term, as_json=args.json)
        if args.command == "info":
            paths.ensure()
            db = load_db(paths)
            return cmd_info(index, db, args.name)
        if args.command == "list":
            paths.ensure()
            return cmd_list(load_db(paths), as_json=args.json)
        if args.command == "update":
            print("Bu prototipte 'update' yereldeki index.json'ı yeniden okur; gerçek sistemde repo senkronize eder.")
            return 0
        if args.command == "install":
            return cmd_install(args, paths, index, index_dir)
        if args.command == "upgrade":
            return cmd_upgrade(args, paths, index, index_dir)
        if args.command == "remove":
            return cmd_remove(args, paths, index)
        if args.command == "autoremove":
            return cmd_autoremove(args, paths, index)
        if args.command == "check":
            paths.ensure()
            return cmd_check(paths, index, index_dir)
        raise AlpError(f"Bilinmeyen komut: {args.command}")
    except AlpError as exc:
        print(f"alp: hata: {exc}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as exc:
        print(f"alp: alt işlem başarısız (çıkış {exc.returncode}): {' '.join(exc.cmd)}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
