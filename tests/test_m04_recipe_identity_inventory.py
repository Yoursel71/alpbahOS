from __future__ import annotations

import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "audit_m04_recipe_identities.py"
SPEC = importlib.util.spec_from_file_location("audit_m04_recipe_identities", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class RecipeIdentityInventoryTests(unittest.TestCase):
    def test_repository_inventory_matches_current_stage_script_coverage(self) -> None:
        inventory = MODULE.build_inventory(
            ROOT,
            repo_commit="test-commit",
            repo_ref="test-branch",
            worktree_dirty=False,
        )
        self.assertEqual(inventory["pinned_package_list"]["package_count"], 79)
        self.assertEqual(inventory["coverage"], {
            "present_dedicated_scripts": 29,
            "missing_dedicated_scripts": 50,
        })
        self.assertEqual(inventory["packages"][0]["name"], "man-pages")
        self.assertEqual(inventory["packages"][-1]["name"], "e2fsprogs")
        for row in inventory["packages"]:
            if row["script_status"] == "present":
                script = ROOT / row["script"]["path"]
                self.assertEqual(row["script"]["sha256"], hashlib.sha256(script.read_bytes()).hexdigest())

    def test_inventory_preserves_order_and_hashes_only_exact_existing_script(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            package_list = root / "packages.json"
            packages = [{"name": "alpha", "version": "1.0"}]
            packages.extend(
                {"name": f"package-{index}", "version": f"{index}.0"}
                for index in range(2, 80)
            )
            package_list.write_text(json.dumps({
                "schema": "alpbahOS.m04-expected-packages/v1",
                "packages": packages,
            }), encoding="utf-8")
            script = root / "scripts" / "build-m04-alpha-stage.sh"
            script.parent.mkdir()
            payload = b"#!/bin/bash\n# exact test bytes\n"
            script.write_bytes(payload)

            inventory = MODULE.build_inventory(
                root,
                packages_file=Path("packages.json"),
                repo_commit="deadbeef",
                repo_ref="test-branch",
                worktree_dirty=False,
            )

            self.assertEqual(inventory["packages"][0]["name"], "alpha")
            self.assertEqual(inventory["packages"][0]["script_status"], "present")
            self.assertEqual(
                inventory["packages"][0]["script"]["sha256"],
                hashlib.sha256(payload).hexdigest(),
            )
            self.assertEqual(inventory["packages"][1]["name"], "package-2")
            self.assertEqual(inventory["packages"][1]["script_status"], "missing")
            self.assertIsNone(inventory["packages"][1]["script"])
            self.assertEqual(inventory["coverage"]["present_dedicated_scripts"], 1)
            self.assertEqual(inventory["coverage"]["missing_dedicated_scripts"], 78)
            self.assertIn("does not prove", inventory["provenance_caveat"])

    def test_rejects_package_list_that_is_not_the_pinned_79_row_scope(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "packages.json").write_text(json.dumps({
                "schema": "alpbahOS.m04-expected-packages/v1",
                "packages": [{"name": "one", "version": "1"}],
            }), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "exactly 79"):
                MODULE.build_inventory(
                    root,
                    packages_file=Path("packages.json"),
                    repo_commit="deadbeef",
                    repo_ref="test-branch",
                    worktree_dirty=False,
                )


if __name__ == "__main__":
    unittest.main()
