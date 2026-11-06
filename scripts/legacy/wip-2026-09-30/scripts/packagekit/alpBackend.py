#!/usr/bin/python3
"""PackageKit helper for alp's read-only catalog and package operations."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

from packagekit.backend import PackageKitBaseBackend, get_package_id, split_package_id
from packagekit.enums import (
    ERROR_INTERNAL_ERROR,
    ERROR_PACKAGE_NOT_FOUND,
    INFO_AVAILABLE,
    INFO_INSTALLED,
    INFO_NORMAL,
    GROUP_OTHER,
    STATUS_REFRESH_CACHE,
    TRANSACTION_FLAG_SIMULATE,
)

ALP = Path("/usr/lib/alp/alp.py")
ROOT = Path("/")
INDEX = Path("/var/lib/alp/catalog/index.json")
UPDATE_LINE = re.compile(r"^güncelleme var: ([^\s]+) ([^\s]+) -> ([^\s]+)$", re.MULTILINE)


class AlpBackend(PackageKitBaseBackend):
    def _recipe(self, name: str) -> dict | None:
        entry = self._entries().get(name)
        if not isinstance(entry, dict) or entry.get("method") != "recipe":
            return None
        relpath = entry.get("recipe")
        if not isinstance(relpath, str) or not relpath:
            return None
        catalog = INDEX.parent.resolve()
        recipe_path = (catalog / relpath).resolve()
        if catalog not in recipe_path.parents or not recipe_path.is_file():
            return None
        try:
            recipe = json.loads(recipe_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return None
        return recipe if isinstance(recipe, dict) else None

    def _catalog_version(self, name: str) -> str:
        recipe = self._recipe(name)
        version = recipe.get("version") if recipe else None
        if isinstance(version, str) and re.fullmatch(r"[A-Za-z0-9.+:~_-]+", version):
            return version
        return "0"

    def _run(self, *args: str) -> subprocess.CompletedProcess[str]:
        # PackageKit intentionally starts helpers with a very small allowlist
        # of environment variables. In particular PATH is absent by default;
        # GCC then cannot locate its cc1 compiler when an Alp recipe builds a
        # source package. Keep PackageKit's forwarded proxy/locale values, but
        # provide the target system's fixed executable search path explicitly.
        env = os.environ.copy()
        env["PATH"] = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        return subprocess.run(
            [sys.executable, str(ALP), "--root", str(ROOT), "--index", str(INDEX), *args],
            check=False,
            capture_output=True,
            text=True,
            stdin=subprocess.DEVNULL,
            timeout=900,
            env=env,
        )

    def _entries(self) -> dict[str, dict]:
        with INDEX.open(encoding="utf-8") as stream:
            data = json.load(stream)
        return data["entries"]

    def _name(self, package_id: str) -> str:
        return split_package_id(package_id)[0] if ";" in package_id else package_id

    def _id(self, name: str) -> str:
        # Recipe-backed source builds carry a concrete version in their recipe.
        # Flatpak/core records may not, so retain the stable unknown version there.
        return get_package_id(name, self._catalog_version(name), "all", "alp")

    def _info(self, name: str) -> dict | None:
        proc = self._run("--json", "info", name)
        if proc.returncode != 0:
            return None
        return json.loads(proc.stdout)

    def search_name(self, filters, values):
        proc = self._run("--json", "search", " ".join(values))
        if proc.returncode not in (0, 1):
            self.error(ERROR_INTERNAL_ERROR, proc.stderr.strip() or "alp search failed")
            return
        installed = {item.get("name") for item in self._installed()}
        for item in json.loads(proc.stdout or "[]"):
            name = item["name"]
            info = INFO_INSTALLED if name in installed else INFO_AVAILABLE
            self.package(self._id(name), info, item.get("description", ""))

    def resolve(self, filters, values):
        for value in values:
            name = self._name(value)
            info = self._info(name)
            if info is None:
                self.error(ERROR_PACKAGE_NOT_FOUND, name, exit=False)
                continue
            status = INFO_INSTALLED if info.get("status") == "installed" else INFO_AVAILABLE
            self.package(self._id(name), status, info.get("description", ""))

    def get_details(self, package_ids):
        for package_id in package_ids:
            name = self._name(package_id)
            info = self._info(name)
            if info is None:
                self.error(ERROR_PACKAGE_NOT_FOUND, name, exit=False)
                continue
            size = info.get("size")
            download_size = size if isinstance(size, int) and not isinstance(size, bool) else None
            self.details(
                self._id(name),
                info.get("description", name),
                info.get("license", "unknown"),
                GROUP_OTHER,
                info.get("description", ""),
                info.get("homepage", ""),
                None,
                download_size,
            )

    def refresh_cache(self, force):
        """Refresh only the local AppStream cache; catalog updates stay explicit via `alp update`."""
        self.status(STATUS_REFRESH_CACHE)
        command = ["/usr/bin/appstreamcli", "refresh-cache"]
        if force:
            command.append("--force")
        try:
            proc = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                stdin=subprocess.DEVNULL,
                timeout=300,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            self.error(ERROR_INTERNAL_ERROR, f"AppStream cache refresh failed: {exc}")
            return
        if proc.returncode != 0:
            detail = proc.stderr.strip() or proc.stdout.strip() or "unknown appstreamcli error"
            self.error(ERROR_INTERNAL_ERROR, f"AppStream cache refresh failed: {detail}")

    def get_updates(self, filters):
        """Use alp's own consistency/version logic and return its available upgrades."""
        proc = self._run("check")
        if proc.returncode not in (0, 1):
            self.error(ERROR_INTERNAL_ERROR, proc.stderr.strip() or "alp check failed")
            return
        for match in UPDATE_LINE.finditer(proc.stdout):
            name, old_version, new_version = match.groups()
            package_id = get_package_id(name, new_version, "all", "alp")
            self.package(package_id, INFO_NORMAL, f"{name}: {old_version} → {new_version}")
        if proc.returncode == 1:
            # `alp check` uses 1 for dependency or pending-transaction issues.
            # Keep any update records it emitted, but do not hide the broken state.
            detail = "alp check reported dependency or pending-transaction problems"
            if proc.stdout.strip():
                detail += f": {proc.stdout.strip()}"
            self.error(ERROR_INTERNAL_ERROR, detail, exit=False)

    def depends_on(self, filters, package_ids, recursive):
        """Report known runtime dependencies for packages.

        The current Alp catalog has no runtime-dependency field. Recipe
        ``requires_libraries`` entries are build prerequisites and must not be
        presented as installed runtime packages. Until Alp models runtime
        dependencies, a valid catalog package therefore has no dependency
        records to return. Discover calls this before a transaction; leaving
        PackageKit's default NOT_SUPPORTED response makes every install fail.
        """
        for package_id in package_ids:
            name = self._name(package_id)
            if self._info(name) is None:
                self.error(ERROR_PACKAGE_NOT_FOUND, name, exit=False)

    def required_by(self, filters, package_ids, recursive):
        """Report packages that depend on the queried packages, if known.

        Alp does not currently expose runtime dependency relationships, so a
        valid package has no reverse-dependency records. Keep package ID
        validation consistent with ``depends_on``.
        """
        for package_id in package_ids:
            name = self._name(package_id)
            if self._info(name) is None:
                self.error(ERROR_PACKAGE_NOT_FOUND, name, exit=False)

    def _installed(self) -> list[dict]:
        proc = self._run("--json", "list")
        if proc.returncode != 0:
            return []
        try:
            return json.loads(proc.stdout or "[]")
        except json.JSONDecodeError:
            return []

    def install_packages(self, transaction_flags, package_ids):
        self._mutate_or_simulate("install", transaction_flags, package_ids)

    def remove_packages(self, transaction_flags, package_ids, allow_deps, autoremove):
        self._mutate_or_simulate("remove", transaction_flags, package_ids)

    def update_packages(self, transaction_flags, package_ids):
        self._mutate_or_simulate("upgrade", transaction_flags, package_ids)

    def _mutate_or_simulate(self, operation: str, transaction_flags: list[str], package_ids: list[str]):
        """Honor PackageKit's Test Changes phase without touching the live root.

        PackageKit invokes the same operation once with the `simulate` flag
        before its real commit. Forward that as Alp's side-effect-free dry run;
        otherwise install/remove would happen twice and the commit phase could
        fail against the already-mutated package database.
        """
        if TRANSACTION_FLAG_SIMULATE not in transaction_flags:
            self._mutate(operation, package_ids)
            return

        for package_id in package_ids:
            name = self._name(package_id)
            proc = self._run("--json", operation, "--dry-run", name)
            if proc.returncode != 0:
                self.error(ERROR_INTERNAL_ERROR, proc.stderr.strip() or f"alp {operation} simulation failed")
                return

    def _mutate(self, operation: str, package_ids: list[str]):
        for package_id in package_ids:
            name = self._name(package_id)
            proc = self._run(operation, "--yes", name)
            if proc.returncode != 0:
                self.error(ERROR_INTERNAL_ERROR, proc.stderr.strip() or f"alp {operation} failed")
                return


if __name__ == "__main__":
    AlpBackend(sys.argv[1:]).dispatcher(sys.argv[1:])
