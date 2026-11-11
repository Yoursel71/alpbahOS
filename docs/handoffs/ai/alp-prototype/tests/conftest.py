"""Shared test setup for the signed catalog (ALP-TRUST-01, DECISIONS D170).

How the suite lives with a catalog that must be signed:

- Tests that drive `alp.main()` or the PackageKit wrappers sign their
  catalog with a key generated here, once per session, in a temp dir
  (trusthelpers.sign_catalog). The built-in keyring paths are pointed at
  that key for the test process; the wrappers' subprocesses get the same
  files through `--keyring/--allowed-keys`.
- Tests that call engine functions directly on unsigned fixtures say so by
  giving their Paths an explicit `TrustPolicy(allow_unsigned=True)`. The
  root-only rule belongs to the `--allow-unsigned` flag and is tested in
  test_trust_catalog.py; nothing here turns signature checking off by default.
- The host's own /usr/share/alp/keys and /etc/alp/trust.conf are never read.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402
import alp_packagekit_backend as pkb  # noqa: E402
import trusthelpers  # noqa: E402


@pytest.fixture(scope="session")
def session_key(tmp_path_factory):
    if not trusthelpers.HAVE_GPG:
        yield None
        return
    key = trusthelpers.make_key(tmp_path_factory.mktemp("trust"), "alp session")
    trusthelpers.SESSION_KEY = key
    yield key
    trusthelpers.SESSION_KEY = None
    trusthelpers.kill_agents(key)


@pytest.fixture(autouse=True)
def _test_trust_anchors(session_key, monkeypatch, tmp_path_factory):
    missing = str(tmp_path_factory.getbasetemp() / "no-such-trust-file")
    monkeypatch.setattr(alp, "SYSTEM_TRUST_CONFIG", missing)
    if session_key is None:
        monkeypatch.setattr(alp, "SYSTEM_KEYRING", missing)
        monkeypatch.setattr(alp, "SYSTEM_ALLOWED_KEYS", missing)
        monkeypatch.setattr(pkb, "TEST_TRUST_ARGS", ("--keyring", missing, "--allowed-keys", missing))
    else:
        monkeypatch.setattr(alp, "SYSTEM_KEYRING", str(session_key.keyring))
        monkeypatch.setattr(alp, "SYSTEM_ALLOWED_KEYS", str(session_key.allowed))
        monkeypatch.setattr(pkb, "TEST_TRUST_ARGS", tuple(session_key.cli))


@pytest.fixture(autouse=True)
def _no_real_debian_box(monkeypatch):
    """D164: no test may create or enter a real Distrobox container on the host or in an image that has one.
    tests/test_kutu_fallback.py turns the box on again with a fake subprocess."""
    monkeypatch.setattr(alp, "kutu_available", lambda: False)
