#!/usr/bin/env python3
"""alp -- PackageKit backend (implementation of design/packagekit-integration.md).

Bu dosya iki farklı güven seviyesinde koddan oluşur, kasıtlı olarak ayrılmış:

1. `alp_*` sarmalayıcı fonksiyonları (aşağıda) -- gerçek `alp.py`'yi subprocess
   olarak çağırır, çıktısını ayrıştırır. **Bu kısım tamamen test edildi**
   (tests/test_packagekit_backend.py, gerçek alp.py'ye karşı, PackageKit
   olmadan) çünkü PackageKit'e hiç bağımlı değil.

2. `AlpPackageKitBackend` sınıfı -- gerçek `packagekit.backend` modülünü
   import eder (yalnızca Linux'ta, PackageKit kurulu bir sistemde mevcut).
   **Bu kısım bu ortamda (Windows, PackageKit yok) hiç import edilemedi,
   hiç çalıştırılamadı.** design/packagekit-integration.md'deki yöntem
   eşlemesinin somut kod hâlidir; gerçek bir PackageKit daemon'una
   yüklenip test edilmeden "çalışıyor" sayılamaz (AGENTS.md kuralı).

Kaynak: design/packagekit-integration.md.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


class AlpBackendError(RuntimeError):
    """Bir `alp` alt komutu başarısız olduğunda fırlatılır. `is_locked`,
    design §6'daki "kilitli -> PK_ERROR_ENUM_LOCK_REQUIRED" eşlemesi için."""

    def __init__(self, message: str, is_locked: bool = False):
        super().__init__(message)
        self.is_locked = is_locked


def _is_lock_error(stderr: str) -> bool:
    return "kilitli" in (stderr or "")


def _run_alp(alp_path: Path, root: Path, index: Path, args: list[str], timeout: float | None = None) -> subprocess.CompletedProcess:
    cmd = [sys.executable, str(alp_path), "--root", str(root), "--index", str(index), *args]
    # stdin=DEVNULL: an inherited invalid stdin handle breaks CreateProcess on
    # Windows. It does not suppress alp's prompt (NUL reports isatty() there);
    # callers that change the system pass --yes for that.
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)


# --------------------------------------------------------------------------
# Test edilmiş sarmalayıcılar -- design §3'teki yöntem eşlemesinin girdi tarafı
# --------------------------------------------------------------------------

def alp_search(alp_path: Path, root: Path, index: Path, term: str) -> list[dict]:
    proc = _run_alp(alp_path, root, index, ["--json", "search", term])
    if proc.returncode not in (0, 1):  # 1 == "eşleşme yok", hata değil
        raise AlpBackendError(proc.stderr.strip() or "alp search başarısız", is_locked=_is_lock_error(proc.stderr))
    return json.loads(proc.stdout or "[]")


def alp_list(alp_path: Path, root: Path, index: Path) -> list[dict]:
    proc = _run_alp(alp_path, root, index, ["--json", "list"])
    if proc.returncode != 0:
        raise AlpBackendError(proc.stderr.strip() or "alp list başarısız", is_locked=_is_lock_error(proc.stderr))
    return json.loads(proc.stdout or "[]")


def alp_info(alp_path: Path, root: Path, index: Path, name: str) -> dict:
    proc = _run_alp(alp_path, root, index, ["info", name])
    if proc.returncode != 0:
        raise AlpBackendError(proc.stderr.strip() or f"alp info {name} başarısız", is_locked=_is_lock_error(proc.stderr))
    return json.loads(proc.stdout)


def alp_install(alp_path: Path, root: Path, index: Path, name: str) -> str:
    # --yes: PackageKit/polkit already asked the user; alp must not ask again.
    proc = _run_alp(alp_path, root, index, ["install", "--yes", name])
    if proc.returncode != 0:
        raise AlpBackendError(proc.stderr.strip() or f"alp install {name} başarısız", is_locked=_is_lock_error(proc.stderr))
    return proc.stdout


def alp_remove(alp_path: Path, root: Path, index: Path, name: str) -> str:
    proc = _run_alp(alp_path, root, index, ["remove", "--yes", name])
    if proc.returncode != 0:
        raise AlpBackendError(proc.stderr.strip() or f"alp remove {name} başarısız", is_locked=_is_lock_error(proc.stderr))
    return proc.stdout


def alp_upgrade(alp_path: Path, root: Path, index: Path, name: str) -> str:
    proc = _run_alp(alp_path, root, index, ["upgrade", "--yes", name])
    if proc.returncode != 0:
        raise AlpBackendError(proc.stderr.strip() or f"alp upgrade {name} başarısız", is_locked=_is_lock_error(proc.stderr))
    return proc.stdout


# --------------------------------------------------------------------------
# PackageKit glue -- BU KISIM BU ORTAMDA HİÇ ÇALIŞTIRILAMADI/TEST EDİLEMEDİ.
#
# `packagekit.backend`'in tam metod imzaları (PkBitField, INFO_*/ERROR_*
# sabitleri) gerçek bir PackageKit kurulumunda doğrulanmalı -- burada genel
# bilinen backend iskeleti sözleşmesine göre yazıldı, birebir API garantisi
# verilmez. Codex'in gerçek bir PackageKit daemon'unda test etmesi gerekiyor.
# --------------------------------------------------------------------------

try:
    from packagekit.backend import PackageKitBaseBackend
    from packagekit.enums import ERROR_INTERNAL_ERROR, ERROR_LOCK_REQUIRED, ERROR_PACKAGE_NOT_FOUND, INFO_AVAILABLE, INFO_INSTALLED

    PACKAGEKIT_AVAILABLE = True
except ImportError:
    PACKAGEKIT_AVAILABLE = False


if PACKAGEKIT_AVAILABLE:

    class AlpPackageKitBackend(PackageKitBaseBackend):
        """design/packagekit-integration.md §3'teki yöntem eşlemesinin
        birebir kodu. Üretim yolları (ALP_PATH/ROOT/INDEX) yer tutucudur;
        gerçek alpbahOS kurulumunda paket kurulumu (Codex) tarafından
        sabitlenmelidir."""

        ALP_PATH = Path("/usr/lib/alp/alp.py")
        ROOT = Path("/")
        INDEX = Path("/var/lib/alp/index.json")

        def _fail(self, exc: AlpBackendError) -> None:
            code = ERROR_LOCK_REQUIRED if exc.is_locked else ERROR_INTERNAL_ERROR
            self.error(code, str(exc))

        def search_name(self, filters, values):
            try:
                hits = alp_search(self.ALP_PATH, self.ROOT, self.INDEX, " ".join(values))
            except AlpBackendError as exc:
                self._fail(exc)
                return
            for hit in hits:
                self.package(hit["name"], INFO_AVAILABLE, "")
            self.finished()

        def resolve(self, filters, values):
            for name in values:
                try:
                    details = alp_info(self.ALP_PATH, self.ROOT, self.INDEX, name)
                except AlpBackendError:
                    self.error(ERROR_PACKAGE_NOT_FOUND, name)
                    continue
                info = INFO_INSTALLED if details.get("status") != "not-installed" else INFO_AVAILABLE
                self.package(name, info, "")
            self.finished()

        def get_files(self, package_ids):
            for pkg_id in package_ids:
                name = pkg_id.split(";")[0]
                try:
                    details = alp_info(self.ALP_PATH, self.ROOT, self.INDEX, name)
                except AlpBackendError as exc:
                    self._fail(exc)
                    return
                self.files(pkg_id, ";".join(details.get("files", [])))
            self.finished()

        def install_packages(self, transaction_flags, package_ids):
            for pkg_id in package_ids:
                name = pkg_id.split(";")[0]
                try:
                    alp_install(self.ALP_PATH, self.ROOT, self.INDEX, name)
                except AlpBackendError as exc:
                    self._fail(exc)
                    return
            self.finished()

        def remove_packages(self, transaction_flags, package_ids, allow_deps, autoremove):
            for pkg_id in package_ids:
                name = pkg_id.split(";")[0]
                try:
                    alp_remove(self.ALP_PATH, self.ROOT, self.INDEX, name)
                except AlpBackendError as exc:
                    self._fail(exc)
                    return
            self.finished()

        def update_packages(self, transaction_flags, package_ids):
            for pkg_id in package_ids:
                name = pkg_id.split(";")[0]
                try:
                    alp_upgrade(self.ALP_PATH, self.ROOT, self.INDEX, name)
                except AlpBackendError as exc:
                    self._fail(exc)
                    return
            self.finished()

        # get_updates() / GetUpdates çağrısı: alp'te henüz depo-genelinde
        # "hangi paketlerin yeni sürümü var" sorgusu yok (index.json'daki
        # sürümle db.json'daki kurulu sürüm karşılaştırılabilir -- bu basit
        # ama henüz yazılmadı, design §3'te "Yok" diye işaretli kalmaya
        # devam ediyor).
