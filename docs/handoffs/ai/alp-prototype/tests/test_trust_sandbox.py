"""ALP-TRUST-01: unprivileged, network-less builds (design/trust-model.md 6.1)
and the root-only halves of the stage checks.

Two kinds of test, both real (real bubblewrap, real processes, no mocks):

- `needs_bwrap`: run as whoever runs pytest. As an ordinary user they cover
  the sandbox itself (alp starts bubblewrap directly; there is nothing to drop).
- `needs_root`: additionally cover the privilege drop, the hand-over of the
  build tree and root-side ownership. Run them with sudo:

      sudo python3 -m pytest tests/test_trust_sandbox.py -v -rs

  They build as the numeric uid/gid 65534 through Paths.build_ids, a
  test-only field; no user is created on the host. As an ordinary user they
  are skipped with the reason shown.

Every test works in a throwaway directory under /var/tmp (traversable by the
build uid, unlike pytest's 0700 tmp dir under root) and removes it.
"""

from __future__ import annotations

import io
import json
import os
import shutil
import socket
import stat
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402
import trusthelpers  # noqa: E402
from trusthelpers import sign_catalog  # noqa: E402

ALP_PY = Path(__file__).resolve().parent.parent / "alp.py"
BUILD_IDS = (65534, 65534)
IS_ROOT = trusthelpers.is_root()


def _bwrap_works() -> str | None:
    """None when a sandboxed `true` runs for the current user, else the reason."""
    bwrap = alp._find_fixed_program(alp.BWRAP_CANDIDATES)
    if bwrap is None:
        return "bwrap yok (" + ", ".join(alp.BWRAP_CANDIDATES) + ")"
    paths = alp.Paths.resolve("/nonexistent-alp-test-root")
    paths.build_ids = BUILD_IDS
    try:
        alp._prepare_sandbox(paths)
    except alp.AlpError as exc:
        return str(exc)
    return None


_BWRAP_PROBLEM = _bwrap_works() if os.name == "posix" else "POSIX değil"
needs_bwrap = pytest.mark.skipif(_BWRAP_PROBLEM is not None, reason=f"çalışan bubblewrap gerekir: {_BWRAP_PROBLEM}")
needs_root = pytest.mark.skipif(not IS_ROOT, reason="root gerekir: sudo python3 -m pytest tests/test_trust_sandbox.py")
not_root = pytest.mark.skipif(IS_ROOT, reason="root olmayan kullanıcı gerekir")


@pytest.fixture
def work():
    """Throwaway directory every uid can walk into."""
    base = Path(tempfile.mkdtemp(prefix="alp-trust-test-", dir="/var/tmp"))
    base.chmod(0o755)
    try:
        yield base
    finally:
        shutil.rmtree(base, ignore_errors=True)


@pytest.fixture
def paths(work: Path) -> alp.Paths:
    p = alp.Paths.resolve(str(work / "root"))
    p.ensure()
    p.build_ids = BUILD_IDS  # used only when alp runs as root
    return p


def _recipe(work: Path, *, configure=("true",), make=("true",), make_install, **extra) -> dict:
    """A recipe whose steps are shell snippets; its source is a one-file tarball."""
    catalog = work / "catalog"
    catalog.mkdir(exist_ok=True)
    archive = catalog / "demo-1.0.tar.gz"
    with tarfile.open(archive, "w:gz") as tf:
        data = b"source file\n"
        info = tarfile.TarInfo("demo-1.0/README")
        info.size = len(data)
        tf.addfile(info, io.BytesIO(data))
        link = tarfile.TarInfo("demo-1.0/README.link")
        link.type = tarfile.SYMTYPE
        link.linkname = "README"
        tf.addfile(link)
    recipe = {
        "name": "demo", "version": "1.0", "source_url": "demo-1.0.tar.gz", "sha256": alp.sha256_of(archive),
        "build": {"configure": list(configure), "make": list(make), "make_install": list(make_install)},
        **extra,
    }
    (catalog / "demo.recipe.json").write_text(json.dumps(recipe), encoding="utf-8")
    return recipe


def _sh(script: str) -> list[str]:
    # "$1" is the stage directory (@DESTDIR@ is filled in by alp)
    return ["sh", "-c", script, "sh", "@DESTDIR@"]


def _install(paths: alp.Paths, work: Path) -> dict:
    return alp.install_recipe(paths, {"recipe": "demo.recipe.json"}, work / "catalog", dry_run=False)


def _log(paths: alp.Paths) -> str:
    return (paths.log_dir / "demo-1.0.build.log").read_text(encoding="utf-8", errors="replace")


REPORT = 'mkdir -p "$1/usr/share/demo" && exec > "$1/usr/share/demo/report" 2>&1; '


# --------------------------------------------------------------------------
# the sandbox itself (any user)
# --------------------------------------------------------------------------

@needs_bwrap
def test_build_can_write_its_stage_and_source_and_the_result_is_installed(paths, work):
    _recipe(work, make=_sh("echo built > built.txt && cat README.link"),
            make_install=_sh('mkdir -p "$1/usr/share/demo" && cp built.txt "$1/usr/share/demo/built.txt"'))
    record = _install(paths, work)
    assert (paths.root / "usr/share/demo/built.txt").read_text() == "built\n"
    assert "/usr/share/demo/built.txt" in record["files"]
    assert "bwrap" in _log(paths)


@needs_bwrap
@pytest.mark.parametrize("target", ["/etc/alp-trust-probe", "/usr/bin/alp-trust-probe", "HOME", "/var/tmp/alp-trust-probe",
                                    "/var/lib/alp-trust-probe", "WORK"])
def test_build_step_writing_outside_its_build_dir_fails_and_changes_nothing(paths, work, target):
    """Design section 7: /etc/x, /usr/bin/x, $HOME/x of the caller (root's
    home when run with sudo). WORK is the test's own directory next to the
    build dir: writable by the caller, but not from inside the sandbox."""
    if target == "HOME":
        target = str(Path.home() / "alp-trust-probe")
    elif target == "WORK":
        target = str(work / "alp-trust-probe")
    assert not os.path.lexists(target)
    _recipe(work, make_install=_sh(f'echo pwned > "{target}"'))
    with pytest.raises(subprocess.CalledProcessError):
        _install(paths, work)
    assert not os.path.lexists(target)
    assert not (paths.root / "usr").exists()
    assert alp.load_db(paths)["packages"] == {}


@needs_bwrap
def test_writes_to_private_tmp_and_run_never_reach_the_host(paths, work):
    marker = f"alp-trust-probe-{os.getpid()}"
    _recipe(work, make_install=_sh(
        f'echo x > /tmp/{marker} && echo x > /run/{marker} && mkdir -p "$1/usr/share/demo" && '
        f'ls /tmp /run > "$1/usr/share/demo/listing"'))
    host_tmp = Path("/tmp") / f"alp-trust-host-{os.getpid()}"
    host_tmp.write_text("host")
    try:
        _install(paths, work)
    finally:
        host_tmp.unlink()
    assert not os.path.lexists(f"/tmp/{marker}") and not os.path.lexists(f"/run/{marker}")
    listing = (paths.root / "usr/share/demo/listing").read_text().split()
    assert host_tmp.name not in listing  # the host's /tmp is not visible
    assert [name for name in listing if not name.endswith(":")].count(marker) == 2
    assert not [name for name in listing if "dbus" in name or "systemd" in name]  # host /run sockets are gone


@needs_bwrap
def test_build_step_cannot_use_the_network(paths, work):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(("127.0.0.1", 0))
    server.listen(1)
    server.settimeout(0.2)
    port = server.getsockname()[1]
    probe = (
        "import socket,sys\n"
        "s=socket.socket(); s.settimeout(3)\n"
        f"s.connect(('127.0.0.1',{port})); print('CONNECTED')\n"
    )
    try:
        # the same probe from outside the sandbox does connect: the test can tell the difference
        assert subprocess.run([sys.executable, "-c", probe], capture_output=True, text=True).stdout.strip() == "CONNECTED"
        server.accept()[0].close()
        _recipe(work, make_install=[sys.executable, "-c", probe])
        with pytest.raises(subprocess.CalledProcessError):
            _install(paths, work)
        with pytest.raises(OSError):  # timeout: nobody connected
            server.accept()
    finally:
        server.close()
    assert not [line for line in _log(paths).splitlines() if line.strip() == "CONNECTED"]
    assert not (paths.root / "usr").exists()


@needs_bwrap
def test_sandbox_has_only_a_loopback_interface(paths, work):
    _recipe(work, make_install=_sh(REPORT + "cat /proc/net/dev"))
    _install(paths, work)
    report = (paths.root / "usr/share/demo/report").read_text()
    interfaces = [line.split(":")[0].strip() for line in report.splitlines() if ":" in line]
    assert interfaces == ["lo"]
    host = [line.split(":")[0].strip() for line in Path("/proc/net/dev").read_text().splitlines() if ":" in line]
    assert len(host) > 1  # the host has more, so "lo only" says something


@needs_bwrap
def test_environment_is_cleared(paths, work, monkeypatch):
    monkeypatch.setenv("MAKEFLAGS", "--eval=$(shell touch /tmp/alp-trust-makeflags)")
    monkeypatch.setenv("CC", "/tmp/evil-cc")
    monkeypatch.setenv("LD_PRELOAD", "/tmp/evil.so")
    monkeypatch.setenv("SECRET_TOKEN", "hunter2")
    monkeypatch.setenv("PATH", "/tmp/evil-bin:" + os.environ["PATH"])
    paths.jobs = 3
    _recipe(work, make_install=_sh(REPORT + "env"), source_date_epoch=1700000000)
    _install(paths, work)
    env = dict(line.split("=", 1) for line in (paths.root / "usr/share/demo/report").read_text().splitlines()
               if "=" in line and not line.startswith(("PWD=", "OLDPWD=", "SHLVL=", "_=")))
    assert env == {
        "PATH": alp.SANDBOX_PATH,
        "HOME": str(paths.cache_dir / "build-demo-1.0"),
        "LC_ALL": "C",
        "MAKEFLAGS": "-j3",
        "SOURCE_DATE_EPOCH": "1700000000",
    }
    assert "MAKEFLAGS=-j3 SOURCE_DATE_EPOCH=1700000000" in _log(paths)


@needs_bwrap
def test_pid_namespace_and_identity(paths, work):
    _recipe(work, make_install=_sh(REPORT + "echo pid=$$; id -u; id -g; id -G; grep -E 'NoNewPrivs|CapEff' /proc/self/status"))
    _install(paths, work)
    report = (paths.root / "usr/share/demo/report").read_text().split("\n")
    assert int(report[0].split("=")[1]) < 10  # a fresh pid namespace
    expected_uid = str(BUILD_IDS[0]) if IS_ROOT else str(os.getuid())
    assert report[1] == expected_uid
    assert "NoNewPrivs:\t1" in report
    assert any(line.startswith("CapEff:\t0000000000000000") for line in report)


@needs_bwrap
def test_a_process_left_behind_by_a_step_does_not_survive_it(paths, work):
    """The stage is checked and merged after the steps. A background process
    of the build user must not be able to change it afterwards: the pid
    namespace is torn down with the step."""
    import time
    _recipe(work, make_install=_sh(
        'mkdir -p "$1/usr/share/demo" && echo ok > "$1/usr/share/demo/ok" && '
        "(setsid sh -c 'sleep 2; echo late > \"$0/usr/share/demo/late\"' \"$1\" >/dev/null 2>&1 &); exit 0"))
    paths.keep_build = True
    _install(paths, work)
    assert (paths.root / "usr/share/demo/ok").is_file()
    time.sleep(3)
    assert not (paths.cache_dir / "destdir-demo-1.0/usr/share/demo/late").exists()


def test_missing_bwrap_refuses_the_build(paths, work, monkeypatch, capsys):
    monkeypatch.setattr(alp, "BWRAP_CANDIDATES", (str(work / "no-bwrap"),))
    _recipe(work, make_install=_sh('mkdir -p "$1/usr/share/demo" && echo ran > "$1/usr/share/demo/ran"'))
    with pytest.raises(alp.AlpError, match="bwrap.*bulunamadı; kaynak derleme reddedildi.*--no-sandbox"):
        _install(paths, work)
    assert not (paths.root / "usr").exists()
    assert not list(paths.cache_dir.glob("destdir-*/usr"))  # no step ran


def test_non_working_bwrap_refuses_the_build(paths, work, monkeypatch):
    fake = work / "bwrap"
    fake.write_text("#!/bin/sh\necho 'bwrap: no user namespaces here' >&2\nexit 1\n")
    fake.chmod(0o755)
    monkeypatch.setattr(alp, "BWRAP_CANDIDATES", (str(fake),))
    _recipe(work, make_install=_sh('mkdir -p "$1/usr/share/demo" && echo ran > "$1/usr/share/demo/ran"'))
    with pytest.raises(alp.AlpError, match="bu sistemde çalışmıyor.*no user namespaces here.*reddedildi"):
        _install(paths, work)
    assert not list(paths.cache_dir.glob("destdir-*/usr"))


def test_bwrap_is_not_looked_up_on_path(paths, work, monkeypatch):
    evil = work / "bin"
    evil.mkdir()
    (evil / "bwrap").write_text(f"#!/bin/sh\ntouch {work}/evil-bwrap-ran\nexit 0\n")
    (evil / "bwrap").chmod(0o755)
    monkeypatch.setenv("PATH", f"{evil}:{os.environ['PATH']}")
    monkeypatch.setattr(alp, "BWRAP_CANDIDATES", (str(work / "no-bwrap"),))
    _recipe(work, make_install=["true"])
    with pytest.raises(alp.AlpError, match="reddedildi"):
        _install(paths, work)
    assert not (work / "evil-bwrap-ran").exists()


def test_engine_sandbox_off_warns_loudly_and_runs_the_step(paths, work, capsys):
    """The engine-side form of --no-sandbox (what main() sets for root)."""
    paths.sandbox = "off"
    _recipe(work, make_install=_sh('mkdir -p "$1/usr/share/demo" && echo ran > "$1/usr/share/demo/ran"'))
    _install(paths, work)
    assert "UYARI: --no-sandbox" in capsys.readouterr().err
    assert (paths.root / "usr/share/demo/ran").is_file()
    assert "korumalı alan yok" in _log(paths)


@pytest.mark.skipif(os.name != "posix", reason="POSIX gerekir")
def test_relocated_stage_root_may_not_be_reached_through_a_symlink(paths, work):
    """With --relocate the staged root is destdir/<root path>. If the build
    made a component of that path a symlink, root must not follow it."""
    paths.relocate = True
    destdir = work / "destdir"
    elsewhere = work / "elsewhere"
    (elsewhere / "usr/bin").mkdir(parents=True)
    (elsewhere / "usr/bin/planted").write_text("x")
    first = paths.root.relative_to("/").parts[0]
    destdir.mkdir()
    os.symlink(elsewhere, destdir / first)
    with pytest.raises(alp.AlpError, match="symlink"):
        alp._staged_tree(paths, destdir)


def test_dry_run_needs_no_sandbox(paths, work, monkeypatch):
    monkeypatch.setattr(alp, "BWRAP_CANDIDATES", (str(work / "no-bwrap"),))
    _recipe(work, make_install=["true"])
    record = alp.install_recipe(paths, {"recipe": "demo.recipe.json"}, work / "catalog", dry_run=True)
    assert record["status"] == "would-install"


def test_drop_helper_refuses_root_ids_and_bad_usage():
    for argv in (["0", "0", "--", "/usr/bin/true"], ["65534", "0", "--", "/usr/bin/true"],
                 ["x", "1", "--", "/usr/bin/true"], ["65534", "65534", "/usr/bin/true"],
                 ["65534", "65534", "--", "true"]):
        done = subprocess.run([sys.executable, "-I", str(ALP_PY), alp._DROP_HELPER_FLAG, *argv],
                              capture_output=True, text=True)
        assert done.returncode == 126 and "çalıştırılmadı" in done.stderr


@not_root
def test_drop_helper_fails_closed_when_it_cannot_drop():
    done = subprocess.run([sys.executable, "-I", str(ALP_PY), alp._DROP_HELPER_FLAG, "65534", "65534", "--",
                           "/usr/bin/id"], capture_output=True, text=True)
    assert done.returncode == 126 and done.stdout == "" and "yetki düşürme başarısız" in done.stderr


# --------------------------------------------------------------------------
# root: privilege drop, hand-over, ownership
# --------------------------------------------------------------------------

STATUS_PROBE = (
    "import os\n"
    "print('resuid', *os.getresuid())\n"
    "print('resgid', *os.getresgid())\n"
    "print('groups', *os.getgroups())\n"
    "print([l.strip() for l in open('/proc/self/status') if l.startswith(('NoNewPrivs', 'CapEff', 'CapPrm', 'CapInh', 'CapBnd', 'Groups'))])\n"
    "for name, call in (('setuid0', lambda: os.setuid(0)), ('setgid0', lambda: os.setgid(0)), ('setgroups', lambda: os.setgroups([0]))):\n"
    "    try:\n"
    "        call(); print(name, 'ALLOWED')\n"
    "    except OSError as exc:\n"
    "        print(name, 'denied')\n"
    "try:\n"
    "    open('/etc/shadow').read(); print('shadow READABLE')\n"
    "except OSError:\n"
    "    print('shadow denied')\n"
)


@needs_root
def test_privilege_drop_helper_really_drops():
    # start from a root process that does have supplementary groups, so "cleared" means something
    launcher = ("import os,sys; os.setgroups([0, 1, 2, 10]); assert len(os.getgroups()) == 4; "
                "os.execv(sys.argv[1], sys.argv[1:])")
    done = subprocess.run([sys.executable, "-I", "-c", launcher,
                           sys.executable, "-I", str(ALP_PY), alp._DROP_HELPER_FLAG, "65534", "65534", "--",
                           sys.executable, "-I", "-c", STATUS_PROBE], capture_output=True, text=True)
    assert done.returncode == 0, done.stderr
    out = done.stdout
    assert "resuid 65534 65534 65534\n" in out
    assert "resgid 65534 65534 65534\n" in out
    assert "groups\n" in out  # no supplementary group survives
    assert "'NoNewPrivs:\\t1'" in out
    assert "'CapEff:\\t0000000000000000'" in out and "'CapPrm:\\t0000000000000000'" in out
    assert "setuid0 denied" in out and "setgid0 denied" in out and "setgroups denied" in out
    assert "shadow denied" in out and "ALLOWED" not in out and "READABLE" not in out


@needs_root
@needs_bwrap
def test_root_build_runs_as_the_build_user_and_installs_as_root(paths, work):
    _recipe(work,
            configure=_sh("id -u > uid.txt && id -G > groups.txt && touch made-by-builder"),
            make_install=_sh('mkdir -p "$1/usr/bin" "$1/usr/share/demo" "$1/etc" && cp uid.txt groups.txt "$1/usr/share/demo/" && '
                             'echo x > "$1/usr/bin/demo" && chmod 777 "$1/usr/bin/demo" "$1/usr/share/demo" && '
                             'echo c > "$1/etc/demo.conf" && chmod 664 "$1/etc/demo.conf" && ln -s demo "$1/usr/bin/demo-link"'))
    paths.keep_build = True
    _install(paths, work)
    assert (paths.root / "usr/share/demo/uid.txt").read_text().strip() == "65534"
    assert (paths.root / "usr/share/demo/groups.txt").read_text().split() == ["65534"]
    for rel in ("usr", "usr/bin", "usr/bin/demo", "usr/bin/demo-link", "usr/share/demo", "usr/share/demo/uid.txt", "etc/demo.conf"):
        st = os.lstat(paths.root / rel)
        assert (st.st_uid, st.st_gid) == (0, 0), rel
    assert stat.S_IMODE((paths.root / "usr/bin/demo").stat().st_mode) == 0o755
    assert stat.S_IMODE((paths.root / "usr/share/demo").stat().st_mode) == 0o755
    assert stat.S_IMODE((paths.root / "etc/demo.conf").stat().st_mode) == 0o644  # also outside /usr
    # the source tree was handed to the build user, the stage was taken back by root
    build = paths.cache_dir / "build-demo-1.0"
    assert os.lstat(build / "demo-1.0/README").st_uid == 65534
    assert os.lstat(build / "demo-1.0/made-by-builder").st_uid == 65534
    stage = paths.cache_dir / "destdir-demo-1.0"
    assert {os.lstat(p).st_uid for p in [stage, *stage.rglob("*")]} == {0}
    assert "bwrap, uid 65534" in _log(paths)


@needs_root
@needs_bwrap
@pytest.mark.parametrize("target", ["/etc/alp-trust-probe", "/usr/bin/alp-trust-probe", "/root/alp-trust-probe",
                                    "/var/lib/alp-trust-probe"])
def test_root_build_step_cannot_write_the_system_even_without_the_read_only_bind(paths, work, monkeypatch, target):
    """Second layer: with the read-only bind taken away (a `--bind / /`
    sandbox), the step still fails, because it is not root any more."""
    assert not os.path.lexists(target)
    real = alp._bwrap_argv

    def writable_root(bwrap, writable, cwd, env):
        argv = real(bwrap, writable, cwd, env)
        i = argv.index("--ro-bind")
        argv[i] = "--bind"
        return argv

    monkeypatch.setattr(alp, "_bwrap_argv", writable_root)
    _recipe(work, make_install=_sh(f'echo pwned > "{target}"'))
    with pytest.raises(subprocess.CalledProcessError):
        _install(paths, work)
    assert not os.path.lexists(target)


@needs_root
@needs_bwrap
def test_root_install_of_a_listed_setuid_file_keeps_the_bit_and_is_root_owned(paths, work):
    script = 'mkdir -p "$1/usr/bin" && echo x > "$1/usr/bin/demo" && chmod 4755 "$1/usr/bin/demo"'
    _recipe(work, make_install=_sh(script))
    with pytest.raises(alp.AlpError, match="/usr/bin/demo: setuid/setgid"):
        _install(paths, work)
    assert not (paths.root / "usr").exists()
    _recipe(work, make_install=_sh(script), setuid=["/usr/bin/demo"])
    _install(paths, work)
    st = (paths.root / "usr/bin/demo").stat()
    assert (st.st_uid, st.st_gid, stat.S_IMODE(st.st_mode)) == (0, 0, 0o4755)


@needs_root
def test_missing_build_user_refuses(paths, work, monkeypatch):
    paths.build_ids = None
    monkeypatch.setattr(alp, "BUILD_USER", "alp-no-such-user-xyz")
    _recipe(work, make_install=_sh('mkdir -p "$1/usr/share/demo" && id -u > "$1/usr/share/demo/uid"'))
    with pytest.raises(alp.AlpError, match="alp-no-such-user-xyz.*yok; kaynak derleme reddedildi"):
        _install(paths, work)
    assert not (paths.root / "usr").exists()


@needs_root
def test_root_ids_are_never_accepted_as_build_ids(paths, work):
    for ids in ((0, 0), (0, 65534), (65534, 0)):
        paths.build_ids = ids
        with pytest.raises(alp.AlpError, match="yetkisiz olmalı"):
            alp._build_ids(paths)


@needs_root
@needs_bwrap
def test_unreachable_build_dir_is_a_clear_refusal(paths, work):
    (work / "root").chmod(0o700)
    _recipe(work, make_install=["true"])
    with pytest.raises(alp.AlpError, match="ulaşamıyor"):
        _install(paths, work)


@needs_root
def test_handing_a_tree_over_does_not_follow_symlinks(work):
    outside = work / "outside-file"
    outside.write_text("root's")
    outside_dir = work / "outside-dir"
    outside_dir.mkdir()
    (outside_dir / "inner").write_text("root's")
    tree = work / "tree"
    (tree / "sub").mkdir(parents=True)
    (tree / "sub/file").write_text("x")
    os.symlink(outside, tree / "file-link")
    os.symlink(outside_dir, tree / "dir-link")
    os.symlink("/etc/passwd", tree / "sub/passwd")
    alp._give_tree_to(tree, *BUILD_IDS)
    for rel in ("", "sub", "sub/file", "file-link", "dir-link", "sub/passwd"):
        assert os.lstat(tree / rel).st_uid == 65534, rel
    for untouched in (outside, outside_dir, outside_dir / "inner", Path("/etc/passwd")):
        assert os.stat(untouched).st_uid == 0, untouched


@needs_root
def test_device_node_in_the_stage_is_refused(work):
    stage, root = work / "stage", work / "root"
    (stage / "usr/bin").mkdir(parents=True)
    root.mkdir()
    os.mknod(stage / "usr/bin/null", 0o666 | stat.S_IFCHR, os.makedev(1, 3))
    with pytest.raises(alp.AlpError, match="FIFO/soket/aygıt"):
        alp._merge_staged(stage, root, config_files=set(), old_record=None, other_owners={})
    assert list(root.iterdir()) == []


@needs_root
def test_hard_link_to_a_system_file_is_refused_before_any_chown_or_chmod(work):
    victim = work / "victim"
    victim.write_text("x")
    os.chown(victim, 1, 1)
    victim.chmod(0o666)
    stage, root = work / "stage", work / "root"
    (stage / "usr/bin").mkdir(parents=True)
    root.mkdir()
    os.link(victim, stage / "usr/bin/leak")
    with pytest.raises(alp.AlpError, match="sabit bağ"):
        alp._merge_staged(stage, root, config_files=set(), old_record=None, other_owners={})
    st = victim.stat()
    assert (st.st_uid, st.st_gid, stat.S_IMODE(st.st_mode)) == (1, 1, 0o666)


# --------------------------------------------------------------------------
# root: the two root-only flags and the root-owned configuration file
# --------------------------------------------------------------------------

def _core_catalog(work: Path, sign: bool) -> Path:
    catalog = work / "cat"
    catalog.mkdir()
    archive = catalog / "tool-1.0.0.tar.gz"
    with tarfile.open(archive, "w:gz") as tf:
        for d in ("usr", "usr/share", "usr/share/tool"):
            info = tarfile.TarInfo(d)
            info.type = tarfile.DIRTYPE
            info.mode = 0o755
            tf.addfile(info)
        info = tarfile.TarInfo("usr/share/tool/data")
        info.size = 4
        tf.addfile(info, io.BytesIO(b"tool"))
    index = catalog / "index.json"
    index.write_text(json.dumps({"entries": {"tool": {
        "method": "core", "name": "tool", "version": "1.0.0", "url": archive.name, "sha256": alp.sha256_of(archive)}}}))
    if sign:
        sign_catalog(index)
    return index


@needs_root
def test_root_may_allow_unsigned_and_is_warned_on_every_run(work, capsys):
    index = _core_catalog(work, sign=False)
    base = ["--root", str(work / "root"), "--index", str(index)]
    assert alp.main(base + ["install", "-y", "tool"]) == 1
    assert "imzalı değil" in capsys.readouterr().err
    for argv in (["search", "tool"], ["install", "-y", "tool"], ["list"]):
        assert alp.main(base + ["--allow-unsigned"] + argv) == 0
        assert "İMZASIZ KATALOG" in capsys.readouterr().err
    assert (work / "root/usr/share/tool/data").is_file()
    # it did not stick: the next run without the flag is refused again, and nothing was written about it
    assert alp.main(base + ["search", "tool"]) == 1
    capsys.readouterr()
    state = work / "root/var/lib/alp"
    assert "unsigned" not in (state / "db.json").read_text()
    assert "catalog" not in json.loads((state / "db.json").read_text())


@needs_root
@needs_bwrap
def test_root_no_sandbox_flag_reaches_the_engine_and_default_does_not(work, capsys, monkeypatch):
    seen = []
    monkeypatch.setattr(alp, "cmd_install", lambda args, paths, index, index_dir: seen.append(paths.sandbox) or 0)
    index = _core_catalog(work, sign=True)
    base = ["--root", str(work / "root"), "--index", str(index)]
    assert alp.main(base + ["install", "-y", "tool"]) == 0
    assert alp.main(base + ["--no-sandbox", "install", "-y", "tool"]) == 0
    assert alp.main(base + ["install", "-y", "tool"]) == 0
    assert seen == ["require", "off", "require"]


@needs_root
def test_root_owned_trust_config_is_honoured_and_a_loose_one_is_not(work, capsys, monkeypatch, session_key):
    index = _core_catalog(work, sign=True)
    missing = str(work / "missing")
    monkeypatch.setattr(alp, "SYSTEM_KEYRING", missing)
    monkeypatch.setattr(alp, "SYSTEM_ALLOWED_KEYS", missing)
    base = ["--root", str(work / "root"), "--index", str(index)]
    assert alp.main(base + ["search", "tool"]) == 1  # built-in paths do not exist here
    capsys.readouterr()
    config = work / "trust.conf"
    config.write_text(f"# site keyring\nkeyring = {session_key.keyring}\nallowed_keys = {session_key.allowed}\n")
    monkeypatch.setattr(alp, "SYSTEM_TRUST_CONFIG", str(config))
    assert alp.main(base + ["search", "tool"]) == 0
    capsys.readouterr()
    config.chmod(0o666)
    assert alp.main(base + ["search", "tool"]) == 1
    assert "root'a ait" in capsys.readouterr().err
    config.chmod(0o644)
    os.chown(config, 65534, 65534)
    assert alp.main(base + ["search", "tool"]) == 1
    os.chown(config, 0, 0)
    config.write_text("keyring = relative/path\n")
    assert alp.main(base + ["search", "tool"]) == 1
    config.write_text(f"keyring = {session_key.keyring}\nallowed_keys = {session_key.allowed}\nno_sandbox = yes\n")
    assert alp.main(base + ["search", "tool"]) == 1
    assert "kapatılamaz" in capsys.readouterr().err


@needs_root
def test_root_refuses_trust_files_a_user_could_write(work, capsys, session_key):
    index = _core_catalog(work, sign=True)
    keyring = work / "k.gpg"
    allowed = work / "allowed.txt"
    shutil.copy(session_key.keyring, keyring)
    shutil.copy(session_key.allowed, allowed)
    base = ["--root", str(work / "root"), "--index", str(index), "--keyring", str(keyring), "--allowed-keys", str(allowed)]
    assert alp.main(base + ["search", "tool"]) == 0
    capsys.readouterr()
    os.chown(keyring, 65534, 65534)
    assert alp.main(base + ["search", "tool"]) == 1
    assert "root'a ait" in capsys.readouterr().err
    os.chown(keyring, 0, 0)
    allowed.chmod(0o664)
    assert alp.main(base + ["search", "tool"]) == 1
    assert "root'a ait" in capsys.readouterr().err
