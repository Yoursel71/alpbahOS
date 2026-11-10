"""ALP-TRUST-01: signed catalog (design/trust-model.md sections 3-5 and 7).

Real gpg/gpgv, no network. Keys are throwaway Ed25519 keys in tmp dirs
(trusthelpers.make_key). Every refusal test also checks that the local
catalog is byte-for-byte what it was.
"""

from __future__ import annotations

import argparse
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402
import alp_packagekit_backend as pkb  # noqa: E402
import trusthelpers  # noqa: E402
from trusthelpers import make_key, merged_keyring, sign_catalog  # noqa: E402

pytestmark = pytest.mark.skipif(not trusthelpers.HAVE_GPG, reason=trusthelpers.NO_GPG_REASON)

ALP_PY = Path(__file__).resolve().parent.parent / "alp.py"
RECIPE = {
    "name": "demo", "version": "1.0", "source_url": "demo-1.0.tar.gz", "sha256": "0" * 64,
    "build": {"configure": ["true"], "make": ["true"], "make_install": ["true"]},
}


def _core(directory: Path, name: str, version: str) -> dict:
    archive = directory / f"{name}-{version}.tar.gz"
    content = f"{name} {version}".encode()
    with tarfile.open(archive, "w:gz") as tf:
        for d in ("usr", "usr/share", f"usr/share/{name}"):
            info = tarfile.TarInfo(d)
            info.type = tarfile.DIRTYPE
            info.mode = 0o755
            tf.addfile(info)
        info = tarfile.TarInfo(f"usr/share/{name}/data")
        info.size = len(content)
        tf.addfile(info, io.BytesIO(content))
    return {"method": "core", "name": name, "version": version, "url": archive.name, "sha256": alp.sha256_of(archive)}


def _catalog(directory: Path, *, version: str = "1.0.0", recipe_version: str = "1.0", sign: bool = True,
             key=None, **stamp) -> Path:
    """index.json with one core package and one recipe, signed unless told otherwise."""
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "recipes").mkdir(exist_ok=True)
    (directory / "recipes/demo.recipe.json").write_text(
        json.dumps({**RECIPE, "version": recipe_version}), encoding="utf-8")
    index = directory / "index.json"
    index.write_text(json.dumps({"schema_version": 1, "entries": {
        "tool": _core(directory, "tool", version),
        "demo": {"method": "recipe", "recipe": "recipes/demo.recipe.json"},
    }}), encoding="utf-8")
    if sign:
        sign_catalog(index, key, **stamp)
    return index


def _snapshot(directory: Path) -> dict[str, bytes]:
    return {str(p.relative_to(directory)): p.read_bytes()
            for p in sorted(directory.rglob("*")) if p.is_file() and ".git" not in p.parts}


def _main(capsys, root: Path, index: Path, *argv: str) -> tuple[int, str, str]:
    code = alp.main(["--root", str(root), "--index", str(index), *argv])
    captured = capsys.readouterr()
    return code, captured.out, captured.err


def _flip_one_byte(path: Path, needle: bytes, replacement: bytes) -> None:
    data = path.read_bytes()
    assert len(needle) == len(replacement) and needle != replacement and needle in data
    assert sum(a != b for a, b in zip(needle, replacement)) == 1
    path.write_bytes(data.replace(needle, replacement, 1))


@pytest.fixture
def root(tmp_path: Path) -> Path:
    return tmp_path / "root"


@pytest.fixture(scope="module")
def other_keys(tmp_path_factory):
    """Keys that are NOT the session key: one unknown to every keyring, one to be revoked."""
    base = tmp_path_factory.mktemp("otherkeys")
    stranger = make_key(base, "alp stranger")
    retired = make_key(base, "alp retired")
    yield {"base": base, "stranger": stranger, "retired": retired}
    trusthelpers.kill_agents(stranger, retired)


# --------------------------------------------------------------------------
# accepted
# --------------------------------------------------------------------------

def test_signed_catalog_is_accepted_and_says_who_signed(tmp_path, root, session_key, capsys):
    index = _catalog(tmp_path / "cat", catalog_version=7)
    catalog = alp.load_catalog(index, alp.Paths.resolve(str(root)))
    assert catalog.signed is True
    assert catalog.signer == session_key.fingerprint
    assert catalog.catalog_version == 7 and catalog.expired is False
    assert catalog["entries"]["demo"]["recipe_sha256"] == alp.sha256_of(tmp_path / "cat/recipes/demo.recipe.json")
    code, out, err = _main(capsys, root, index, "search", "tool")
    assert code == 0 and "tool" in out and err == ""


def test_install_records_the_accepted_catalog_version_in_the_database(tmp_path, root, capsys):
    index = _catalog(tmp_path / "cat", catalog_version=7)
    assert _main(capsys, root, index, "install", "-y", "tool")[0] == 0
    db = alp.load_db(alp.Paths.resolve(str(root)))
    assert db["catalog"]["version"] == 7
    assert alp.stored_catalog_version(db) == 7


def test_read_only_commands_do_not_write_the_database(tmp_path, root, capsys):
    index = _catalog(tmp_path / "cat", catalog_version=7)
    assert _main(capsys, root, index, "search", "tool")[0] == 0
    assert _main(capsys, root, index, "check")[0] == 0
    assert not (root / "var/lib/alp/db.json").exists()


# --------------------------------------------------------------------------
# section 7, bullet 1: tampered catalog
# --------------------------------------------------------------------------

@pytest.mark.parametrize("command", [["search", "tool"], ["info", "tool"], ["install", "-y", "tool"],
                                     ["upgrade", "-y"], ["check"], ["list"], ["remove", "-y", "tool"]])
def test_one_changed_byte_in_index_is_refused_by_every_command(tmp_path, root, capsys, command):
    index = _catalog(tmp_path / "cat")
    _flip_one_byte(index, b"1.0.0", b"1.0.1")
    code, out, err = _main(capsys, root, index, *command)
    assert code == 1
    assert "Katalog imzası geçersiz" in err and "değiştirilmiş" in err
    assert not (root / "usr").exists()


def test_tampered_recipe_is_refused_before_it_is_parsed(tmp_path, root, capsys):
    index = _catalog(tmp_path / "cat")
    recipe = tmp_path / "cat/recipes/demo.recipe.json"
    # still valid JSON, and it would run a command of the attacker's choice
    recipe.write_text(recipe.read_text().replace('"configure": ["true"]', '"configure": ["evil"]'))
    code, out, err = _main(capsys, root, index, "install", "-y", "demo")
    assert code == 1
    assert "özetle uyuşmuyor" in err and "evil" not in err
    assert not (root / "usr").exists()


def test_tampered_recipe_that_is_not_json_reports_the_hash_not_a_parse_error(tmp_path, root):
    index = _catalog(tmp_path / "cat")
    (tmp_path / "cat/recipes/demo.recipe.json").write_text("{ not json")
    catalog = alp.load_catalog(index, alp.Paths.resolve(str(root)))
    with pytest.raises(alp.CatalogTrustError, match="özetle uyuşmuyor"):
        alp.read_recipe(catalog["entries"]["demo"], index.parent)
    with pytest.raises(alp.CatalogTrustError, match="özetle uyuşmuyor"):
        alp.catalog_version(catalog, index.parent, "demo")


def test_signed_catalog_must_pin_every_recipe(tmp_path, root, capsys, session_key):
    index = _catalog(tmp_path / "cat", sign=False)
    data = json.loads(index.read_text())
    data.update({"catalog_version": 1, "valid_until": "2999-01-01", "signed_keyring_version": 1})
    index.write_text(json.dumps(data))
    sign_catalog(index, stamp=False)  # a good signature over an index without recipe_sha256
    code, _, err = _main(capsys, root, index, "search", "tool")
    assert code == 1 and "recipe_sha256" in err


@pytest.mark.parametrize("field", ["catalog_version", "valid_until", "signed_keyring_version"])
def test_signed_catalog_must_carry_the_signed_fields(tmp_path, root, capsys, field):
    index = _catalog(tmp_path / "cat")
    data = json.loads(index.read_text())
    del data[field]
    index.write_text(json.dumps(data))
    sign_catalog(index, stamp=False)
    code, _, err = _main(capsys, root, index, "search", "tool")
    assert code == 1 and field in err


# --------------------------------------------------------------------------
# section 7, bullet 2: missing signature
# --------------------------------------------------------------------------

def test_missing_signature_is_refused(tmp_path, root, capsys):
    index = _catalog(tmp_path / "cat", sign=False)
    code, out, err = _main(capsys, root, index, "install", "-y", "tool")
    assert code == 1 and "imzalı değil" in err
    assert not (root / "usr").exists()


@pytest.mark.skipif(trusthelpers.is_root(), reason="root olmayan kullanıcı gerekir")
@pytest.mark.parametrize("flag", ["--allow-unsigned", "--no-sandbox"])
def test_dangerous_flags_are_root_only(tmp_path, root, capsys, flag):
    index = _catalog(tmp_path / "cat", sign=False)
    for argv in ([flag, "install", "-y", "tool"], ["install", "-y", "tool", flag]):
        code, out, err = _main(capsys, root, index, *argv)
        assert code == 1 and f"{flag} yalnız root" in err
    assert not (root / "usr").exists()


def test_engine_unsigned_policy_warns_every_time(tmp_path, root, capsys):
    """The engine-side form of --allow-unsigned (what main() sets for root)."""
    index = _catalog(tmp_path / "cat", sign=False)
    paths = alp.Paths.resolve(str(root))
    paths.trust = alp.TrustPolicy(allow_unsigned=True)
    for _ in range(2):
        catalog = alp.load_catalog(index, paths)
        assert catalog.signed is False
        assert "İMZASIZ KATALOG" in capsys.readouterr().err


def test_unsigned_policy_still_refuses_a_bad_signature(tmp_path, root):
    index = _catalog(tmp_path / "cat")
    _flip_one_byte(index, b"1.0.0", b"1.0.1")
    paths = alp.Paths.resolve(str(root))
    paths.trust = alp.TrustPolicy(allow_unsigned=True)
    with pytest.raises(alp.CatalogTrustError, match="imzası geçersiz"):
        alp.load_catalog(index, paths)


def test_unsigned_catalog_never_moves_the_stored_version(tmp_path, root):
    index = _catalog(tmp_path / "cat", sign=False)
    data = json.loads(index.read_text())
    data["catalog_version"] = 10 ** 9  # would block every real catalog if it were believed
    index.write_text(json.dumps(data))
    paths = alp.Paths.resolve(str(root))
    paths.trust = alp.TrustPolicy(allow_unsigned=True)
    catalog = alp.load_catalog(index, paths)
    args = argparse.Namespace(name="tool", dry_run=False, yes=True, reinstall=False)
    assert alp.cmd_install(args, paths, catalog, index.parent) == 0
    assert "catalog" not in alp.load_db(paths)


def test_no_configuration_can_allow_unsigned(tmp_path, monkeypatch):
    config = tmp_path / "trust.conf"
    config.write_text("allow_unsigned = true\n")
    monkeypatch.setattr(alp, "SYSTEM_TRUST_CONFIG", str(config))
    with pytest.raises(alp.CatalogTrustError):
        alp._load_trust_config()  # non-root: not root-owned; root: unknown key


# --------------------------------------------------------------------------
# section 7, bullet 3: wrong key, revoked key
# --------------------------------------------------------------------------

def test_signature_by_a_key_that_is_not_in_the_keyring(tmp_path, root, capsys, other_keys):
    index = _catalog(tmp_path / "cat", key=other_keys["stranger"])
    code, _, err = _main(capsys, root, index, "install", "-y", "tool")
    assert code == 1 and "anahtarlıkta yok" in err
    assert not (root / "usr").exists()


def test_signature_by_a_key_in_the_keyring_but_not_in_the_allowed_list(tmp_path, root, capsys, session_key, other_keys):
    stranger = other_keys["stranger"]
    keyring, allowed = merged_keyring(tmp_path, "both", [session_key, stranger], allowed=[session_key])
    index = _catalog(tmp_path / "cat", key=stranger)
    code, _, err = _main(capsys, root, index, "--keyring", str(keyring), "--allowed-keys", str(allowed),
                         "install", "-y", "tool")
    assert code == 1 and "izinli listede değil" in err and stranger.fingerprint in err


def test_signature_by_a_revoked_key(tmp_path, root, capsys, session_key, other_keys):
    retired = other_keys["retired"]
    index = _catalog(tmp_path / "cat", key=retired)
    trusted = merged_keyring(tmp_path, "before", [session_key, retired], allowed=[session_key, retired])
    code, _, err = _main(capsys, root, index, "--keyring", str(trusted[0]), "--allowed-keys", str(trusted[1]),
                         "search", "tool")
    assert code == 0, err  # the same catalog was fine while the key was allowed
    revoked = merged_keyring(tmp_path, "after", [session_key, retired], allowed=[session_key, retired],
                             revoked=[retired])
    code, _, err = _main(capsys, root, index, "--keyring", str(revoked[0]), "--allowed-keys", str(revoked[1]),
                         "install", "-y", "tool")
    assert code == 1 and "iptal listesinde" in err
    assert not (root / "usr").exists()


def test_signature_by_an_expired_key(tmp_path, root, capsys):
    key = make_key(tmp_path, "alp shortlived", expire="seconds=4")
    try:
        index = _catalog(tmp_path / "cat", key=key)
        time.sleep(5)
        code, _, err = _main(capsys, root, index, *key.cli, "search", "tool")
    finally:
        trusthelpers.kill_agents(key)
    assert code == 1 and "süresi dolmuş" in err


def test_two_signatures_are_refused(tmp_path, root, capsys, session_key, other_keys):
    index = _catalog(tmp_path / "cat")
    sig = index.with_name("index.json.sig")
    first = sig.read_bytes()
    sign_catalog(index, other_keys["stranger"], stamp=False)
    sig.write_bytes(first + sig.read_bytes())
    # both keys known and allowed: each signature alone would be good
    stranger = other_keys["stranger"]
    keyring, allowed = merged_keyring(tmp_path, "both", [session_key, stranger], allowed=[session_key, stranger])
    code, _, err = _main(capsys, root, index, "--keyring", str(keyring), "--allowed-keys", str(allowed),
                         "search", "tool")
    assert code == 1 and "tam olarak bir geçerli imza" in err


def test_signature_of_another_file_is_refused(tmp_path, root, capsys):
    index = _catalog(tmp_path / "cat", version="1.0.0")
    other = _catalog(tmp_path / "other", version="2.0.0")
    shutil.copy(other.with_name("index.json.sig"), index.with_name("index.json.sig"))
    code, _, err = _main(capsys, root, index, "search", "tool")
    assert code == 1 and "imzası geçersiz" in err


FPR = "A" * 40
GOOD = f"[GNUPG:] NEWSIG\n[GNUPG:] GOODSIG {FPR[-16:]} x\n[GNUPG:] VALIDSIG {FPR} 2026-11-10 1 0 4 0 22 10 00 {FPR}\n"


@pytest.mark.parametrize("status, code, why", [
    (GOOD.encode(), 0, None),
    (GOOD.encode(), 1, "gpgv"),                                              # good lines, bad exit code
    (b"", 0, "tam olarak bir"),                                              # exit 0 alone proves nothing
    (GOOD.replace("GOODSIG", "EXPKEYSIG").encode(), 0, "süresi dolmuş"),     # VALIDSIG present, key expired
    (GOOD.replace("GOODSIG", "REVKEYSIG").encode(), 0, "iptal"),
    ((GOOD + f"[GNUPG:] BADSIG {FPR[-16:]} x\n").encode(), 0, "uyuşmuyor"),
    ((GOOD + GOOD).encode(), 0, "tam olarak bir"),                           # two signatures
    (GOOD.replace("[GNUPG:] VALIDSIG", "VALIDSIG").encode(), 0, "beklenmeyen"),  # not a status line
    (GOOD.replace(" 22 10 00 ", " 22 10 01 ").encode(), 0, "ikili"),         # text-mode signature
    (GOOD.replace(" 22 10 00 ", " 22 2 00 ").encode(), 0, "zayıf"),          # SHA-1
    (GOOD.replace(f" 00 {FPR}", " 00").encode(), 0, "eksik alanlı"),         # no primary fingerprint
    (f"[GNUPG:] VALIDSIG {FPR} 2026-11-10 1 0 4 0 22 10 00 {FPR}\n".encode(), 0, "tam olarak bir"),  # no GOODSIG
])
def test_gpgv_status_is_read_strictly(status, code, why):
    if why is None:
        assert alp._parse_gpgv_status(status, code) == (FPR, FPR)
    else:
        with pytest.raises(alp.CatalogTrustError, match=why):
            alp._parse_gpgv_status(status, code)


def test_allowed_keys_file_is_parsed_strictly():
    parsed = alp.parse_allowed_keys(
        f"# c\nkeyring-version 4\n{FPR.lower()}  # trailing comment\nrevoked {'B' * 40}\n\n".encode(), "x")
    assert parsed == alp.AllowedKeys(frozenset({FPR}), frozenset({"B" * 40}), 4)
    for bad in (b"revoke " + FPR.encode(), b"ABCD", FPR.encode() + b" extra", b"keyring-version x",
                b"keyring-version 1\nkeyring-version 2", "ş".encode()):
        with pytest.raises(alp.CatalogTrustError):
            alp.parse_allowed_keys(bad, "x")


def test_environment_cannot_redirect_the_keyring(tmp_path, root, other_keys, monkeypatch):
    """A catalog signed by a stranger stays refused whatever the environment
    says: alp reads no trust setting from it, and gpgv gets a fixed one."""
    stranger = other_keys["stranger"]
    index = _catalog(tmp_path / "cat", key=stranger)
    env = dict(os.environ, GNUPGHOME=str(stranger.home), ALP_KEYRING=str(stranger.keyring),
               ALP_ALLOWED_KEYS=str(stranger.allowed), ALP_ALLOW_UNSIGNED="1", ALP_TRUST_CONFIG=str(tmp_path / "c"),
               HOME=str(stranger.home.parent))
    (tmp_path / "c").write_text(f"keyring = {stranger.keyring}\nallowed_keys = {stranger.allowed}\n")
    done = subprocess.run(
        [sys.executable, str(ALP_PY), "--root", str(root), "--index", str(index), *trusthelpers.SESSION_KEY.cli,
         "search", "tool"], capture_output=True, text=True, env=env, stdin=subprocess.DEVNULL)
    assert done.returncode == 1 and "anahtarlıkta yok" in done.stderr
    # and the same catalog is fine once the stranger's key is given on the command line
    done = subprocess.run(
        [sys.executable, str(ALP_PY), "--root", str(root), "--index", str(index), *stranger.cli, "search", "tool"],
        capture_output=True, text=True, env=env, stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr


@pytest.mark.skipif(trusthelpers.is_root(), reason="root olmayan kullanıcı gerekir")
def test_trust_config_must_be_root_owned(tmp_path, monkeypatch, session_key):
    config = tmp_path / "trust.conf"
    config.write_text(f"keyring = {session_key.keyring}\nallowed_keys = {session_key.allowed}\n")
    monkeypatch.setattr(alp, "SYSTEM_TRUST_CONFIG", str(config))
    with pytest.raises(alp.CatalogTrustError, match="root'a ait"):
        alp._trust_paths(alp.TrustPolicy())
    # both files named on the command line: the config file is not even read
    assert alp._trust_paths(session_key.policy()) == (str(session_key.keyring), str(session_key.allowed))


def test_trust_files_may_not_be_symlinks(tmp_path, root, capsys, session_key):
    index = _catalog(tmp_path / "cat")
    link = tmp_path / "keyring-link.gpg"
    link.symlink_to(session_key.keyring)
    code, _, err = _main(capsys, root, index, "--keyring", str(link), "--allowed-keys", str(session_key.allowed),
                         "search", "tool")
    assert code == 1 and "anahtarlığı okunamadı" in err


def test_missing_gpgv_refuses(tmp_path, root, capsys, monkeypatch):
    index = _catalog(tmp_path / "cat")
    monkeypatch.setattr(alp, "GPGV_CANDIDATES", (str(tmp_path / "no-gpgv"),))
    code, _, err = _main(capsys, root, index, "search", "tool")
    assert code == 1 and "gpgv bulunamadı" in err


def test_keyring_version_hint_is_printed_but_does_not_refuse(tmp_path, root, capsys):
    index = _catalog(tmp_path / "cat", keyring_version=2)  # the session allowed.txt says keyring-version 1
    code, out, err = _main(capsys, root, index, "search", "tool")
    assert code == 0 and "alp upgrade alp-keyring" in err


# --------------------------------------------------------------------------
# section 7, bullet 4: rollback and expiry
# --------------------------------------------------------------------------

def _update(capsys, root: Path, index: Path, source: Path, *extra: str) -> tuple[int, str, str]:
    return _main(capsys, root, index, "update", "--source", str(source), *extra)


def test_update_accepts_a_newer_signed_index_and_records_its_version(tmp_path, root, capsys):
    index = _catalog(tmp_path / "local", version="1.0.0", catalog_version=5)
    newer = _catalog(tmp_path / "upstream", version="2.0.0", catalog_version=6)
    shutil.copy(tmp_path / "upstream/tool-2.0.0.tar.gz", tmp_path / "local")
    code, out, err = _update(capsys, root, index, newer)
    assert code == 0, err
    assert "değişti   tool 1.0.0 -> 2.0.0" in out
    assert index.read_bytes() == newer.read_bytes()
    assert index.with_name("index.json.sig").read_bytes() == newer.with_name("index.json.sig").read_bytes()
    assert alp.load_db(alp.Paths.resolve(str(root)))["catalog"]["version"] == 6
    assert _main(capsys, root, index, "install", "-y", "tool")[0] == 0
    assert (root / "usr/share/tool/data").read_text() == "tool 2.0.0"


def test_update_refuses_an_older_catalog_version(tmp_path, root, capsys):
    index = _catalog(tmp_path / "local", version="2.0.0", catalog_version=6)
    older = _catalog(tmp_path / "upstream", version="1.0.0", catalog_version=5)  # genuine signature, replayed
    before = _snapshot(tmp_path / "local")
    code, out, err = _update(capsys, root, index, older)
    assert code == 1 and "geri gidiyor" in err and "Yerel katalog değiştirilmedi" in err
    assert _snapshot(tmp_path / "local") == before
    assert not (root / "var/lib/alp/db.json").exists()


def test_update_refuses_rollback_below_the_stored_version_even_if_the_local_file_is_older(tmp_path, root, capsys):
    index = _catalog(tmp_path / "local", version="1.0.0", catalog_version=9)
    assert _main(capsys, root, index, "install", "-y", "tool")[0] == 0  # stores 9
    # the local file is swapped for an older, genuinely signed one ...
    _catalog(tmp_path / "local", version="1.0.0", catalog_version=3)
    code, _, err = _main(capsys, root, index, "search", "tool")
    assert code == 1 and "geri gidiyor" in err and "bu katalog 3" in err and "9" in err
    # ... and an update to version 8 is still a rollback for this system
    eight = _catalog(tmp_path / "upstream", version="1.5.0", catalog_version=8)
    before = _snapshot(tmp_path / "local")
    code, _, err = _update(capsys, root, index, eight)
    assert code == 1 and "geri gidiyor" in err
    assert _snapshot(tmp_path / "local") == before
    # `alp update` is the way out: a catalog at or above 9 is accepted although the local one is refused
    nine = _catalog(tmp_path / "upstream", version="1.5.0", catalog_version=9)
    shutil.copy(tmp_path / "upstream/tool-1.5.0.tar.gz", tmp_path / "local")
    code, _, err = _update(capsys, root, index, nine)
    assert code == 0 and "yerel katalog kabul edilmedi" in err
    assert _main(capsys, root, index, "search", "tool")[0] == 0


def test_update_refuses_an_expired_catalog(tmp_path, root, capsys):
    index = _catalog(tmp_path / "local", catalog_version=5)
    stale = _catalog(tmp_path / "upstream", version="2.0.0", catalog_version=6, valid_until="2020-01-01")
    before = _snapshot(tmp_path / "local")
    code, _, err = _update(capsys, root, index, stale)
    assert code == 1 and "süresi dolmuş" in err and "2020-01-01" in err
    assert _snapshot(tmp_path / "local") == before


def test_expired_local_catalog_warns_and_still_installs(tmp_path, root, capsys):
    """D172: the image ships a signed snapshot and must install offline after it expires."""
    index = _catalog(tmp_path / "cat", valid_until="2020-01-01")
    code, out, err = _main(capsys, root, index, "install", "-y", "tool")
    assert code == 0
    assert "katalog süresi doldu" in err and "`alp update` çalıştırın" in err and "2020-01-01" in err
    assert (root / "usr/share/tool/data").is_file()


def test_valid_until_is_inclusive_and_the_clock_is_a_parameter(session_key):
    data = json.dumps({"entries": {}, "catalog_version": 1, "valid_until": "2026-06-30",
                       "signed_keyring_version": 1}).encode()
    home = session_key.home
    done = subprocess.run([trusthelpers.GPG, "--homedir", str(home), "--batch", "--detach-sign", "--output", "-"],
                          input=data, capture_output=True)
    sig = done.stdout
    accept = lambda today, at_update: alp.accept_catalog_bytes(  # noqa: E731
        data, sig, alp.TrustPolicy(), origin="t", at_update=at_update, floor=None, today=today)
    assert accept("2026-06-30", True).expired is False
    assert accept("2026-07-01", False).expired is True
    with pytest.raises(alp.CatalogTrustError, match="süresi dolmuş"):
        accept("2026-07-01", True)
    for bad in ("2026-13-01", "20260630", "yarın"):
        other = data.replace(b"2026-06-30", bad.encode())
        done = subprocess.run([trusthelpers.GPG, "--homedir", str(home), "--batch", "--detach-sign", "--output", "-"],
                              input=other, capture_output=True)
        with pytest.raises(alp.CatalogTrustError, match="valid_until"):
            alp.accept_catalog_bytes(other, done.stdout, alp.TrustPolicy(), origin="t", at_update=True, floor=None)


# --------------------------------------------------------------------------
# section 7: the old catalog stays after every refused update
# --------------------------------------------------------------------------

def _bundle(tmp_path: Path, upstream: Path, extra: dict[str, bytes] | None = None, name: str = "bundle.tar.gz") -> Path:
    bundle = tmp_path / name
    with tarfile.open(bundle, "w:gz") as tf:
        for path in sorted(upstream.rglob("*")):
            if path.is_file():
                tf.add(path, arcname=str(path.relative_to(upstream)))
        for rel, data in (extra or {}).items():
            info = tarfile.TarInfo(rel)
            info.size = len(data)
            tf.addfile(info, io.BytesIO(data))
    return bundle


def test_update_refuses_an_unsigned_index_and_an_unsigned_bundle(tmp_path, root, capsys):
    index = _catalog(tmp_path / "local", catalog_version=5)
    before = _snapshot(tmp_path / "local")
    plain = _catalog(tmp_path / "upstream", version="2.0.0", sign=False)
    code, _, err = _update(capsys, root, index, plain)
    assert code == 1 and "imzalı değil" in err
    code, _, err = _update(capsys, root, index, _bundle(tmp_path, tmp_path / "upstream"))
    assert code == 1 and "imzalı değil" in err
    assert _snapshot(tmp_path / "local") == before


def test_update_refuses_a_tampered_index(tmp_path, root, capsys):
    index = _catalog(tmp_path / "local", catalog_version=5)
    before = _snapshot(tmp_path / "local")
    newer = _catalog(tmp_path / "upstream", version="2.0.0", catalog_version=6)
    _flip_one_byte(newer, b"2.0.0", b"2.0.1")
    code, _, err = _update(capsys, root, index, newer)
    assert code == 1 and "imzası geçersiz" in err and "Yerel katalog değiştirilmedi" in err
    code, _, err = _update(capsys, root, index, _bundle(tmp_path, tmp_path / "upstream"))
    assert code == 1 and "imzası geçersiz" in err
    assert _snapshot(tmp_path / "local") == before


def test_update_refuses_a_bundle_with_a_tampered_recipe(tmp_path, root, capsys):
    index = _catalog(tmp_path / "local", catalog_version=5)
    before = _snapshot(tmp_path / "local")
    _catalog(tmp_path / "upstream", version="2.0.0", recipe_version="2.0", catalog_version=6)
    recipe = tmp_path / "upstream/recipes/demo.recipe.json"
    recipe.write_text(recipe.read_text().replace('["true"]', '["evil"]', 1))
    code, _, err = _update(capsys, root, index, _bundle(tmp_path, tmp_path / "upstream"))
    assert code == 1 and "özetle uyuşmuyor" in err and "Yerel katalog değiştirilmedi" in err
    assert _snapshot(tmp_path / "local") == before


def test_update_refuses_a_bundle_with_a_tampered_core_archive(tmp_path, root, capsys):
    index = _catalog(tmp_path / "local", catalog_version=5)
    before = _snapshot(tmp_path / "local")
    _catalog(tmp_path / "upstream", version="2.0.0", catalog_version=6)
    (tmp_path / "upstream/tool-2.0.0.tar.gz").write_bytes(b"not the archive that was signed")
    code, _, err = _update(capsys, root, index, _bundle(tmp_path, tmp_path / "upstream"))
    assert code == 1 and "özetle uyuşmuyor" in err
    assert _snapshot(tmp_path / "local") == before


def test_update_refuses_a_bare_index_when_a_recipe_it_pins_differs_locally(tmp_path, root, capsys):
    index = _catalog(tmp_path / "local", catalog_version=5)
    before = _snapshot(tmp_path / "local")
    newer = _catalog(tmp_path / "upstream", recipe_version="2.0", catalog_version=6)
    code, _, err = _update(capsys, root, index, newer)
    assert code == 1 and "özetle uyuşmuyor" in err and "katalog paketi" in err
    assert _snapshot(tmp_path / "local") == before


def test_bundle_installs_only_what_the_signed_index_names(tmp_path, root, capsys, other_keys):
    """A genuine signed index wrapped together with files of the sender's own:
    a replacement keyring must not land next to the catalog."""
    index = _catalog(tmp_path / "local", catalog_version=5)
    _catalog(tmp_path / "upstream", version="2.0.0", recipe_version="2.0", catalog_version=6)
    stranger = other_keys["stranger"]
    bundle = _bundle(tmp_path, tmp_path / "upstream", extra={
        "keys/allowed.txt": stranger.allowed.read_bytes(),
        "keys/alpbahos-catalog.gpg": stranger.keyring.read_bytes(),
        "recipes/unlisted.recipe.json": b"{}",
        ".alp-update/x": b"x",
    })
    code, out, err = _update(capsys, root, index, bundle)
    assert code == 0, err
    assert "4 dosya katalogda adı geçmediği için yok sayıldı" in out
    local = tmp_path / "local"
    assert not (local / "keys").exists() and not (local / "recipes/unlisted.recipe.json").exists()
    assert json.loads((local / "recipes/demo.recipe.json").read_text())["version"] == "2.0"
    assert (local / "tool-2.0.0.tar.gz").is_file()
    assert (local / "index.json.prev").is_file() and (local / "index.json.sig.prev").is_file()
    assert not (local / ".alp-update").exists()
    assert alp.load_db(alp.Paths.resolve(str(root)))["catalog"]["version"] == 6
    assert _main(capsys, root, index, "search", "tool")[0] == 0  # the installed pair verifies


def test_update_dry_run_verifies_but_changes_nothing(tmp_path, root, capsys):
    index = _catalog(tmp_path / "local", catalog_version=5)
    before = _snapshot(tmp_path / "local")
    newer = _catalog(tmp_path / "upstream", version="2.0.0", catalog_version=6)
    code, out, _ = _update(capsys, root, index, newer, "--dry-run")
    assert code == 0 and "dry-run" in out
    stale = _catalog(tmp_path / "upstream", version="2.0.0", catalog_version=4)
    assert _update(capsys, root, index, stale, "--dry-run")[0] == 1
    assert _snapshot(tmp_path / "local") == before


def test_update_is_the_way_out_of_an_unsigned_local_catalog(tmp_path, root, capsys):
    index = _catalog(tmp_path / "local", sign=False)
    data = json.loads(index.read_text())
    newer = _catalog(tmp_path / "upstream", version="2.0.0", catalog_version=6)
    data["source"] = str(newer)  # an unverified catalog's "source" must not be followed
    index.write_text(json.dumps(data))
    code, _, err = _main(capsys, root, index, "update")
    assert code == 1 and "kaynağı yok" in err
    shutil.copy(tmp_path / "upstream/tool-2.0.0.tar.gz", tmp_path / "local")
    code, _, err = _update(capsys, root, index, newer)
    assert code == 0 and "yerel katalog kabul edilmedi" in err
    assert _main(capsys, root, index, "search", "tool")[0] == 0


def test_recover_does_not_need_a_catalog(tmp_path, root, capsys):
    index = _catalog(tmp_path / "cat", sign=False)
    code, out, _ = _main(capsys, root, index, "recover")
    assert code == 0 and "Geri alınacak yarım işlem yok" in out
    assert alp.main(["--root", str(root), "recover"]) == 0


# --------------------------------------------------------------------------
# git transport
# --------------------------------------------------------------------------

needs_git = pytest.mark.skipif(shutil.which("git") is None, reason="git yok")


def _git(cwd: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


def _commit_push(repo: Path, message: str) -> None:
    _git(repo, "add", "-A")
    _git(repo, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", message)
    _git(repo, "push", "-q", "origin", "HEAD:main")


@pytest.fixture
def git_catalogs(tmp_path):
    bare = tmp_path / "remote.git"
    _git(tmp_path, "init", "-q", "--bare", "-b", "main", str(bare))
    upstream = tmp_path / "upstream"
    _git(tmp_path, "clone", "-q", str(bare), str(upstream))
    _catalog(upstream, version="1.0.0", catalog_version=5)
    _commit_push(upstream, "v1")
    local = tmp_path / "local"
    _git(tmp_path, "clone", "-q", str(bare), str(local))
    return upstream, local


@needs_git
def test_git_update_fast_forwards_to_a_signed_catalog(git_catalogs, root, capsys):
    upstream, local = git_catalogs
    _catalog(upstream, version="2.0.0", recipe_version="2.0", catalog_version=6)
    _commit_push(upstream, "v2")
    code, out, err = _main(capsys, root, local / "index.json", "update")
    assert code == 0, err
    assert "Katalog güncellendi" in out
    assert _git(local, "rev-parse", "HEAD") == _git(upstream, "rev-parse", "HEAD")
    assert alp.load_db(alp.Paths.resolve(str(root)))["catalog"]["version"] == 6


@needs_git
@pytest.mark.parametrize("damage", ["index", "recipe", "unsigned", "rollback", "expired"])
def test_git_update_verifies_before_touching_the_checkout(git_catalogs, root, capsys, damage):
    upstream, local = git_catalogs
    if damage == "rollback":
        _catalog(upstream, version="0.9.0", catalog_version=4)
    elif damage == "expired":
        _catalog(upstream, version="2.0.0", catalog_version=6, valid_until="2020-01-01")
    else:
        _catalog(upstream, version="2.0.0", recipe_version="2.0", catalog_version=6)
    if damage == "index":
        _flip_one_byte(upstream / "index.json", b"2.0.0", b"2.0.1")
    elif damage == "recipe":
        recipe = upstream / "recipes/demo.recipe.json"
        recipe.write_text(recipe.read_text().replace('["true"]', '["evil"]', 1))
    elif damage == "unsigned":
        (upstream / "index.json.sig").unlink()
    _commit_push(upstream, damage)
    head, before = _git(local, "rev-parse", "HEAD"), _snapshot(local)
    code, _, err = _main(capsys, root, local / "index.json", "update")
    assert code == 1 and "eski hâline dokunulmadı" in err
    assert _git(local, "rev-parse", "HEAD") == head and _snapshot(local) == before
    assert _git(local, "status", "--porcelain") == ""


@needs_git
def test_git_update_refuses_when_the_keyring_lives_in_the_checkout(git_catalogs, root, capsys, session_key):
    upstream, local = git_catalogs
    (local / "keys").mkdir()
    shutil.copy(session_key.keyring, local / "keys/alpbahos-catalog.gpg")
    shutil.copy(session_key.allowed, local / "keys/allowed.txt")
    _catalog(upstream, version="2.0.0", recipe_version="2.0", catalog_version=6)
    _commit_push(upstream, "v2")
    head = _git(local, "rev-parse", "HEAD")
    code, _, err = _main(capsys, root, local / "index.json", "--keyring", str(local / "keys/alpbahos-catalog.gpg"),
                         "--allowed-keys", str(local / "keys/allowed.txt"), "update")
    assert code == 1 and "git katalog deposunun içinde" in err
    assert _git(local, "rev-parse", "HEAD") == head


# --------------------------------------------------------------------------
# PackageKit backend
# --------------------------------------------------------------------------

def test_packagekit_backend_refuses_an_unsigned_catalog(tmp_path, root):
    index = _catalog(tmp_path / "cat", sign=False)
    for call in (lambda: pkb.alp_search(ALP_PY, root, index, "tool"),
                 lambda: pkb.alp_install(ALP_PY, root, index, "tool"),
                 lambda: pkb.alp_plan(ALP_PY, root, index, "install", "tool"),
                 lambda: pkb.alp_updates(ALP_PY, root, index),
                 lambda: pkb.alp_list(ALP_PY, root, index)):
        with pytest.raises(pkb.AlpBackendError, match="imzalı değil"):
            call()
    assert not (root / "usr").exists()


def test_packagekit_backend_accepts_the_signed_catalog(tmp_path, root):
    index = _catalog(tmp_path / "cat")
    pkb.alp_install(ALP_PY, root, index, "tool")
    assert (root / "usr/share/tool/data").is_file()


@pytest.mark.parametrize("flag", ["--allow-unsigned", "--no-sandbox", "--allow-unsigned=1"])
def test_packagekit_backend_never_passes_the_dangerous_flags(tmp_path, root, monkeypatch, flag):
    index = _catalog(tmp_path / "cat", sign=False)
    ran = []
    monkeypatch.setattr(pkb.subprocess, "run", lambda *a, **k: ran.append(a))
    with pytest.raises(pkb.AlpBackendError, match="kullanmaz"):
        pkb._run_alp(ALP_PY, root, index, [flag, "install", "--yes", "tool"])
    monkeypatch.setattr(pkb, "TEST_TRUST_ARGS", (flag,))
    with pytest.raises(pkb.AlpBackendError, match="kullanmaz"):
        pkb._run_alp(ALP_PY, root, index, ["install", "--yes", "tool"])
    assert ran == []


def test_no_wrapper_in_the_backend_mentions_the_dangerous_flags():
    source = Path(pkb.__file__).read_text(encoding="utf-8")
    assert source.count("--allow-unsigned") == 1 and source.count("--no-sandbox") == 1  # only FORBIDDEN_ALP_FLAGS
