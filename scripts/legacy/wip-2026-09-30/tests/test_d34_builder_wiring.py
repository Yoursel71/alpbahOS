from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[1]
SCRIPTS = REPO / "scripts"
EXPECTED_MANIFEST = REPO / "docs/verification/manifests/lfs-base/m04-expected-chapter8-packages-12.4.json"
SPECIAL_CASES = {
    "build-lfs-glibc-ch8.sh",
    "build-lfs-iana-etc-ch8.sh",
    "build-lfs-man-pages-ch8.sh",
}
BUILDER_NAME_ALIASES = {"python": "python3"}


class D34BuilderWiringTests(unittest.TestCase):
    def official_builders(self):
        import json

        data = json.loads(EXPECTED_MANIFEST.read_text(encoding="utf-8"))
        return [
            SCRIPTS / f"build-lfs-{BUILDER_NAME_ALIASES.get(row['name'], row['name'])}-ch8.sh"
            for row in data["packages"]
        ]

    def test_every_chapter8_builder_is_accounted_for(self):
        builders = self.official_builders()
        self.assertEqual(len(builders), 79)
        self.assertTrue(all(builder.is_file() for builder in builders))
        self.assertEqual({path.name for path in builders if "lfs-build-guard.sh" not in path.read_text()},
                         SPECIAL_CASES)

    def test_shared_guard_is_wired_to_all_host_orchestrators(self):
        builders = self.official_builders()
        adapted = [path for path in builders if path.name not in SPECIAL_CASES]
        self.assertEqual(len(adapted), 76)
        for path in adapted:
            with self.subTest(builder=path.name):
                source = path.read_text()
                self.assertEqual(source.count("source \"$(cd -- \"$(dirname -- \"${BASH_SOURCE[0]}\")\" && pwd)/lfs-build-guard.sh\""), 1)
                self.assertEqual(source.count('lfs_validate_target "$LFS" "$DATA"'), 1)
                self.assertEqual(source.count('lfs_acquire_writer_lock "$DATA"'), 1)
                self.assertNotIn("is not on ext4.", source)
                self.assertNotIn("expected HDD bind mount.", source)
                self.assertNotIn("flock -n 9", source)

    def test_shared_guard_keeps_legacy_defaults_and_binds_d34_to_identity(self):
        source = (SCRIPTS / "lfs-build-guard.sh").read_text()
        for required in (
            'if [[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]]',
            '[[ "$(findmnt -n -o FSTYPE -T "$root")" == btrfs ]]',
            '[[ "$fs_uuid" == "${ALPBAHOS_D34_FS_UUID:-}" ]]',
            '[[ "$mount_id" == "${ALPBAHOS_D34_MOUNT_ID:-}" ]]',
            '[[ "$root_identity" == "${ALPBAHOS_D34_ROOT_DEVICE_INODE:-}" ]]',
            '[[ "$subvolume_uuid" == "${ALPBAHOS_D34_SUBVOL_UUID:-}" ]]',
            '[[ "$subvolume_id" == "${ALPBAHOS_D34_SUBVOL_ID:-}" ]]',
            '[[ "$(findmnt -n -o FSTYPE -T "$root")" == ext4 ]]',
            '"$data_root/lfs"',
            'exec 9>"$data_root/locks/lfs-build-writer.lock"',
        ):
            with self.subTest(required=required):
                self.assertIn(required, source)

    def test_network_supplemental_builders_use_shared_d34_guard(self):
        for name in ("build-blfs-libunistring.sh", "build-blfs-libidn2.sh",
                     "build-blfs-libpsl.sh", "build-blfs-curl.sh"):
            source = (SCRIPTS / name).read_text()
            with self.subTest(builder=name):
                self.assertIn("lfs-build-guard.sh", source)
                self.assertEqual(source.count('lfs_validate_target "$LFS" "$DATA"'), 1)
                self.assertEqual(source.count('lfs_acquire_writer_lock "$DATA"'), 1)
                self.assertNotIn('"$DATA/lfs"', source)
                self.assertNotIn("flock -n 9", source)
        libidn2 = (SCRIPTS / "build-blfs-libidn2.sh").read_text()
        self.assertIn("/usr/include/unistr.h", libidn2)
        self.assertIn("_LIBUNISTRING_VERSION 0x010300", libidn2)
        curl = (SCRIPTS / "build-blfs-curl.sh").read_text()
        self.assertIn("libpsl 0.21.5", curl)
        self.assertIn('"OpenSSL 3.5.2"*', curl)
        trust_stack = (SCRIPTS / "build-blfs-qca-prereqs.sh").read_text()
        self.assertIn("lfs-build-guard.sh", trust_stack)
        self.assertEqual(trust_stack.count('lfs_validate_target "$LFS" "$DATA"'), 1)
        self.assertEqual(trust_stack.count('lfs_acquire_writer_lock "$DATA"'), 1)
        self.assertNotIn('"$DATA/lfs"', trust_stack)
        self.assertIn("https://hg-edge.mozilla.org/projects/nss/raw-file/tip/lib/ckfw/builtins/certdata.txt", trust_stack)
        self.assertIn("make-ca -C /sources/mozilla-nss-certdata.txt", trust_stack)
        self.assertNotIn("make-ca -g", trust_stack)
        duktape = (SCRIPTS / "build-blfs-duktape.sh").read_text()
        self.assertIn("lfs-build-guard.sh", duktape)
        self.assertEqual(duktape.count('lfs_validate_target "$LFS" "$DATA"'), 1)
        self.assertEqual(duktape.count('lfs_acquire_writer_lock "$DATA"'), 1)
        self.assertNotIn('"$DATA/lfs"', duktape)
        polkit = (SCRIPTS / "build-blfs-polkit.sh").read_text()
        self.assertIn("lfs-build-guard.sh", polkit)
        self.assertEqual(polkit.count('lfs_validate_target "$LFS" "$DATA"'), 1)
        self.assertEqual(polkit.count('lfs_acquire_writer_lock "$DATA"'), 1)
        self.assertNotIn('"$DATA/lfs"', polkit)
        pam_config = (SCRIPTS / "configure-blfs-pam-stack-d34.sh").read_text()
        self.assertIn("lfs-build-guard.sh", pam_config)
        self.assertEqual(pam_config.count('lfs_validate_target "$LFS" "$DATA"'), 1)
        self.assertEqual(pam_config.count('lfs_acquire_writer_lock "$DATA"'), 1)
        libndp = (SCRIPTS / "build-blfs-libndp.sh").read_text()
        self.assertIn("lfs-build-guard.sh", libndp)
        self.assertEqual(libndp.count('lfs_validate_target "$LFS" "$DATA"'), 1)
        self.assertEqual(libndp.count('lfs_acquire_writer_lock "$DATA"'), 1)
        nspr = (SCRIPTS / "build-blfs-nspr.sh").read_text()
        self.assertIn("lfs-build-guard.sh", nspr)
        self.assertEqual(nspr.count('lfs_validate_target "$LFS" "$DATA"'), 1)
        self.assertEqual(nspr.count('lfs_acquire_writer_lock "$DATA"'), 1)
        nss = (SCRIPTS / "build-blfs-nss.sh").read_text()
        self.assertIn("lfs-build-guard.sh", nss)
        self.assertEqual(nss.count('lfs_validate_target "$LFS" "$DATA"'), 1)
        self.assertEqual(nss.count('lfs_acquire_writer_lock "$DATA"'), 1)
        networkmanager = (SCRIPTS / "build-blfs-networkmanager.sh").read_text()
        self.assertIn("lfs-build-guard.sh", networkmanager)
        self.assertEqual(networkmanager.count('lfs_validate_target "$LFS" "$DATA"'), 1)
        self.assertEqual(networkmanager.count('lfs_acquire_writer_lock "$DATA"'), 1)
        libxml2 = (SCRIPTS / "build-blfs-libxml2-d34.sh").read_text()
        self.assertIn("lfs-build-guard.sh", libxml2)
        self.assertEqual(libxml2.count('lfs_validate_target "$LFS" "$DATA"'), 1)
        self.assertEqual(libxml2.count('lfs_acquire_writer_lock "$DATA"'), 1)
        libxslt = (SCRIPTS / "build-blfs-libxslt-d34.sh").read_text()
        self.assertIn("lfs-build-guard.sh", libxslt)
        self.assertEqual(libxslt.count('lfs_validate_target "$LFS" "$DATA"'), 1)
        self.assertEqual(libxslt.count('lfs_acquire_writer_lock "$DATA"'), 1)


if __name__ == "__main__":
    unittest.main()
