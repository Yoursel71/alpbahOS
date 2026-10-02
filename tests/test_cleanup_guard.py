import importlib.util
import unittest
from unittest.mock import patch
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / 'scripts/infra/cleanup-old-artifacts.py'
spec = importlib.util.spec_from_file_location('infra_cleanup_guard', SOURCE)
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)


class CleanupProcessGuardTests(unittest.TestCase):
    def test_user_cleanup_skips_root_only_subvolume_inventory(self):
        with patch.object(cleanup, 'subvolume_index', side_effect=AssertionError('must not run')):
            self.assertEqual(cleanup.subvolume_index_if_needed(True), {})

    def test_nvme_scope_accepts_only_paths_under_nvme_root(self):
        self.assertTrue(cleanup.within_nvme('/home/yrslf/alpbahOS-nvme/builds/m07'))
        self.assertFalse(cleanup.within_nvme('/mnt/alpbahOS-ssd/alpbahos-builds/archive'))

    def test_hdd_scope_accepts_only_build_artifacts(self):
        self.assertTrue(cleanup.within_hdd_build('/mnt/alpbahOS-data/alpbahOS-build/backups'))
        self.assertFalse(cleanup.within_hdd_build('/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs'))

    def test_current_user_flatpak_dbus_sandbox_is_not_misclassified_as_build(self):
        cgroup = r'0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-flatpak-com.opera.opera\x2dgx-1295026887.scope'
        self.assertTrue(cleanup.desktop_sandbox_identity(
            1000, [cgroup], ['/usr/bin/bwrap', '--args', '77', '--', '/usr/bin/xdg-dbus-proxy']))
        self.assertTrue(cleanup.desktop_sandbox_identity(
            1000, [cgroup], ['/usr/bin/bwrap', '--args', '79', '--', '/usr/bin/xdg-dbus-proxy']))
        self.assertTrue(cleanup.desktop_sandbox_identity(
            1000, [cgroup], ['/usr/bin/bwrap', '--args', '77', '--', '/app/bin/zypak-helper']))
        spotify = '0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-flatpak-com.spotify.Client-1168654954.scope'
        self.assertTrue(cleanup.desktop_sandbox_identity(
            1000, [spotify], ['/usr/bin/bwrap', '--args', '77', '--', '/usr/bin/xdg-dbus-proxy', '--args=76']))
        self.assertTrue(cleanup.desktop_sandbox_identity(
            1000, [spotify], ['/usr/bin/bwrap', '--args', '75', '--', 'spotify']))

    def test_build_sandbox_or_other_user_cannot_use_desktop_exception(self):
        opera_cgroup = r'0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-flatpak-com.opera.opera\x2dgx-1295026887.scope'
        build_cgroup = '0::/user.slice/user-1000.slice/user@1000.service/app.slice/codex-build.scope'
        self.assertFalse(cleanup.desktop_sandbox_identity(
            1000, [opera_cgroup], ['/usr/bin/bwrap', '--', '/usr/bin/make']))
        self.assertFalse(cleanup.desktop_sandbox_identity(
            1000, [build_cgroup], ['/usr/bin/bwrap', '--', 'opera-gx']))
        self.assertFalse(cleanup.desktop_sandbox_identity(
            0, [opera_cgroup], ['/usr/bin/bwrap', '--', 'opera-gx']))


if __name__ == '__main__':
    unittest.main()
