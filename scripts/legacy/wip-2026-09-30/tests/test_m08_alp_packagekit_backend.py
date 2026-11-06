from __future__ import annotations

import importlib.util
import sys
import types
from pathlib import Path


BACKEND_PATH = Path(__file__).resolve().parents[1] / "scripts/packagekit/alpBackend.py"


def load_backend(monkeypatch):
    """Load the helper without requiring PackageKit on the test host."""
    packagekit = types.ModuleType("packagekit")
    packagekit.__path__ = []
    backend_module = types.ModuleType("packagekit.backend")
    enums_module = types.ModuleType("packagekit.enums")

    class PackageKitBaseBackend:
        def __init__(self, _cmds):
            self.errors = []
            self.packages = []

        def error(self, code, *details, **kwargs):
            self.errors.append((code, details, kwargs))

        def package(self, *args):
            self.packages.append(args)

    backend_module.PackageKitBaseBackend = PackageKitBaseBackend
    backend_module.get_package_id = lambda name, version, arch, data: (
        f"{name};{version};{arch};{data}"
    )
    backend_module.split_package_id = lambda package_id: package_id.split(";")
    for name, value in {
        "ERROR_INTERNAL_ERROR": "internal-error",
        "ERROR_PACKAGE_NOT_FOUND": "package-not-found",
        "INFO_AVAILABLE": "available",
        "INFO_INSTALLED": "installed",
        "INFO_NORMAL": "normal",
        "GROUP_OTHER": "other",
        "STATUS_REFRESH_CACHE": "refresh-cache",
        "TRANSACTION_FLAG_SIMULATE": "simulate",
    }.items():
        setattr(enums_module, name, value)

    monkeypatch.setitem(sys.modules, "packagekit", packagekit)
    monkeypatch.setitem(sys.modules, "packagekit.backend", backend_module)
    monkeypatch.setitem(sys.modules, "packagekit.enums", enums_module)
    spec = importlib.util.spec_from_file_location("alp_packagekit_helper_under_test", BACKEND_PATH)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_depends_on_returns_success_for_catalog_package_without_inventing_runtime_deps(monkeypatch):
    module = load_backend(monkeypatch)
    backend = module.AlpBackend([])
    backend._info = lambda name: {"name": name, "requires_libraries": ["ncursesw"]}

    backend.depends_on([], ["htop;3.3.0;all;alp"], recursive=False)

    assert backend.errors == []
    assert backend.packages == []


def test_required_by_returns_success_for_catalog_package_without_dependency_graph(monkeypatch):
    module = load_backend(monkeypatch)
    backend = module.AlpBackend([])
    backend._info = lambda name: {"name": name}

    backend.required_by([], ["htop;3.3.0;all;alp"], recursive=True)

    assert backend.errors == []
    assert backend.packages == []


def test_dependency_queries_report_unknown_package_ids(monkeypatch):
    module = load_backend(monkeypatch)
    backend = module.AlpBackend([])
    backend._info = lambda _name: None

    backend.depends_on([], ["missing;0;all;alp"], recursive=False)
    backend.required_by([], ["missing;0;all;alp"], recursive=False)

    assert [error[0] for error in backend.errors] == [
        module.ERROR_PACKAGE_NOT_FOUND,
        module.ERROR_PACKAGE_NOT_FOUND,
    ]


def test_alp_subprocess_gets_fixed_path_when_packagekit_filters_environment(monkeypatch):
    module = load_backend(monkeypatch)
    captured = {}

    def fake_run(command, **kwargs):
        captured["command"] = command
        captured.update(kwargs)
        return types.SimpleNamespace(returncode=0, stdout="", stderr="")

    monkeypatch.setattr(module.subprocess, "run", fake_run)
    monkeypatch.delenv("PATH", raising=False)

    result = module.AlpBackend([])._run("--json", "info", "htop")

    assert result.returncode == 0
    assert captured["env"]["PATH"] == "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"


def test_packagekit_simulate_uses_alp_dry_run_without_mutating(monkeypatch):
    module = load_backend(monkeypatch)
    backend = module.AlpBackend([])
    calls = []
    backend._run = lambda *args: calls.append(args) or types.SimpleNamespace(returncode=0, stdout="{}", stderr="")
    backend._mutate = lambda *args: (_ for _ in ()).throw(AssertionError("simulate must not mutate"))

    backend.remove_packages([module.TRANSACTION_FLAG_SIMULATE], ["htop;3.3.0;all;alp"], False, False)

    assert calls == [("--json", "remove", "--dry-run", "htop")]
    assert backend.errors == []


def test_packagekit_real_commit_uses_mutation_path(monkeypatch):
    module = load_backend(monkeypatch)
    backend = module.AlpBackend([])
    calls = []
    backend._mutate = lambda operation, package_ids: calls.append((operation, package_ids))

    backend.install_packages([], ["htop;3.3.0;all;alp"])

    assert calls == [("install", ["htop;3.3.0;all;alp"])]
