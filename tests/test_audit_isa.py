"""Tests for scripts/lfs-blfs/cpu-baseline/audit-isa.sh (REBUILD-R2, D146).

Each case assembles a small shared object with `as` and `ld` (binutils only, no
compiler), runs the audit on it, and checks the exit code and the reported result.
Skipped when binutils or bash are not installed.
"""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
TOOL = REPO / "scripts" / "lfs-blfs" / "cpu-baseline" / "audit-isa.sh"
TOOLS = ("as", "ld", "objdump", "readelf", "gawk", "bash")

# A VEX instruction (non-baseline) and a plain baseline instruction.
VEX = "vzeroupper"
BASE = "nop"


def func(name, body, exported=True, calls=(), address_taken=False):
    """Return assembly text for one function. Local functions get no .globl."""
    lines = []
    if exported:
        lines.append(f".globl {name}")
    lines.append(f".type {name},@function")
    lines.append(f"{name}:")
    lines += [f"\tcall {c}" for c in calls]
    lines.append(f"\t{body}")
    lines.append("\tret")
    text = "\n".join(lines)
    if address_taken:
        text += f"\n.data\n{name}_ptr:\n\t.quad {name}\n.text"
    return text


class AuditIsaTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        missing = [t for t in TOOLS if shutil.which(t) is None]
        if missing:
            raise unittest.SkipTest("missing tools: " + ", ".join(missing))

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.empty_allow = self.tmp / "empty.allow"
        self.empty_allow.write_text("# no entries\n")

    def tearDown(self):
        self._tmp.cleanup()

    def build(self, name, functions):
        src = self.tmp / f"{name}.s"
        src.write_text(".text\n" + "\n\n".join(functions) + "\n")
        obj = self.tmp / f"{name}.o"
        so = self.tmp / name
        subprocess.run(["as", "-o", str(obj), str(src)], check=True)
        subprocess.run(["ld", "-shared", "-o", str(so), str(obj)], check=True)
        return so

    def audit(self, *paths, allow=None):
        allow = allow or self.empty_allow
        return subprocess.run(
            ["bash", str(TOOL), "--allowlist", str(allow), *map(str, paths)],
            capture_output=True,
            text=True,
        )

    # ---- rules ---------------------------------------------------------------

    def test_clean_file_passes(self):
        so = self.build("libclean.so", [func("base_fn", BASE)])
        r = self.audit(so)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("0 unallowed", r.stdout)

    def test_baseline_vex_function_fails(self):
        so = self.build("libbase.so", [func("base_fn", VEX)])
        r = self.audit(so)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("NONVARIANT  base_fn", r.stdout)

    def test_variant_named_function_passes(self):
        so = self.build("libvariant.so", [func("foo_avx2_fn", VEX)])
        r = self.audit(so)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_pclmul_named_function_passes(self):
        so = self.build("libcrc.so", [func("crc32_update_no_xor_pclmul", VEX)])
        r = self.audit(so)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_vector_abi_name_passes(self):
        so = self.build("libmvec-fixture.so", [func("_ZGVcN4v_acos", VEX)])
        r = self.audit(so)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_vector_abi_name_in_baseline_form_is_not_a_pass_by_name(self):
        # Only _ZGV[cde] is a vector-ABI name; a _ZGVb name gets no free pass.
        so = self.build("libmvecb.so", [func("_ZGVbN4v_acos", VEX)])
        r = self.audit(so)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)

    def test_local_helper_reached_only_from_variant_passes(self):
        so = self.build(
            "libhelper.so",
            [
                func("helper_local", VEX, exported=False),
                func("foo_fma", BASE, calls=["helper_local"]),
            ],
        )
        r = self.audit(so)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_local_helper_also_reached_from_baseline_fails(self):
        so = self.build(
            "libhelper2.so",
            [
                func("helper_local", VEX, exported=False),
                func("foo_fma", BASE, calls=["helper_local"]),
                func("base_fn", BASE, calls=["helper_local"]),
            ],
        )
        r = self.audit(so)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("NONVARIANT  helper_local", r.stdout)

    def test_exported_helper_fails_even_if_called_from_variant(self):
        so = self.build(
            "libexp.so",
            [
                func("helper_pub", VEX, exported=True),
                func("foo_fma", BASE, calls=["helper_pub"]),
            ],
        )
        r = self.audit(so)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("NONVARIANT  helper_pub", r.stdout)

    def test_address_taken_helper_fails(self):
        so = self.build(
            "libaddr.so",
            [
                func("helper_local", VEX, exported=False, address_taken=True),
                func("foo_fma", BASE, calls=["helper_local"]),
            ],
        )
        r = self.audit(so)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("NONVARIANT  helper_local", r.stdout)

    # ---- allowlist -----------------------------------------------------------

    def test_allowlist_entry_passes_reviewed_hit(self):
        so = self.build("libitm-fixture.so", [func("_ITM_RM256", VEX)])
        allow = self.tmp / "allow"
        allow.write_text(
            "libitm-fixture.so\t_ITM_*M256\treason text\treviewer 2026-11-06\n"
        )
        r = self.audit(so)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        r = self.audit(so, allow=allow)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("ALLOWED     _ITM_RM256", r.stdout)
        self.assertIn("1 hit(s) allowlisted", r.stdout)

    def test_allowlist_wrong_symbol_does_not_pass(self):
        so = self.build("libitm-fixture2.so", [func("_ITM_RM256", VEX)])
        allow = self.tmp / "allow"
        allow.write_text(
            "libitm-fixture2.so\t_ITM_*M128\treason text\treviewer 2026-11-06\n"
        )
        r = self.audit(so, allow=allow)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)

    def test_allowlist_wrong_file_does_not_pass(self):
        so = self.build("libitm-fixture3.so", [func("_ITM_RM256", VEX)])
        allow = self.tmp / "allow"
        allow.write_text("usr/lib/other.so\t_ITM_*M256\treason\treviewer 2026-11-06\n")
        r = self.audit(so, allow=allow)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)

    def test_stale_allowlist_entry_warns_only(self):
        so = self.build("libstale.so", [func("base_fn", BASE)])
        allow = self.tmp / "allow"
        allow.write_text("libstale.so\t_ITM_*M256\treason\treviewer 2026-11-06\n")
        r = self.audit(so, allow=allow)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("WARN stale allowlist entry", r.stdout)

    def test_malformed_allowlist_is_usage_error(self):
        so = self.build("libmal.so", [func("base_fn", BASE)])
        allow = self.tmp / "allow"
        allow.write_text("libmal.so\t_ITM_*M256\treason only\n")
        r = self.audit(so, allow=allow)
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertIn("need 4 TAB-separated fields", r.stderr)

    def test_directory_scan_skips_ko_unless_include_ko(self):
        # Kernel modules are mode 644, so a plain directory scan must not take them.
        mod_dir = self.tmp / "modules"
        mod_dir.mkdir()
        self.build("mod-vex.ko", [func("mod_vex", VEX)])
        mod = mod_dir / "mod-vex.ko"
        shutil.move(str(self.tmp / "mod-vex.ko"), str(mod))
        mod.chmod(0o644)
        r = self.audit(mod_dir)
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertIn("no ELF files found", r.stderr)
        r = subprocess.run(
            ["bash", str(TOOL), "--include-ko", "--allowlist", str(self.empty_allow), str(mod_dir)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("NONVARIANT  mod_vex", r.stdout)


if __name__ == "__main__":
    unittest.main()
