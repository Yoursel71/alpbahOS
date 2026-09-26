import configparser
import contextlib
import copy
import io
import hashlib
import importlib.machinery
import importlib.util
import json
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SHORTCUTS = REPO / "profiles" / "shortcuts"
LNF = REPO / "profiles" / "desktop" / "lookandfeel" / "org.alpbahos.solid.desktop"
WALLPAPER = REPO / "branding" / "ataturk-theme" / "wallpaper" / "alpbahOS-Ataturk"


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


GEN = load("m08_gen", SHORTCUTS / "generate_kglobalshortcutsrc.py")
LIVE = load("m08_live", SHORTCUTS / "verify_shortcuts_live.py")

# docs/MASTER_PLAN.md §6 tablosundaki sistem kısayolları (Ctrl+C/V/X/Z uygulama katmanıdır).
MASTER_PLAN_KEYS = [
    "Alt+Tab", "Alt+Shift+Tab", "Meta+D", "Meta+E", "Meta+L", "Meta+R", "Meta", "Meta+I",
    "Meta+Left", "Meta+Right", "Meta+Up", "Meta+Down", "Meta+Tab", "Alt+F4",
    "Ctrl+Shift+Esc", "Meta+Shift+S",
]


def ini(text):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    parser.read_string(text)
    return parser


def profile_records(profile, overrides=None, missing=()):
    """Profil uygulanmış kglobalaccel durumunu taklit eden kayıtlar."""
    records = []
    for _source, binding in GEN.iter_bindings(profile):
        if binding["component"] in missing:
            continue
        keys = [GEN.qt_key_code(k) for k in binding["set"]]
        records.append({"component": binding["component"], "action": binding["action"],
                        "keys": [k for k in keys if k is not None], "default_keys": []})
    for (component, action), keys in (overrides or {}).items():
        for record in records:
            if (record["component"], record["action"]) == (component, action):
                record["keys"] = [GEN.qt_key_code(k) for k in keys]
    return records


class ShortcutProfileTests(unittest.TestCase):
    def setUp(self):
        self.profile = GEN.load_profile()

    def test_profile_is_valid(self):
        self.assertEqual(GEN.validate(self.profile), [])

    def test_generated_file_is_current(self):
        generated = (SHORTCUTS / "generated" / "kglobalshortcutsrc").read_text(encoding="utf-8")
        self.assertEqual(GEN.render(self.profile), generated)

    def test_covers_master_plan_table(self):
        promised = {GEN.normalize_key(k) for row in self.profile["shortcuts"] for k in row["keys"]}
        for key in MASTER_PLAN_KEYS:
            self.assertIn(GEN.normalize_key(key), promised)

    def test_normalize_and_qt_codes(self):
        self.assertEqual(GEN.normalize_key("shift+meta+s"), "Meta+Shift+S")
        self.assertEqual(GEN.normalize_key("ctrl+SHIFT+esc"), "Ctrl+Shift+Esc")
        self.assertEqual(GEN.qt_key_code("Meta+E"), 0x10000045)
        self.assertEqual(GEN.qt_key_code("Alt+F4"), 0x09000033)
        self.assertEqual(GEN.qt_key_code("Meta"), 0x01000022)
        self.assertEqual(GEN.qt_key_code("Meta+PgUp"), 0x11000016)
        self.assertIsNone(GEN.qt_key_code("Screensaver"))
        self.assertIn(0x0B000002, GEN.equivalent_codes(GEN.qt_key_code("Alt+Shift+Tab")))
        for bad in ("Meta+Q+", "Hyper+E", "Meta+Meta", "Ctrl+Meta"):
            with self.assertRaises(GEN.ProfileError):
                GEN.normalize_key(bad)

    def test_detects_conflicting_binding(self):
        broken = copy.deepcopy(self.profile)
        row = next(r for r in broken["shortcuts"] if r["id"] == "file-manager")
        row["bindings"][0]["set"] = ["Meta+D"]
        errors = GEN.validate(broken)
        self.assertTrue(any("çakışma: Meta+D" in e for e in errors), errors)
        self.assertTrue(any("vaat edilen Meta+E" in e for e in errors), errors)

    def test_detects_unexplained_upstream_removal(self):
        broken = copy.deepcopy(self.profile)
        broken["cakisma_cozumleri"] = [c for c in broken["cakisma_cozumleri"] if c["action"] != "Window Quick Tile Top"]
        broken["shortcuts"] = [r for r in broken["shortcuts"] if r["id"] != "maximize"]
        broken["cakisma_cozumleri"].append({
            "for": "minimize", "kind": "component", "component": "kwin", "action": "Window Quick Tile Top",
            "friendly": "Quick Tile Window to the Top", "set": [], "upstream_default": ["Meta+Up"],
            "upstream_kaynak": "test", "neden": "test",
        })
        errors = GEN.validate(broken)
        self.assertTrue(any("upstream Meta+Up gerekçesiz" in e for e in errors), errors)

    def test_rendered_kconfig_format(self):
        text = GEN.render(self.profile)
        self.assertIn("Window Maximize=Meta+Up\\tMeta+PgUp,Meta+PgUp,Maximize Window", text)
        self.assertIn("Window Quick Tile Top=none,Meta+Up,Quick Tile Window to the Top", text)
        self.assertIn("[services][org.kde.krunner.desktop]\n_launch=Meta+R\\tAlt+Space\\tAlt+F2\\tSearch", text)
        self.assertNotIn("\t", text.replace("\\t", ""))  # gerçek sekme karakteri yok


class LiveVerifierTests(unittest.TestCase):
    def setUp(self):
        self.profile = GEN.load_profile()

    def results(self, records):
        return {r["id"]: r for r in LIVE.analyze(self.profile, records)}

    def test_applied_profile_passes(self):
        results = self.results(profile_records(self.profile))
        failing = {k: v for k, v in results.items() if v["sonuc"] not in ("GEÇTİ", "KAPSAM DIŞI")}
        self.assertEqual(failing, {})

    def test_upstream_defaults_fail_where_expected(self):
        upstream = {}
        for _source, binding in GEN.iter_bindings(self.profile):
            upstream[(binding["component"], binding["action"])] = binding["upstream_default"]
        results = self.results(profile_records(self.profile, overrides=upstream))
        for row in ("overview", "maximize", "minimize", "run-launcher", "region-screenshot"):
            self.assertEqual(results[row]["sonuc"], "KALDI", row)
        self.assertEqual(results["show-desktop"]["sonuc"], "GEÇTİ")
        self.assertEqual(results["cozum:maximize:Window Quick Tile Top"]["sonuc"], "KALDI")

    def test_missing_component_is_not_a_pass(self):
        results = self.results(profile_records(self.profile, missing=("ksmserver", "org.kde.dolphin.desktop")))
        self.assertEqual(results["lock-session"]["sonuc"], "KAYITSIZ")
        self.assertEqual(results["file-manager"]["sonuc"], "KAYITSIZ")

    def test_from_dump_exit_codes(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            dump = Path(temp_dir) / "kga.json"
            dump.write_text(json.dumps({"records": profile_records(self.profile)}), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()) as out:
                self.assertEqual(LIVE.main(["--from-dump", str(dump)]), 0)
            self.assertIn("GEÇTİ=19", out.getvalue())
            dump.write_text(json.dumps({"records": profile_records(self.profile, missing=("ksmserver",))}), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(LIVE.main(["--from-dump", str(dump)]), 1)


class LookAndFeelPackageTests(unittest.TestCase):
    def test_metadata(self):
        meta = json.loads((LNF / "metadata.json").read_text(encoding="utf-8"))
        self.assertEqual(meta["KPackageStructure"], "Plasma/LookAndFeel")
        self.assertEqual(meta["KPlugin"]["Id"], LNF.name)
        xdg = ini((REPO / "profiles" / "desktop" / "xdg" / "kdeglobals").read_text(encoding="utf-8"))
        self.assertEqual(xdg["KDE"]["LookAndFeelPackage"], LNF.name)

    def test_defaults_reference_shipped_assets(self):
        defaults = (LNF / "contents" / "defaults").read_text(encoding="utf-8")
        scheme = re.search(r"^\[kdeglobals\]\[General\]\nColorScheme=(\S+)$", defaults, re.M).group(1)
        colors = REPO / "profiles" / "desktop" / "colorscheme" / f"{scheme}.colors"
        self.assertTrue(colors.exists(), colors)
        self.assertEqual(ini(colors.read_text(encoding="utf-8"))["General"]["ColorScheme"], scheme)
        image = re.search(r"^\[Wallpaper\]\nImage=(\S+)$", defaults, re.M).group(1)
        wall_meta = json.loads((WALLPAPER / "metadata.json").read_text(encoding="utf-8"))
        self.assertEqual(image, wall_meta["KPlugin"]["Id"])
        self.assertEqual(image, WALLPAPER.name)

    def test_layout_script(self):
        layout = (LNF / "contents" / "layouts" / "org.kde.plasma.desktop-layout.js").read_text(encoding="utf-8")
        for applet in ("org.kde.plasma.kickoff", "org.kde.plasma.windowlist", "org.kde.plasma.digitalclock",
                       "org.kde.plasma.systemtray", "org.kde.plasma.icontasks"):
            self.assertIn(f'"{applet}"', layout)
        self.assertEqual(layout.count("org.kde.plasma.kickoff") + layout.count("org.kde.plasma.kicker"), 1,
                         "tek başlatıcı olmalı (Meta tuşu belirsizleşmesin)")
        icon = re.search(r'writeConfig\("icon", "([^"]+)"\)', layout).group(1)
        self.assertTrue((REPO / "branding" / "icons" / "hicolor" / "48x48" / "apps" / f"{icon}.png").exists())
        self.assertNotIn("/usr/share/wallpapers", layout)

    def test_layout_script_syntax(self):
        node = shutil.which("node")
        if not node:
            self.skipTest("node yok; JS sözdizimi denetlenmedi")
        layout = LNF / "contents" / "layouts" / "org.kde.plasma.desktop-layout.js"
        proc = subprocess.run([node, "--check", str(layout)], capture_output=True, text=True, cwd=REPO)
        self.assertEqual(proc.returncode, 0, proc.stderr)


class WallpaperTests(unittest.TestCase):
    def test_source_hash_matches_record(self):
        digest = hashlib.sha256((REPO / "branding" / "ataturk-theme" / "source" / "Ataturk1930s.jpg").read_bytes()).hexdigest()
        self.assertIn(digest, (REPO / "branding" / "ataturk-theme" / "README.md").read_text(encoding="utf-8"))
        self.assertIn(digest, (WALLPAPER / "ATTRIBUTION.md").read_text(encoding="utf-8"))

    def test_images_and_safe_areas(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("Pillow yok")
        builder = load("m08_wallpaper", REPO / "branding" / "ataturk-theme" / "tools" / "build_wallpaper.py")
        shipped = sorted(p.name for p in (WALLPAPER / "contents" / "images").iterdir())
        self.assertEqual(shipped, sorted(f"{w}x{h}.jpg" for w, h in builder.SIZES))
        photo = builder.load_source()
        for w, h in builder.SIZES:
            with Image.open(WALLPAPER / "contents" / "images" / f"{w}x{h}.jpg") as image:
                self.assertEqual(image.size, (w, h))
            _image, face = builder.compose((w, h), photo)
            builder.check_safe_area((w, h), face)
        with self.assertRaises(builder.CompositionError):
            builder.check_safe_area((1920, 1080), (100, 10, 400, 300))
        with Image.open(WALLPAPER / "contents" / "screenshot.png") as preview:
            self.assertEqual(preview.size, builder.SCREENSHOT_SIZE)


def load_script(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


GORUNUM = load_script("m08_gorunum", REPO / "profiles" / "desktop" / "bin" / "alpbah-gorunum")

SUPPORT_SOFTPIPE = """Compositing
===========
Compositing is active
Compositing Type: OpenGL
OpenGL vendor string: Mesa
OpenGL renderer string: softpipe
Driver: softpipe
"""
SUPPORT_NVIDIA = SUPPORT_SOFTPIPE.replace("softpipe", "NVIDIA GeForce RTX 5060/PCIe/SSE2").replace(
    "Driver: NVIDIA GeForce RTX 5060/PCIe/SSE2", "Driver: NVIDIA")


class FakeRunner(GORUNUM.Runner):
    def __init__(self, support):
        super().__init__(dry_run=False)
        self.support = support

    def run(self, cmd, mutating=True):
        self.log.append(cmd)
        if "supportInformation" in cmd:
            return json.dumps({"type": "s", "data": [self.support]})
        return ""


class ProfileSwitcherTests(unittest.TestCase):
    def setUp(self):
        self._tool = GORUNUM.tool
        GORUNUM.tool = lambda name: name

    def tearDown(self):
        GORUNUM.tool = self._tool

    def run_main(self, args, support):
        runner = FakeRunner(support)
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()) as err:
            code = GORUNUM.main(args, runner=runner)
        mutating = [c for c in runner.log if "supportInformation" not in c]
        return code, mutating, err.getvalue()

    def test_parse_and_block_software_renderer(self):
        renderer = GORUNUM.parse_renderer(SUPPORT_SOFTPIPE)
        self.assertEqual(renderer["type"], "OpenGL")
        self.assertTrue(any("yazılım" in r for r in GORUNUM.glass_blockers(renderer)))
        self.assertEqual(GORUNUM.glass_blockers(GORUNUM.parse_renderer(SUPPORT_NVIDIA)), [])
        self.assertTrue(GORUNUM.glass_blockers(GORUNUM.parse_renderer("Compositing Type: QPainter")))

    def test_glass_refused_on_softpipe_without_changes(self):
        code, mutating, err = self.run_main(["glass"], SUPPORT_SOFTPIPE)
        self.assertEqual(code, 3)
        self.assertEqual(mutating, [])
        self.assertIn("softpipe", err)

    def test_glass_applies_on_hardware(self):
        code, mutating, _ = self.run_main(["glass"], SUPPORT_NVIDIA)
        self.assertEqual(code, 0)
        flat = [" ".join(c) for c in mutating]
        self.assertIn("kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled true", flat)
        self.assertIn("kwriteconfig6 --file kwinrc --group Effect-blur --key BlurStrength 8", flat)
        self.assertTrue(any("loadEffect s blur" in c for c in flat))
        self.assertTrue(any("evaluateScript" in c and '"translucent"' in c for c in flat))
        self.assertIn("kwriteconfig6 --file alpbahrc --group Gorunum --key Profil glass", flat)

    def test_forced_glass_and_solid(self):
        code, mutating, _ = self.run_main(["glass", "--zorla"], SUPPORT_SOFTPIPE)
        self.assertEqual(code, 0)
        code, mutating, _ = self.run_main(["solid"], SUPPORT_SOFTPIPE)
        flat = [" ".join(c) for c in mutating]
        self.assertEqual(code, 0)
        self.assertIn("kwriteconfig6 --file kwinrc --group Effect-blur --key BlurStrength --delete", flat)
        self.assertTrue(any("unloadEffect s blur" in c for c in flat))
        self.assertTrue(any('"opaque"' in c for c in flat))

    def test_values_match_tokens(self):
        tokens = json.loads((REPO / "profiles" / "desktop" / "tokens.json").read_text(encoding="utf-8"))
        for name, spec in GORUNUM.PROFILES.items():
            self.assertEqual(tokens["profiles"][name]["kde"], spec, name)
        xdg = ini((REPO / "profiles" / "desktop" / "xdg" / "kwinrc").read_text(encoding="utf-8"))
        self.assertEqual(xdg["Plugins"]["blurEnabled"], str(GORUNUM.PROFILES["solid"]["blur"]).lower())
        layout = (LNF / "contents" / "layouts" / "org.kde.plasma.desktop-layout.js").read_text(encoding="utf-8")
        self.assertIn(f'opacity = "{GORUNUM.PROFILES["solid"]["panel_opacity"]}"', layout)


MIMEAPPS = load("m08_mimeapps", REPO / "profiles" / "apps" / "generate_mimeapps.py")


class AppProfileTests(unittest.TestCase):
    def setUp(self):
        self.profile = MIMEAPPS.load_profile()

    def test_profile_valid_and_generated_current(self):
        self.assertEqual(MIMEAPPS.validate(self.profile), [])
        generated = (REPO / "profiles" / "apps" / "generated" / "mimeapps.list").read_text(encoding="utf-8")
        self.assertEqual(MIMEAPPS.render(self.profile), generated)
        parsed = ini(generated)
        self.assertEqual(parsed["Default Applications"]["application/pdf"], "okularApplication_pdf.desktop;")
        self.assertEqual(parsed["Default Applications"]["inode/directory"], "org.kde.dolphin.desktop;")
        self.assertEqual(parsed["Default Applications"]["x-scheme-handler/https"], "firefox.desktop;")

    def test_pending_decisions_are_not_emitted(self):
        generated = (REPO / "profiles" / "apps" / "generated" / "mimeapps.list").read_text(encoding="utf-8")
        for pending in self.profile["karar_bekleyen"]:
            for mime in pending["mime"]:
                self.assertNotIn(mime, generated)
            if pending["desktop"]:
                self.assertNotIn(pending["desktop"], generated)

    def test_detects_duplicate_default(self):
        broken = copy.deepcopy(self.profile)
        broken["apps"][0]["mime"].append("application/pdf")
        self.assertTrue(any("application/pdf" in e for e in MIMEAPPS.validate(broken)))
        broken = copy.deepcopy(self.profile)
        broken["apps"][0]["mime"].append("application/x-ms-dos-executable")
        self.assertTrue(any("karar bekleyen" in e for e in MIMEAPPS.validate(broken)))

    def test_master_plan_needs_covered(self):
        needs = {a["ihtiyac"].split(" — ")[0] for a in self.profile["apps"]}
        needs |= {p["ihtiyac"] for p in self.profile["karar_bekleyen"]}
        for need in ("Dosyalar", "Terminal", "Not Defteri", "PDF", "Görseller", "Arşivler", "Ekran görüntüsü",
                     "Medya", "Hesap makinesi", "Sistem ve disk", "Tarayıcı", "Ofis", "Mağaza",
                     "Windows uygulamaları", "Oyun"):
            self.assertIn(need, needs)

    def test_dock_launchers_resolve(self):
        layout = (LNF / "contents" / "layouts" / "org.kde.plasma.desktop-layout.js").read_text(encoding="utf-8")
        desktops = {a["desktop"] for a in self.profile["apps"]}
        for launcher in re.findall(r'"applications:([^"]+)"', layout):
            self.assertIn(launcher, desktops)
        mimes = {m for a in self.profile["apps"] for m in a["mime"]}
        if "preferred://browser" in layout:
            self.assertIn("x-scheme-handler/https", mimes)
        if "preferred://filemanager" in layout:
            self.assertIn("inode/directory", mimes)


PERF_CSV = load("m08_perf_csv", REPO / "profiles" / "perf" / "analyze_kwin_perf_csv.py")
PERF_COLLECT = load("m08_perf_collect", REPO / "profiles" / "perf" / "collect_session_metrics.py")


def write_perf_csv(path, intervals_ms, refresh_ms=16.666, render_ms=4.0):
    ns = 1_000_000
    t = 1_000_000_000
    lines = [",".join(PERF_CSV.COLUMNS)]
    for interval in [refresh_ms] + list(intervals_ms):
        target = t + int(refresh_ms * ns)
        t += int(interval * ns)
        start = t - int((render_ms + 2) * ns)
        lines.append(f"{target},{t},{start},{start + int(render_ms * ns)},1500000,{int(refresh_ms * ns)},0,0,{int(render_ms * ns)}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


class PerfToolTests(unittest.TestCase):
    def test_smooth_scene_within_budget(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            csv_path = Path(temp_dir) / "kwin perf statistics Virtual-1.csv"
            write_perf_csv(csv_path, [16.666] * 120)
            summary = PERF_CSV.summarize(PERF_CSV.load_rows(csv_path))
            self.assertAlmostEqual(summary["frame_interval_ms"]["median"], 16.666, places=2)
            self.assertEqual(summary["over_budget_pct"], 0.0)
            self.assertAlmostEqual(summary["render_ms"]["median"], 4.0, places=2)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(PERF_CSV.main([str(csv_path), "--budget-ms", "16.7"]), 0)

    def test_dropped_frames_detected(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            csv_path = Path(temp_dir) / "perf.csv"
            write_perf_csv(csv_path, [33.3] * 60 + [16.666] * 40)
            summary = PERF_CSV.summarize(PERF_CSV.load_rows(csv_path))
            self.assertGreater(summary["over_budget_pct"], 50)
            self.assertGreater(summary["late_frames"], 0)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(PERF_CSV.main([str(csv_path), "--budget-ms", "16.7"]), 1)

    def test_rejects_wrong_header(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            csv_path = Path(temp_dir) / "bad.csv"
            csv_path.write_text("a,b\n1,2\n", encoding="utf-8")
            with self.assertRaises(PERF_CSV.PerfDataError):
                PERF_CSV.load_rows(csv_path)

    def test_collect_from_fake_proc(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            proc = Path(temp_dir) / "proc"
            (proc / "sys" / "kernel").mkdir(parents=True)
            (proc / "sys" / "kernel" / "osrelease").write_text("6.16.1-alpbahOS\n", encoding="utf-8")
            (proc / "uptime").write_text("321.5 100.0\n", encoding="utf-8")
            (proc / "meminfo").write_text("MemTotal:        4194304 kB\nMemFree:  100 kB\n"
                                          "MemAvailable:    3145728 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\n", encoding="utf-8")
            for pid, name, uid, pss in ((100, "kwin_wayland", 1000, 204800), (101, "plasmashell", 1000, 307200),
                                        (102, "sshd", 0, 5120), (103, "bash", 1000, 2048)):
                d = proc / str(pid)
                d.mkdir()
                (d / "status").write_text(f"Name:\t{name}\nUid:\t{uid}\t{uid}\t{uid}\t{uid}\nVmRSS:\t{pss + 1024} kB\n", encoding="utf-8")
                (d / "smaps_rollup").write_text(f"Rss: {pss + 1024} kB\nPss: {pss} kB\n", encoding="utf-8")
            home = Path(temp_dir) / "home"
            (home / ".config").mkdir(parents=True)
            (home / ".config" / "alpbahrc").write_text("[Gorunum]\nProfil=glass\n", encoding="utf-8")
            data = PERF_COLLECT.collect(proc, 1000, home, use_dbus=False, label="test-idle")
        self.assertEqual(data["memory"]["used_mib"], 1024.0)
        self.assertTrue(data["memory"]["within_idle_budget"])
        self.assertEqual([p["name"] for p in data["processes"]], ["plasmashell", "kwin_wayland"])
        self.assertEqual(data["user_pss_mib"], 502.0)
        self.assertEqual(data["profile"], "glass")
        self.assertEqual(data["kernel"], "6.16.1-alpbahOS")


class InstallScriptTests(unittest.TestCase):
    def setUp(self):
        self.bash = shutil.which("bash")
        if not self.bash:
            self.skipTest("bash yok")

    def run_install(self, *args):
        return subprocess.run([self.bash, "profiles/desktop/install-desktop-profile.sh", *args],
                              capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=REPO)

    def test_install_idempotent_and_conflict_safe(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            first = self.run_install("--destdir", root.as_posix(), "--manifest", (root / "m.txt").as_posix())
            self.assertEqual(first.returncode, 0, first.stderr)
            manifest = (root / "m.txt").read_text(encoding="utf-8").splitlines()
            self.assertIn("/etc/xdg/kglobalshortcutsrc", "\n".join(manifest))
            self.assertTrue((root / "usr/share/plasma/look-and-feel/org.alpbahos.solid.desktop/metadata.json").exists())
            self.assertTrue((root / "usr/share/wallpapers/alpbahOS-Ataturk/contents/images/1920x1080.jpg").exists())
            second = self.run_install("--destdir", root.as_posix())
            self.assertEqual(second.returncode, 0, second.stderr)
            (root / "etc/xdg/kdeglobals").write_text("[KDE]\n", encoding="utf-8")
            third = self.run_install("--destdir", root.as_posix())
            self.assertEqual(third.returncode, 1)
            self.assertIn("ÇAKIŞMA", third.stderr)
            self.assertEqual((root / "etc/xdg/kdeglobals").read_text(encoding="utf-8"), "[KDE]\n")

    def test_refuses_missing_or_live_root(self):
        self.assertEqual(self.run_install().returncode, 2)
        self.assertEqual(self.run_install("--destdir", "/").returncode, 2)


if __name__ == "__main__":
    unittest.main()
