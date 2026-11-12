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
  - The catalog is signed (index.json + index.json.sig, checked with gpgv on
    every load) and pins every recipe by sha256; see "Catalog trust" below and
    design/trust-model.md.
  - A recipe's build commands are code execution by design. They run as the
    unprivileged build user inside bubblewrap, without network, and what they
    stage is checked by root before the merge; see "Build sandbox". A recipe
    we signed is still trusted for what it installs.
"""

from __future__ import annotations

import argparse
import contextlib
import difflib
import hashlib
import inspect
import json
import os
import posixpath
import pwd
import re
import shutil
import socket
import stat
import subprocess
import sys
import tarfile
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from pathlib import PurePosixPath

SCHEMA_VERSION = 1
ALP_VERSION = "0.1.0-proto"
DEFAULT_STATE_DIR = "var/lib/alp"
DEFAULT_LOG_DIR = "var/log/alp"
DOWNLOAD_TIMEOUT_S = 30
BASE_MANIFEST_SCHEMA = "alpbahOS.package-files/v1"
_SHA256_RE = re.compile(r"[0-9a-f]{64}\Z")
_PACKAGE_NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._+-]*\Z")


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
    keep_build: bool = False  # --keep-build: leave build/destdir trees in the cache
    relocate: bool = False  # --relocate: build recipes for <root>/usr instead of /usr
    progress: object = None  # --progress-fd: text stream for JSON-line progress events
    # How the catalog is accepted. Default: signed by an allowed key (see "Catalog trust").
    trust: "TrustPolicy" = field(default_factory=lambda: TrustPolicy())
    # "require": recipe steps run inside bubblewrap or not at all. "off" is the
    # engine-side form of --no-sandbox (root only, enforced in main()).
    sandbox: str = "require"
    # Test-only: numeric (uid, gid) to build as instead of looking up the
    # `alpbuild` user. No command-line option or environment variable sets it.
    build_ids: tuple | None = None
    jobs: int = 1  # --jobs: MAKEFLAGS=-j<jobs> inside the build environment

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


def _first_line(exc: BaseException) -> str:
    text = str(exc)
    return text.splitlines()[0] if text else type(exc).__name__


def _emit(paths: Paths, event: str, **fields) -> None:
    """One JSON line on the --progress-fd channel (design/packagekit-integration.md §4).
    Human messages stay on stdout/stderr; a store/PackageKit backend reads
    only this channel. A closed reader never breaks the transaction."""
    if paths.progress is None:
        return
    try:
        paths.progress.write(json.dumps({"event": event, **fields}, ensure_ascii=False) + "\n")
        paths.progress.flush()
    except (OSError, ValueError):
        paths.progress = None


# --------------------------------------------------------------------------
# Single-writer lock.
# CLAUDE.md: "Tek paket veri tabanı ve tek yazıcı/işlem kilidi kullan."
# --------------------------------------------------------------------------

def _pid_namespace() -> str:
    try:
        return os.readlink("/proc/self/ns/pid")
    except OSError:
        return "?"


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
    # A holder in another PID namespace (container) shares the hostname but
    # not the pid numbering: its pid proves nothing here.
    if fields.get("pidns") not in (None, _pid_namespace()):
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


_LOCK_PERMISSION_MSG = (
    "Bu işlem paket veritabanını değiştirir ve yönetici yetkisi ister; "
    "komutu başına 'sudo' ekleyerek çalıştırın (örnek: sudo alp install <paket>). "
    "Yazılamayan yer: {path}"
)


class DbLock:
    def __init__(self, lock_file: Path):
        self.lock_file = lock_file
        self._held = False

    def __enter__(self) -> "DbLock":
        try:
            self.lock_file.parent.mkdir(parents=True, exist_ok=True)
        except PermissionError as exc:
            raise AlpError(_LOCK_PERMISSION_MSG.format(path=self.lock_file.parent)) from exc
        for attempt in (1, 2):
            try:
                fd = os.open(str(self.lock_file), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                break
            except PermissionError as exc:
                raise AlpError(_LOCK_PERMISSION_MSG.format(path=self.lock_file)) from exc
            except FileExistsError as exc:
                holder = self._read_holder()
                if attempt == 1 and _lock_holder_is_dead(holder):
                    # Take the stale lock over atomically: rename it to a private
                    # name (only one racing process can win the rename), then
                    # check it is still the content we judged stale. If another
                    # process had already replaced it, put it back.
                    mine = self.lock_file.with_name(f"{self.lock_file.name}.stale.{os.getpid()}")
                    try:
                        os.rename(self.lock_file, mine)
                    except FileNotFoundError:
                        continue
                    try:
                        taken = mine.read_text(encoding="utf-8").strip()
                    except OSError:
                        taken = "?"
                    if taken == holder:
                        mine.unlink(missing_ok=True)
                        print(f"uyarı: sahibi çalışmayan eski kilit temizlendi ({holder})", file=sys.stderr)
                        continue
                    try:
                        os.link(mine, self.lock_file)  # fails if a new lock exists already
                    except OSError:
                        pass
                    mine.unlink(missing_ok=True)
                    raise AlpError(
                        f"Veritabanı kilitli, başka bir alp/mağaza işlemi sürüyor ({taken}). "
                        f"Kilit dosyası: {self.lock_file}"
                    ) from exc
                raise AlpError(
                    f"Veritabanı kilitli, başka bir alp/mağaza işlemi sürüyor ({holder}). "
                    f"Kilit dosyası: {self.lock_file}"
                ) from exc
        with os.fdopen(fd, "w") as f:
            f.write(f"pid={os.getpid()} host={socket.gethostname()} pidns={_pid_namespace()} ts={_now()}\n")
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
    try:
        with open(paths.db_file, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as exc:
        raise AlpError(f"Paket veritabanı okunamadı/bozuk ({paths.db_file}): {exc}") from exc
    if not isinstance(data, dict) or data.get("schema_version") != SCHEMA_VERSION:
        raise AlpError(f"Beklenmeyen db şema sürümü: {data.get('schema_version')!r}")
    return data


def _db_tmp(paths: Paths) -> Path:
    return paths.db_file.with_suffix(".json.tmp")


def _fsync_dir(path: Path) -> None:
    try:
        fd = os.open(str(path), os.O_RDONLY)
    except OSError:
        return
    try:
        os.fsync(fd)
    except OSError:
        pass
    finally:
        os.close(fd)


def stage_db(paths: Paths, db: dict) -> None:
    """Phase 1: write the new db next to the real one and fsync it. Nothing
    reads the staged file until publish_db() renames it."""
    db["updated_at"] = _now()
    tmp = _db_tmp(paths)
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2, ensure_ascii=False, sort_keys=True)
        f.flush()
        os.fsync(f.fileno())


def publish_db(paths: Paths) -> bool:
    """Phase 2: atomically make the staged db the real one. False when nothing was staged."""
    tmp = _db_tmp(paths)
    if not tmp.exists():
        return False
    tmp.replace(paths.db_file)  # atomic rename on the same filesystem
    _fsync_dir(paths.db_file.parent)
    return True


def discard_staged_db(paths: Paths) -> None:
    _db_tmp(paths).unlink(missing_ok=True)


def save_db(paths: Paths, db: dict) -> None:
    stage_db(paths, db)
    publish_db(paths)


def _base_manifest_relpath(raw: object) -> str:
    """Validate a captured absolute POSIX path and return its root-relative form.

    A backslash is an ordinary byte in a POSIX file name (systemd installs escaped unit
    names such as system-systemd\\x2dmute\\x2dconsole.slice), so it is allowed. NUL and line
    breaks are refused, and so are relative paths, empty, "." and ".." segments, which are
    the ways a path could leave the root.
    """
    if (not isinstance(raw, str) or not raw.startswith("/")
            or "\x00" in raw or "\n" in raw or "\r" in raw):
        raise AlpError(f"Geçersiz taban manifest yolu: {raw!r}")
    parts = raw[1:].split("/")
    if not parts or any(part in ("", ".", "..") for part in parts):
        raise AlpError(f"Normalize edilmemiş taban manifest yolu: {raw!r}")
    path = PurePosixPath(*parts)
    rel = path.as_posix()
    if rel.startswith("var/lib/alp/") or rel in ("var/lib/alp", "var/log/alp") or rel.startswith("var/log/alp/"):
        raise AlpError(f"alp veritabanı/log yolları taban paket sahipliğine alınamaz: {raw}")
    return rel


def _validate_base_manifest(path: Path, name: str, version: str, source_sha256: str,
                            expected_manifest_sha256: str | None) -> tuple[dict, str]:
    if not _PACKAGE_NAME_RE.fullmatch(name):
        raise AlpError(f"Geçersiz paket adı: {name!r}")
    if not isinstance(version, str) or not version or len(version) > 128 or any(c.isspace() for c in version):
        raise AlpError(f"Geçersiz paket sürümü: {version!r}")
    if not _SHA256_RE.fullmatch(source_sha256):
        raise AlpError("Kaynak SHA-256 değeri 64 küçük hex karakteri olmalı.")
    if expected_manifest_sha256 is not None and not _SHA256_RE.fullmatch(expected_manifest_sha256):
        raise AlpError("Manifest SHA-256 değeri 64 küçük hex karakteri olmalı.")
    try:
        raw_bytes = path.read_bytes()
        manifest_hash = hashlib.sha256(raw_bytes).hexdigest()
        if expected_manifest_sha256 and manifest_hash != expected_manifest_sha256:
            raise AlpError(f"Manifest SHA-256 uyuşmadı: beklenen {expected_manifest_sha256}, bulunan {manifest_hash}")
        manifest = json.loads(raw_bytes)
    except AlpError:
        raise
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise AlpError(f"Taban manifesti okunamadı/geçersiz JSON: {exc}") from exc
    if not isinstance(manifest, dict) or manifest.get("schema") != BASE_MANIFEST_SCHEMA:
        raise AlpError(f"Desteklenmeyen taban manifest şeması: {manifest.get('schema') if isinstance(manifest, dict) else type(manifest).__name__}")
    captured_at = manifest.get("captured_at")
    package = manifest.get("package")
    entries = manifest.get("entries")
    if not isinstance(captured_at, str) or not captured_at or not isinstance(package, dict) or not isinstance(entries, list):
        raise AlpError("Taban manifestinde captured_at, package ve entries alanları gerekli.")
    source = package.get("source")
    if (package.get("name") != name or package.get("version") != version or not isinstance(source, dict)
            or source.get("sha256") != source_sha256 or not isinstance(source.get("url"), str)
            or not source["url"].startswith("https://")):
        raise AlpError("Manifest paket adı/sürümü/kaynak URL/SHA-256, istenen kimlikle uyuşmuyor.")
    seen: set[str] = set()
    normalized: list[tuple[str, dict]] = []
    for entry in entries:
        if not isinstance(entry, dict):
            raise AlpError("Manifest entries içindeki kayıt nesne olmalı.")
        rel = _base_manifest_relpath(entry.get("path"))
        if rel in seen:
            raise AlpError(f"Manifest aynı yolu birden çok kez içeriyor: {rel}")
        seen.add(rel)
        if (type(entry.get("uid")) is not int or entry["uid"] < 0
                or type(entry.get("gid")) is not int or entry["gid"] < 0):
            raise AlpError(f"Manifest uid/gid alanları geçersiz: {rel}")
        kind = entry.get("type")
        if kind == "directory":
            normalized.append((rel, entry))
            continue
        if kind == "file":
            if (not isinstance(entry.get("sha256"), str) or not _SHA256_RE.fullmatch(entry["sha256"])
                    or type(entry.get("size")) is not int or entry["size"] < 0):
                raise AlpError(f"Manifest dosya özeti geçersiz: {rel}")
        elif kind == "symlink":
            if not isinstance(entry.get("target"), str) or not entry["target"] or "\x00" in entry["target"]:
                raise AlpError(f"Manifest symlink hedefi geçersiz: {rel}")
        else:
            raise AlpError(f"Desteklenmeyen manifest dosya türü ({kind!r}): {rel}")
        if type(entry.get("mode")) is not int or entry["mode"] < 0 or entry["mode"] > 0o7777:
            raise AlpError(f"Manifest dosya modu geçersiz: {rel}")
        normalized.append((rel, entry))
    if not normalized:
        raise AlpError("Boş taban manifesti kabul edilmez.")
    return {"captured_at": captured_at, "package": package, "entries": normalized}, manifest_hash


def _verify_base_entry(root: Path, rel: str, entry: dict) -> None:
    target = root.joinpath(*rel.split("/"))
    # Do not follow an unexpected symlink in a parent directory: an apparently
    # in-root manifest path must not escape or alias another owned path.
    cursor = root
    for part in rel.split("/")[:-1]:
        cursor = cursor / part
        if cursor.is_symlink() or not cursor.is_dir():
            raise AlpError(f"Manifest polusunun üst dizini normal dizin değil: {rel}")
    kind = entry["type"]
    if kind == "directory":
        if target.is_symlink() or not target.is_dir():
            raise AlpError(f"Canlı rootfs dizin türü uyuşmuyor: /{rel}")
        return
    if kind == "symlink":
        if not target.is_symlink() or os.readlink(target) != entry["target"]:
            raise AlpError(f"Canlı rootfs symlink hedefi uyuşmuyor: /{rel}")
    else:
        if target.is_symlink() or not target.is_file():
            raise AlpError(f"Canlı rootfs dosya türü uyuşmuyor: /{rel}")
        if target.stat().st_size != entry["size"] or sha256_of(target) != entry["sha256"]:
            raise AlpError(f"Canlı rootfs dosya içeriği uyuşmuyor: /{rel}")
    if stat.S_IMODE(target.lstat().st_mode) != entry["mode"]:
        raise AlpError(f"Canlı rootfs modu uyuşmuyor: /{rel}")
    live_stat = target.lstat()
    if live_stat.st_uid != entry["uid"] or live_stat.st_gid != entry["gid"]:
        raise AlpError(f"Canlı rootfs sahibi/grubu uyuşmuyor: /{rel}")


def cmd_adopt_base(args: argparse.Namespace, paths: Paths) -> int:
    """Adopt live files from a manifest after the caller independently verifies its source.

    The manifest binds exact rootfs paths and hashes; it cannot prove source
    authenticity by itself. Callers must independently verify the source
    archive and manifest, then pass the verified source SHA and (optionally)
    expected manifest SHA here.
    """
    manifest, manifest_hash = _validate_base_manifest(
        Path(args.manifest), args.name, args.version, args.source_sha256,
        getattr(args, "manifest_sha256", None),
    )
    paths.ensure()
    with DbLock(paths.lock_file):
        _require_no_pending(paths)
        db = load_db(paths)
        packages = db["packages"]
        existing = packages.get(args.name)
        if existing is not None and not (
            existing.get("method") == "lfs-base"
            and existing.get("ownership", {}).get("manifest_sha256") == manifest_hash
            and existing.get("source", {}).get("sha256") == args.source_sha256
            and existing.get("version") == args.version
        ):
            raise AlpError(f"{args.name} zaten farklı bir kayıtla kurulu; taban sahipliği üzerine yazılmadı.")
        claims = _other_owners(db, exclude=args.name)
        files: list[str] = []
        symlinks: list[str] = []
        for rel, entry in manifest["entries"]:
            _verify_base_entry(paths.root, rel, entry)
            if entry["type"] == "directory":
                continue  # shared parents are validated, never claimed/removable
            if _owner_key(rel) in claims:
                raise AlpError(f"/{rel} zaten {claims[_owner_key(rel)]} paketine ait; sahiplik çakışması.")
            (symlinks if entry["type"] == "symlink" else files).append(rel)
        record = {
            "name": args.name,
            "version": args.version,
            "method": "lfs-base",
            "status": "installed",
            "installed_at": existing.get("installed_at", _now()) if existing else _now(),
            "installed_by": "alp/adopt-base",
            "source": {"url": manifest["package"]["source"]["url"], "sha256": args.source_sha256},
            "files": sorted(files),
            "symlinks": sorted(symlinks),
            "config_files": [],
            "config_hashes": {},
            "depends": [],
            "conflicts": [],
            "reason": "explicit",
            "protected": True,
            "ownership": {
                "manifest_schema": BASE_MANIFEST_SCHEMA,
                "manifest_sha256": manifest_hash,
                "captured_at": manifest["captured_at"],
            },
        }
        if existing is not None:
            if existing == record:
                print(f"{args.name} {args.version} taban sahipliği zaten kayıtlı ({manifest_hash}).")
                return 0
            raise AlpError(f"{args.name} için aynı manifestli korumalı kayıt var, ancak kayıt alanları değişmiş; üzerine yazılmadı.")
        if getattr(args, "dry_run", False):
            print("[dry-run] aşağıdaki korumalı taban paket kaydı eklenecekti; veritabanı değiştirilmedi:")
            print(json.dumps(record, indent=2, ensure_ascii=False, sort_keys=True))
            return 0
        packages[args.name] = record
        save_db(paths, db)
    print(f"{args.name} {args.version} taban sahipliği kaydedildi; {len(files)} dosya, {len(symlinks)} symlink, dizin sahipliği yok.")
    return 0


# --------------------------------------------------------------------------
# Index: the catalog alp installs from (stand-in for "our GitHub repository").
# --------------------------------------------------------------------------

def load_index(index_path: Path) -> dict:
    try:
        with open(index_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as exc:
        raise AlpError(f"Katalog dizini okunamadı/geçersiz JSON ({index_path}): {exc}") from exc
    if not isinstance(data, dict) or not isinstance(data.get("entries"), dict):
        raise AlpError(f"Katalog dizininde 'entries' tablosu yok: {index_path}")
    return data


# --------------------------------------------------------------------------
# Catalog trust (design/trust-model.md; DECISIONS D170, D171, D172, D173).
#
# index.json carries a detached OpenPGP signature, index.json.sig. The bytes
# that are parsed are the bytes that were verified: both files are read once
# into memory, gpgv gets the data on stdin and the signature and the keyring
# through anonymous file descriptors, and the JSON parser then runs on the
# very same bytes object. No path is verified and then opened again.
#
# The signed index pins every recipe file by sha256 (recipe_sha256), recipes
# pin their source archive, core entries pin their archive: one signature
# covers index -> recipe -> source.
#
# Trust anchors (keyring, allowed.txt) come from the system that RUNS alp,
# never from --root and never from an environment variable. They can be
# redirected only by /etc/alp/trust.conf (root-owned) or by --keyring /
# --allowed-keys on the command line.
#
# load_index() above stays the raw JSON reader. It does not verify anything
# and main() does not use it; the entry points that take catalog bytes from
# disk or the network are load_catalog() and cmd_update().
# --------------------------------------------------------------------------

SYSTEM_KEYRING = "/usr/share/alp/keys/alpbahos-catalog.gpg"
SYSTEM_ALLOWED_KEYS = "/usr/share/alp/keys/allowed.txt"
SYSTEM_TRUST_CONFIG = "/etc/alp/trust.conf"
SIGNATURE_SUFFIX = ".sig"
# Fixed locations: a PATH from the caller's environment must not choose the
# program that decides whether a signature is good.
GPGV_CANDIDATES = ("/usr/bin/gpgv", "/bin/gpgv")
GPGV_TIMEOUT_S = 30
MAX_SIGNATURE_BYTES = 64 * 1024
MAX_TRUST_FILE_BYTES = 4 * 1024 * 1024
_FINGERPRINT_RE = re.compile(r"(?:[0-9A-F]{40}|[0-9A-F]{64})\Z")
_ISO_DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}\Z")
# OpenPGP hash algorithm ids accepted for the catalog signature: SHA-256, SHA-384, SHA-512.
_SIG_HASH_ALGOS = frozenset({"8", "9", "10"})
_GPGV_BAD_STATUS = frozenset({
    "BADSIG", "ERRSIG", "EXPSIG", "EXPKEYSIG", "REVKEYSIG", "NODATA", "UNEXPECTED", "FAILURE",
})


class CatalogTrustError(AlpError):
    """The catalog (or a recipe it names) failed a trust check."""


@dataclass(frozen=True)
class TrustPolicy:
    """How a catalog is accepted. The default is the strict one: a valid
    signature by an allowed key from the system keyring.

    `keyring` / `allowed_keys` empty means "the configured or built-in system
    path". `allow_unsigned` is the engine-side form of --allow-unsigned;
    main() is where the root-only rule for that flag is enforced, and no
    configuration file or environment variable can set it.
    """
    keyring: str = ""
    allowed_keys: str = ""
    allow_unsigned: bool = False


def _is_root() -> bool:
    return hasattr(os, "geteuid") and os.geteuid() == 0


def _read_trust_file(path: str, what: str, *, must_be_root_owned: bool) -> bytes:
    """Read a trust anchor once. The final path component may not be a
    symlink, the file must be a regular file and, when alp runs as root (or
    always, for the configuration file), owned by root and not writable by
    group or others."""
    if not os.path.isabs(path):
        raise CatalogTrustError(f"{what} yolu mutlak olmalı: {path}")
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
    try:
        fd = os.open(path, flags)
    except OSError as exc:
        raise CatalogTrustError(f"{what} okunamadı ({path}): {exc.strerror or exc}") from exc
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode):
            raise CatalogTrustError(f"{what} normal dosya değil: {path}")
        if must_be_root_owned and hasattr(os, "geteuid"):
            if st.st_uid != 0 or st.st_mode & 0o022:
                raise CatalogTrustError(
                    f"{what} root'a ait ve yalnız root tarafından yazılabilir olmalı: {path} "
                    f"(sahip uid {st.st_uid}, izin {stat.S_IMODE(st.st_mode):04o})"
                )
        if st.st_size > MAX_TRUST_FILE_BYTES:
            raise CatalogTrustError(f"{what} beklenmedik kadar büyük: {path}")
        chunks = []
        while True:
            chunk = os.read(fd, 1 << 16)
            if not chunk:
                break
            chunks.append(chunk)
        return b"".join(chunks)
    finally:
        os.close(fd)


def _load_trust_config() -> dict[str, str]:
    """/etc/alp/trust.conf: `keyring = /abs/path` and `allowed_keys = /abs/path`.

    Nothing else is accepted. In particular there is no key that switches
    signature checking or the build sandbox off, so neither can be made
    permanent. The file must belong to root whoever runs alp."""
    path = SYSTEM_TRUST_CONFIG
    if not os.path.lexists(path):
        return {}
    raw = _read_trust_file(path, "alp güven yapılandırması", must_be_root_owned=True)
    out: dict[str, str] = {}
    for number, line in enumerate(raw.decode("utf-8", errors="replace").splitlines(), 1):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        key, sep, value = line.partition("=")
        key, value = key.strip(), value.strip()
        if not sep or key not in ("keyring", "allowed_keys") or not os.path.isabs(value) or key in out:
            raise CatalogTrustError(
                f"{path}:{number}: geçersiz satır. Yalnız 'keyring = /yol' ve 'allowed_keys = /yol' "
                "yazılabilir; imza denetimi ya da derleme korumalı alanı buradan kapatılamaz."
            )
        out[key] = value
    return out


def _trust_paths(policy: TrustPolicy) -> tuple[str, str]:
    """(keyring, allowed.txt): command line, then /etc/alp/trust.conf, then the built-in paths."""
    config = _load_trust_config() if not (policy.keyring and policy.allowed_keys) else {}
    keyring = policy.keyring or config.get("keyring") or SYSTEM_KEYRING
    allowed = policy.allowed_keys or config.get("allowed_keys") or SYSTEM_ALLOWED_KEYS
    return os.path.abspath(keyring), os.path.abspath(allowed)


@dataclass(frozen=True)
class AllowedKeys:
    allowed: frozenset
    revoked: frozenset
    keyring_version: int | None


def parse_allowed_keys(raw: bytes, origin: str) -> AllowedKeys:
    """allowed.txt, one statement per line:

        # comment
        keyring-version 3
        0123...CDEF            primary-key fingerprint that may sign catalogs
        revoked 0123...CDEF    fingerprint (primary key or signing subkey) that may not

    Fingerprints are 40 or 64 hex digits without spaces. A line that is none
    of these is an error: a typo must not silently drop a revocation."""
    allowed: set[str] = set()
    revoked: set[str] = set()
    version: int | None = None
    try:
        text = raw.decode("ascii")
    except UnicodeDecodeError as exc:
        raise CatalogTrustError(f"{origin}: yalnız ASCII olmalı.") from exc
    for number, line in enumerate(text.splitlines(), 1):
        words = line.split("#", 1)[0].split()
        if not words:
            continue
        if len(words) == 1 and _FINGERPRINT_RE.fullmatch(words[0].upper()):
            allowed.add(words[0].upper())
        elif len(words) == 2 and words[0] == "revoked" and _FINGERPRINT_RE.fullmatch(words[1].upper()):
            revoked.add(words[1].upper())
        elif len(words) == 2 and words[0] == "keyring-version" and words[1].isdigit() and version is None:
            version = int(words[1])
        else:
            raise CatalogTrustError(f"{origin}:{number}: anlaşılmayan satır; anahtar listesi kullanılmadı.")
    return AllowedKeys(frozenset(allowed), frozenset(revoked), version)


def _find_fixed_program(candidates: tuple[str, ...]) -> str | None:
    for candidate in candidates:
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


def _anonymous_fd(data: bytes, label: str) -> int:
    """An inheritable descriptor holding `data`, with no name in any directory
    another process could swap."""
    if hasattr(os, "memfd_create"):
        fd = os.memfd_create(label)
    else:  # pragma: no cover - non-Linux fallback
        import tempfile
        with tempfile.TemporaryFile() as tmp:
            fd = os.dup(tmp.fileno())
    try:
        view = memoryview(data)
        while view:
            view = view[os.write(fd, view):]
        os.lseek(fd, 0, os.SEEK_SET)
    except BaseException:
        os.close(fd)
        raise
    return fd


@dataclass(frozen=True)
class SignatureInfo:
    signing_fingerprint: str
    primary_fingerprint: str
    keyring_version: int | None


def _parse_gpgv_status(status: bytes, returncode: int) -> tuple[str, str]:
    """Strict reading of `gpgv --status-fd` output. Returns (signing key
    fingerprint, primary key fingerprint) of the one good signature, or
    raises. The exit code is checked too, but never trusted alone."""
    counts: dict[str, int] = {}
    validsig: list[str] | None = None
    for raw_line in status.split(b"\n"):
        if not raw_line.strip():
            continue
        try:
            line = raw_line.decode("ascii")
        except UnicodeDecodeError:
            line = raw_line.decode("utf-8", errors="replace")
        if not line.startswith("[GNUPG:] "):
            raise CatalogTrustError("gpgv beklenmeyen bir çıktı verdi; imza kabul edilmedi.")
        words = line[len("[GNUPG:] "):].split()
        if not words:
            raise CatalogTrustError("gpgv beklenmeyen bir çıktı verdi; imza kabul edilmedi.")
        counts[words[0]] = counts.get(words[0], 0) + 1
        if words[0] == "VALIDSIG":
            validsig = words[1:]
    bad = sorted(k for k in counts if k in _GPGV_BAD_STATUS)
    if bad:
        reason = {
            "BADSIG": "imza katalogla uyuşmuyor (katalog ya da imza değiştirilmiş)",
            "ERRSIG": "imzayı atan anahtar anahtarlıkta yok ya da imza denetlenemedi",
            "EXPSIG": "imzanın süresi dolmuş",
            "EXPKEYSIG": "imzayı atan anahtarın süresi dolmuş",
            "REVKEYSIG": "imzayı atan anahtar iptal edilmiş",
        }.get(bad[0], f"gpgv durumu {bad[0]}")
        raise CatalogTrustError(f"Katalog imzası geçersiz: {reason}.")
    if counts.get("NEWSIG", 0) > 1 or counts.get("GOODSIG", 0) != 1 or counts.get("VALIDSIG", 0) != 1:
        raise CatalogTrustError(
            "Katalog imzası geçersiz: tam olarak bir geçerli imza bekleniyordu "
            f"(GOODSIG {counts.get('GOODSIG', 0)}, VALIDSIG {counts.get('VALIDSIG', 0)})."
        )
    if returncode != 0:
        raise CatalogTrustError(f"Katalog imzası geçersiz: gpgv {returncode} koduyla çıktı.")
    # VALIDSIG <fpr> <date> <timestamp> <expire> <version> <reserved> <pubkey-algo> <hash-algo> <class> <primary-fpr>
    if validsig is None or len(validsig) < 10:
        raise CatalogTrustError("Katalog imzası geçersiz: VALIDSIG satırı eksik alanlı.")
    signing, hash_algo, sig_class, primary = validsig[0].upper(), validsig[7], validsig[8], validsig[9].upper()
    if not _FINGERPRINT_RE.fullmatch(signing) or not _FINGERPRINT_RE.fullmatch(primary):
        raise CatalogTrustError("Katalog imzası geçersiz: parmak izi okunamadı.")
    if sig_class != "00":
        # A text-mode signature (class 01) ignores line-ending changes, so the
        # verified bytes would not be exactly the bytes that are parsed.
        raise CatalogTrustError("Katalog imzası geçersiz: ikili (binary) belge imzası değil.")
    if hash_algo not in _SIG_HASH_ALGOS:
        raise CatalogTrustError("Katalog imzası geçersiz: zayıf özet algoritması.")
    return signing, primary


def verify_catalog_signature(data: bytes, signature: bytes, policy: TrustPolicy) -> SignatureInfo:
    """Check `signature` over exactly `data`. Returns who signed, or raises CatalogTrustError."""
    if len(signature) > MAX_SIGNATURE_BYTES:
        raise CatalogTrustError("Katalog imza dosyası beklenmedik kadar büyük; kabul edilmedi.")
    keyring_path, allowed_path = _trust_paths(policy)
    keys = parse_allowed_keys(
        _read_trust_file(allowed_path, "İzinli anahtar listesi", must_be_root_owned=_is_root()), allowed_path)
    keyring = _read_trust_file(keyring_path, "Katalog anahtarlığı", must_be_root_owned=_is_root())
    gpgv = _find_fixed_program(GPGV_CANDIDATES)
    if gpgv is None:
        raise CatalogTrustError(
            "gpgv bulunamadı (" + ", ".join(GPGV_CANDIDATES) + "); katalog imzası denetlenemedi, katalog kabul edilmedi."
        )
    sig_fd = _anonymous_fd(signature, "alp-catalog-sig")
    try:
        key_fd = _anonymous_fd(keyring, "alp-catalog-keyring")
    except BaseException:
        os.close(sig_fd)
        raise
    try:
        done = subprocess.run(
            [gpgv, "--status-fd", "1", "--homedir", "/nonexistent-alp-gnupg",
             "--keyring", f"/dev/fd/{key_fd}", f"/dev/fd/{sig_fd}", "-"],
            input=data, capture_output=True, pass_fds=(sig_fd, key_fd), timeout=GPGV_TIMEOUT_S,
            env={"LC_ALL": "C", "PATH": "/usr/bin:/bin"}, cwd="/",
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise CatalogTrustError(f"gpgv çalıştırılamadı; katalog kabul edilmedi: {_first_line(exc)}") from exc
    finally:
        os.close(sig_fd)
        os.close(key_fd)
    signing, primary = _parse_gpgv_status(done.stdout, done.returncode)
    if signing in keys.revoked or primary in keys.revoked:
        raise CatalogTrustError(f"Katalog imzası geçersiz: imzalayan anahtar iptal listesinde ({primary}).")
    if primary not in keys.allowed:
        raise CatalogTrustError(
            f"Katalog imzası geçersiz: imzalayan anahtar izinli listede değil ({primary})."
        )
    return SignatureInfo(signing, primary, keys.keyring_version)


class SignedEntry(dict):
    """A package entry of a catalog that was accepted with a valid
    signature. The type is the mark read_recipe() looks at: for such an
    entry a missing recipe_sha256 is a refusal, never "nothing to check"."""


class Catalog(dict):
    """A catalog that passed load_catalog()/cmd_update(): the parsed index
    plus how it was accepted. Code that only reads entries treats it as the
    plain dict it always was."""
    signed: bool = False
    signer: str | None = None
    catalog_version: int | None = None
    valid_until: str | None = None
    expired: bool = False


def _warn_unsigned(origin: str) -> None:
    red, reset = ("\033[1;31m", "\033[0m") if sys.stderr.isatty() and not os.environ.get("NO_COLOR") else ("", "")
    print(
        f"{red}alp: UYARI: İMZASIZ KATALOG kullanılıyor ({origin}). --allow-unsigned yalnız geliştirme ve "
        f"test içindir; bu katalogdaki her tarif doğrulanmadan çalıştırılır.{reset}",
        file=sys.stderr,
    )


def _today_utc() -> str:
    return time.strftime("%Y-%m-%d", time.gmtime())


def _signed_int(index: dict, key: str) -> int:
    value = index.get(key)
    if type(value) is not int or value < 0:
        raise CatalogTrustError(f"İmzalı katalogda '{key}' alanı yok ya da negatif olmayan tam sayı değil.")
    return value


def stored_catalog_version(db: dict) -> int | None:
    """catalog_version of the last signed catalog this system accepted, or None."""
    value = (db.get("catalog") or {}).get("version") if isinstance(db.get("catalog"), dict) else None
    return value if type(value) is int and value >= 0 else None


def _note_accepted_catalog(db: dict, index: dict) -> bool:
    """Raise the stored high-water mark to a signed catalog's version (in
    memory; the caller's two-phase database write makes it durable). Unsigned
    catalogs never move it: their catalog_version is not authenticated."""
    if not getattr(index, "signed", False) or index.catalog_version is None:
        return False
    stored = stored_catalog_version(db)
    if stored is not None and stored >= index.catalog_version:
        return False
    db["catalog"] = {"version": index.catalog_version, "signer": index.signer, "accepted_at": _now()}
    return True


def accept_catalog_bytes(
    data: bytes, signature: bytes | None, policy: TrustPolicy, *,
    origin: str, at_update: bool, floor: int | None, today: str | None = None,
) -> Catalog:
    """Turn catalog bytes into a Catalog, or raise. `today` (YYYY-MM-DD) is
    a parameter for tests only; nothing on the command line or in the
    environment sets it.

    Rules (design/trust-model.md 3.3; D171, D172):
      1. A signature must be present, good, and made by an allowed, unrevoked key.
      2. catalog_version must not be lower than `floor`, the highest version
         this system has accepted.
      3. valid_until in the past: refused when this is a new catalog being
         fetched (`at_update`); for the catalog already on disk it is a
         warning, so an installed system can still install offline.
      4. Every recipe entry carries recipe_sha256.
    Without a signature the catalog is accepted only under
    policy.allow_unsigned, with a warning every time, and rules 2-4 do not
    apply (nothing in it is authenticated).
    """
    if signature is None:
        if not policy.allow_unsigned:
            raise CatalogTrustError(
                f"Katalog imzalı değil ({origin}{SIGNATURE_SUFFIX} yok); kabul edilmedi. "
                "alpbahOS katalogları imzalıdır: 'alp update' ile yenileyin."
            )
        _warn_unsigned(origin)
        info = None
    else:
        # A signature that is present is always checked, --allow-unsigned or
        # not: a bad signature is evidence of tampering, not of a dev catalog.
        info = verify_catalog_signature(data, signature, policy)
    try:
        index = json.loads(data.decode("utf-8"))
    except (ValueError, UnicodeError) as exc:
        raise AlpError(f"Katalog dizini okunamadı/geçersiz JSON ({origin}): {exc}") from exc
    if not isinstance(index, dict) or not isinstance(index.get("entries"), dict):
        raise AlpError(f"Katalog dizininde 'entries' tablosu yok: {origin}")
    catalog = Catalog(index)
    if info is None:
        return catalog

    version = _signed_int(index, "catalog_version")
    wanted_keyring = _signed_int(index, "signed_keyring_version")
    valid_until = index.get("valid_until")
    if not isinstance(valid_until, str) or not _ISO_DATE_RE.fullmatch(valid_until):
        raise CatalogTrustError("İmzalı katalogda 'valid_until' alanı yok ya da YYYY-AA-GG biçiminde değil.")
    try:
        time.strptime(valid_until, "%Y-%m-%d")
    except ValueError as exc:
        raise CatalogTrustError(f"İmzalı katalogda 'valid_until' geçerli bir tarih değil: {valid_until}") from exc
    for name, entry in index["entries"].items():
        # Any entry that names a recipe file, whatever its method says:
        # read_recipe() reads the file of every entry that has the field.
        if isinstance(entry, dict) and ("recipe" in entry or entry.get("method") == "recipe"):
            digest = entry.get("recipe_sha256")
            if not isinstance(digest, str) or not _SHA256_RE.fullmatch(digest):
                raise CatalogTrustError(
                    f"İmzalı katalogda {name!r} tarifi için 'recipe_sha256' yok ya da geçersiz; katalog kabul edilmedi."
                )
    if floor is not None and version < floor:
        raise CatalogTrustError(
            f"Katalog sürümü geri gidiyor: bu katalog {version}, bu sistemin son kabul ettiği {floor}. "
            "Eski bir katalog yeniden sunulmuş olabilir; kabul edilmedi."
        )
    expired = valid_until < (today or _today_utc())  # ISO dates compare as text
    if expired and at_update:
        raise CatalogTrustError(
            f"Yeni kataloğun süresi dolmuş (geçerlilik sonu {valid_until}); kabul edilmedi. "
            "Kaynak eski bir kataloğu sunuyor olabilir."
        )
    if expired:
        print(
            f"alp: UYARI: katalog süresi doldu (geçerlilik sonu {valid_until}); güvenlik güncellemeleri "
            "eksik olabilir. Bağlantı olduğunda `alp update` çalıştırın.",
            file=sys.stderr,
        )
    if info.keyring_version is not None and wanted_keyring > info.keyring_version:
        print(
            f"alp: bilgi: bu katalog anahtarlık sürümü {wanted_keyring} bekliyor, kurulu olan "
            f"{info.keyring_version}. Önce anahtarlık paketini yükseltin: alp upgrade alp-keyring",
            file=sys.stderr,
        )
    for name, entry in list(catalog["entries"].items()):
        if isinstance(entry, dict):
            catalog["entries"][name] = SignedEntry(entry)
    catalog.signed = True
    catalog.signer = info.primary_fingerprint
    catalog.catalog_version = version
    catalog.valid_until = valid_until
    catalog.expired = expired
    return catalog


def _read_optional(path: Path, limit: int) -> bytes | None:
    try:
        with open(path, "rb") as f:
            data = f.read(limit + 1)
    except FileNotFoundError:
        return None
    if len(data) > limit:
        raise CatalogTrustError(f"Dosya beklenmedik kadar büyük: {path}")
    return data


def load_catalog(index_path: Path, paths: "Paths") -> Catalog:
    """Read, verify and parse the local catalog. Every command that uses the
    catalog goes through here, on every run (design 3.4)."""
    try:
        data = index_path.read_bytes()
    except OSError as exc:
        raise AlpError(f"Katalog dizini okunamadı/geçersiz JSON ({index_path}): {exc}") from exc
    try:
        signature = _read_optional(index_path.with_name(index_path.name + SIGNATURE_SUFFIX), MAX_SIGNATURE_BYTES)
    except OSError as exc:
        raise CatalogTrustError(f"Katalog imza dosyası okunamadı: {exc}") from exc
    floor = stored_catalog_version(load_db(paths)) if signature is not None else None
    return accept_catalog_bytes(
        data, signature, paths.trust, origin=str(index_path), at_update=False, floor=floor,
    )


def _check_recipe_hash(entry: dict, raw: bytes, origin: str) -> None:
    """recipe_sha256 from the (signed) index must match the recipe bytes
    about to be parsed. "No digest, nothing to check" holds only for an
    entry of a catalog that was accepted unsigned (or a dict a caller built
    itself). An entry of a signed catalog (SignedEntry) without a digest is
    refused here as well as at load (rule 4 of accept_catalog_bytes)."""
    wanted = entry.get("recipe_sha256")
    if wanted is None:
        if isinstance(entry, SignedEntry):
            raise CatalogTrustError(
                f"İmzalı katalog girdisinde 'recipe_sha256' yok ({origin}); tarif okunmadı."
            )
        return
    actual = hashlib.sha256(raw).hexdigest()
    if not isinstance(wanted, str) or actual != wanted.lower():
        raise CatalogTrustError(
            f"Tarif dosyası katalogdaki özetle uyuşmuyor ({origin}):\n  beklenen : {wanted}\n  hesaplanan: {actual}\n"
            "Tarif değiştirilmiş olabilir; okunmadı."
        )


def read_recipe(entry: dict, index_dir: Path) -> dict:
    """The one place a recipe file is read: bytes once, hash check, then the
    same bytes are parsed."""
    path = index_dir / entry["recipe"]
    raw = path.read_bytes()
    _check_recipe_hash(entry, raw, str(path))
    recipe = json.loads(raw.decode("utf-8"))
    if not isinstance(recipe, dict):
        raise ValueError(f"tarif bir JSON nesnesi değil: {path}")
    return recipe


# --------------------------------------------------------------------------
# Download + mandatory checksum verification.
# CLAUDE.md: "Kaynağı doğrulamadan derleme yapma."
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


def _download_raw(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if url.startswith(("http://", "https://")):
        try:
            with urllib.request.urlopen(url, timeout=DOWNLOAD_TIMEOUT_S) as resp, open(dest, "wb") as out:  # noqa: S310
                shutil.copyfileobj(resp, out)
        except OSError as exc:
            raise AlpError(f"İndirme başarısız ({DOWNLOAD_TIMEOUT_S}s zaman aşımı dahil): {url}\n  {exc}") from exc
    else:
        shutil.copyfile(url, dest)


def fetch(url: str, dest: Path, expected_sha256: str) -> None:
    _download_raw(url, dest)

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
    chroot, alpbah-builder VM): shutil.copyfile() copies file *content* only, never
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
    tmp = _tmp_name(dst)
    if os.path.lexists(tmp):
        tmp.unlink()
    try:
        shutil.copyfile(src, tmp)
        shutil.copymode(src, tmp)
        os.replace(tmp, dst)
    except BaseException:
        tmp.unlink(missing_ok=True)  # never leave a half-written sibling behind
        raise


def _tmp_name(dst: Path) -> Path:
    return dst.with_name(f".{dst.name}.alp-tmp")


# --------------------------------------------------------------------------
# Rollback journal. Every filesystem change an install, upgrade or removal
# makes is logged *before* it happens, together with a backup of whatever it
# is about to replace or delete. An error halfway through -- full disk, I/O
# error, Ctrl-C -- then puts every file back. The log is a file, so a process
# killed mid-transaction (kill -9) can still be undone with `alp recover`.
#
# Backups are hard links (same inode, no data copied) with a copy fallback;
# they live under var/lib/alp/rollback/, on the same filesystem as the state.
# --------------------------------------------------------------------------

ROLLBACK_DIR = "rollback"
JOURNAL_NAME = "journal.jsonl"


class FileJournal:
    def __init__(self, backup_dir: Path):
        self.dir = backup_dir
        self.log_file = backup_dir / JOURNAL_NAME
        self._seen: set[str] = set()
        self._count = 0
        self._fh = None

    def _record(self, entry: list) -> None:
        if self._fh is None:
            self.dir.mkdir(parents=True, exist_ok=True)
            self._fh = open(self.log_file, "a", encoding="utf-8")
        self._fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
        self._fh.flush()

    def close(self) -> None:
        if self._fh is not None:
            self._fh.close()
            self._fh = None

    def commit(self) -> None:
        """Mark the transaction as complete (after the db was saved). A crash
        after this point must not be rolled back by `alp recover`."""
        self._record(["commit"])

    def _backup(self, path: Path, for_write: bool) -> None:
        key = str(path)
        if key in self._seen:
            return
        self._seen.add(key)
        if not os.path.lexists(path):
            if for_write:
                self._record(["created", key])
            return
        if path.is_symlink():
            self._record(["symlink", key, os.readlink(path)])
        elif path.is_dir():
            if not for_write:  # about to rmdir an empty directory
                self._record(["dir", key, stat.S_IMODE(path.stat().st_mode)])
        else:
            self._count += 1
            slot = self.dir / "files" / str(self._count)
            slot.parent.mkdir(parents=True, exist_ok=True)
            try:
                os.link(path, slot)
            except OSError:
                shutil.copy2(path, slot)
            self._record(["file", key, str(slot)])

    def will_write(self, path: Path) -> None:
        """Call before creating or overwriting a file or symlink."""
        self._backup(path, for_write=True)

    def will_remove(self, path: Path) -> None:
        """Call before deleting a file, symlink or empty directory."""
        self._backup(path, for_write=False)

    def will_mkdir(self, path: Path) -> None:
        self._backup(path, for_write=True)


def undo_journal(log_file: Path) -> list[str]:
    """Replay a journal backwards; returns the failures (empty = everything
    was restored). A journal that reached its commit marker is left alone."""
    entries: list[list] = []
    try:
        with open(log_file, "r", encoding="utf-8") as f:
            for line in f:
                try:
                    entries.append(json.loads(line))
                except ValueError:
                    continue  # truncated last line of a killed process
    except FileNotFoundError:
        return []
    if any(e and e[0] == "commit" for e in entries):
        return []
    failures: list[str] = []
    for entry in reversed(entries):
        kind, path = entry[0], Path(entry[1])
        try:
            if kind == "created":
                if path.is_symlink() or path.is_file():
                    path.unlink()
                elif path.is_dir():
                    with contextlib.suppress(OSError):
                        path.rmdir()  # foreign files inside keep the directory
            elif kind == "symlink":
                if os.path.lexists(path):
                    path.unlink()
                os.symlink(entry[2], path)
            elif kind == "file":
                slot = Path(entry[2])
                path.parent.mkdir(parents=True, exist_ok=True)
                try:
                    os.replace(slot, path)
                except OSError:
                    shutil.copy2(slot, path)
                    slot.unlink(missing_ok=True)
            elif kind == "dir":
                path.mkdir(exist_ok=True)
                os.chmod(path, entry[2])
        except OSError as exc:
            failures.append(f"{path}: {exc}")
    return failures


def journal_committed(log_file: Path) -> bool:
    try:
        with open(log_file, "r", encoding="utf-8") as f:
            for line in f:
                try:
                    e = json.loads(line)
                except ValueError:
                    continue
                if e and e[0] == "commit":
                    return True
    except OSError:
        pass
    return False


def pending_journals(paths: Paths) -> list[Path]:
    base = paths.state_dir / ROLLBACK_DIR
    if not base.is_dir():
        return []
    return sorted(p for p in base.iterdir() if (p / JOURNAL_NAME).exists())


@contextlib.contextmanager
def _transaction(paths: Paths, label: str):
    """One package's filesystem changes plus its db update: all of it happens,
    or (on any error, including Ctrl-C) none of the file changes stay."""
    safe = re.sub(r"[^A-Za-z0-9._-]", "_", label)
    journal = FileJournal(paths.state_dir / ROLLBACK_DIR / f"{int(time.time() * 1000)}-{os.getpid()}-{safe}")
    try:
        yield journal
    except BaseException:
        journal.close()
        discard_staged_db(paths)
        failures = undo_journal(journal.log_file)
        if failures:
            print(
                f"alp: UYARI: {label} için geri alma tam yapılamadı ({len(failures)} yol); "
                f"yedek korunuyor: {journal.dir}\n  'alp recover' ile yeniden deneyin. İlk hata: {failures[0]}",
                file=sys.stderr,
            )
        else:
            shutil.rmtree(journal.dir, ignore_errors=True)
            print(f"alp: hata nedeniyle {label} için yapılan dosya değişiklikleri geri alındı.", file=sys.stderr)
        raise
    else:
        # Commit point: the staged db is complete and fsynced. Once the marker
        # is on disk, `alp recover` rolls forward (publishes the db) instead of
        # rolling the files back, so db and files can never disagree.
        journal.commit()
        journal.close()
        publish_db(paths)
        shutil.rmtree(journal.dir, ignore_errors=True)


def _maybe_transaction(paths: Paths, label: str, dry_run: bool):
    return contextlib.nullcontext(None) if dry_run else _transaction(paths, label)


def _tool_available(binary: str, cwd: Path, search_path: str | None = None) -> bool:
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
    if search_path is not None:  # the PATH the build step will really see
        return shutil.which(binary, path=search_path) is not None
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


def _owner_key(rel: str) -> str:
    """One spelling for ownership lookups. Recipe/core records store
    "/usr/bin/x" (from _walk_staged) while adopt-base records store
    "usr/bin/x"; comparing them raw made a path owned by both invisible to
    both, so adopt-base could claim an alp-installed file and removing
    that package deleted the protected base file."""
    return "/" + rel.lstrip("/")


def _other_owners(db: dict, exclude: str) -> dict[str, str]:
    """owner key (see _owner_key) -> owning package, for every installed
    package except `exclude`. Symlinks count too: adopt-base keeps them out
    of files[]."""
    owners: dict[str, str] = {}
    for pkg_name, record in db["packages"].items():
        if pkg_name == exclude:
            continue
        for rel in [*record.get("files", []), *record.get("symlinks", [])]:
            owners.setdefault(_owner_key(rel), pkg_name)
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
        owner = other_owners.get(_owner_key(rel))
        if owner is not None:
            problems.append(f"{rel}: '{owner}' paketine ait")
        elif rel not in self_owned:
            problems.append(f"{rel}: sistemde zaten var ve hiçbir alp paketine ait değil")
    if problems:
        shown = "\n  ".join(problems[:20])
        more = f"\n  ... ve {len(problems) - 20} çakışma daha" if len(problems) > 20 else ""
        raise AlpError("Kurulum çakışması, hiçbir dosyaya dokunulmadı:\n  " + shown + more)


# Top-level directories a package may install into. Everything else in a
# staged tree (/dev, /proc, /sys, /run, /tmp, /home, /root, /mnt, /media, a
# stray build directory, ...) is refused.
STAGE_ALLOWED_TOP = frozenset({
    "usr", "etc", "var", "opt", "boot", "srv", "bin", "sbin", "lib", "lib32", "lib64", "libx32",
})
_STAGE_FORBIDDEN = ("/" + DEFAULT_STATE_DIR, "/" + DEFAULT_LOG_DIR)


def _symlink_escapes(rel: str, target: str, absolute_root: Path | None) -> bool:
    """Would this staged symlink point outside the root once installed?
    Resolved lexically, as the installed system will see it (other symlinks
    on the way are not followed)."""
    if target.startswith("/"):
        if absolute_root is None:
            return False  # built for "/": an absolute target is inside the installed system
        root = posixpath.normpath(str(absolute_root))
        resolved = posixpath.normpath(target)
        return not (resolved == root or resolved.startswith(root.rstrip("/") + "/"))
    depth = 0
    for part in (posixpath.dirname(rel).strip("/").split("/") + target.split("/")):
        if part in ("", "."):
            continue
        if part == "..":
            depth -= 1
            if depth < 0:
                return True
        else:
            depth += 1
    return False


def _preflight_stage(
    staged_root: Path, entries: list[tuple[str, str]], *,
    setuid_allowed: frozenset = frozenset(), absolute_link_root: Path | None = None,
) -> None:
    """Root-side checks of what a build (or a core archive) staged, before
    anything is merged or even chowned (design/trust-model.md 6.2). The tree
    was writable by the unprivileged build user, so nothing in it is taken
    on trust. Device nodes, sockets and FIFOs were already refused by
    _walk_staged()."""
    problems: list[str] = []
    stats = {rel: os.lstat(staged_root / rel.lstrip("/")) for rel, _kind in entries}
    names_per_inode: dict[tuple[int, int], int] = {}
    for rel, kind in entries:
        if kind == "file":
            key = (stats[rel].st_dev, stats[rel].st_ino)
            names_per_inode[key] = names_per_inode.get(key, 0) + 1
    for rel, kind in entries:
        st = stats[rel]
        top = rel.lstrip("/").split("/", 1)[0]
        if top not in STAGE_ALLOWED_TOP:
            problems.append(f"{rel}: izin verilen kurulum dizinlerinin dışında")
            continue
        if any(rel == bad or rel.startswith(bad + "/") for bad in _STAGE_FORBIDDEN):
            problems.append(f"{rel}: alp'in kendi durum/günlük dizini")
            continue
        if kind == "symlink":
            if _symlink_escapes(rel, os.readlink(staged_root / rel.lstrip("/")), absolute_link_root):
                problems.append(f"{rel}: kök dizinin dışını gösteren symlink")
            continue
        if kind == "file" and st.st_nlink > names_per_inode[(st.st_dev, st.st_ino)]:
            # More names than the stage holds: the inode is also linked from
            # somewhere else. Touching it (chown, chmod) would touch that file.
            problems.append(f"{rel}: hazırlık dizininin dışına sabit bağ (hard link)")
            continue
        if os.name == "posix" and st.st_mode & (stat.S_ISUID | stat.S_ISGID) and rel not in setuid_allowed:
            problems.append(f"{rel}: setuid/setgid ama tarifin 'setuid' listesinde değil")
    if problems:
        shown = "\n  ".join(problems[:20])
        more = f"\n  ... ve {len(problems) - 20} sorun daha" if len(problems) > 20 else ""
        raise AlpError("Hazırlanan paket ağacı reddedildi, hiçbir dosyaya dokunulmadı:\n  " + shown + more)


def _chmod_nofollow(directory_fd: int, name: str, mode: int) -> None:
    if hasattr(os, "O_PATH"):
        fd = os.open(name, os.O_PATH | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=directory_fd)
        try:
            if stat.S_ISLNK(os.fstat(fd).st_mode):
                return
            os.chmod(f"/proc/self/fd/{fd}", mode)
        finally:
            os.close(fd)
    else:  # pragma: no cover - non-Linux
        os.chmod(name, mode, dir_fd=directory_fd)


def _normalise_stage(staged_root: Path) -> None:
    """After _preflight_stage(): make the staged tree root's (when alp is
    root) and drop group and other write from every file and directory,
    wherever it is (/usr, /etc, /var, /opt, /boot ...): the tree was written
    by the build user and nothing in it may stay writable by everybody.
    The one exception is a directory with the sticky bit (var/tmp 1777
    style), which is world-writable on purpose and safe for it. Recipes
    have no way to ask for another exception. Modes are otherwise kept, so
    the unchanged merge copies them as they are.

    chown clears setuid/setgid on Linux, even for root, so the mode read
    before the chown is put back afterwards; the bits that survive are
    exactly the ones _preflight_stage() allowed."""
    if os.name != "posix":
        return
    as_root = _is_root()
    top = str(staged_root)
    for dirpath, dirnames, filenames, dirfd in os.fwalk(top, follow_symlinks=False):
        if as_root:
            os.fchown(dirfd, 0, 0)
        for name in [*dirnames, *filenames]:
            st = os.lstat(name, dir_fd=dirfd)
            if as_root:
                os.chown(name, 0, 0, dir_fd=dirfd, follow_symlinks=False)
            if stat.S_ISLNK(st.st_mode):
                continue
            mode = stat.S_IMODE(st.st_mode)
            if not (stat.S_ISDIR(st.st_mode) and mode & stat.S_ISVTX):
                mode &= ~0o022
            if as_root or mode != stat.S_IMODE(st.st_mode):
                _chmod_nofollow(dirfd, name, mode)


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
    journal: FileJournal | None = None,
    setuid_allowed: frozenset = frozenset(),
    absolute_link_root: Path | None = None,
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
    _preflight_stage(staged_root, entries, setuid_allowed=setuid_allowed, absolute_link_root=absolute_link_root)
    _preflight_merge(entries, root, self_owned, other_owners)
    _normalise_stage(staged_root)

    owned: list[str] = []
    symlinks: list[str] = []
    new_hashes: dict[str, str] = {}
    alpnew: list[str] = []

    def write(src: Path, dst: Path) -> None:
        if journal is not None:
            journal.will_write(dst)
            journal.will_write(_tmp_name(dst))  # the sibling _copy_entry writes first
        _copy_entry(src, dst)

    try:
        for rel, kind in entries:
            src = staged_root / rel.lstrip("/")
            dst = root / rel.lstrip("/")
            if kind == "dir":
                if os.path.lexists(dst) and rel in self_owned and (dst.is_symlink() or not dst.is_dir()):
                    if journal is not None:
                        journal.will_remove(dst)
                    dst.unlink()  # our own file/symlink becoming a real directory
                if not dst.is_dir():
                    if journal is not None:
                        journal.will_mkdir(dst)
                    dst.mkdir()
                    shutil.copymode(src, dst)
                    owned.append(rel)
                elif rel in self_owned:
                    owned.append(rel)
                continue

            owned.append(rel)
            if kind == "symlink":
                symlinks.append(rel)
                write(src, dst)
            elif rel in config_files:
                current = _file_sha256_or_none(dst)
                recorded = old_hashes.get(rel)
                if current is None or recorded is None or current == recorded:
                    write(src, dst)
                    new_hashes[rel] = sha256_of(src)
                else:
                    write(src, dst.with_name(dst.name + ".alpnew"))
                    new_hashes[rel] = recorded  # still "user-modified" next time
                    alpnew.append(rel)
            else:
                write(src, dst)
    except OSError as exc:
        raise AlpError(
            f"Dosya kopyalanırken hata: {exc}. Bu paketin o ana kadar yazılan dosyaları "
            "geri alınıyor; veritabanı güncellenmedi."
        ) from exc
    return MergeResult(installed=sorted(owned), symlinks=sorted(symlinks), config_hashes=new_hashes, alpnew=sorted(alpnew))


def _remove_owned_paths(
    root: Path, rel_paths, record: dict, dry_run: bool, journal: FileJournal | None = None,
) -> None:
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
                    if journal is not None:
                        journal.will_write(save_path)
                        journal.will_remove(target)
                    os.replace(target, save_path)
                    print(f"Değiştirilmiş yapılandırma korundu: {save_path}")
                continue
        if dry_run:
            print(f"[dry-run] rm {target}")
            continue
        if journal is not None:
            journal.will_remove(target)
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
# Build sandbox (design/trust-model.md section 6.1; DECISIONS D170, D174).
#
# Recipe steps never run as root and never run unconfined:
#   - alp as root: a helper process drops to the build user (`alpbuild`),
#     then starts bubblewrap, which runs the step;
#   - alp as an ordinary user: bubblewrap runs the step directly (there is
#     nothing to drop).
# Inside: "/" is read-only, only the transaction's source and stage
# directories are writable, /tmp and /run are private and empty, there is no
# network, and the environment is cleared.
# Without a working bubblewrap (or, for root, without the build user) the
# build is refused. The only way around is --no-sandbox, root only, with a
# warning on every build, and nothing can make it permanent.
# --------------------------------------------------------------------------

BUILD_USER = "alpbuild"
BWRAP_CANDIDATES = ("/usr/bin/bwrap", "/bin/bwrap")
_TRUE_CANDIDATES = ("/usr/bin/true", "/bin/true")
SANDBOX_PATH = "/usr/bin:/usr/sbin:/bin:/sbin"
DEFAULT_SOURCE_DATE_EPOCH = 315532800  # 1980-01-01, the earliest date zip can store
_DROP_HELPER_FLAG = "--alp-internal-drop-exec"
_PR_SET_NO_NEW_PRIVS = 38
_PR_GET_NO_NEW_PRIVS = 39


def _drop_privileges(uid: int, gid: int) -> None:
    """Become uid:gid for good, in the calling process: no supplementary
    groups, real/effective/saved ids all set, no_new_privs on. Every step is
    checked afterwards; any doubt raises and the caller must not exec."""
    import ctypes

    if type(uid) is not int or type(gid) is not int or uid <= 0 or gid <= 0:
        raise RuntimeError(f"geçersiz derleme kimliği uid={uid!r} gid={gid!r}")
    os.setgroups([])
    os.setresgid(gid, gid, gid)
    os.setresuid(uid, uid, uid)
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(_PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0:
        raise RuntimeError(f"no_new_privs ayarlanamadı (errno {ctypes.get_errno()})")
    if os.getresuid() != (uid, uid, uid) or os.getresgid() != (gid, gid, gid):
        raise RuntimeError("uid/gid düşürülemedi")
    if os.getgroups() not in ([], [gid]):
        raise RuntimeError("ek gruplar bırakılamadı")
    if libc.prctl(_PR_GET_NO_NEW_PRIVS, 0, 0, 0, 0) != 1:
        raise RuntimeError("no_new_privs doğrulanamadı")
    for regain in (lambda: os.setuid(0), lambda: os.setgid(0), lambda: os.setgroups([0])):
        try:
            regain()
        except OSError:
            continue
        raise RuntimeError("yetkiler geri alınabiliyor; düşürme başarısız")
    os.umask(0o022)


def _drop_helper_main(argv: list[str]) -> int:
    """`alp.py --alp-internal-drop-exec UID GID -- PROGRAM ARGS...`: drop, verify, exec.

    A separate process (not a preexec_fn) so the drop runs in ordinary,
    single-threaded Python and its failure is an exit status. It can only
    lower privileges, so being reachable from the command line gives a
    caller nothing it did not have."""
    try:
        uid, gid = int(argv[0]), int(argv[1])
        if argv[2] != "--" or not os.path.isabs(argv[3]):
            raise ValueError("kullanım: UID GID -- /mutlak/program [argümanlar]")
        _drop_privileges(uid, gid)
        os.execv(argv[3], argv[3:])
    except Exception as exc:  # noqa: BLE001 - anything at all means: do not run the build
        print(f"alp: yetki düşürme başarısız, derleme adımı çalıştırılmadı: {exc}", file=sys.stderr)
    return 126


@dataclass
class BuildSandbox:
    bwrap: str | None  # None: --no-sandbox, steps run directly
    ids: tuple | None  # (uid, gid) to drop to before bubblewrap; None when alp is not root


def _build_ids(paths: Paths) -> tuple:
    if paths.build_ids is not None:
        uid, gid = paths.build_ids
    else:
        import pwd
        try:
            entry = pwd.getpwnam(BUILD_USER)
        except KeyError as exc:
            raise AlpError(
                f"Derleme kullanıcısı '{BUILD_USER}' bu sistemde yok; kaynak derleme reddedildi. "
                "Tarif adımları root olarak çalıştırılmaz."
            ) from exc
        uid, gid = entry.pw_uid, entry.pw_gid
    if type(uid) is not int or type(gid) is not int or uid <= 0 or gid <= 0:
        raise AlpError(f"Derleme kullanıcısı yetkisiz olmalı (uid {uid}, gid {gid}); kaynak derleme reddedildi.")
    return uid, gid


def _drop_prefix(ids: tuple | None) -> list[str]:
    if ids is None:
        return []
    return [sys.executable, "-I", os.path.abspath(__file__), _DROP_HELPER_FLAG, str(ids[0]), str(ids[1]), "--"]


def _bwrap_argv(bwrap: str, writable: list[Path], cwd: Path | None, env: dict[str, str]) -> list[str]:
    argv = [
        bwrap,
        "--unshare-user", "--unshare-net", "--unshare-ipc", "--unshare-pid", "--unshare-uts",
        "--die-with-parent", "--new-session",
        "--ro-bind", "/", "/",
        "--dev", "/dev", "--proc", "/proc",
        # Private and empty. /run goes too: its sockets (D-Bus, resolved, nscd)
        # are a way out of "no network" that a network namespace does not close.
        "--tmpfs", "/tmp", "--tmpfs", "/run",
    ]
    for directory in writable:  # after the tmpfs lines: a build dir under /tmp must stay visible
        argv += ["--bind", str(directory), str(directory)]
    if cwd is not None:
        argv += ["--chdir", str(cwd)]
    argv.append("--clearenv")
    for key, value in env.items():
        argv += ["--setenv", key, value]
    argv.append("--")
    return argv


_OUTER_ENV = {"PATH": SANDBOX_PATH, "LC_ALL": "C"}


def _prepare_sandbox(paths: Paths) -> BuildSandbox:
    """Decide how recipe steps will run, or refuse. Never falls back silently."""
    if paths.sandbox == "off":
        print(
            "alp: UYARI: --no-sandbox: tarif adımları KORUMALI ALAN OLMADAN, alp'i çalıştıran kullanıcının "
            "yetkileriyle (root ise root olarak) çalıştırılacak. Yalnız bubblewrap'in çalışamadığı derleme "
            "ortamları içindir.",
            file=sys.stderr,
        )
        return BuildSandbox(bwrap=None, ids=None)
    if paths.sandbox != "require":
        raise AlpError(f"Tanımsız korumalı alan kipi: {paths.sandbox!r}")
    hint = " Korumalı alan olmadan derlemek için root olarak --no-sandbox verilmelidir."
    bwrap = _find_fixed_program(BWRAP_CANDIDATES)
    if bwrap is None:
        raise AlpError("bubblewrap (bwrap) bulunamadı; kaynak derleme reddedildi." + hint)
    ids = _build_ids(paths) if _is_root() else None
    probe = _find_fixed_program(_TRUE_CANDIDATES)
    if probe is None:
        raise AlpError("Korumalı alan denenemedi (/usr/bin/true yok); kaynak derleme reddedildi." + hint)
    try:
        done = subprocess.run(
            _drop_prefix(ids) + _bwrap_argv(bwrap, [], None, {"PATH": SANDBOX_PATH}) + [probe],
            stdin=subprocess.DEVNULL, capture_output=True, text=True, errors="replace", timeout=60,
            env=_OUTER_ENV, cwd="/",
        )
        failure = "" if done.returncode == 0 else (done.stderr.strip().splitlines() or [f"çıkış {done.returncode}"])[-1]
    except (OSError, subprocess.SubprocessError) as exc:
        failure = _first_line(exc)
    if failure:
        raise AlpError(f"bubblewrap bu sistemde çalışmıyor ({failure}); kaynak derleme reddedildi." + hint)
    return BuildSandbox(bwrap=bwrap, ids=ids)


def _build_environment(paths: Paths, recipe: dict, home: Path) -> dict[str, str]:
    """The whole environment of a build step. Nothing is inherited from the
    caller: an inherited MAKEFLAGS or CC could put code into a package."""
    path = SANDBOX_PATH
    if paths.relocate and not _is_fs_root(paths.root):
        path = f"{paths.root}{DEFAULT_RECIPE_PREFIX}/bin:{path}"
    epoch = recipe.get("source_date_epoch")
    if type(epoch) is not int or epoch < 0:
        epoch = DEFAULT_SOURCE_DATE_EPOCH
    jobs = paths.jobs if type(paths.jobs) is int and 1 <= paths.jobs <= 1024 else 1
    return {
        "PATH": path,
        "HOME": str(home),
        "LC_ALL": "C",
        "MAKEFLAGS": f"-j{jobs}",
        "SOURCE_DATE_EPOCH": str(epoch),
    }


def _give_tree_to(top: Path, uid: int, gid: int) -> None:
    """chown -R without following anything: every name is changed relative to
    an open directory descriptor with lchown semantics, so a symlink or a
    path swapped underneath cannot redirect the change outside `top`."""
    for _dirpath, dirnames, filenames, dirfd in os.fwalk(str(top), follow_symlinks=False):
        os.fchown(dirfd, uid, gid)
        for name in [*dirnames, *filenames]:
            os.chown(name, uid, gid, dir_fd=dirfd, follow_symlinks=False)


def _require_reachable(directory: Path, uid: int, gid: int) -> None:
    """The build user must be able to walk down to its build directory."""
    for parent in reversed(directory.resolve().parents):
        st = os.stat(parent)
        mode = st.st_mode
        ok = (mode & 0o100) if st.st_uid == uid else (mode & 0o010) if st.st_gid == gid else (mode & 0o001)
        if not ok:
            raise AlpError(
                f"Derleme kullanıcısı (uid {uid}) derleme dizinine ulaşamıyor: {parent} geçiş izni vermiyor "
                f"(izin {stat.S_IMODE(mode):04o}). Kaynak derleme başlatılmadı."
            )


def _run_recipe_steps(
    paths: Paths, recipe: dict, steps: list[list[str]], *,
    src_dir: Path, build_root: Path, destdir: Path, log_path: Path, emit_name: str,
) -> None:
    """Run configure/make/make_install. The source tree was downloaded,
    sha256-checked and unpacked by the caller (as root on a real system);
    only now, right before the first step, is it handed to the build user."""
    env = _build_environment(paths, recipe, build_root)
    sandbox: BuildSandbox | None = None
    for label, step in zip(("configure", "make", "make_install"), steps):
        _emit(paths, "phase", name=emit_name, phase="build", step=label)
        binary = step[0]
        if not _tool_available(binary, src_dir, search_path=env["PATH"]):
            raise AlpError(
                f"Gerekli araç bulunamadı: {binary!r}. Bu adım gerçek bir Linux "
                "build ortamı (configure/make toolchain) gerektirir."
            )
        if sandbox is None:
            sandbox = _prepare_sandbox(paths)
            if sandbox.ids is not None:
                for tree in (build_root, destdir):
                    _require_reachable(tree, *sandbox.ids)
                    _give_tree_to(tree, *sandbox.ids)
        if sandbox.bwrap is None:
            argv, run_env, cwd = list(step), env, src_dir
        else:
            argv = (_drop_prefix(sandbox.ids)
                    + _bwrap_argv(sandbox.bwrap, [build_root, destdir], src_dir, env) + list(step))
            run_env, cwd = _OUTER_ENV, Path("/")
        with open(log_path, "a", encoding="utf-8") as log:
            mode = "korumalı alan yok" if sandbox.bwrap is None else (
                f"bwrap, uid {sandbox.ids[0]}" if sandbox.ids else "bwrap, çağıran kullanıcı")
            log.write(f"$ {' '.join(step)}\n# [{mode}; MAKEFLAGS={env['MAKEFLAGS']} "
                      f"SOURCE_DATE_EPOCH={env['SOURCE_DATE_EPOCH']}]\n")
            log.flush()
            done = subprocess.run(argv, cwd=cwd, env=run_env, stdin=subprocess.DEVNULL,
                                  stdout=log, stderr=subprocess.STDOUT)
        if done.returncode != 0:
            raise subprocess.CalledProcessError(done.returncode, step)


def _recipe_setuid(recipe: dict) -> frozenset:
    """The recipe's `setuid` list: absolute installed paths that may carry
    the setuid or setgid bit. It is part of the recipe, so it is covered by
    recipe_sha256 and the catalog signature."""
    listed = recipe.get("setuid", [])
    if not isinstance(listed, list) or not all(isinstance(p, str) and p.startswith("/") for p in listed):
        raise AlpError(f"Tarif {recipe.get('name', '?')!r}: 'setuid' mutlak yolların listesi olmalı.")
    return frozenset(posixpath.normpath(p) for p in listed)


def _absolute_link_root(paths: Paths) -> Path | None:
    """Where an absolute symlink target must stay. None for an ordinary
    package (built for "/", so "/x" is inside the installed system by
    definition); the root itself for a --relocate build, which runs from there."""
    return paths.root if paths.relocate and not _is_fs_root(paths.root) else None


# --------------------------------------------------------------------------
# Method 1: System Build Recipes
# --------------------------------------------------------------------------

RECIPE_PREFIX_TOKEN = "@PREFIX@"
RECIPE_DESTDIR_TOKEN = "@DESTDIR@"
DEFAULT_RECIPE_PREFIX = "/usr"
_UNRESOLVED_TOKEN_RE = re.compile(r"@[A-Z][A-Z0-9_]*@")


def _recipe_prefix(paths: Paths) -> str:
    """Install prefix substituted for @PREFIX@ in recipe build steps.

    Normally /usr: the package is compiled for its final location under /
    and --root is only a staging/testing root. With --relocate the package
    is compiled for <root>/usr instead, so a non-/ root on a host distro
    (e.g. ~/.local/share/alp/root) gets binaries that find their own data
    files (fonts, units database, ...) at runtime.
    """
    if paths.relocate and not _is_fs_root(paths.root):
        return str(paths.root) + DEFAULT_RECIPE_PREFIX
    return DEFAULT_RECIPE_PREFIX


def _is_fs_root(path: Path) -> bool:
    """True for the filesystem root itself ("/", "//", or "C:\\" on Windows).
    Comparing against Path("/") missed the spellings Path.resolve() keeps."""
    return path == Path(path.anchor)


def _recipe_steps(recipe: dict, paths: Paths, destdir: str) -> list[list[str]]:
    """configure/make/make_install with @PREFIX@ and @DESTDIR@ filled in.

    `DESTDIR=<staging dir>` is appended to make_install, unless the recipe
    places @DESTDIR@ itself -- for Makefiles that misuse the DESTDIR name
    (tree uses it as the bin directory) and need the staging root spliced
    into other variables instead.
    """
    build = recipe["build"]
    prefix = _recipe_prefix(paths)
    make_install = list(build["make_install"])
    if not any(RECIPE_DESTDIR_TOKEN in arg for arg in make_install):
        make_install.append(f"DESTDIR={destdir}")
    steps = [
        [arg.replace(RECIPE_PREFIX_TOKEN, prefix).replace(RECIPE_DESTDIR_TOKEN, destdir) for arg in step]
        for step in (build["configure"], build["make"], make_install)
    ]
    # The catalog is fetched separately from this engine (`alp update`), so it
    # can name a placeholder this alp does not know. Left alone, the literal
    # reaches ./configure ("expected an absolute directory name for --prefix:
    # @PREFIX@" on an alp that predates @PREFIX@) and fails only after the
    # download, with a build log to dig through. Refuse before anything runs.
    for step in steps:
        for arg in step:
            unknown = _UNRESOLVED_TOKEN_RE.search(arg)
            if unknown:
                raise AlpError(
                    f"Tarif {recipe.get('name', '?')!r} bu alp sürümünün tanımadığı yer tutucuyu içeriyor: "
                    f"{unknown.group(0)} (adım: {' '.join(step)}). Katalog bu alp'ten yeni olabilir; "
                    "alp'i güncelleyin. Hiçbir şey indirilmedi veya derlenmedi."
                )
    return steps


def _staged_tree(paths: Paths, destdir: Path) -> Path:
    """Directory inside `destdir` that maps onto paths.root.

    Without --relocate that is destdir itself. With --relocate, `make
    install DESTDIR=...` stages files under destdir/<root>/..., so the tree
    to merge is that subdirectory; anything staged outside it (an absolute
    /etc path hardcoded by the Makefile) cannot be placed under the root
    and is refused rather than silently dropped.
    """
    if not paths.relocate or _is_fs_root(paths.root):
        return destdir
    staged = destdir / paths.root.relative_to(paths.root.anchor)
    # The build user owned destdir. A symlink on the way down to the staged
    # root would make the mkdir and the merge below work on another tree.
    cursor = destdir
    for part in staged.relative_to(destdir).parts:
        cursor = cursor / part
        if cursor.is_symlink():
            raise AlpError(f"--relocate: hazırlık dizininde kök yolu bir symlink: {cursor}; paket reddedildi.")
    stray = [
        p for p in destdir.rglob("*")
        if (p.is_symlink() or not p.is_dir()) and staged not in p.parents
    ]
    if stray:
        shown = ", ".join("/" + str(p.relative_to(destdir)) for p in stray[:5])
        raise AlpError(f"--relocate: paket kök dizini dışına dosya kurdu: {shown}")
    staged.mkdir(parents=True, exist_ok=True)
    return staged


def install_recipe(
    paths: Paths, entry: dict, index_dir: Path, dry_run: bool,
    db: dict | None = None, pkg_name: str | None = None, journal: FileJournal | None = None,
) -> dict:
    recipe = read_recipe(entry, index_dir)
    setuid_allowed = _recipe_setuid(recipe)

    _require_recipe_dependencies(recipe)

    source_url = resolve_source_url(recipe["source_url"], index_dir)
    log_path = paths.log_dir / f"{recipe['name']}-{recipe['version']}.build.log"
    steps = _recipe_steps(recipe, paths, "<destdir>")

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
    _emit(paths, "phase", name=pkg_name or recipe["name"], phase="download", url=recipe["source_url"])
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

    real_steps = _recipe_steps(recipe, paths, str(destdir))
    _run_recipe_steps(
        paths, recipe, real_steps, src_dir=src_dir, build_root=build_root, destdir=destdir,
        log_path=log_path, emit_name=pkg_name or recipe["name"],
    )

    config_files = set(recipe.get("config_files", []))
    db = db if db is not None else load_db(paths)
    _emit(paths, "phase", name=pkg_name or recipe["name"], phase="merge")
    merged = _merge_staged(
        _staged_tree(paths, destdir), paths.root,
        config_files=config_files, old_record=None,
        other_owners=_other_owners(db, exclude=pkg_name or recipe["name"]),
        journal=journal,
        setuid_allowed=setuid_allowed, absolute_link_root=_absolute_link_root(paths),
    )
    _cleanup_build(paths, build_root, destdir)

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
    db: dict | None = None, pkg_name: str | None = None, journal: FileJournal | None = None,
) -> dict:
    recipe = read_recipe(entry, index_dir)
    setuid_allowed = _recipe_setuid(recipe)

    _require_recipe_dependencies(recipe)

    source_url = resolve_source_url(recipe["source_url"], index_dir)
    config_files = set(recipe.get("config_files", []))

    if dry_run:
        print(f"[dry-run] yükseltilecekti: {old_record.get('version')} -> {recipe['version']} ({source_url})")
        return {**old_record, "version": recipe["version"], "status": "would-upgrade"}

    archive = paths.cache_dir / f"{recipe['name']}-{recipe['version']}.src"
    _emit(paths, "phase", name=pkg_name or recipe["name"], phase="download", url=recipe["source_url"])
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
    steps = _recipe_steps(recipe, paths, str(destdir))
    _run_recipe_steps(
        paths, recipe, steps, src_dir=src_dir, build_root=build_root, destdir=destdir,
        log_path=log_path, emit_name=pkg_name or recipe["name"],
    )

    db = db if db is not None else load_db(paths)
    other_owners = _other_owners(db, exclude=pkg_name or recipe["name"])
    _emit(paths, "phase", name=pkg_name or recipe["name"], phase="merge")
    merged = _merge_staged(
        _staged_tree(paths, destdir), paths.root,
        config_files=config_files, old_record=old_record, other_owners=other_owners, journal=journal,
        setuid_allowed=setuid_allowed, absolute_link_root=_absolute_link_root(paths),
    )
    _drop_stale_files(paths.root, old_record, merged.installed, other_owners, journal=journal)
    _cleanup_build(paths, build_root, destdir)
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


def _cleanup_build(paths: Paths, *dirs: Path) -> None:
    """Build trees and DESTDIRs are only needed while a build runs; leaving
    them piled up under var/lib/alp/cache eats disk. Kept after a *failed*
    build (for debugging) and with --keep-build."""
    if paths.keep_build:
        return
    for d in dirs:
        shutil.rmtree(d, ignore_errors=True)


def _drop_stale_files(
    root: Path, old_record: dict, new_files: list[str], other_owners: dict[str, str],
    journal: FileJournal | None = None,
) -> None:
    """Remove what the old version owned that the new version no longer
    ships (a renamed binary, a dropped doc file), with the same safety rules
    as removal -- including .alpsave for a user-modified config file the new
    version dropped. Paths another package owns are left alone."""
    kept = {_owner_key(rel) for rel in new_files}
    dropped = {
        rel for rel in old_record.get("files", [])
        if _owner_key(rel) not in kept and _owner_key(rel) not in other_owners
    }
    if dropped:
        _remove_owned_paths(root, dropped, old_record, dry_run=False, journal=journal)


def _warn_about_alpnew(alpnew: list[str]) -> None:
    if not alpnew:
        return
    print(f"Uyarı: {len(alpnew)} yapılandırma dosyası elle değiştirilmiş; yeni sürüm yanına yazıldı:")
    for rel in alpnew:
        print(f"  {rel}.alpnew  (elle birleştirin; orijinal dosyanız değiştirilmedi)")


# --------------------------------------------------------------------------
# Method 2: Universal Apps (Flatpak wrapper)
# --------------------------------------------------------------------------

def _flatpak_installed_version(ref: str) -> str | None:
    """Version flatpak reports for an installed app, or None.

    Flathub apps update themselves, so a version pinned in the catalog would
    go stale; the installed version is recorded instead. Column output is
    not localized, unlike `flatpak info`.
    """
    try:
        out = subprocess.run(
            ["flatpak", "list", "--app", "--columns=application,version"],
            check=True, capture_output=True, text=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    for line in out.splitlines():
        app, _, version = line.partition("\t")
        if app.strip() == ref and version.strip():
            return version.strip()
    return None


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

    version = entry.get("version") or (None if dry_run else _flatpak_installed_version(ref))
    return {
        "name": ref,
        "version": version or "unknown",
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
    _emit(paths, "phase", name=name, phase="download", url=entry["url"])
    fetch(resolve_source_url(entry["url"], index_dir), archive, entry["sha256"])
    staged = paths.cache_dir / f"{prefix}-stage-{name}-{version}"
    if staged.exists():
        shutil.rmtree(staged)
    safe_extract(archive, staged)
    return staged


def install_core(
    paths: Paths, entry: dict, index_dir: Path, dry_run: bool,
    db: dict | None = None, pkg_name: str | None = None, journal: FileJournal | None = None,
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
    _emit(paths, "phase", name=pkg_name or name, phase="merge")
    try:
        merged = _merge_staged(
            staged, paths.root,
            config_files=config_files, old_record=None,
            other_owners=_other_owners(db, exclude=pkg_name or name), journal=journal,
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
    db: dict | None = None, pkg_name: str | None = None, journal: FileJournal | None = None,
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
    _emit(paths, "phase", name=pkg_name or name, phase="merge")
    try:
        merged = _merge_staged(
            staged, paths.root,
            config_files=config_files, old_record=old_record, other_owners=other_owners, journal=journal,
        )
    finally:
        shutil.rmtree(staged, ignore_errors=True)
    _drop_stale_files(paths.root, old_record, merged.installed, other_owners, journal=journal)
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

def remove_package(paths: Paths, db: dict, name: str, dry_run: bool, journal: FileJournal | None = None) -> None:
    pkg = db["packages"].get(name)
    if pkg is None:
        raise AlpError(f"Kurulu değil: {name}")
    if pkg.get("method") == "lfs-base":
        raise AlpError(f"{name} LFS taban paketi; doğrudan kaldırılması kapalı.")

    if pkg["method"] == "flatpak":
        remove_flatpak(pkg["flatpak_ref"], dry_run)
    else:
        other_owners = _other_owners(db, exclude=name)
        ours = [rel for rel in pkg.get("files", []) if _owner_key(rel) not in other_owners]
        _remove_owned_paths(paths.root, ours, pkg, dry_run, journal=journal)

    if not dry_run:
        del db["packages"][name]


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def _fold(text: str) -> str:
    # casefold() turns Turkish "İ" into "i" + U+0307; drop the dot so
    # "DÜZENLEYİCİ" still matches "düzenleyici".
    return text.casefold().replace("\u0307", "")


def _entry_metadata(entry: dict, index_dir: Path | None) -> dict:
    """version/license/homepage/size a store can show for a catalog entry.

    A recipe entry keeps its version (and, optionally, license/homepage) in
    its recipe file; the entry itself may carry any of them too and wins.
    `size` is the entry's optional download size in bytes. Every field is
    optional and never guessed: PackageKit reports "unknown" as MAXUINT64,
    which Discover prints as "16.0 EiB", so a caller must be able to tell
    "absent" from a real value. A missing or unreadable recipe file only
    drops its fields -- it must not break search.
    """
    recipe: dict = {}
    if index_dir is not None and entry.get("method") == "recipe" and isinstance(entry.get("recipe"), str):
        try:
            recipe = read_recipe(entry, index_dir)
        except (OSError, ValueError):
            pass
        except CatalogTrustError:
            # Display only: nothing from the mismatching file is shown or used.
            # Installing the package is refused where the recipe is read for real.
            print(f"alp: uyarı: {entry['recipe']} katalogdaki özetle uyuşmuyor; bilgileri gösterilmiyor.",
                  file=sys.stderr)
    meta: dict = {}
    for key in ("version", "license", "homepage"):
        value = entry.get(key, recipe.get(key))
        if isinstance(value, str) and value:
            meta[key] = value
    size = entry.get("size")
    if isinstance(size, int) and not isinstance(size, bool) and size >= 0:
        meta["size"] = size
    return meta


def cmd_search(index: dict, term: str, as_json: bool = False, index_dir: Path | None = None) -> int:
    needle = _fold(term)
    hits = sorted(
        n for n, entry in index["entries"].items()
        if needle in _fold(n) or needle in _fold(str(entry.get("description", "")))
    )
    if as_json:
        # Machine-readable mode for callers like a PackageKit backend (see
        # design/packagekit-integration.md §2) that must not scrape the
        # human-readable text format below.
        rows = []
        for n in hits:
            row = {"name": n, "method": index["entries"][n]["method"]}
            if index["entries"][n].get("description"):
                row["description"] = index["entries"][n]["description"]
            row.update(_entry_metadata(index["entries"][n], index_dir))
            rows.append(row)
        print(json.dumps(rows, ensure_ascii=False))
        return 0 if hits else 1
    if not hits:
        print(f"Eşleşme yok: {term}")
        return 1
    width = max(len(n) for n in hits)
    for n in hits:
        entry = index["entries"][n]
        description = entry.get("description", "")
        print(f"{n.ljust(width)}  {('(' + entry['method'] + ')').ljust(9)}  {description}".rstrip())
    return 0


def cmd_info(index: dict, db: dict, name: str, index_dir: Path | None = None) -> int:
    if name in db["packages"]:
        pkg = dict(db["packages"][name])
        pkg["required_by"] = reverse_dependents(index, db["packages"], name)
        print(json.dumps(pkg, indent=2, ensure_ascii=False))
        return 0
    entry = index["entries"].get(name)
    if entry is None:
        print(f"Bilinmeyen paket: {name}", file=sys.stderr)
        return 1
    print(json.dumps({"name": name, **entry, **_entry_metadata(entry, index_dir), "status": "not-installed"},
                     indent=2, ensure_ascii=False))
    return 0


def cmd_list(db: dict, as_json: bool = False, box: dict | None = None) -> int:
    if as_json:
        rows = [
            {"name": name, "version": pkg["version"], "method": pkg["method"],
             "status": pkg.get("status", "installed"), "reason": pkg.get("reason", "explicit"),
             # only present when true: keeps the JSON contract PackageKit parses unchanged
             **({"protected": True} if pkg.get("protected") else {})}
            for name, pkg in sorted(db["packages"].items())
        ]
        print(json.dumps(rows, ensure_ascii=False))
        return 0
    box = box or {}
    if not db["packages"] and not box:
        print("Kurulu paket yok.")
        return 0
    for name, pkg in sorted(db["packages"].items()):
        suffix = "\t(bağımlılık)" if pkg.get("reason") == "dependency" else ""
        if pkg.get("protected"):
            suffix += "\t(korumalı)"
        print(f"{name}\t{pkg['version']}\t{pkg['method']}{suffix}")
    for name, pkg in sorted(box.items()):
        print(f"{name}\t{pkg.get('version', '?')}\tkutu ({pkg.get('box', KUTU_NAME)})")
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
    and a remaining number marks a newer release (1.0.1 > 1.0). Only known
    pre-release words (alpha, beta, rc, pre, dev, a1/b1...) count as older;
    other trailing letters are patch releases (1.1.1k > 1.1.1). Trailing
    zero segments are ignored (1.0 == 1.0.0). Separators (. - _ +) are ignored.
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
        return _tail_cmp(ta, len(tb))
    return -_tail_cmp(tb, len(ta))


_PRERELEASE_WORDS = frozenset({"alpha", "beta", "rc", "pre", "preview", "dev", "snapshot", "nightly", "git", "svn"})


def _tail_cmp(tokens: list[str], start: int) -> int:
    """The longer version has `tokens[start:]` left over: +1 if it is newer
    than the shorter one, -1 if older, 0 if equal (1.0 == 1.0.0)."""
    rest = tokens[start:]
    if all(t.isdigit() and int(t) == 0 for t in rest):
        return 0
    first = rest[0]
    if first.isdigit():
        return 1
    word = first.lower()
    followed_by_digit = len(rest) > 1 and rest[1].isdigit()
    if word in _PRERELEASE_WORDS or (word in ("a", "b") and followed_by_digit):
        return -1  # 1.0rc1 < 1.0
    return 1  # 1.1.1k, 9.0p1: post-release letters are newer


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
        return str(read_recipe(entry, index_dir)["version"])
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

    guarded = sorted(
        n for n in removing
        if (installed.get(n) or {}).get("protected")
        or (installed.get(n) or {}).get("method") == "lfs-base"
    )
    if guarded:
        raise AlpError(
            f"{', '.join(guarded)} korumalı (taban/sistem paketi); kaldırılamaz. "
            f"Bilerek kaldırmak için önce: alp unprotect {guarded[0]}"
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
            and not installed[name].get("protected")
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
        version = "" if version == "unknown" else f" {version}"
        note = "  (bağımlılık)" if s.action == "install" and s.reason == "dependency" else ""
        method = index["entries"][s.name]["method"]
        print(f"  {_ACTION_LABEL[s.action]:<12}{s.name}{version} [{method}]{note}")


def _install_one(
    paths: Paths, name: str, entry: dict, index_dir: Path, dry_run: bool, db: dict,
    journal: FileJournal | None = None,
) -> dict:
    method = entry["method"]
    if method == "recipe":
        return install_recipe(paths, entry, index_dir, dry_run, db=db, pkg_name=name, journal=journal)
    if method == "flatpak":
        return install_flatpak(entry, dry_run)
    if method == "core":
        return install_core(paths, entry, index_dir, dry_run, db=db, pkg_name=name, journal=journal)
    raise AlpError(f"Tanımsız kurulum yöntemi: {method!r}")


def _upgrade_one(
    paths: Paths, name: str, entry: dict, index_dir: Path, old: dict, dry_run: bool, db: dict,
    journal: FileJournal | None = None,
) -> dict:
    if old.get("method") == "lfs-base":
        raise AlpError(f"{name} LFS taban paketi; alp ile yükseltilmesi kapalı. Önce resmi rootfs build/install akışını kullanın.")
    method = entry["method"]
    if method == "recipe":
        return upgrade_recipe(paths, entry, index_dir, old, dry_run, db=db, pkg_name=name, journal=journal)
    if method == "core":
        return upgrade_core(paths, entry, index_dir, old, dry_run, db=db, pkg_name=name, journal=journal)
    if method == "flatpak":
        raise AlpError(_FLATPAK_UPGRADE_MSG)
    raise AlpError(f"Tanımsız yöntem: {method!r}")



# --------------------------------------------------------------------------
# Triggers (NVIDIA-PKG-01 groundwork): a catalogue entry may name fixed system steps that run once after a
# transaction that installed, upgraded or removed it: "ldconfig" (library cache) and "depmod" (kernel module index,
# for every kernel under usr/lib/modules). Only these names exist; a catalogue that names any other is refused, so
# a catalogue can never make alp run an arbitrary command. A failing trigger is reported, not rolled back: the
# files and the database are already committed, and the trigger can be run again by hand.
# --------------------------------------------------------------------------

TRIGGERS = ("ldconfig", "depmod")


def _trigger_commands(paths: Paths, name: str) -> list[list[str]]:
    root = str(paths.root)
    if name == "ldconfig":
        return [["ldconfig"] if root == "/" else ["ldconfig", "-r", root]]
    if name == "depmod":
        mods = Path(paths.root, "usr/lib/modules")
        kvers = sorted(d.name for d in mods.iterdir() if d.is_dir()) if mods.is_dir() else []
        return [["depmod", "-a", kv] if root == "/" else ["depmod", "-a", "-b", root, kv] for kv in kvers]
    raise AlpError(f"Tanımsız tetikleyici: {name!r}")


def run_triggers(paths: Paths, names: set[str], dry_run: bool) -> None:
    for name in [t for t in TRIGGERS if t in names]:
        for cmd in _trigger_commands(paths, name):
            if dry_run:
                print(f"[dry-run] tetikleyici: {' '.join(cmd)}")
                continue
            exe = shutil.which(cmd[0], path="/usr/sbin:/usr/bin:/sbin:/bin")
            if exe is None:
                print(f"alp: uyarı: tetikleyici çalıştırılamadı, {cmd[0]} bulunamadı.", file=sys.stderr)
                continue
            r = subprocess.run([exe, *cmd[1:]], capture_output=True, text=True)
            _emit(paths, "trigger", name=name, command=cmd, returncode=r.returncode)
            if r.returncode != 0:
                print(f"alp: uyarı: tetikleyici başarısız (çıkış {r.returncode}): {' '.join(cmd)}: "
                      f"{_first_line(RuntimeError(r.stderr.strip() or '-'))}. Elle yeniden çalıştırın.", file=sys.stderr)


def _entry_triggers(entry: dict | None) -> set[str]:
    return set((entry or {}).get("triggers", []) or [])

def _run_plan(
    steps: list[PlanStep], paths: Paths, index: dict, index_dir: Path, db: dict,
    dry_run: bool, explicit: set[str],
) -> None:
    tag = "[dry-run] " if dry_run else ""
    done: list[str] = []
    total = len(steps)
    _emit(paths, "plan", steps=_plan_rows(steps, index))
    for position, step in enumerate(steps):
        entry = index["entries"][step.name]
        old = db["packages"].get(step.name)
        _emit(paths, "step", name=step.name, action=step.action, phase="start",
              index=position + 1, total=total, percentage=round(100 * position / total))
        try:
            if step.action in ("upgrade", "reinstall") and old and old.get("method") == "lfs-base":
                raise AlpError(f"{step.name} LFS taban paketi; catalog install/reinstall/upgrade ile değiştirilemez.")
            # One transaction per package: its files and its db record change
            # together, or every file change is rolled back (see FileJournal).
            with _maybe_transaction(paths, step.name, dry_run) as journal:
                if old is not None and entry["method"] in ("recipe", "core"):
                    # upgrade and --reinstall share the config-aware path, so
                    # modified configs get .alpnew and dropped files are removed.
                    record = _upgrade_one(paths, step.name, entry, index_dir, old, dry_run, db, journal=journal)
                else:
                    record = _install_one(paths, step.name, entry, index_dir, dry_run, db, journal=journal)
                record["depends"] = list(entry.get("depends", []))
                record["conflicts"] = list(entry.get("conflicts", []))
                if _entry_triggers(entry):
                    record["triggers"] = sorted(_entry_triggers(entry))
                if step.name in explicit:
                    record["reason"] = "explicit"
                elif old is not None:
                    record["reason"] = old.get("reason", "explicit")
                else:
                    record["reason"] = step.reason
                if entry.get("protected") or (old or {}).get("protected"):
                    record["protected"] = True
                if not dry_run:
                    db["packages"][step.name] = record
                    stage_db(paths, db)
        except Exception as exc:
            _emit(paths, "error", name=step.name, message=_first_line(exc), completed=list(done))
            if not dry_run:
                # the db file is the truth: drop the in-memory change a failed save left behind
                db.clear()
                db.update(load_db(paths))
            if done:
                remaining = [s.name for s in steps[len(done):]]
                print(
                    f"alp: işlem yarıda kaldı. Tamamlanan ve kaydedilen: {', '.join(done)}; "
                    f"yapılmayan: {', '.join(remaining)}",
                    file=sys.stderr,
                )
            raise
        done.append(step.name)
        shown = record.get("version")
        _emit(paths, "step", name=step.name, action=step.action, phase="done", version=shown,
              index=position + 1, total=total, percentage=round(100 * (position + 1) / total))
        shown = "" if shown in (None, "unknown") else f" -> {shown}"
        print(f"{tag}{step.name} ({entry['method']}){shown} {_ACTION_DONE[step.action]}.")
    run_triggers(paths, set().union(*(_entry_triggers(index["entries"][n]) for n in done)) if done else set(), dry_run)
    _emit(paths, "done", completed=list(done))


def _guarded_steps(installed: dict, steps: list[PlanStep]) -> list[str]:
    return sorted(
        step.name for step in steps
        if step.action in ("upgrade", "reinstall")
        and (installed.get(step.name) or {}).get("method") == "lfs-base"
    )


def _plan_rows(steps: list[PlanStep], index: dict) -> list[dict]:
    """Machine-readable plan rows (store/PackageKit: show before confirming,
    MASTER_PLAN §5.3). `download_size` is the catalog's optional `size` field
    in bytes; null when the catalog does not say (the size is never guessed)."""
    rows = []
    for s in steps:
        entry = index["entries"].get(s.name, {})
        size = entry.get("size")
        rows.append({
            "action": s.action, "name": s.name, "old_version": s.old_version,
            "new_version": s.new_version, "method": entry.get("method"), "reason": s.reason,
            "download_size": size if isinstance(size, int) and not isinstance(size, bool) else None,
        })
    return rows


def _print_plan_json(command: str, rows: list[dict], problems: list[str], **extra) -> int:
    """--json --dry-run: the plan as one JSON object on stdout, nothing changed.
    Exit 1 when the transaction would be refused (problems non-empty)."""
    sizes = [r["download_size"] for r in rows if r["action"] != "remove"]
    total = sum(sizes) if sizes and all(isinstance(x, int) for x in sizes) else None
    print(json.dumps({"command": command, "steps": rows, "problems": problems,
                      "download_size_total": total, **extra}, ensure_ascii=False))
    return 1 if problems else 0


def _plan_problems(index: dict, installed: dict, steps: list[PlanStep]) -> list[str]:
    guarded = [f"{n}: LFS taban paketi; catalog ile değiştirilemez" for n in _guarded_steps(installed, steps)]
    return guarded + state_problems(index, installed, steps)


def _plan_or_refuse(index: dict, installed: dict, steps: list[PlanStep]) -> None:
    guarded_upgrades = _guarded_steps(installed, steps)
    if guarded_upgrades:
        raise AlpError(
            "LFS taban paketleri catalog install/reinstall/upgrade ile değiştirilemez: "
            + ", ".join(guarded_upgrades) + ". Resmi rootfs build/install akışını kullanın."
        )
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


FLATHUB_REMOTE = "flathub"


def _flathub_rank(term: str, app: str, name: str) -> int:
    """0: exact (application id, its last part or the app's name), 1: the term is in the name or id, 2: other."""
    t = term.lower()
    if app.lower() == t or app.rsplit(".", 1)[-1].lower() == t or name.lower() == t:
        return 0
    if t in name.lower() or t in app.lower():
        return 1
    return 2


def flathub_candidates(term: str) -> list[tuple[str, str]]:
    """Flathub apps for `term` as (application id, name), best match first (D163). Empty when flatpak, the Flathub
    remote or its AppStream data is missing; this is only an offer, never an error."""
    if shutil.which("flatpak") is None:
        return []
    try:
        out = subprocess.run(["flatpak", "search", "--columns=application,name,remotes", term],
                             capture_output=True, text=True, timeout=120).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    rows: list[tuple[str, str]] = []
    for line in out.splitlines():
        parts = [p.strip() for p in line.split("\t")]
        if len(parts) < 3 or not parts[0] or "." not in parts[0]:
            continue
        if FLATHUB_REMOTE not in [r.strip() for r in parts[2].split(",")]:
            continue
        if (parts[0], parts[1]) not in rows:
            rows.append((parts[0], parts[1]))
    rows.sort(key=lambda r: (_flathub_rank(term, r[0], r[1]), r[0]))
    return rows


def _choose_flathub(term: str, cands: list[tuple[str, str]], assume_yes: bool) -> tuple[str, str] | None:
    exact = [c for c in cands if _flathub_rank(term, *c) == 0]
    if len(exact) == 1:
        return exact[0]
    if assume_yes or sys.stdin is None or not sys.stdin.isatty():
        raise AlpError(f"{term!r} için Flathub'da birden çok uygulama var; uygulama kimliğini yazın, örneğin: "
                       f"alp install {cands[0][0]}")
    try:
        answer = input(f"Hangisi kurulsun? [1-{min(len(cands), 5)}, boş = iptal] ").strip()
    except EOFError:
        return None
    if answer.isdigit() and 1 <= int(answer) <= min(len(cands), 5):
        return cands[int(answer) - 1]
    return None


def _install_from_flathub(args: argparse.Namespace, paths: Paths,
                          cands: list[tuple[str, str]] | None = None) -> int:
    """D163: a name that is not in the alp catalogue is looked up on Flathub; after a yes the app is installed with
    flatpak (system-wide) and recorded in the alp database (method flatpak), so 'alp list' and 'alp remove' see it."""
    if cands is None:
        cands = flathub_candidates(args.name)
    if not cands:
        raise AlpError(f"Bilinmeyen paket: {args.name!r}. alp kataloğunda yok, Flathub'da da bulunamadı "
                       f"(flatpak kurulu mu, Flathub ekli mi?). 'alp search {args.name}' ile denetleyin.")
    shown = cands[:5]
    print(f"{args.name!r} alp kataloğunda yok. Flathub'da bulunanlar:")
    for i, (app, name) in enumerate(shown, 1):
        print(f"  {i}. {name} ({app})")
    choice = _choose_flathub(args.name, shown, getattr(args, "yes", False))
    if choice is None:
        print("İptal edildi, hiçbir şey değişmedi.")
        return 1
    app, name = choice
    paths.ensure()
    with DbLock(paths.lock_file):
        _require_no_pending(paths)
        db = load_db(paths)
        if app in db["packages"]:
            print(f"{name} ({app}) zaten kurulu.")
            return 0
        if not args.dry_run and not _confirm(f"{name} ({app}) Flathub'dan kurulsun mu?", getattr(args, "yes", False)):
            print("İptal edildi, hiçbir şey değişmedi.")
            return 1
        record = install_flatpak({"flatpak_ref": app, "remote": FLATHUB_REMOTE}, args.dry_run)
        if args.dry_run:
            return 0
        record["reason"] = "explicit"
        record["description"] = f"{name} (Flathub)"
        db["packages"][app] = record
        save_db(paths, db)
        print(f"Kuruldu: {name} ({app}), Flathub. Kaldırmak için: alp remove {app}")
    return 0


# --------------------------------------------------------------------------
# D164 (ALP-KUTU-01): the Debian box. A name that neither the alp catalogue nor Flathub (exact match) has is installed
# with apt into a Debian 13 container of the user (Distrobox, rootless Podman); its commands are exported to
# ~/.local/bin and its desktop entries to the menu. The box belongs to one user, so this step always runs as that user
# (under sudo: SUDO_USER) and keeps its own record in ~/.local/share/alp/kutu.json; the base system and the alp
# database are never touched. Kernel drivers and firmware cannot work from a container (it uses the alpbahOS kernel)
# and are refused. The PackageKit backend (--no-flathub) never reaches this step.
# --------------------------------------------------------------------------

KUTU_NAME = "alp-debian"
KUTU_IMAGE = "docker.io/library/debian:13"
KUTU_NOT_FOUND = 3  # exit code when Debian has no such package; the caller may still offer other Flathub matches
_DEB_NAME = re.compile(r"^[a-z0-9][a-z0-9+.-]+$")  # Debian policy 5.6.1
_KUTU_DRIVER = re.compile(r"^(nvidia|linux-image|linux-headers|linux-modules|firmware-|grub|dkms$)|-dkms$")
_KUTU_BIN_DIRS = ("/usr/bin", "/usr/games", "/usr/sbin", "/bin", "/sbin")


def kutu_available() -> bool:
    return shutil.which("distrobox") is not None and shutil.which("podman") is not None


def _kutu_home() -> Path:
    return Path(os.environ.get("HOME") or pwd.getpwuid(os.getuid()).pw_dir)


def _kutu_state_file(home: Path) -> Path:
    return home / ".local" / "share" / "alp" / "kutu.json"


def load_kutu(home: Path) -> dict:
    path = _kutu_state_file(home)
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {"packages": {}}
    except (OSError, ValueError) as exc:
        raise AlpError(f"Debian kutusu kaydı okunamadı ({path}): {exc}") from exc
    if not isinstance(data, dict) or not isinstance(data.get("packages"), dict):
        raise AlpError(f"Debian kutusu kaydı bozuk: {path}")
    return data


def save_kutu(home: Path, data: dict) -> None:
    path = _kutu_state_file(home)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def _kutu_cmd(*cmd: str) -> list[str]:
    return ["distrobox", "enter", KUTU_NAME, "--", *cmd]


def kutu_exists() -> bool:
    return subprocess.run(["podman", "container", "exists", KUTU_NAME], capture_output=True, text=True).returncode == 0


def kutu_create() -> None:
    print(f"Debian kutusu oluşturuluyor ({KUTU_IMAGE}); ilk sefer birkaç dakika sürer ve internet gerekir.")
    subprocess.run(["distrobox", "create", "--name", KUTU_NAME, "--image", KUTU_IMAGE, "--yes", "--no-entry"],
                   check=True)
    subprocess.run(_kutu_cmd("true"), check=True)  # the first entry sets the box up


def kutu_candidate(name: str) -> str | None:
    """The version apt would install in the box, or None when Debian has no installable package of that name."""
    r = subprocess.run(_kutu_cmd("env", "LC_ALL=C", "apt-cache", "policy", name),
                       capture_output=True, text=True, timeout=600)
    if r.returncode != 0:
        return None
    for line in r.stdout.splitlines():
        key, _, value = line.strip().partition(":")
        if key == "Candidate":
            value = value.strip()
            return None if not value or value == "(none)" else value
    return None


def _host_has_command(name: str) -> bool:
    return shutil.which(name, path="/usr/bin:/usr/sbin:/bin:/sbin") is not None


def _kutu_exports(files: list[str]) -> tuple[list[str], list[str], list[str]]:
    """(commands to export, desktop entries to export, commands skipped because the host has the same name)."""
    bins: list[str] = []
    apps: list[str] = []
    skipped: list[str] = []
    for f in files:
        pp = PurePosixPath(f)
        if str(pp.parent) in _KUTU_BIN_DIRS and pp.name:
            (skipped if _host_has_command(pp.name) else bins).append(f)
        elif str(pp.parent) == "/usr/share/applications" and pp.suffix == ".desktop":
            apps.append(pp.stem)
    return bins, apps, skipped


def _kutu_argv(command: str, args: argparse.Namespace) -> list[str]:
    argv = [command, args.name, "--kutu"]
    if getattr(args, "yes", False):
        argv.append("--yes")
    if getattr(args, "dry_run", False):
        argv.append("--dry-run")
    return argv


def _as_box_user(argv: list[str]) -> int:
    """alp runs as root (sudo alp ...): the box belongs to the user who ran sudo, so this step runs again as that
    user with a clean environment (HOME, XDG_RUNTIME_DIR of the user's session for rootless Podman)."""
    user = os.environ.get("SUDO_USER", "")
    if not user or user == "root":
        raise AlpError("Debian kutusu bir kullanıcıya aittir, root oturumundan kullanılamaz. Komutu kendi "
                       f"kullanıcınızla yazın: alp {' '.join(argv)}")
    try:
        pw = pwd.getpwnam(user)
    except KeyError as exc:
        raise AlpError(f"Kullanıcı bulunamadı: {user}") from exc
    runtime = f"/run/user/{pw.pw_uid}"
    if not os.path.isdir(runtime):
        raise AlpError(f"{user} kullanıcısının oturumu açık değil ({runtime} yok); Debian kutusu için masaüstünde "
                       "oturum açın.")
    env = [f"HOME={pw.pw_dir}", f"USER={user}", f"LOGNAME={user}", "PATH=/usr/bin:/bin",
           f"XDG_RUNTIME_DIR={runtime}", f"DBUS_SESSION_BUS_ADDRESS=unix:path={runtime}/bus",
           f"LANG={os.environ.get('LANG', 'tr_TR.UTF-8')}", f"TERM={os.environ.get('TERM', 'dumb')}"]
    me = os.path.abspath(__file__)
    # No runuser/setpriv in the image (LFS builds util-linux without them): alp switches to the user itself
    cmd = [sys.executable, "-I", me, _AS_USER_FLAG, user, "--", "/usr/bin/env", "-i", *env, sys.executable, "-I", me,
           *argv]
    return subprocess.run(cmd).returncode


_AS_USER_FLAG = "--alp-internal-as-user"


def _as_user_main(argv: list[str]) -> int:
    """`alp.py --alp-internal-as-user USER -- /absolute/program ARGS...`: become USER (its groups, real/effective/saved
    ids) and exec. Unlike the build drop (_drop_privileges), no_new_privs stays off: rootless Podman needs the setuid
    newuidmap/newgidmap. Only root can switch, so a caller gains nothing it did not have."""
    try:
        user = argv[0]
        if len(argv) < 3 or argv[1] != "--" or not os.path.isabs(argv[2]):
            raise ValueError("kullanım: KULLANICI -- /mutlak/program [argümanlar]")
        pw = pwd.getpwnam(user)
        if pw.pw_uid <= 0 or pw.pw_gid <= 0:
            raise ValueError("root'a geçilmez")
        os.initgroups(user, pw.pw_gid)
        os.setresgid(pw.pw_gid, pw.pw_gid, pw.pw_gid)
        os.setresuid(pw.pw_uid, pw.pw_uid, pw.pw_uid)
        if os.getresuid() != (pw.pw_uid,) * 3 or os.getresgid() != (pw.pw_gid,) * 3:
            raise RuntimeError("kimlik değiştirilemedi")
        try:
            os.setuid(0)
        except OSError:
            pass
        else:
            raise RuntimeError("root yetkisi geri alınabiliyor")
        os.execv(argv[2], argv[2:])
    except Exception as exc:  # noqa: BLE001 - any doubt: do not run the box step
        print(f"alp: kullanıcıya geçilemedi, Debian kutusu adımı çalıştırılmadı: {exc}", file=sys.stderr)
    return 126


def _install_from_kutu(args: argparse.Namespace, explicit: bool = True) -> int:
    name = args.name
    if _KUTU_DRIVER.search(name):
        raise AlpError(f"{name!r} bir sürücü/çekirdek paketi: Debian kutusu alpbahOS çekirdeğini kullandığı için "
                       "çalışmaz. Sürücüler alp paketi olarak gelir (örneğin: alp search nvidia).")
    if not _DEB_NAME.match(name):
        if not explicit:
            return KUTU_NOT_FOUND
        raise AlpError(f"Geçersiz Debian paket adı: {name!r}")
    if not kutu_available():
        if not explicit:
            return KUTU_NOT_FOUND
        raise AlpError("Debian kutusu için distrobox ve podman gerekir; bu sistemde yoklar.")
    if _is_root():
        if not explicit and os.environ.get("SUDO_USER", "root") == "root":
            return KUTU_NOT_FOUND  # plain root: no box; the other Flathub matches may still be offered
        return _as_box_user(_kutu_argv("install", args))
    yes = getattr(args, "yes", False)
    home = _kutu_home()
    state = load_kutu(home)
    if name in state["packages"]:
        print(f"{name} Debian kutusunda zaten kurulu (sürüm {state['packages'][name].get('version', '?')}).")
        return 0
    if not kutu_exists():
        if args.dry_run:
            print(f"[dry-run] Debian kutusu yok; önce oluşturulurdu: distrobox create --name {KUTU_NAME} "
                  f"--image {KUTU_IMAGE}")
            print(f"[dry-run] sonra kutuda: apt-get install -y {name}")
            return 0
        if not _confirm(f"{name!r} alp kataloğunda ve Flathub'da yok. Debian 13 kutusu ({KUTU_NAME}) oluşturulup "
                        "orada aransın mı? İlk sefer birkaç dakika sürer, internet gerekir.", yes):
            print("İptal edildi, hiçbir şey değişmedi.")
            return 1
        kutu_create()
    if not args.dry_run:
        subprocess.run(_kutu_cmd("sudo", "apt-get", "update", "-qq"), check=True)
    version = kutu_candidate(name)
    if version is None:
        print(f"{name!r} Debian 13 depolarında da yok.")
        return KUTU_NOT_FOUND
    if args.dry_run:
        print(f"[dry-run] Debian kutusuna ({KUTU_NAME}) kurulurdu: {name} {version}")
        return 0
    if not _confirm(f"{name} {version} Debian kutusuna (apt) kurulsun mu?", yes):
        print("İptal edildi, hiçbir şey değişmedi.")
        return 1
    subprocess.run(_kutu_cmd("sudo", "env", "DEBIAN_FRONTEND=noninteractive", "apt-get", "install", "-y", name),
                   check=True)
    record = {"version": version, "box": KUTU_NAME, "image": KUTU_IMAGE, "installed_at": _now(),
              "installed_by": f"alp/{ALP_VERSION}", "bins": [], "apps": []}
    state["packages"][name] = record
    save_kutu(home, state)  # recorded before the exports, so 'alp remove' finds it even if an export fails
    files = subprocess.run(_kutu_cmd("dpkg", "-L", name), capture_output=True, text=True, check=True).stdout
    bins, apps, skipped = _kutu_exports(files.splitlines())
    bindir = home / ".local" / "bin"
    bindir.mkdir(parents=True, exist_ok=True)
    try:
        for b in bins:
            subprocess.run(_kutu_cmd("distrobox-export", "--bin", b, "--export-path", str(bindir)), check=True)
            record["bins"].append(b)
        for a in apps:
            subprocess.run(_kutu_cmd("distrobox-export", "--app", a), check=True)
            record["apps"].append(a)
    finally:
        save_kutu(home, state)
    print(f"Kuruldu: {name} {version}, Debian kutusu ({KUTU_NAME}).")
    if bins:
        print("Komutlar: " + ", ".join(PurePosixPath(b).name for b in bins) + " (~/.local/bin; yeni açılan "
              "terminalde çalışır)")
    if apps:
        print("Uygulama menüsüne eklendi: " + ", ".join(apps))
    if skipped:
        print("Sistemde aynı adlı komut olduğu için dışa aktarılmadı: "
              + ", ".join(PurePosixPath(b).name for b in skipped)
              + f". Kutudakini çalıştırmak için: distrobox enter {KUTU_NAME} -- <komut>")
    if not bins and not apps:
        print(f"Kutuda çalıştırmak için: distrobox enter {KUTU_NAME}")
    print(f"Kaldırmak için: alp remove {name}")
    return 0


def _box_packages_of_caller() -> dict:
    """The box record of the user alp acts for (the sudo user when root); empty when there is none or it is
    unreadable. Read only."""
    try:
        if _is_root():
            user = os.environ.get("SUDO_USER", "")
            if not user or user == "root":
                return {}
            home = Path(pwd.getpwnam(user).pw_dir)
        else:
            home = _kutu_home()
        return load_kutu(home)["packages"]
    except (AlpError, KeyError, OSError):
        return {}


def _remove_from_kutu(args: argparse.Namespace) -> int:
    if _is_root():
        return _as_box_user(_kutu_argv("remove", args))
    name = args.name
    home = _kutu_home()
    state = load_kutu(home)
    record = state["packages"].get(name)
    if record is None:
        raise AlpError(f"Debian kutusunda kurulu değil: {name}")
    if args.dry_run:
        print(f"[dry-run] Debian kutusundan kaldırılırdı: {name} (dışa aktarılanlar: "
              f"{', '.join([PurePosixPath(b).name for b in record.get('bins', [])] + record.get('apps', [])) or 'yok'})")
        return 0
    if not _confirm(f"{name} Debian kutusundan kaldırılsın mı?", getattr(args, "yes", False)):
        print("İptal edildi, hiçbir şey değişmedi.")
        return 1
    if kutu_exists():
        bindir = home / ".local" / "bin"
        for a in record.get("apps", []):
            subprocess.run(_kutu_cmd("distrobox-export", "--app", a, "--delete"), check=False)
        for b in record.get("bins", []):
            subprocess.run(_kutu_cmd("distrobox-export", "--bin", b, "--export-path", str(bindir), "--delete"),
                           check=False)
        subprocess.run(_kutu_cmd("sudo", "env", "DEBIAN_FRONTEND=noninteractive", "apt-get", "remove", "-y", name),
                       check=True)
    else:
        print(f"Debian kutusu ({KUTU_NAME}) artık yok; yalnız kayıt siliniyor.")
    del state["packages"][name]
    save_kutu(home, state)
    print(f"Kaldırıldı: {name} (Debian kutusu). Kutu ve içindeki diğer paketler duruyor.")
    return 0


def _install_unknown(args: argparse.Namespace, paths: Paths) -> int:
    """D163/D164: a name the alp catalogue does not have: the Flathub app on an exact match, else the Debian box,
    else the other Flathub matches."""
    cands = flathub_candidates(args.name)
    if any(_flathub_rank(args.name, *c) == 0 for c in cands):
        return _install_from_flathub(args, paths, cands)
    rc = _install_from_kutu(args, explicit=False)
    if rc != KUTU_NOT_FOUND:
        return rc
    if cands:
        return _install_from_flathub(args, paths, cands)
    if not kutu_available():
        hint = " (Debian kutusu için distrobox gerekir)"
    elif _is_root() and os.environ.get("SUDO_USER", "root") == "root":
        hint = " (Debian kutusu root oturumundan kullanılamaz; kendi kullanıcınızla 'sudo alp install' yazın)"
    else:
        hint = ""
    raise AlpError(f"Bilinmeyen paket: {args.name!r}. alp kataloğunda, Flathub'da ve Debian'da bulunamadı{hint}. "
                   f"'alp search {args.name}' ile denetleyin.")


def cmd_install(args: argparse.Namespace, paths: Paths, index: dict, index_dir: Path) -> int:
    if getattr(args, "kutu", False):
        return _install_from_kutu(args)
    if args.name not in index["entries"]:
        if getattr(args, "no_flathub", False):
            raise AlpError(f"Bilinmeyen paket: {args.name!r}. Önce 'alp search {args.name}' ile denetleyin.")
        return _install_unknown(args, paths)

    paths.ensure()
    with DbLock(paths.lock_file):
        _require_no_pending(paths)
        db = load_db(paths)
        installed = db["packages"]
        steps = plan_transaction(
            index, index_dir, installed, [args.name],
            mode="install", reinstall=getattr(args, "reinstall", False),
        )
        if not args.dry_run:
            _note_accepted_catalog(db, index)  # durable with this transaction's database write

        if getattr(args, "json", False) and args.dry_run:
            return _print_plan_json("install", _plan_rows(steps, index),
                                    _plan_problems(index, installed, steps), already_installed=not steps)
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
        _require_no_pending(paths)
        db = load_db(paths)
        installed = db["packages"]
        name = getattr(args, "name", None)
        if not args.dry_run:
            _note_accepted_catalog(db, index)  # durable with this transaction's database write

        if name:
            if name not in installed:
                raise AlpError(f"Kurulu değil: {name}. 'alp upgrade' yalnız kurulu paketler içindir.")
            if installed[name].get("method") == "lfs-base":
                raise AlpError(f"{name} LFS taban paketi; alp ile yükseltilmesi kapalı. Resmi rootfs build/install akışını kullanın.")
            if name not in index["entries"]:
                raise AlpError(f"Bilinmeyen paket: {name!r}")
            if index["entries"][name]["method"] == "flatpak":
                raise AlpError(_FLATPAK_UPGRADE_MSG)
            targets = [name]
        else:
            targets, flatpaks, kept = [], [], []
            for pkg in sorted(installed):
                if installed[pkg].get("method") == "lfs-base":
                    continue
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
        if getattr(args, "json", False) and args.dry_run:
            return _print_plan_json("upgrade", _plan_rows(steps, index),
                                    _plan_problems(index, installed, steps), kept_back=[] if name else kept)
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
    total = len(order)
    triggers = set().union(*(_entry_triggers(db["packages"].get(n)) for n in order)) if order else set()
    for position, name in enumerate(order):
        _emit(paths, "step", name=name, action="remove", phase="start",
              index=position + 1, total=total, percentage=round(100 * position / total))
        try:
            with _maybe_transaction(paths, f"remove-{name}", dry_run) as journal:
                remove_package(paths, db, name, dry_run, journal=journal)
                if not dry_run:
                    stage_db(paths, db)
        except Exception as exc:
            _emit(paths, "error", name=name, message=_first_line(exc), completed=list(order[:position]))
            if not dry_run:
                db.clear()
                db.update(load_db(paths))
            raise
        _emit(paths, "step", name=name, action="remove", phase="done",
              index=position + 1, total=total, percentage=round(100 * (position + 1) / total))
        print(f"{tag}{name} kaldırıldı.")
    run_triggers(paths, triggers, dry_run)
    _emit(paths, "done", completed=list(order))


def cmd_remove(args: argparse.Namespace, paths: Paths, index: dict | None = None) -> int:
    if getattr(args, "kutu", False):
        return _remove_from_kutu(args)
    if (not getattr(args, "no_flathub", False) and args.name not in load_db(paths)["packages"]
            and args.name in _box_packages_of_caller()):
        return _remove_from_kutu(args)
    index = index or {"entries": {}}
    paths.ensure()
    with DbLock(paths.lock_file):
        _require_no_pending(paths)
        db = load_db(paths)
        installed = db["packages"]
        if args.name not in installed:
            raise AlpError(f"Kurulu değil: {args.name}")
        order = plan_remove(index, installed, [args.name], cascade=getattr(args, "cascade", False))
        if getattr(args, "json", False) and args.dry_run:
            rows = [{"action": "remove", "name": n, "old_version": installed[n].get("version"),
                     "new_version": None, "method": installed[n].get("method"),
                     "reason": installed[n].get("reason", "explicit"), "download_size": None} for n in order]
            return _print_plan_json("remove", rows, [], orphans_after=find_orphans(index, installed, set(order)))
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
        _require_no_pending(paths)
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


def _require_no_pending(paths: Paths) -> None:
    pending = pending_journals(paths)
    if pending:
        raise AlpError(
            f"Yarım kalmış {len(pending)} işlem var ({pending[0].name}...). Önce 'alp recover' çalıştırın; "
            "dosya sistemi ile veritabanı arasında tutarsızlık olabilir."
        )


def cmd_recover(args: argparse.Namespace, paths: Paths) -> int:
    """Undo what a killed alp process (kill -9, power cut) left half-done.
    A transaction stages the new db, writes a commit marker, then publishes
    the db. A journal without the marker is rolled back (files restored, the
    staged db dropped); one with the marker is rolled forward (db published)."""
    paths.ensure()
    with DbLock(paths.lock_file):
        pending = pending_journals(paths)
        if not pending:
            print("Geri alınacak yarım işlem yok.")
            return 0
        bad = 0
        for journal_dir in reversed(pending):  # newest first
            if journal_committed(journal_dir / JOURNAL_NAME):
                publish_db(paths)
                shutil.rmtree(journal_dir, ignore_errors=True)
                print(f"{journal_dir.name}: tamamlanmış işlem, veritabanı yayımlandı.")
                continue
            discard_staged_db(paths)
            failures = undo_journal(journal_dir / JOURNAL_NAME)
            if failures:
                bad += 1
                print(f"{journal_dir.name}: TAM geri alınamadı ({len(failures)} yol), ilk hata: {failures[0]}", file=sys.stderr)
            else:
                shutil.rmtree(journal_dir, ignore_errors=True)
                print(f"{journal_dir.name}: geri alındı.")
        return 1 if bad else 0


def cmd_protect(args: argparse.Namespace, paths: Paths, protect: bool) -> int:
    paths.ensure()
    with DbLock(paths.lock_file):
        db = load_db(paths)
        pkg = db["packages"].get(args.name)
        if pkg is None:
            raise AlpError(f"Kurulu değil: {args.name}")
        if protect:
            pkg["protected"] = True
        else:
            if pkg.get("method") == "lfs-base":
                raise AlpError(f"{args.name} LFS taban paketi kalıcı olarak korumalıdır.")
            pkg.pop("protected", None)
        if not args.dry_run:
            save_db(paths, db)
    print(f"{args.name} {'korumalı olarak işaretlendi' if protect else 'artık korumalı değil'}.")
    return 0


def cmd_check(paths: Paths, index: dict, index_dir: Path) -> int:
    pending = pending_journals(paths)
    if pending:
        print(f"SORUN: {len(pending)} yarım kalmış işlem yedeği var; 'alp recover' çalıştırın.")
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
    if problems or pending:
        for p in problems:
            print(f"SORUN: {p}")
        return 1
    print(f"Bağımlılık tutarlılığı: sorun yok ({len(installed)} kurulu paket).")
    return 0


# --------------------------------------------------------------------------
# update: refresh the catalog. The catalog is index.json plus the recipe files
# and core archives it points at, so the source is either a bare index.json
# (recipes/archives stay as they are) or a .tar.gz bundle with index.json at
# its top (everything in it replaces the local copy, index.json last).
#
# A bundle and a git checkout are only transports. What is accepted is the
# signed index.json: its signature, catalog_version and valid_until are
# checked on the fetched bytes before anything local is replaced, and from a
# bundle only the files the signed index names (and pins by sha256) are
# installed. On any refusal the local catalog is left exactly as it was.
# --------------------------------------------------------------------------

def _catalog_versions(index: dict, base_dir: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for name in index["entries"]:
        try:
            out[name] = catalog_version(index, base_dir, name)
        except (OSError, ValueError, KeyError):
            out[name] = "?"
    return out


def _catalog_relpath(raw: object) -> str | None:
    """A catalog-relative file name in plain form, or None when it is not one
    (absolute, climbing out with "..", empty, or a name alp keeps for itself)."""
    if not isinstance(raw, str) or not raw or "\x00" in raw or "\\" in raw or raw.startswith("/"):
        return None
    norm = posixpath.normpath(raw)
    parts = norm.split("/")
    if norm in (".", "") or ".." in parts or parts[0].startswith(".alp-") or parts[0] == ".git":
        return None
    if norm in ("index.json", "index.json" + SIGNATURE_SUFFIX) or norm.endswith(".prev"):
        return None
    return norm


def _validate_catalog(index: object, base_dir: Path, read=None) -> None:
    """Structural check of a new catalog. Recipes are read through `read`
    (catalog-relative name -> bytes; default: the files under base_dir) and
    each one must match its recipe_sha256 before it is parsed."""
    if not isinstance(index, dict) or not isinstance(index.get("entries"), dict):
        raise AlpError("Yeni katalog geçersiz: 'entries' tablosu yok. Yerel katalog değiştirilmedi.")
    real_base = os.path.realpath(base_dir)

    def read_from_disk(rel: str) -> bytes:
        target = os.path.realpath(os.path.join(real_base, rel))
        if not _inside(real_base, target) or not os.path.isfile(target):
            raise FileNotFoundError(rel)
        with open(target, "rb") as f:
            return f.read()

    read = read or read_from_disk
    for name, entry in index["entries"].items():
        if not isinstance(entry, dict) or entry.get("method") not in ("recipe", "core", "flatpak"):
            raise AlpError(f"Yeni katalog geçersiz: {name!r} için tanımsız yöntem. Yerel katalog değiştirilmedi.")
        trig = entry.get("triggers", [])
        if not isinstance(trig, list) or any(t not in TRIGGERS for t in trig):
            raise AlpError(f"Yeni katalog geçersiz: {name!r} için tanımsız tetikleyici {trig!r} "
                           f"(yalnız {', '.join(TRIGGERS)}). Yerel katalog değiştirilmedi.")
        if entry["method"] == "recipe":
            rel = _catalog_relpath(entry.get("recipe"))
            try:
                if rel is None:
                    raise FileNotFoundError(str(entry.get("recipe", "")))
                raw = read(rel)
            except OSError as exc:
                raise AlpError(
                    f"Yeni katalog geçersiz: {name!r} tarif dosyası yok ya da katalog dışında. "
                    "Yerel katalog değiştirilmedi."
                ) from exc
            try:
                _check_recipe_hash(entry, raw, rel)
            except CatalogTrustError as exc:
                raise CatalogTrustError(
                    f"Yeni katalog geçersiz: {name!r}: {exc} Yerel katalog değiştirilmedi. (Tarifler değiştiyse "
                    "katalog tek index.json olarak değil, katalog paketi olarak güncellenmelidir.)"
                ) from exc
            try:
                r = json.loads(raw.decode("utf-8"))
                for key in ("name", "version", "source_url", "sha256", "build"):
                    r[key]
            except (ValueError, KeyError, TypeError) as exc:
                raise AlpError(f"Yeni katalog geçersiz: {name!r} tarifi okunamadı ({exc}). Yerel katalog değiştirilmedi.") from exc
        elif entry["method"] == "core" and not (entry.get("url") and entry.get("sha256")):
            raise AlpError(f"Yeni katalog geçersiz: {name!r} için url/sha256 yok. Yerel katalog değiştirilmedi.")


def _update_floor(paths: Paths, current: object) -> int | None:
    """Lowest catalog_version `alp update` may accept: the highest of what
    the database remembers and what the verified local catalog is at."""
    known = [v for v in (stored_catalog_version(load_db(paths)),
                         getattr(current, "catalog_version", None) if getattr(current, "signed", False) else None)
             if v is not None]
    return max(known) if known else None


def _record_accepted_catalog(paths: Paths, catalog: dict) -> None:
    """After the new catalog is in place: remember its version (two-phase
    database write, under the caller's lock)."""
    db = load_db(paths)
    if _note_accepted_catalog(db, catalog):
        save_db(paths, db)


def _write_atomic(dst: Path, data: bytes) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    tmp = _tmp_name(dst)
    try:
        with open(tmp, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, dst)
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise


def _old_versions(index: object, index_dir: Path) -> dict[str, str]:
    """Versions of the catalog being replaced, for the diff. That catalog may
    be the very thing that is broken, so nothing here may stop the update."""
    if not isinstance(index, dict) or not isinstance(index.get("entries"), dict):
        return {}
    out: dict[str, str] = {}
    for name in index["entries"]:
        try:
            out[name] = catalog_version(index, index_dir, name)
        except (OSError, ValueError, KeyError, TypeError, AlpError):
            out[name] = "?"
    return out


def _print_catalog_diff(paths: Paths, old_v: dict[str, str], new_v: dict[str, str]) -> None:
    added = sorted(set(new_v) - set(old_v))
    removed = sorted(set(old_v) - set(new_v))
    changed = sorted(n for n in set(old_v) & set(new_v) if old_v[n] != new_v[n])
    for n in added:
        print(f"yeni      {n} {new_v[n]}")
    for n in changed:
        print(f"değişti   {n} {old_v[n]} -> {new_v[n]}")
    for n in removed:
        print(f"kalktı    {n} {old_v[n]}")
    if not (added or changed or removed):
        print("Katalog zaten güncel.")
    installed = load_db(paths)["packages"]
    for n in sorted(installed):
        if n in new_v and installed[n].get("method") != "flatpak" and new_v[n] != "?":
            if vercmp(new_v[n], installed[n]["version"]) > 0:
                print(f"güncelleme var: {n} {installed[n]['version']} -> {new_v[n]}  (alp upgrade)")


def _git(index_dir: Path, *args: str) -> str:
    try:
        done = subprocess.run(
            ["git", "-C", str(index_dir), *args],
            check=True, capture_output=True, text=True,
        )
    except FileNotFoundError as exc:
        raise AlpError("Katalog bir git deposu ama 'git' kurulu değil.") from exc
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or "").strip()
        raise AlpError(f"git {' '.join(args)} başarısız: {detail}") from exc
    return done.stdout.strip()


def _git_show(index_dir: Path, rev: str, rel: str) -> bytes:
    """Bytes of `rel` in commit `rev`, straight from the object store."""
    done = subprocess.run(["git", "-C", str(index_dir), "show", f"{rev}:{rel}"], capture_output=True)
    if done.returncode != 0:
        raise FileNotFoundError(rel)
    return done.stdout


def _refuse_trust_files_inside(index_dir: Path, policy: TrustPolicy) -> None:
    """A git fast-forward rewrites every tracked file of the checkout before
    alp can look at it. The keyring and the allowed list must therefore not
    live inside the checkout: an upstream that only added keys/allowed.txt
    would otherwise replace the trust anchors while index.json still verifies."""
    real_dir = os.path.realpath(index_dir)
    for path in _trust_paths(policy):
        if _inside(real_dir, os.path.realpath(path)):
            raise CatalogTrustError(
                f"Katalog anahtarlığı ({path}) git katalog deposunun içinde ({index_dir}); git ile güncelleme "
                "reddedildi. Anahtarlar katalog deposunun dışında durmalıdır."
            )


def _update_git_catalog(args: argparse.Namespace, paths: Paths, index_path: Path, index: dict) -> int:
    """`alp update` for a catalog that is a git checkout and has no "source".

    Fetches the upstream branch and fast-forwards to it; git handles auth
    (e.g. a private GitHub catalog through `gh auth git-credential`). Never
    merges or overwrites local edits: a diverged or dirty checkout is
    refused. The new catalog is verified from the fetched commit (signature,
    version, expiry, recipe hashes) before the working tree is touched, and
    once more from the files after the fast-forward; if that second check
    fails the checkout is moved back.
    """
    index_dir = index_path.parent
    paths.ensure()
    with DbLock(paths.lock_file):
        _require_no_pending(paths)
        _refuse_trust_files_inside(index_dir, paths.trust)
        if _git(index_dir, "status", "--porcelain", "--untracked-files=no"):
            raise AlpError(f"Katalog deposunda kaydedilmemiş değişiklik var ({index_dir}); güncelleme yapılmadı.")
        try:
            upstream = _git(index_dir, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
        except AlpError as exc:
            raise AlpError(f"Katalog dalının uzak karşılığı yok ({index_dir}); güncelleme yapılmadı.") from exc
        print(f"Katalog kaynağı: git ({upstream})")
        _git(index_dir, "fetch", "--quiet")
        old = _git(index_dir, "rev-parse", "HEAD")
        new = _git(index_dir, "rev-parse", "@{u}")
        if old == new:
            print("Katalog zaten güncel.")
            return 0
        if _git(index_dir, "merge-base", old, new) != old:
            raise AlpError(
                f"Yerel katalog dalı {upstream} ile ayrışmış; alp yalnız ileri sarar. "
                "Güncelleme yapılmadı."
            )
        floor = _update_floor(paths, index)
        try:
            data = _git_show(index_dir, new, index_path.name)
            try:
                signature = _git_show(index_dir, new, index_path.name + SIGNATURE_SUFFIX)
            except FileNotFoundError:
                signature = None
            fetched = accept_catalog_bytes(
                data, signature, paths.trust, origin=f"git {new[:7]}:{index_path.name}",
                at_update=True, floor=floor,
            )
            _validate_catalog(fetched, index_dir, read=lambda rel: _git_show(index_dir, new, rel))
        except (AlpError, ValueError, OSError) as exc:
            kind = CatalogTrustError if isinstance(exc, CatalogTrustError) else AlpError
            text = str(exc).replace(" Yerel katalog değiştirilmedi.", "")
            text = text if text.startswith("Yeni katalog geçersiz") else f"Yeni katalog geçersiz: {text}"
            raise kind(f"{text} Yerel kataloğun eski hâline dokunulmadı.") from exc
        old_v = _old_versions(index, index_dir)
        if args.dry_run:
            print(_git(index_dir, "diff", "--stat", old, new))
            print("[dry-run] yerel katalog değiştirilmedi.")
            return 0
        _git(index_dir, "merge", "--ff-only", "--quiet", new)
        try:
            # Again from the working tree: checkout filters can change bytes,
            # and these are the files every later command will read.
            new_index = accept_catalog_bytes(
                index_path.read_bytes(),
                _read_optional(index_path.with_name(index_path.name + SIGNATURE_SUFFIX), MAX_SIGNATURE_BYTES),
                paths.trust, origin=str(index_path), at_update=True, floor=floor,
            )
            _validate_catalog(new_index, index_dir)
        except (AlpError, ValueError, OSError) as exc:
            _git(index_dir, "reset", "--keep", old)
            raise AlpError(f"Yeni katalog geçersiz: {exc}. Katalog eski hâline döndürüldü.") from exc
        _record_accepted_catalog(paths, new_index)
        _print_catalog_diff(paths, old_v, _catalog_versions(new_index, index_dir))
        print(f"Katalog güncellendi ({old[:7]} -> {new[:7]}).")
        return 0


def _fetch_signature(source: str, dest: Path) -> tuple[bytes | None, str | None]:
    """The detached signature published next to a bare index.json.

    Returns (signature, None); (None, None) when the source really has no
    signature file (local file missing, HTTP 404); (None, reason) when it
    could not be fetched for another reason. Either None is "no signature"
    for the decision; the reason only makes the message truthful."""
    try:
        _download_raw(source + SIGNATURE_SUFFIX, dest)
    except FileNotFoundError:
        return None, None
    except (AlpError, OSError) as exc:
        cause = exc.__cause__ if isinstance(exc, AlpError) and exc.__cause__ is not None else exc
        if isinstance(cause, urllib.error.HTTPError) and cause.code == 404:
            return None, None
        return None, _first_line(cause)
    return _read_optional(dest, MAX_SIGNATURE_BYTES), None


def _bundle_payload(new_index: dict, new_root: Path) -> tuple[dict[str, bytes], int]:
    """What a bundle may install besides index.json: only files the accepted
    index names, each read once and checked against the sha256 the index (or,
    for a recipe, recipe_sha256) pins. Returns ({relative name: bytes},
    number of other files that were ignored).

    Copying everything in the archive, as before, would let whoever serves
    the bundle add files of their own next to a genuine signed index -- for
    example a replacement keyring, if the catalog directory holds the keys."""
    real_root = os.path.realpath(new_root)
    payload: dict[str, bytes] = {}

    def take(raw_rel: object, expected: object, what: str) -> None:
        rel = _catalog_relpath(raw_rel)
        if rel is None:
            return
        src = os.path.join(real_root, rel)
        if os.path.islink(src) or not os.path.isfile(src) or not _inside(real_root, os.path.realpath(src)):
            return
        with open(src, "rb") as f:
            data = f.read()
        if expected is not None:
            actual = hashlib.sha256(data).hexdigest()
            if not isinstance(expected, str) or actual != expected.lower():
                raise CatalogTrustError(
                    f"Katalog paketindeki {what} katalogdaki özetle uyuşmuyor: {rel}\n  beklenen : {expected}\n"
                    f"  hesaplanan: {actual}\nYerel katalog değiştirilmedi."
                )
        payload[rel] = data

    for entry in new_index["entries"].values():
        if entry.get("method") == "recipe":
            take(entry.get("recipe"), entry.get("recipe_sha256"), "tarif")
        elif entry.get("method") == "core" and not str(entry.get("url", "")).startswith(("http://", "https://", "file://")):
            take(entry.get("url"), entry.get("sha256"), "arşiv")
    present = sum(1 for p in new_root.rglob("*") if p.is_symlink() or p.is_file())
    listed = sum(1 for name in ("index.json", "index.json" + SIGNATURE_SUFFIX) if (new_root / name).is_file())
    return payload, max(0, present - listed - len(payload))


def cmd_update(args: argparse.Namespace, paths: Paths, index_path: Path, index: dict | None) -> int:
    """`index` is the current local catalog, or None when it could not be
    accepted (main() still lets `update` run then: it is the way out of an
    expired, damaged or rolled-back local catalog). Nothing from an
    unaccepted local catalog is used, so its "source" is not either."""
    source = getattr(args, "source", None) or (index or {}).get("source")
    if not source and (index_path.parent / ".git").exists():
        return _update_git_catalog(args, paths, index_path, index or {})
    if not source:
        raise AlpError("Katalog kaynağı yok: --source verin ya da index.json'a \"source\" alanı ekleyin.")
    if str(source).startswith("http://"):
        raise AlpError("http:// güvensiz. https:// ya da yerel yol kullanın.")
    index_dir = index_path.parent
    source = resolve_source_url(source, index_dir)
    sig_path = index_path.with_name(index_path.name + SIGNATURE_SUFFIX)

    paths.ensure()
    with DbLock(paths.lock_file):
        _require_no_pending(paths)
        work = index_dir / ".alp-update"
        shutil.rmtree(work, ignore_errors=True)
        work.mkdir(parents=True)
        try:
            blob = work / "download"
            _download_raw(source, blob)
            wanted = getattr(args, "sha256", None)
            if wanted and sha256_of(blob).lower() != wanted.lower():
                raise AlpError(
                    f"Checksum uyuşmadı: {source}\n  beklenen : {wanted}\n  hesaplanan: {sha256_of(blob)}\n"
                    "Katalog doğrulanamadı; yerel katalog değiştirilmedi."
                )
            bundle = tarfile.is_tarfile(blob)
            if bundle:
                # Unpacked before it is verified (the signature is inside), but
                # only into the work directory and only through safe_extract().
                new_root = work / "catalog"
                safe_extract(blob, new_root)
                if not (new_root / "index.json").is_file():
                    new_root = _single_top_level_dir(new_root)
                if not (new_root / "index.json").is_file():
                    raise AlpError("Katalog paketinde index.json yok. Yerel katalog değiştirilmedi.")
                data = (new_root / "index.json").read_bytes()
                signature = _read_optional(new_root / ("index.json" + SIGNATURE_SUFFIX), MAX_SIGNATURE_BYTES)
                versions_dir = new_root
            else:
                data = blob.read_bytes()
                signature, sig_problem = _fetch_signature(source, work / "download.sig")
                if signature is None and sig_problem and not paths.trust.allow_unsigned:
                    raise CatalogTrustError(
                        f"Katalog imza dosyası alınamadı ({source}{SIGNATURE_SUFFIX}): {sig_problem}. "
                        "İmza denetlenemedi; yerel katalog değiştirilmedi. Daha sonra yeniden deneyin."
                    )
                versions_dir = index_dir
            try:
                new_index = accept_catalog_bytes(
                    data, signature, paths.trust, origin=str(source), at_update=True,
                    floor=_update_floor(paths, index),
                )
            except CatalogTrustError as exc:
                raise CatalogTrustError(f"{exc} Yerel katalog değiştirilmedi.") from exc
            except AlpError as exc:
                raise AlpError(f"Yeni katalog JSON değil ya da geçersiz: {exc}. Yerel katalog değiştirilmedi.") from exc
            _validate_catalog(new_index, versions_dir)
            payload, ignored = _bundle_payload(new_index, new_root) if bundle else ({}, 0)

            _print_catalog_diff(
                paths, _old_versions(index, index_dir), _catalog_versions(new_index, versions_dir),
            )
            if ignored:
                print(f"Katalog paketindeki {ignored} dosya katalogda adı geçmediği için yok sayıldı.")

            if args.dry_run:
                print("[dry-run] yerel katalog değiştirilmedi.")
                return 0
            if bundle:
                prev = index_dir / ".alp-catalog-prev"
                shutil.rmtree(prev, ignore_errors=True)
                for rel in sorted(payload):
                    dst = index_dir / rel
                    if dst.is_file():
                        (prev / rel).parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(dst, prev / rel)
                    _write_atomic(dst, payload[rel])  # the bytes that were hash-checked
            if index_path.is_file():
                shutil.copy2(index_path, index_path.with_name(index_path.name + ".prev"))
            if sig_path.is_file():
                shutil.copy2(sig_path, sig_path.with_name(sig_path.name + ".prev"))
            # Signature first, index last: the catalog only points at files
            # that already exist, and a crash in between leaves a pair that
            # fails verification (and `alp update` repairs), never a pair
            # that verifies but was not what was accepted.
            if signature is not None:
                _write_atomic(sig_path, signature)
            else:
                sig_path.unlink(missing_ok=True)
            _write_atomic(index_path, data)  # the bytes that were verified, not a re-read
            _record_accepted_catalog(paths, new_index)
            print("Katalog güncellendi. Önceki index.json: " + index_path.name + ".prev")
            return 0
        finally:
            shutil.rmtree(work, ignore_errors=True)


# --------------------------------------------------------------------------
# CLI: Turkish help screen and argparse wrapper
# --------------------------------------------------------------------------

def _use_color() -> bool:
    return sys.stdout.isatty() and not os.environ.get("NO_COLOR") and os.environ.get("TERM") != "dumb"


def main_help() -> str:
    """The screen shown for plain `alp`, `alp help` and `alp --help`."""
    color = _use_color()
    bold = (lambda t: f"\033[1m{t}\033[0m") if color else (lambda t: t)
    head = (lambda t: f"\033[1;36m{t}\033[0m") if color else (lambda t: t)
    cmd = (lambda t: f"\033[32m{t}\033[0m") if color else (lambda t: t)
    dim = (lambda t: f"\033[2m{t}\033[0m") if color else (lambda t: t)

    def rows(items: list[tuple[str, str]]) -> str:
        return "\n".join(f"  {cmd(c.ljust(width))}   {d}" for c, d in items)

    sections = [
        ("Paket bulma", [
            ("search <kelime>", "Katalogda paket ara"),
            ("info <paket>", "Paketin ayrıntılarını göster"),
            ("list", "Kurulu paketleri listele"),
        ]),
        ("Kurma ve kaldırma", [
            ("install <paket>", "Paketi kur; alp'de yoksa Flathub'dan ya da Debian kutusundan"),
            ("install --kutu <paket>", "Debian paketini kutuya (apt) kur"),
            ("remove <paket>", "Paketi kaldır"),
            ("upgrade [paket]", "Paketi yükselt; ad verilmezse hepsini"),
            ("autoremove", "Artık gerekmeyen bağımlılıkları kaldır"),
        ]),
        ("Bakım", [
            ("update", "Paket kataloğunu yenile"),
            ("check", "Kurulu sistemdeki sorunları denetle"),
            ("recover", "Yarım kalan işlemi geri al"),
            ("protect <paket>", "Paketi kaldırılmaya karşı koru"),
            ("unprotect <paket>", "Korumayı kaldır"),
        ]),
        ("Seçenekler", [
            ("-y, --yes", "Onay sormadan devam et"),
            ("--dry-run", "Ne yapılacağını göster, hiçbir şeyi değiştirme"),
            ("--json", "search/list çıktısını JSON olarak ver"),
            ("--keep-build", "Derleme dosyalarını silme (hata ayıklama için)"),
        ]),
    ]
    width = max(len(c) for _, items in sections for c, _ in items)
    out = [
        f"{bold('alp')} — alpbahOS paket yöneticisi {dim('(prototip, ' + ALP_VERSION + ')')}",
        "",
        f"{head('Kullanım:')} alp {cmd('<komut>')} [seçenekler]",
    ]
    for title, items in sections:
        out += ["", head(title), rows(items)]
    out += [
        "",
        head("Örnekler"),
        f"  alp search tema          {dim('# adında/açıklamasında tema geçenler')}",
        f"  alp install figlet       {dim('# kur (önce planı gösterip onay ister)')}",
        f"  alp install htop         {dim('# alp ve Flathub da yoksa Debian kutusuna (apt) kurar')}",
        f"  alp remove -y figlet     {dim('# sormadan kaldır')}",
        f"  alp upgrade              {dim('# eskimiş her şeyi yükselt')}",
        "",
        f"Bir komutun ayrıntıları için: {cmd('alp <komut> --help')}",
        dim("Geliştirici seçenekleri (--root, --index, --relocate, adopt-base): alp help gelistirici"),
    ]
    return "\n".join(out) + "\n"


def developer_help() -> str:
    return """alp — geliştirici seçenekleri

  --root DİZİN      Paketleri / yerine bu dizine kur (test için; varsayılan: /)
  --index DOSYA     Kullanılacak katalog index.json dosyası
  --relocate        Tarifleri --root altında çalışacak şekilde derle
                    (@PREFIX@ = <root>/usr); başka dağıtımda kullanıcı kökü için

  --progress-fd N   İlerlemeyi N numaralı dosya tanıtıcısına satır başına bir JSON
                    olay olarak yaz (plan, step, phase, error, done); mağaza ve
                    PackageKit arka ucu içindir
  --json --dry-run  install/upgrade/remove işlem planını tek JSON nesnesi olarak
                    ver; hiçbir şey değişmez (işlem reddedilecekse çıkış 1)

  adopt-base        Önceden kurulmuş LFS dosyalarını korumalı paket olarak kaydet
                    (ayrıntı: alp adopt-base --help)

Güven ve derleme (ayrıntı: design/trust-model.md):
  --keyring DOSYA       Katalog imzasının denetleneceği anahtarlık
                        (varsayılan: /usr/share/alp/keys/alpbahos-catalog.gpg)
  --allowed-keys DOSYA  İmzalamaya izinli ve iptal edilmiş parmak izleri
                        (varsayılan: /usr/share/alp/keys/allowed.txt)
  --allow-unsigned      İmzasız kataloğu kabul et. Yalnız root; her çalıştırmada
                        uyarır; kalıcı yapılamaz; mağaza (PackageKit) kabul etmez
  --no-sandbox          Tarif adımlarını bubblewrap olmadan çalıştır. Yalnız root;
                        her derlemede uyarır; kalıcı yapılamaz
  --jobs N              Derlemede MAKEFLAGS=-jN (varsayılan 1)

Bu seçenekler komuttan önce ya da sonra yazılabilir:
  alp --root /tmp/deneme install figlet
  alp install figlet --root /tmp/deneme
"""


_ARGPARSE_TR = [
    ("usage: ", "Kullanım: "),
    ("\noptions:\n", "\nSeçenekler:\n"),
    ("\npositional arguments:\n", "\nArgümanlar:\n"),
    ("show this help message and exit", "Bu yardımı göster"),
]


class _AlpArgumentParser(argparse.ArgumentParser):
    """argparse with Turkish headings and short, friendly errors."""

    def __init__(self, *args, **kwargs):
        # Python 3.14+: plain text so the Turkish replacements below match.
        if "color" in inspect.signature(argparse.ArgumentParser.__init__).parameters:
            kwargs.setdefault("color", False)
        super().__init__(*args, **kwargs)

    def format_help(self) -> str:
        text = super().format_help()
        for en, tr in _ARGPARSE_TR:
            text = text.replace(en, tr)
        return text

    def format_usage(self) -> str:
        return super().format_usage().replace("usage: ", "Kullanım: ")

    def error(self, message: str):  # noqa: D401 - argparse API
        msg = _translate_argparse_error(message)
        self.exit(2, f"alp: {msg}\nYardım için: {self.prog} --help\n")


def _translate_argparse_error(message: str) -> str:
    m = re.match(r"argument command: invalid choice: '([^']*)'(?:, maybe you meant '([^']*)'\?)?", message)
    if m:
        wrong, close = m.group(1), m.group(2)
        if close is None:
            close = next(iter(difflib.get_close_matches(wrong, COMMANDS, 1)), None)
        hint = f" Bunu mu demek istediniz: alp {close}" if close else ""
        return f"'{wrong}' diye bir komut yok.{hint}"
    m = re.match(r"the following arguments are required: (.*)", message)
    if m:
        return f"eksik: {m.group(1)}"
    m = re.match(r"unrecognized arguments: (.*)", message)
    if m:
        return f"tanınmayan argüman: {m.group(1)}"
    m = re.match(r"argument (\S+): expected one argument", message)
    if m:
        return f"{m.group(1)} bir değer bekliyor"
    m = re.match(r"argument (\S+): invalid int value: '([^']*)'", message)
    if m:
        return f"{m.group(1)} bir tam sayı bekliyor: '{m.group(2)}'"
    m = re.match(r"argument (\S+): ignored explicit argument '([^']*)'", message)
    if m:
        return f"{m.group(1)} bir değer almaz: '{m.group(2)}'"
    return message


COMMANDS = [
    "search", "info", "list", "install", "remove", "upgrade", "autoremove",
    "update", "check", "recover", "protect", "unprotect", "adopt-base", "help",
]


def build_parser() -> argparse.ArgumentParser:
    p = _AlpArgumentParser(prog="alp", add_help=False)
    p.add_argument("-h", "--help", action="store_true", help=argparse.SUPPRESS)

    def global_options(parser: argparse.ArgumentParser, default) -> None:
        # Defined on the top-level parser AND every subcommand, so
        # `alp --dry-run install x` and `alp install x --dry-run` both work.
        # Subcommands use default=SUPPRESS so they never overwrite a value
        # given before the command.
        g = parser.add_argument_group("Genel seçenekler")
        g.add_argument("--dry-run", action="store_true", default=default,
                       help="Ne yapılacağını göster, hiçbir şeyi değiştirme")
        g.add_argument("--json", action="store_true", default=default,
                       help="search/list çıktısını ve --dry-run işlem planını JSON olarak ver (info her zaman JSON)")
        g.add_argument("--keep-build", action="store_true", default=default,
                       help="Başarılı kurulumdan sonra derleme dosyalarını silme")
        g.add_argument("--root", default=None if default is False else default, help=argparse.SUPPRESS)
        g.add_argument("--index", default=None if default is False else default, help=argparse.SUPPRESS)
        g.add_argument("--relocate", action="store_true", default=default, help=argparse.SUPPRESS)
        g.add_argument("--progress-fd", type=int, default=None if default is False else default,
                       help=argparse.SUPPRESS)
        # Trust and sandbox switches. None of them has a configuration-file or
        # environment form; --allow-unsigned and --no-sandbox are root only (main()).
        g.add_argument("--allow-unsigned", action="store_true", default=default, help=argparse.SUPPRESS)
        g.add_argument("--no-sandbox", action="store_true", default=default, help=argparse.SUPPRESS)
        g.add_argument("--keyring", default=None if default is False else default, help=argparse.SUPPRESS)
        g.add_argument("--allowed-keys", default=None if default is False else default, help=argparse.SUPPRESS)
        g.add_argument("--jobs", type=int, default=None if default is False else default, help=argparse.SUPPRESS)
        # D163/D164: the PackageKit backend (Discover has its own Flatpak backend) turns the Flathub offer and the
        # Debian box off: it never creates containers
        g.add_argument("--no-flathub", action="store_true", default=default, help=argparse.SUPPRESS)

    global_options(p, False)
    common = _AlpArgumentParser(add_help=False)
    global_options(common, argparse.SUPPRESS)

    sub = p.add_subparsers(dest="command", parser_class=_AlpArgumentParser)

    def command(name: str, description: str, *, args: str = "", confirm: bool = False, epilog: str | None = None):
        usage = f"alp {name} {args} [seçenekler]".replace("  ", " ")
        sp = sub.add_parser(
            name, parents=[common], description=description, epilog=epilog, usage=usage,
            formatter_class=argparse.RawDescriptionHelpFormatter,
            add_help=False,
        )
        sp.add_argument("-h", "--help", action="help", help="Bu yardımı göster")
        if confirm:
            sp.add_argument("-y", "--yes", action="store_true", help="Onay sormadan devam et")
        return sp

    sp = command("search", args="<kelime>", description="Katalogda adı veya açıklaması kelimeyi içeren paketleri listeler. Hiçbir şey kurmaz.",
                 epilog="Örnek:\n  alp search tema\n  alp search \"\"      # tüm katalog")
    sp.add_argument("term", metavar="kelime", help="Aranacak kelime")

    sp = command("info", args="<paket>", description="Paketin katalog ve kurulum bilgilerini JSON olarak gösterir.",
                 epilog="Örnek:\n  alp info figlet")
    sp.add_argument("name", metavar="paket", help="Paket adı")

    sp = command("install", args="<paket>", description="Paketi ve katalogdan gerektirdiği paketleri kurar. Önce işlem planını gösterip onay ister.",
                 confirm=True, epilog="Örnek:\n  alp install figlet\n  alp install -y figlet --reinstall")
    sp.add_argument("name", metavar="paket", help="Paket adı")
    sp.add_argument("--reinstall", action="store_true", help="Kuruluysa yeniden kur")
    sp.add_argument("--kutu", action="store_true",
                    help="Debian 13 kutusuna (Distrobox) apt ile kur; komutlar ~/.local/bin'e, uygulamalar menüye gelir")

    sp = command("upgrade", args="[paket]", description="Kurulu paketi yeni sürüme yükseltir. Ad verilmezse eskimiş tüm paketleri yükseltir.",
                 confirm=True, epilog="Örnek:\n  alp upgrade\n  alp upgrade figlet")
    sp.add_argument("name", metavar="paket", nargs="?", help="Paket adı (boşsa hepsi)")

    sp = command("remove", args="<paket>", description="Kurulu paketi kaldırır. Başka bir paket ona bağlıysa --cascade olmadan reddeder.",
                 confirm=True, epilog="Örnek:\n  alp remove figlet\n  alp remove --cascade libfoo")
    sp.add_argument("name", metavar="paket", help="Paket adı")
    sp.add_argument("--cascade", action="store_true", help="Ona bağlı kurulu paketleri de kaldır")
    sp.add_argument("--kutu", action="store_true", help="Debian kutusuna kurulmuş paketi kaldır")

    command("autoremove", "Bağımlılık olarak gelip artık hiçbir paketin ihtiyaç duymadığı paketleri kaldırır.",
            confirm=True)
    command("check", "Kurulu sistemi denetler: bozuk bağımlılıklar, çakışmalar, güncellemeler, sahipsiz paketler.")
    command("list", "Kurulu paketleri listeler.")
    command("recover", "Kesintiye uğrayan (kill -9, elektrik kesintisi) yarım işlemi günlükten geri alır.")

    sp = command("protect", args="<paket>", description="Paketi korumalı işaretler; remove ve autoremove onu kaldıramaz.")
    sp.add_argument("name", metavar="paket", help="Paket adı")
    sp = command("unprotect", args="<paket>", description="Paketin koruma işaretini kaldırır.")
    sp.add_argument("name", metavar="paket", help="Paket adı")

    sp = command("adopt-base", "Önceden kurulmuş LFS dosyalarını canlı kökle karşılaştırıp korumalı paket olarak kaydeder. "
                               "Kaynak arşivin doğruluğunu çağıran ayrıca doğrulamalıdır.")
    sp.add_argument("--manifest", required=True, help="alpbahOS.package-files/v1 JSON manifesti")
    sp.add_argument("--name", required=True, help="Beklenen paket adı; manifestle aynı olmalı")
    sp.add_argument("--version", required=True, help="Beklenen sürüm; manifestle aynı olmalı")
    sp.add_argument("--source-sha256", required=True, help="Bağımsız doğrulanmış kaynak arşiv SHA-256'sı")
    sp.add_argument("--manifest-sha256", help="Manifest dosyasının beklenen SHA-256'sı (isteğe bağlı)")

    sp = command("update", "Paket kataloğunu (index.json veya .tar.gz katalog paketi) kaynaktan yeniler. "
                           "Değiştirmeden önce farkı gösterir. Katalog bir git deposuysa ve \"source\" "
                           "yoksa uzak daldan ileri sarar (git pull --ff-only).",
                 epilog="Örnek:\n  alp update\n  alp update --dry-run")
    sp.add_argument("--source", help="https:// adresi veya yerel yol (varsayılan: katalogdaki \"source\" alanı)")
    sp.add_argument("--sha256", help="İndirilen dosyanın beklenen SHA-256'sı (önerilir)")

    sp = command("help", args="[konu]", description="Yardım ekranını gösterir.")
    sp.add_argument("topic", metavar="konu", nargs="?", help="Komut adı veya 'gelistirici'")

    return p


# Round 7: the installed system keeps its catalog at <root>/usr/share/alp/index.json; without --index the
# commands use that file (no config file exists; this is the smallest default that works on an installed system).
DEFAULT_INDEX_REL = "usr/share/alp/index.json"


def resolve_index_path(index_arg: str | None, paths: "Paths") -> Path:
    if index_arg:
        return Path(index_arg).resolve()
    candidate = paths.root / DEFAULT_INDEX_REL
    if candidate.is_file():
        return candidate.resolve()
    raise AlpError("Bu komut için --index PATH gereklidir (varsayılan katalog yok: %s)." % candidate)


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.help or args.command is None:
        sys.stdout.write(main_help())
        return 0
    if args.command == "help":
        if args.topic in ("gelistirici", "geliştirici", "dev"):
            sys.stdout.write(developer_help())
        elif args.topic:
            parser.parse_args([args.topic, "--help"])
        else:
            sys.stdout.write(main_help())
        return 0
    paths = Paths.resolve(args.root)
    try:
        if getattr(args, "kutu", False) and args.command in ("install", "remove"):
            # The Debian box needs no alp catalogue (and runs as a user, see _as_box_user)
            return _install_from_kutu(args) if args.command == "install" else _remove_from_kutu(args)
        if args.command == "adopt-base":
            return cmd_adopt_base(args, paths)
        if args.command == "recover":
            # Needs no catalog, and must stay usable when the catalog is the
            # problem: a pending journal blocks `alp update` too.
            return cmd_recover(args, paths)
        for flag, given in (("--allow-unsigned", args.allow_unsigned), ("--no-sandbox", args.no_sandbox)):
            if given and not _is_root():
                raise AlpError(f"{flag} yalnız root tarafından kullanılabilir.")
        jobs = getattr(args, "jobs", None)
        if jobs is not None and not 1 <= jobs <= 1024:
            raise AlpError("--jobs 1 ile 1024 arasında olmalı.")
        paths.trust = TrustPolicy(
            keyring=os.path.abspath(args.keyring) if args.keyring else "",
            allowed_keys=os.path.abspath(args.allowed_keys) if args.allowed_keys else "",
            allow_unsigned=bool(args.allow_unsigned),
        )
        paths.sandbox = "off" if args.no_sandbox else "require"
        paths.jobs = jobs or 1
        index_path = resolve_index_path(args.index, paths)
        index_dir = index_path.parent
        try:
            index = load_catalog(index_path, paths)
        except AlpError as exc:
            if args.command != "update":
                raise
            print(f"alp: uyarı: yerel katalog kabul edilmedi, içeriği kullanılmıyor: {_first_line(exc)}",
                  file=sys.stderr)
            index = None
        if args.command == "search":
            return cmd_search(index, args.term, as_json=args.json, index_dir=index_dir)
        if args.command == "info":
            db = load_db(paths)
            return cmd_info(index, db, args.name, index_dir=index_dir)
        if args.command == "list":
            return cmd_list(load_db(paths), as_json=args.json, box=None if args.json else _box_packages_of_caller())
        paths.keep_build = getattr(args, "keep_build", False)
        paths.relocate = getattr(args, "relocate", False)
        progress_fd = getattr(args, "progress_fd", None)
        if progress_fd is not None:
            try:
                paths.progress = os.fdopen(progress_fd, "w", encoding="utf-8", buffering=1, closefd=False)
            except OSError as exc:
                raise AlpError(f"--progress-fd {progress_fd} açılamadı: {exc}") from exc
        if args.command == "update":
            return cmd_update(args, paths, index_path, index)
        if args.command == "protect":
            return cmd_protect(args, paths, protect=True)
        if args.command == "unprotect":
            return cmd_protect(args, paths, protect=False)
        if args.command == "install":
            return cmd_install(args, paths, index, index_dir)
        if args.command == "upgrade":
            return cmd_upgrade(args, paths, index, index_dir)
        if args.command == "remove":
            return cmd_remove(args, paths, index)
        if args.command == "autoremove":
            return cmd_autoremove(args, paths, index)
        if args.command == "check":
            return cmd_check(paths, index, index_dir)
        raise AlpError(f"Bilinmeyen komut: {args.command}")
    except AlpError as exc:
        print(f"alp: hata: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"alp: hata: {exc}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as exc:
        print(f"alp: alt işlem başarısız (çıkış {exc.returncode}): {' '.join(exc.cmd)}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == _DROP_HELPER_FLAG:
        raise SystemExit(_drop_helper_main(sys.argv[2:]))
    if len(sys.argv) > 1 and sys.argv[1] == _AS_USER_FLAG:
        raise SystemExit(_as_user_main(sys.argv[2:]))
    raise SystemExit(main())
