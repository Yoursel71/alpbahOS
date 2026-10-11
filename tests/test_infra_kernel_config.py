import importlib.util
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('kernel_config', REPO / 'scripts/infra-kernel-config.py')
kernel = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(kernel)


class KernelConfig(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.config = Path(self.temporary.name) / '.config'
        self.text = '# Linux/x86_64 6.16.1 Kernel Configuration\n' + kernel.fragment()
        self.config.write_text(self.text)

    def test_verification_is_configuration_only(self):
        result = kernel.verify(self.config)
        self.assertEqual(result['result'], 'CONFIG_VERIFIED')
        self.assertIn('no kernel build', result['scope'])

    def test_actual_kconfig_font_symbol_spelling_is_supported(self):
        self.config.write_text(self.text + 'CONFIG_FONT_8x8=y\nCONFIG_FONT_8x16=y\n')
        self.assertEqual(kernel.verify(self.config)['result'], 'CONFIG_VERIFIED')

    def test_dependency_resolution_cannot_silently_remove_boot_abi_or_console(self):
        for key in ('CONFIG_IA32_EMULATION', 'CONFIG_VIRTIO_BLK', 'CONFIG_EXT4_FS',
                    'CONFIG_DRM_VIRTIO_GPU', 'CONFIG_FRAMEBUFFER_CONSOLE', 'CONFIG_SERIAL_8250_CONSOLE'):
            with self.subTest(key=key):
                self.config.write_text(self.text.replace(key + '=y\n', '# ' + key + ' is not set\n'))
                with self.assertRaisesRegex(RuntimeError, key):
                    kernel.verify(self.config)

    def test_boot_driver_module_and_unselected_x32_are_rejected(self):
        for old, new in (('CONFIG_VIRTIO_BLK=y', 'CONFIG_VIRTIO_BLK=m'),
                         ('CONFIG_X86_X32_ABI=n', 'CONFIG_X86_X32_ABI=y')):
            self.config.write_text(self.text.replace(old, new))
            with self.assertRaises(RuntimeError):
                kernel.verify(self.config)

    def test_wrong_version_and_architecture_are_rejected(self):
        for header in ('# Linux/x86_64 6.16.2 Kernel Configuration', '# Linux/arm64 6.16.1 Kernel Configuration'):
            self.config.write_text(self.text.replace('# Linux/x86_64 6.16.1 Kernel Configuration', header))
            with self.assertRaisesRegex(RuntimeError, 'version/architecture'):
                kernel.verify(self.config)

    def test_duplicate_assignment_including_disabled_is_ambiguous(self):
        self.config.write_text(self.text + '# CONFIG_IA32_EMULATION is not set\n')
        with self.assertRaisesRegex(RuntimeError, 'Duplicate'):
            kernel.verify(self.config)

    def test_missing_panic_formatter_and_malformed_lines_fail(self):
        for suffix in ('CONFIG_BROKEN=$value\n', 'unexpected text\n'):
            self.config.write_text(self.text + suffix)
            with self.assertRaisesRegex(RuntimeError, 'Malformed'):
                kernel.verify(self.config)
        self.config.write_text(self.text.replace('CONFIG_DRM_PANIC_SCREEN="kmsg"\n', ''))
        with self.assertRaisesRegex(RuntimeError, 'CONFIG_DRM_PANIC_SCREEN'):
            kernel.verify(self.config)

    def test_aliased_and_changed_requirements_are_rejected(self):
        alias = self.config.parent / 'alias'
        alias.symlink_to(self.config)
        with self.assertRaisesRegex(RuntimeError, 'aliased'):
            kernel.verify(alias)
        changed = self.config.parent / 'required.config'
        changed.write_bytes(kernel.REQUIRED.read_bytes() + b'CONFIG_NEW=y\n')
        with self.assertRaisesRegex(RuntimeError, 'fragment changed'):
            kernel.fragment(changed)
