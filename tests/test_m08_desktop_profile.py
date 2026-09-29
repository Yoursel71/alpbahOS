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
import zipfile
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


def plasma_color_scheme_name(scheme):
    """plasma-workspace v6.4.4 kcms/lookandfeel/lookandfeelmanager.cpp colorSchemeFile() normalleştirmesi."""
    name = scheme.replace("'", "")
    fixer = re.compile(r"[\W,.-]+(.?)")
    while (match := fixer.search(name)):
        name = name[:match.start()] + match.group(1).upper() + name[match.end():]
    return name[:1].upper() + name[1:]


class LookAndFeelPackageTests(unittest.TestCase):
    def test_system_fonts_match_tokens(self):
        tokens = json.loads((REPO / "profiles" / "desktop" / "tokens.json").read_text(encoding="utf-8"))["typography"]
        xdg = ini((REPO / "profiles" / "desktop" / "xdg" / "kdeglobals").read_text(encoding="utf-8"))
        for key in ("font", "menuFont", "smallestReadableFont", "toolBarFont"):
            self.assertEqual(xdg["General"][key].split(",")[0], tokens["font_primary"], key)
        self.assertEqual(xdg["WM"]["activeFont"].split(",")[0], tokens["font_primary"])
        self.assertEqual(xdg["General"]["fixed"].split(",")[0], tokens["font_terminal"])

    def test_color_scheme_sets_and_contrast(self):
        colors = ini((REPO / "profiles" / "desktop" / "colorscheme" / "AlpbahDark.colors").read_text(encoding="utf-8"))

        def luminance(rgb):
            channels = []
            for c in (int(v) / 255 for v in rgb.split(",")):
                channels.append(c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4)
            return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]

        # Plasma 6 şemalarının taşıdığı setler; eksik Header, Breeze başlık/Kirigami başlıklarını varsayılana düşürür.
        for group in ("Window", "View", "Button", "Selection", "Tooltip", "Complementary", "Header", "Header][Inactive"):
            section = colors[f"Colors:{group}"]
            hi, lo = sorted((luminance(section["ForegroundNormal"]), luminance(section["BackgroundNormal"])), reverse=True)
            self.assertGreaterEqual((hi + 0.05) / (lo + 0.05), 4.5, group)  # WCAG AA gövde metni
        # Tasarım: başlık çubuğu koyu lacivert (mockups §3); WM etkin başlığıyla aynı.
        self.assertEqual(colors["Colors:Header"]["BackgroundNormal"], colors["WM"]["activeBackground"])

    def test_color_scheme_name_normalization(self):
        self.assertEqual(plasma_color_scheme_name("alpbah-dark"), "AlpbahDark")
        self.assertFalse("alpbah-dark.colors".endswith(plasma_color_scheme_name("alpbah-dark") + ".colors"))
        self.assertEqual(plasma_color_scheme_name("BreezeDark"), "BreezeDark")

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
        # startplasma renkleri LookAndFeelManager::colorSchemeFile ile bulur: ad normalleştirilir,
        # dosya adı bununla bitmelidir. 'alpbah-dark' -> 'AlpbahDark' bulunamamıştı (29 Eylül Gen2).
        self.assertTrue(colors.name.endswith(plasma_color_scheme_name(scheme) + ".colors"), colors.name)
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

    def test_excluded_apps_are_not_emitted(self):
        generated = (REPO / "profiles" / "apps" / "generated" / "mimeapps.list").read_text(encoding="utf-8")
        for excluded in self.profile["dahil_degil"]:
            for mime in excluded["mime"]:
                self.assertNotIn(mime, generated)
            if excluded["desktop"]:
                self.assertNotIn(excluded["desktop"], generated)

    def test_detects_duplicate_default(self):
        broken = copy.deepcopy(self.profile)
        broken["apps"][0]["mime"].append("application/pdf")
        self.assertTrue(any("application/pdf" in e for e in MIMEAPPS.validate(broken)))
        broken = copy.deepcopy(self.profile)
        broken["apps"][0]["mime"].append("application/x-ms-dos-executable")
        self.assertTrue(any("dahil olmayan" in e for e in MIMEAPPS.validate(broken)))

    def test_master_plan_needs_covered(self):
        needs = {a["ihtiyac"].split(" — ")[0] for a in self.profile["apps"]}
        needs |= {p["ihtiyac"] for p in self.profile["dahil_degil"]}
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


OFFICE = load("m08_office", REPO / "profiles" / "apps" / "office" / "office_fixtures.py")


class OfficeFixtureTests(unittest.TestCase):
    def test_generated_documents_pass_check(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            out = Path(temp_dir)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(OFFICE.main(["make", "--out", str(out)]), 0)
                self.assertEqual(OFFICE.main(["check", str(out / "alpbah-test.docx"), str(out / "alpbah-test.xlsx")]), 0)
            paragraphs, table = OFFICE.docx_text(out / "alpbah-test.docx")
            self.assertIn(OFFICE.TURKISH, paragraphs)
            self.assertIn("\t", paragraphs[2])
            self.assertEqual(table, OFFICE.TABLE)

    def test_detects_damaged_text(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            out = Path(temp_dir)
            OFFICE.make_docx(out / "a.docx")
            with zipfile.ZipFile(out / "a.docx") as z:
                parts = {n: z.read(n) for n in z.namelist()}
            # İ -> I: tipik yanlış Türkçe büyük harf dönüşümü
            parts["word/document.xml"] = parts["word/document.xml"].replace("ĞÜŞİÖÇ".encode(), "ĞÜŞIÖÇ".encode())
            with zipfile.ZipFile(out / "b.docx", "w") as z:
                for name, data in parts.items():
                    z.writestr(name, data)
            self.assertTrue(OFFICE.check(out / "b.docx"))

    def test_shared_strings_and_recomputed_formula(self):
        # Excel/Calc kaydettiğinde dizgiler sharedStrings.xml'e taşınır ve formül '=' içermez.
        S = OFFICE.S
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "shared.xlsx"
            strings = ["Ürün", "Adet", "Çay", "Şeker"]
            sst = "".join(f"<si><t>{s}</t></si>" for s in strings)
            sheet = (f'<worksheet xmlns="{S}"><sheetData>'
                     '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>'
                     '<row r="2"><c r="A2" t="s"><v>2</v></c><c r="B2"><v>12</v></c></row>'
                     '<row r="3"><c r="A3" t="s"><v>3</v></c><c r="B3"><v>30</v></c></row>'
                     '<row r="4"><c r="B4"><f>SUM(B2:B3)</f><v>42</v></c></row>'
                     '</sheetData></worksheet>')
            with zipfile.ZipFile(path, "w") as z:
                z.writestr("xl/sharedStrings.xml", f'<sst xmlns="{S}">{sst}</sst>')
                z.writestr("xl/worksheets/sheet1.xml", sheet)
            self.assertEqual(OFFICE.check(path), [])
            broken = Path(temp_dir) / "broken.xlsx"
            with zipfile.ZipFile(broken, "w") as z:
                z.writestr("xl/sharedStrings.xml", f'<sst xmlns="{S}">{sst}</sst>')
                z.writestr("xl/worksheets/sheet1.xml", sheet.replace("<v>42</v>", "<v>0</v>"))
            self.assertTrue(any("B4" in p for p in OFFICE.check(broken)))


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
            joined = "\n".join(manifest)
            for target in ("/usr/share/alpbahos/kglobalshortcutsrc", "/usr/bin/alpbah-oturum-hazirla",
                           "/etc/xdg/plasma-workspace/env/alpbahos-oturum.sh", "/usr/share/color-schemes/AlpbahDark.colors"):
                self.assertIn(target, joined)
            # kglobalacceld /etc/xdg'yi okumaz (SimpleConfig); yanıltıcı sistem dosyası kurulmaz.
            self.assertNotIn("/etc/xdg/kglobalshortcutsrc", joined)
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


OTURUM = load_script("m08_oturum", REPO / "profiles" / "desktop" / "bin" / "alpbah-oturum-hazirla")
PROFILE_TEXT = (SHORTCUTS / "generated" / "kglobalshortcutsrc").read_text(encoding="utf-8")

# kglobalacceld'in ilk oturumda yazdığı upstream durum (etkin == varsayılan) ve ilgisiz satırlar.
KDE_WRITTEN = """[kwin]
_k_friendly_name=KWin
Expose=Ctrl+F9,Ctrl+F9,Toggle Present Windows (Current desktop)
Overview=Meta+W,Meta+W,Toggle Overview
Walk Through Windows=Meta+Tab\\tAlt+Tab,Meta+Tab\\tAlt+Tab,Walk Through Windows
Window Maximize=Meta+PgUp,Meta+PgUp,Maximize Window
Window Quick Tile Top=Meta+Up,Meta+Up,Quick Tile Window to the Top

[plasmashell]
_k_friendly_name=plasmashell
activate application launcher=Meta\\tAlt+F1,Meta\\tAlt+F1,Activate Application Launcher
"""


class SessionPrepTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.config = root / "config"
        self.data = root / "data"
        (self.data / "alpbahos").mkdir(parents=True)
        self.profile = self.data / "alpbahos" / "kglobalshortcutsrc"
        self.profile.write_text(PROFILE_TEXT, encoding="utf-8")
        self.env = {"HOME": str(root), "XDG_CONFIG_HOME": str(self.config), "XDG_DATA_HOME": str(self.data),
                    "XDG_DATA_DIRS": ""}
        self.user = self.config / "kglobalshortcutsrc"
        self._kwin = OTURUM.kwin_running
        OTURUM.kwin_running = lambda *a: False

    def tearDown(self):
        OTURUM.kwin_running = self._kwin
        self.temp.cleanup()

    def run_tool(self, *args):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(OTURUM.main(list(args), env=self.env), 0)
        return out.getvalue()

    def entry(self, group, key):
        return OTURUM.KConfigText(self.user.read_text(encoding="utf-8")).get(group, key)

    def test_first_login_gets_whole_profile(self):
        self.run_tool()
        user = ini(self.user.read_text(encoding="utf-8"))
        profile = ini(PROFILE_TEXT)
        for section in profile.sections():
            for key, value in profile[section].items():
                self.assertEqual(user[section][key], value, (section, key))
        self.assertNotIn("ÜRETİLMİŞ", self.user.read_text(encoding="utf-8"))
        # Durum ~/.config altında: Gen2'de ~/.local root'a aitti ve yazılamadı.
        self.assertTrue((self.config / "alpbahos" / "oturum.json").exists())
        self.assertIn("eklendi: [kwin] Window Maximize", (self.config / "alpbahos" / "oturum-hazirla.log").read_text(encoding="utf-8"))

    def test_upstream_entries_replaced_other_lines_kept(self):
        self.config.mkdir(parents=True)
        self.user.write_text(KDE_WRITTEN, encoding="utf-8")
        self.run_tool()
        self.assertEqual(self.entry("[kwin]", "Window Maximize"), "Meta+Up\\tMeta+PgUp,Meta+PgUp,Maximize Window")
        self.assertEqual(self.entry("[kwin]", "Window Quick Tile Top"), "none,Meta+Up,Quick Tile Window to the Top")
        self.assertEqual(self.entry("[kwin]", "Walk Through Windows"), "Alt+Tab,Meta+Tab\\tAlt+Tab,Walk Through Windows")
        self.assertEqual(self.entry("[kwin]", "Expose"), "Ctrl+F9,Ctrl+F9,Toggle Present Windows (Current desktop)")
        self.assertEqual(self.entry("[kwin]", "_k_friendly_name"), "KWin")
        self.assertEqual(self.entry("[services][org.kde.krunner.desktop]", "_launch"), "Meta+R\\tAlt+Space\\tAlt+F2\\tSearch")

    def test_user_customisation_is_kept(self):
        self.config.mkdir(parents=True)
        custom = KDE_WRITTEN.replace("Window Maximize=Meta+PgUp,", "Window Maximize=Meta+M,")
        custom += "\n[services][org.kde.dolphin.desktop]\n_launch=Meta+F\n"
        self.user.write_text(custom, encoding="utf-8")
        out = self.run_tool("--durum")
        self.assertIn("kullanıcı ayarı korundu: [kwin] Window Maximize = Meta+M", out)
        self.assertEqual(self.user.read_text(encoding="utf-8"), custom)  # --durum yazmaz
        self.run_tool()
        self.assertEqual(self.entry("[kwin]", "Window Maximize"), "Meta+M,Meta+PgUp,Maximize Window")
        self.assertEqual(self.entry("[services][org.kde.dolphin.desktop]", "_launch"), "Meta+F")

    def test_applied_once_then_profile_update_moves_own_values(self):
        self.run_tool()
        # Kullanıcı sonradan KDE varsayılanına dönerse aynı profil yeniden dayatılmaz.
        text = self.user.read_text(encoding="utf-8").replace("Window Maximize=Meta+Up\\tMeta+PgUp,", "Window Maximize=Meta+PgUp,")
        self.user.write_text(text, encoding="utf-8")
        self.assertIn("zaten uygulanmış", self.run_tool())
        self.assertEqual(self.entry("[kwin]", "Window Maximize"), "Meta+PgUp,Meta+PgUp,Maximize Window")
        # Yeni profil: aracın kendi yazdığı değer (Minimize) kullanıcı değişikliği sayılmaz ve güncellenir.
        self.profile.write_text(PROFILE_TEXT.replace("Window Minimize=Meta+Down\\tMeta+PgDown,", "Window Minimize=Meta+Down,"),
                                encoding="utf-8")
        self.run_tool()
        self.assertEqual(self.entry("[kwin]", "Window Minimize"), "Meta+Down,Meta+PgDown,Minimize Window")
        # Varsayılana dönüş kullanıcı kararıdır; profil güncellemesi onu geri almaz.
        self.assertEqual(self.entry("[kwin]", "Window Maximize"), "Meta+PgUp,Meta+PgUp,Maximize Window")

    def test_skips_while_kwin_runs_unless_forced(self):
        OTURUM.kwin_running = lambda *a: True
        self.assertIn("KWin çalışıyor", self.run_tool())
        self.assertFalse(self.user.exists())
        self.run_tool("--zorla")
        self.assertTrue(self.user.exists())

    def test_old_color_scheme_default_is_migrated(self):
        defaults = self.config / "kdedefaults"
        defaults.mkdir(parents=True)
        (defaults / "package").write_text("org.alpbahos.solid.desktop", encoding="utf-8")
        # Gen2'de görülen durum: şema bulunamadığı için ColorScheme hiç yazılmamış.
        (defaults / "kdeglobals").write_text("[Icons]\nTheme=breeze-dark\n\n[KDE]\nwidgetStyle=Breeze\n", encoding="utf-8")
        self.run_tool()
        self.assertFalse((defaults / "package").exists())
        (defaults / "package").write_text("org.alpbahos.solid.desktop", encoding="utf-8")
        (defaults / "kdeglobals").write_text("[General]\nColorScheme=alpbah-dark\n", encoding="utf-8")
        (self.config / "kdeglobals").write_text("[General]\nColorScheme=alpbah-dark\nfont=X\n", encoding="utf-8")
        self.run_tool()
        self.assertFalse((defaults / "package").exists())
        self.assertEqual((self.config / "kdeglobals").read_text(encoding="utf-8"), "[General]\nColorScheme=AlpbahDark\nfont=X\n")
        (defaults / "package").write_text("org.alpbahos.solid.desktop", encoding="utf-8")
        (defaults / "kdeglobals").write_text("[General]\nColorScheme=AlpbahDark\n", encoding="utf-8")
        self.run_tool()
        self.assertTrue((defaults / "package").exists())
        # Kullanıcı başka bir global tema seçtiyse dokunulmaz.
        (defaults / "package").write_text("org.kde.breeze.desktop", encoding="utf-8")
        (defaults / "kdeglobals").write_text("[KDE]\nwidgetStyle=Breeze\n", encoding="utf-8")
        self.run_tool()
        self.assertTrue((defaults / "package").exists())

    def test_env_script_is_silent(self):
        sh = shutil.which("sh")
        if not sh:
            self.skipTest("sh yok")
        with tempfile.TemporaryDirectory() as temp_dir:
            fake = Path(temp_dir) / "alpbah-oturum-hazirla"
            fake.write_text("#!/bin/sh\necho GURULTU\necho HATA >&2\nexit 7\n", encoding="utf-8", newline="\n")
            fake.chmod(0o755)
            script = (REPO / "profiles" / "desktop" / "xdg" / "plasma-workspace" / "env" / "alpbahos-oturum.sh").as_posix()
            proc = subprocess.run([sh, "-c", f'PATH="{Path(temp_dir).as_posix()}:$PATH"; . "{script}"; echo SON'],
                                  capture_output=True, text=True, encoding="utf-8", errors="replace")
            self.assertEqual(proc.stdout, "SON\n")
            self.assertEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()
