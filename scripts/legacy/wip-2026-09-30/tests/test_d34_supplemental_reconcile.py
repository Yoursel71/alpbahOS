from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/d34_reconcile_package_deltas.py"
SPEC = importlib.util.spec_from_file_location("d34_reconcile_supplemental_under_test", SCRIPT)
assert SPEC and SPEC.loader
RECONCILER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = RECONCILER
SPEC.loader.exec_module(RECONCILER)


class SupplementalReconcileTests(unittest.TestCase):
    def make_chain(self, root: Path, official_count: int, supplemental: list[str]):
        expected = [{"name": f"lfs-{index}", "version": "1"} for index in range(79)]
        names = [item["name"] for item in expected[:official_count]] + supplemental
        previous_uuid = RECONCILER.EXPECTED_INITIAL_SUBVOL_UUID
        runs = []
        for index, package in enumerate(names):
            run = root / f"{index:03d}-{package}"
            run.mkdir()
            after_uuid = f"00000000-0000-4000-8000-{index + 1:012d}"
            (run / "events.jsonl").write_text("{}\n", encoding="utf-8")
            status = {
                "package": package,
                "candidate": {
                    "filesystem_uuid": RECONCILER.EXPECTED_FS_UUID,
                    "subvolume_uuid": previous_uuid,
                    "path": "/candidate",
                },
                "base_readonly": {"uuid": f"00000000-0000-4000-9000-{index + 1:012d}"},
                "after_readonly": {"uuid": after_uuid, "path": "/candidate"},
            }
            runs.append((run, status))
            previous_uuid = after_uuid
        return expected, runs

    def test_hwdata_is_allowed_as_post_chapter8_supplemental(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata"])
            RECONCILER._check_chain(runs, expected)

    def test_hwdata_is_rejected_before_chapter8_is_complete(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 78, ["hwdata"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_duplicate_hwdata_run_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata", "hwdata"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_libdisplay_info_requires_hwdata_first(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libdisplay-info"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_libdisplay_info_is_accepted_after_hwdata(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata", "libdisplay-info"])
            RECONCILER._check_chain(runs, expected)

    def test_libnl_is_accepted_after_hwdata(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata", "libnl"])
            RECONCILER._check_chain(runs, expected)

    def test_libpciaccess_requires_hwdata_first(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libpciaccess"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata", "libpciaccess"])
            RECONCILER._check_chain(runs, expected)

    def test_libdrm_requires_libpciaccess_first(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata", "libpciaccess", "libdrm"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libdrm"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_wayland_requires_libdrm_and_libxml2(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(
                Path(temporary), 79, ["hwdata", "libpciaccess", "libdrm", "libxml2", "wayland"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["wayland"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_wayland_protocols_requires_wayland(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(
                Path(temporary), 79,
                ["hwdata", "libpciaccess", "libdrm", "libxml2", "wayland", "wayland-protocols"],
            )
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["wayland-protocols"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_libyaml_is_allowed_after_chapter8(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libyaml"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 78, ["libyaml"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_cython_requires_libyaml(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libyaml", "Cython"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["Cython"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_mako_requires_cython(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libyaml", "Cython", "Mako"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libyaml", "Mako"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_pyyaml_requires_libyaml_and_cython(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libyaml", "Cython", "PyYAML"])
            RECONCILER._check_chain(runs, expected)
        for chain in (["libyaml", "PyYAML"], ["Cython", "PyYAML"]):
            with self.subTest(chain=chain), tempfile.TemporaryDirectory() as temporary:
                expected, runs = self.make_chain(Path(temporary), 79, chain)
                with self.assertRaises(RECONCILER.LedgerError):
                    RECONCILER._check_chain(runs, expected)

    def test_mesa_requires_graphics_and_python_build_prerequisites(self):
        prerequisites = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                         "libyaml", "Cython", "Mako", "PyYAML"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prerequisites + ["Mesa"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prerequisites[:-1] + ["Mesa"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_freetype_bootstrap_requires_mesa(self):
        prerequisites = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                         "libyaml", "Cython", "Mako", "PyYAML", "Mesa"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prerequisites + ["freetype-bootstrap"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["freetype-bootstrap"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_harfbuzz_requires_freetype_bootstrap(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "freetype-bootstrap"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prefix + ["harfbuzz"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["harfbuzz"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_fontconfig_requires_freetype_and_harfbuzz(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "freetype-bootstrap", "harfbuzz"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prefix + ["fontconfig"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["fontconfig"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_dejavu_fonts_require_fontconfig(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "freetype-bootstrap",
                  "harfbuzz", "fontconfig"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prefix + ["dejavu-fonts"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["dejavu-fonts"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_libpng_requires_mesa_before_qt(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prefix + ["libpng"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libpng"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_qtbase_requires_graphics_and_font_prerequisites(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "freetype-bootstrap", "harfbuzz",
                  "fontconfig", "dejavu-fonts", "libpng"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prefix + ["QtBase"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["QtBase"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_cmake_requires_complete_base_before_desktop_builds(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "libpng"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prefix + ["CMake"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["CMake"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_sqlite_desktop_requires_cmake(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "libpng", "CMake"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prefix + ["sqlite-desktop"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["sqlite-desktop"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_qt_modules_reconcile_in_dependency_order(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "freetype-bootstrap", "harfbuzz",
                  "fontconfig", "dejavu-fonts", "libpng", "CMake", "sqlite-desktop", "QtBase"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prefix + ["qtshadertools", "qtdeclarative", "qtwayland"])
            RECONCILER._check_chain(runs, expected)
        for chain in (["QtBase", "qtdeclarative"], ["QtBase", "qtshadertools", "qtwayland"]):
            with self.subTest(chain=chain), tempfile.TemporaryDirectory() as temporary:
                expected, runs = self.make_chain(Path(temporary), 79, prefix + chain)
                with self.assertRaises(RECONCILER.LedgerError):
                    RECONCILER._check_chain(runs, expected)

    def test_kf6_frameworks_require_complete_qt_svg_ecm_prefix_and_exact_order(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "freetype-bootstrap", "harfbuzz",
                  "fontconfig", "dejavu-fonts", "libpng", "CMake", "sqlite-desktop", "QtBase",
                  "qtshadertools", "qtdeclarative", "qtwayland"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79,
                                             prefix + ["extra-cmake-modules", "qtsvg", "attica", "qttools", "karchive"])
            RECONCILER._check_chain(runs, expected)
        for chain in (["extra-cmake-modules", "qtsvg", "attica", "karchive"],
                      ["extra-cmake-modules", "qtsvg", "qttools"]):
            with self.subTest(chain=chain), tempfile.TemporaryDirectory() as temporary:
                expected, runs = self.make_chain(Path(temporary), 79, prefix + chain)
                with self.assertRaises(RECONCILER.LedgerError):
                    RECONCILER._check_chain(runs, expected)

    def test_kguiaddons_requires_plasma_wayland_protocols_candidate_prerequisite(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "freetype-bootstrap", "harfbuzz",
                  "fontconfig", "dejavu-fonts", "libpng", "CMake", "sqlite-desktop", "QtBase",
                  "qtshadertools", "qtdeclarative", "qtwayland", "extra-cmake-modules", "qtsvg",
                  "attica", "qttools", "karchive", "kcodecs", "kconfig", "kcoreaddons", "kdbusaddons", "kdnssd"]
        valid = prefix + ["plasma-wayland-protocols", "kguiaddons"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, valid)
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prefix + ["kguiaddons"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_kwindowsystem_requires_ordered_xkb_runtime(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "freetype-bootstrap", "harfbuzz",
                  "fontconfig", "dejavu-fonts", "libpng", "CMake", "sqlite-desktop", "QtBase",
                  "qtshadertools", "qtdeclarative", "qtwayland", "extra-cmake-modules", "qtsvg",
                  "attica", "qttools", "karchive", "kcodecs", "kconfig", "kcoreaddons", "kdbusaddons",
                  "kdnssd", "plasma-wayland-protocols", "kguiaddons", "ki18n", "kidletime", "kimageformats",
                  "kitemmodels", "kitemviews", "kplotting", "kwidgetsaddons"]
        valid = prefix + ["xkeyboard-config", "libxkbcommon", "kwindowsystem"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, valid)
            RECONCILER._check_chain(runs, expected)
        for invalid in (prefix + ["libxkbcommon", "xkeyboard-config", "kwindowsystem"],
                        prefix + ["xkeyboard-config", "kwindowsystem"]):
            with self.subTest(invalid=invalid[-3:]), tempfile.TemporaryDirectory() as temporary:
                expected, runs = self.make_chain(Path(temporary), 79, invalid)
                with self.assertRaises(RECONCILER.LedgerError):
                    RECONCILER._check_chain(runs, expected)

    def test_sonnet_requires_a_spellcheck_backend(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "freetype-bootstrap", "harfbuzz",
                  "fontconfig", "dejavu-fonts", "libpng", "CMake", "sqlite-desktop", "QtBase",
                  "qtshadertools", "qtdeclarative", "qtwayland", "extra-cmake-modules", "qtsvg",
                  "attica", "qttools", "karchive", "kcodecs", "kconfig", "kcoreaddons", "kdbusaddons",
                  "kdnssd", "plasma-wayland-protocols", "kguiaddons", "ki18n", "kidletime", "kimageformats",
                  "kitemmodels", "kitemviews", "kplotting", "kwidgetsaddons", "xkeyboard-config",
                  "libxkbcommon", "kwindowsystem", "networkmanager-qt", "solid"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prefix + ["aspell", "sonnet"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prefix + ["sonnet"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_kdoctools_requires_ordered_docbook_dtd_stylesheets_and_catalogs(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "freetype-bootstrap", "harfbuzz",
                  "fontconfig", "dejavu-fonts", "libpng", "CMake", "sqlite-desktop", "QtBase",
                  "qtshadertools", "qtdeclarative", "qtwayland", "extra-cmake-modules", "qtsvg",
                  "attica", "qttools", "karchive", "kcodecs", "kconfig", "kcoreaddons", "kdbusaddons",
                  "kdnssd", "plasma-wayland-protocols", "kguiaddons", "ki18n", "kidletime", "kimageformats",
                  "kitemmodels", "kitemviews", "kplotting", "kwidgetsaddons", "xkeyboard-config",
                  "libxkbcommon", "kwindowsystem", "networkmanager-qt", "solid", "aspell", "sonnet",
                  "threadweaver", "kauth", "kcompletion", "kcrash"]
        valid = prefix + ["docbook-xml", "docbook-xsl", "docbook-catalogs", "perl-uri", "kdoctools"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, valid)
            RECONCILER._check_chain(runs, expected)
        for invalid in (prefix + ["docbook-xsl", "docbook-xml", "docbook-catalogs", "perl-uri", "kdoctools"],
                        prefix + ["docbook-xml", "docbook-xsl", "kdoctools"],
                        prefix + ["docbook-xml", "docbook-xsl", "docbook-catalogs", "kdoctools"]):
            with self.subTest(invalid=invalid[-4:]), tempfile.TemporaryDirectory() as temporary:
                expected, runs = self.make_chain(Path(temporary), 79, invalid)
                with self.assertRaises(RECONCILER.LedgerError):
                    RECONCILER._check_chain(runs, expected)

    def test_kiconthemes_requires_breeze_icons_after_kdesu(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "freetype-bootstrap", "harfbuzz",
                  "fontconfig", "dejavu-fonts", "libpng", "CMake", "sqlite-desktop", "QtBase",
                  "qtshadertools", "qtdeclarative", "qtwayland", "extra-cmake-modules", "qtsvg",
                  "attica", "qttools", "karchive", "kcodecs", "kconfig", "kcoreaddons", "kdbusaddons",
                  "kdnssd", "plasma-wayland-protocols", "kguiaddons", "ki18n", "kidletime", "kimageformats",
                  "kitemmodels", "kitemviews", "kplotting", "kwidgetsaddons", "xkeyboard-config",
                  "libxkbcommon", "kwindowsystem", "networkmanager-qt", "solid", "aspell", "sonnet",
                  "threadweaver", "kauth", "kcompletion", "kcrash", "docbook-xml", "docbook-xsl",
                  "docbook-catalogs", "perl-uri", "kdoctools", "kpty", "kunitconversion", "kcolorscheme",
                  "kconfigwidgets", "kservice", "kglobalaccel", "kpackage", "kdesu"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, prefix + ["breeze-icons", "kiconthemes"])
            RECONCILER._check_chain(runs, expected)
        for invalid in (prefix + ["kiconthemes"], prefix + ["breeze-icons", "breeze-icons", "kiconthemes"]):
            with self.subTest(invalid=invalid[-3:]), tempfile.TemporaryDirectory() as temporary:
                expected, runs = self.make_chain(Path(temporary), 79, invalid)
                with self.assertRaises(RECONCILER.LedgerError):
                    RECONCILER._check_chain(runs, expected)

    def test_knotifications_requires_ordered_canberra_audio_stack(self):
        prefix = ["libxml2", "hwdata", "libpciaccess", "libdrm", "wayland", "wayland-protocols",
                  "libyaml", "Cython", "Mako", "PyYAML", "Mesa", "freetype-bootstrap", "harfbuzz",
                  "fontconfig", "dejavu-fonts", "libpng", "CMake", "sqlite-desktop", "QtBase",
                  "qtshadertools", "qtdeclarative", "qtwayland", "extra-cmake-modules", "qtsvg",
                  "attica", "qttools", "karchive", "kcodecs", "kconfig", "kcoreaddons", "kdbusaddons",
                  "kdnssd", "plasma-wayland-protocols", "kguiaddons", "ki18n", "kidletime", "kimageformats",
                  "kitemmodels", "kitemviews", "kplotting", "kwidgetsaddons", "xkeyboard-config",
                  "libxkbcommon", "kwindowsystem", "networkmanager-qt", "solid", "aspell", "sonnet",
                  "threadweaver", "kauth", "kcompletion", "kcrash", "docbook-xml", "docbook-xsl",
                  "docbook-catalogs", "perl-uri", "kdoctools", "kpty", "kunitconversion", "kcolorscheme",
                  "kconfigwidgets", "kservice", "kglobalaccel", "kpackage", "kdesu", "breeze-icons",
                  "kiconthemes"]
        valid = prefix + ["libogg", "libvorbis", "libcanberra", "knotifications"]
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, valid)
            RECONCILER._check_chain(runs, expected)
        invalid_sequences = (
            prefix + ["libvorbis", "libogg", "libcanberra", "knotifications"],
            prefix + ["libogg", "libvorbis", "knotifications"],
        )
        for invalid in invalid_sequences:
            with self.subTest(invalid=invalid[-4:]), tempfile.TemporaryDirectory() as temporary:
                expected, runs = self.make_chain(Path(temporary), 79, invalid)
                with self.assertRaises(RECONCILER.LedgerError):
                    RECONCILER._check_chain(runs, expected)

    def test_libndp_requires_libnl(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata", "libndp"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata", "libnl", "libndp"])
            RECONCILER._check_chain(runs, expected)

    def test_nspr_is_allowed_after_chapter8(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["nspr"])
            RECONCILER._check_chain(runs, expected)

    def test_nss_requires_nspr(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["nss"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["nspr", "nss"])
            RECONCILER._check_chain(runs, expected)

    def test_nss_trust_integration_requires_nss_and_ca_trust(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libunistring", "libidn2", "libpsl", "curl", "ca-trust-stack", "nspr", "nss", "nss-trust-integration"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["nss-trust-integration"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_wpa_supplicant_requires_network_and_tls_prerequisites(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(
                Path(temporary), 79,
                ["hwdata", "libnl", "libunistring", "libidn2", "libpsl", "curl", "ca-trust-stack",
                 "nspr", "nss", "nss-trust-integration", "wpa_supplicant"],
            )
            RECONCILER._check_chain(runs, expected)

    def test_networkmanager_requires_wpa_ndp_polkit_and_nss(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(
                Path(temporary), 79,
                ["hwdata", "libnl", "libndp", "pcre2", "glib", "libunistring", "libidn2", "libpsl",
                 "curl", "ca-trust-stack", "duktape", "pam-stack-config", "polkit", "nspr",
                 "nss", "nss-trust-integration", "wpa_supplicant", "libxml2", "libxslt", "networkmanager"],
            )
            RECONCILER._check_chain(runs, expected)

    def test_libxslt_is_allowed_as_networkmanager_build_prerequisite(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libxml2", "libxslt"])
            RECONCILER._check_chain(runs, expected)

    def test_libxml2_can_be_added_after_chapter8(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libxml2"])
            RECONCILER._check_chain(runs, expected)

    def test_alsa_lib_is_accepted_after_hwdata(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata", "alsa-lib"])
            RECONCILER._check_chain(runs, expected)

    def test_libsndfile_requires_alsa_lib_first(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata", "libsndfile"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_libsndfile_is_accepted_after_alsa_lib(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata", "alsa-lib", "libsndfile"])
            RECONCILER._check_chain(runs, expected)

    def test_pipewire_requires_alsa_and_libsndfile(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata", "alsa-lib", "pipewire"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_wireplumber_requires_pipewire_and_lua(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata", "lua", "wireplumber"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_audio_services_are_accepted_after_their_prerequisites(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(
                Path(temporary), 79,
                ["hwdata", "alsa-lib", "libsndfile", "lua", "pipewire", "pcre2", "glib", "wireplumber"],
            )
            RECONCILER._check_chain(runs, expected)

    def test_glib_requires_pcre2_and_wireplumber_requires_glib(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["hwdata", "glib"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_libidn2_requires_libunistring(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libidn2"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_network_id_dependencies_are_accepted_in_order(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libunistring", "libidn2"])
            RECONCILER._check_chain(runs, expected)

    def test_libpsl_and_curl_require_network_prerequisites(self):
        for chain in (["libunistring", "libidn2", "libpsl"],
                      ["libunistring", "libidn2", "libpsl", "curl"]):
            with self.subTest(chain=chain), tempfile.TemporaryDirectory() as temporary:
                expected, runs = self.make_chain(Path(temporary), 79, chain)
                RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["libunistring", "libpsl"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_ca_trust_stack_requires_tls_network_stack(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["ca-trust-stack"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(
                Path(temporary), 79,
                ["libunistring", "libidn2", "libpsl", "curl", "ca-trust-stack"],
            )
            RECONCILER._check_chain(runs, expected)

    def test_duktape_can_be_added_as_an_independent_blfs_runtime(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["duktape"])
            RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(
                Path(temporary), 79,
                ["hwdata", "alsa-lib", "libsndfile", "lua", "pipewire", "pcre2", "wireplumber"],
            )
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)

    def test_polkit_requires_glib_and_duktape_after_chapter8(self):
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(Path(temporary), 79, ["glib", "duktape", "polkit"])
            with self.assertRaises(RECONCILER.LedgerError):
                RECONCILER._check_chain(runs, expected)
        with tempfile.TemporaryDirectory() as temporary:
            expected, runs = self.make_chain(
                Path(temporary), 79,
                ["pcre2", "glib", "duktape", "pam-stack-config", "polkit"],
            )
            RECONCILER._check_chain(runs, expected)


if __name__ == "__main__":
    unittest.main()
