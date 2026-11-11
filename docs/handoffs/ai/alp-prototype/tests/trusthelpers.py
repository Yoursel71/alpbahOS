"""Test keys and signed test catalogs (ALP-TRUST-01).

Keys are made with the host's gpg in a temp GNUPGHOME: Ed25519, no
passphrase, never written anywhere else, gone with the temp dir. Nothing
here is a product path: alp verifies with gpgv and never calls gpg.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402
import alp_catalog_tool  # noqa: E402

GPG = shutil.which("gpg")
HAVE_GPG = GPG is not None and alp._find_fixed_program(alp.GPGV_CANDIDATES) is not None
NO_GPG_REASON = "gpg ya da gpgv yok: imzalı katalog testleri çalıştırılamaz"

# The session key the suite signs with; set by conftest.py.
SESSION_KEY: "TestKey | None" = None


@dataclass
class TestKey:
    __test__ = False  # not a pytest class
    home: Path
    fingerprint: str
    keyring: Path  # exported public key (binary), what --keyring takes
    allowed: Path  # allowed.txt naming this key

    @property
    def cli(self) -> list[str]:
        return ["--keyring", str(self.keyring), "--allowed-keys", str(self.allowed)]

    def policy(self) -> alp.TrustPolicy:
        return alp.TrustPolicy(keyring=str(self.keyring), allowed_keys=str(self.allowed))


def _gpg(home: Path, *args: str) -> str:
    done = subprocess.run([GPG, "--homedir", str(home), "--batch", "--no-tty", *args],
                          capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if done.returncode != 0:
        raise RuntimeError(f"gpg {' '.join(args)} -> {done.returncode}: {done.stderr}")
    return done.stdout


def make_key(base: Path, name: str = "alp test", expire: str = "never") -> TestKey:
    """A fresh Ed25519 signing key in base/<name>/, with its keyring and allowed.txt."""
    if not HAVE_GPG:
        pytest.skip(NO_GPG_REASON)
    slug = name.replace(" ", "-")
    home = base / f"gnupg-{slug}"
    home.mkdir(mode=0o700, parents=True)
    _gpg(home, "--pinentry-mode", "loopback", "--passphrase", "",
         "--quick-generate-key", f"{name} <test@alp.invalid>", "ed25519", "sign", expire)
    listing = _gpg(home, "--list-keys", "--with-colons")
    fingerprint = next(line.split(":")[9] for line in listing.splitlines() if line.startswith("fpr:"))
    keyring = base / f"{slug}.gpg"
    _gpg(home, "--output", str(keyring), "--export", fingerprint)
    allowed = base / f"{slug}.allowed.txt"
    allowed.write_text(f"# test key\nkeyring-version 1\n{fingerprint}\n", encoding="ascii")
    return TestKey(home, fingerprint, keyring, allowed)


def kill_agents(*keys: TestKey) -> None:
    gpgconf = shutil.which("gpgconf")
    for key in keys:
        if gpgconf and key is not None:
            subprocess.run([gpgconf, "--homedir", str(key.home), "--kill", "all"],
                           capture_output=True, stdin=subprocess.DEVNULL)


def merged_keyring(base: Path, name: str, keys: list[TestKey], *, allowed: list[TestKey],
                   revoked: list[TestKey] = (), keyring_version: int = 1) -> tuple[Path, Path]:
    """One keyring holding several public keys, and an allowed.txt for it."""
    keyring = base / f"{name}.gpg"
    keyring.write_bytes(b"".join(k.keyring.read_bytes() for k in keys))
    allowed_file = base / f"{name}.allowed.txt"
    lines = [f"keyring-version {keyring_version}"]
    lines += [k.fingerprint for k in allowed]
    lines += [f"revoked {k.fingerprint}" for k in revoked]
    allowed_file.write_text("\n".join(lines) + "\n", encoding="ascii")
    return keyring, allowed_file


def sign_catalog(index_path: Path, key: TestKey | None = None, *, catalog_version: int = 1,
                 valid_until: str | None = None, keyring_version: int = 1, stamp: bool = True) -> Path:
    """Stamp (recipe hashes, version, expiry) and sign index.json in place.
    Call it again after every change to the catalog. Returns the .sig path."""
    key = key or SESSION_KEY
    if key is None:
        pytest.skip(NO_GPG_REASON)
    if stamp:
        alp_catalog_tool.stamp(Path(index_path), catalog_version=catalog_version,
                               keyring_version=keyring_version, valid_until=valid_until)
    return alp_catalog_tool.sign(Path(index_path), gpg=GPG, homedir=str(key.home), local_user=key.fingerprint)


def is_root() -> bool:
    return hasattr(os, "geteuid") and os.geteuid() == 0
