import importlib.util
import json
import os
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('kernel_payload', REPO / 'scripts/infra-kernel-payload.py')
kernel = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(kernel)


class KernelPayload(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.compilation = tempfile.TemporaryDirectory()
        cls.module = Path(cls.compilation.name) / 'fixture.ko'
        # Actual tiny host ET_REL object with a modinfo fixture, not a Linux module build.
        subprocess.run(['/usr/bin/gcc', '-c', '-x', 'c', '-o', str(cls.module), '-'],
                       input=b'const char info[] __attribute__((section(".modinfo"))) = "vermagic=6.16.1 SMP ";\n',
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    @classmethod
    def tearDownClass(cls):
        cls.compilation.cleanup()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.stage = self.root / 'stage'
        self.boot = self.stage / 'boot'
        self.boot.mkdir(parents=True)
        self.mods = self.stage / kernel.MODROOT
        (self.mods / 'kernel/drivers').mkdir(parents=True)
        self.manifest = self.root / 'manifest.json'
        self.config = self.boot / 'config-6.16.1'
        self.config.write_text('# Linux/x86_64 6.16.1 Kernel Configuration\n' + kernel.config.fragment()
                               + '# CONFIG_MODULE_COMPRESS is not set\nCONFIG_LOCALVERSION=""\n')
        self.image = self.boot / 'vmlinuz-6.16.1-alpbahOS'
        raw = bytearray(8192)
        raw[:2] = b'MZ'
        struct.pack_into('<I', raw, 0x3c, 0x80)
        raw[0x80:0x84] = b'PE\0\0'
        struct.pack_into('<H', raw, 0x84, 0x8664)
        struct.pack_into('<H', raw, 0x98, 0x20b)
        raw[0x1f1] = 4
        struct.pack_into('<I', raw, 0x1f4, 352)
        raw[0x1fe:0x200] = b'\x55\xaa'
        raw[0x202:0x206] = b'HdrS'
        struct.pack_into('<H', raw, 0x206, 0x20f)
        struct.pack_into('<H', raw, 0x20e, 0x100)
        raw[0x211] = 1
        struct.pack_into('<H', raw, 0x236, 1)
        struct.pack_into('<II', raw, 0x248, 10, 5000)
        version = b'6.16.1 (fixture builder)\0'
        raw[0x300:0x300 + len(version)] = version
        self.image.write_bytes(raw)
        (self.boot / 'System.map-6.16.1').write_text(
            'ffffffff81000000 T _text\nffffffff81000100 T start_kernel\nffffffff82000000 D init_task\n')
        (self.mods / 'kernel/drivers/fixture.ko').write_bytes(self.module.read_bytes())
        (self.mods / 'modules.order').write_text('kernel/drivers/fixture.ko\n')
        (self.mods / 'modules.dep').write_text('kernel/drivers/fixture.ko:\n')
        for name in ('modules.builtin', 'modules.builtin.modinfo', 'modules.dep.bin',
                     'modules.alias', 'modules.alias.bin', 'modules.symbols', 'modules.symbols.bin'):
            (self.mods / name).write_bytes(b'fixture')
        self.capture()

    def capture(self):
        self.manifest.write_text(json.dumps({'schema': 'alpbahOS.package-files/v1',
            'package': {'name': 'linux-kernel', 'version': kernel.VERSION,
                        'source': {'url': kernel.SOURCE_URL, 'sha256': kernel.SOURCE_SHA}},
            'entries': kernel.capture.capture_tree(self.stage)}))

    def reject(self, pattern):
        self.capture()
        with self.assertRaisesRegex(RuntimeError, pattern):
            kernel.verify(self.stage, self.manifest)

    def test_actual_elf_fixture_candidate_has_explicit_limited_scope(self):
        proof = kernel.verify(self.stage, self.manifest)
        self.assertEqual(proof['result'], 'VERIFIED_CANDIDATE_BYTES')
        self.assertEqual(proof['module_count'], 1)
        self.assertEqual(proof['numeric_owner']['uid'], os.getuid())
        self.assertIn('no source/build provenance, Alp ownership', proof['scope'])

    def test_complete_manifest_rejects_added_removed_or_changed_payload(self):
        module = self.mods / 'kernel/drivers/fixture.ko'
        module.write_bytes(module.read_bytes() + b'drift')
        with self.assertRaisesRegex(RuntimeError, 'complete manifest'):
            kernel.verify(self.stage, self.manifest)
        self.capture()
        module.unlink()
        with self.assertRaisesRegex(RuntimeError, 'complete manifest'):
            kernel.verify(self.stage, self.manifest)

    def test_kernel_and_module_releases_must_match(self):
        raw = self.image.read_bytes()
        self.image.write_bytes(raw.replace(b'6.16.1 (', b'6.16.2 ('))
        self.reject('boot release')
        self.image.write_bytes(raw)
        module = self.mods / 'kernel/drivers/fixture.ko'
        module.write_bytes(module.read_bytes().replace(b'6.16.1 SMP', b'6.16.2 SMP'))
        self.reject('vermagic release')

    def test_bad_bzimage_payload_and_efi_headers_fail(self):
        original = self.image.read_bytes()
        for offset, fmt, value in ((0x236, '<H', 0), (0x24c, '<I', 999999),
                                   (0x84, '<H', 3), (0x98, '<H', 0x10b)):
            with self.subTest(offset=offset):
                raw = bytearray(original)
                struct.pack_into(fmt, raw, offset, value)
                self.image.write_bytes(raw)
                self.reject('x86_64|bounds')

    def test_modules_cannot_be_elf32_or_executables_or_truncated_sections(self):
        module = self.mods / 'kernel/drivers/fixture.ko'
        original = module.read_bytes()
        for offset, fmt, value in ((4, '<B', 1), (16, '<H', 2), (18, '<H', 3),
                                   (40, '<Q', len(original))):
            with self.subTest(offset=offset):
                raw = bytearray(original)
                struct.pack_into(fmt, raw, offset, value)
                module.write_bytes(raw)
                self.reject('ELF64|section table')

    def test_dependency_and_order_require_exact_coverage(self):
        cases = [('modules.order', 'kernel/drivers/fixture.ko\nkernel/drivers/fixture.ko\n', 'order'),
                 ('modules.order', '../fixture.ko\n', 'Unsafe'),
                 ('modules.dep', 'kernel/drivers/fixture.ko: /etc/passwd\n', 'Unsafe'),
                 ('modules.dep', 'kernel/drivers/fixture.ko: kernel/absent.ko\n', 'outside'),
                 ('modules.dep', 'kernel/absent.ko:\n', 'index')]
        for name, contents, pattern in cases:
            with self.subTest(name=name, contents=contents):
                path = self.mods / name
                old = path.read_bytes()
                path.write_text(contents)
                self.reject(pattern)
                path.write_bytes(old)

    def test_absolute_build_symlink_and_unrelated_files_are_rejected(self):
        link = self.mods / 'build'
        link.symlink_to('/srv/lfs/build/kernel')
        self.reject('Unexpected')
        link.unlink()
        unwanted = self.stage / 'etc'
        unwanted.mkdir()
        self.reject('Unexpected')

    def test_contained_doc_alias_is_allowed_but_escape_is_rejected(self):
        docs = self.stage / 'usr/share/doc/linux-6.16.1'
        (docs / 'process').mkdir(parents=True)
        (docs / 'process/changes.rst').write_text('fixture')
        link = docs / 'Changes'
        link.symlink_to('process/changes.rst')
        self.capture()
        self.assertEqual(kernel.verify(self.stage, self.manifest)['module_count'], 1)
        link.unlink()
        link.symlink_to('../../../../../../etc/passwd')
        self.reject('Unsafe')
        link.unlink()
        link.symlink_to('Loop')
        (docs / 'Loop').symlink_to('Changes')
        self.reject('cyclic')

    def test_wrong_config_and_source_pin_cannot_pass(self):
        self.config.write_text(self.config.read_text().replace('CONFIG_IA32_EMULATION=y', '# CONFIG_IA32_EMULATION is not set'))
        self.reject('IA32_EMULATION')
        value = json.loads(self.manifest.read_text())
        value['package']['source']['sha256'] = '0' * 64
        self.manifest.write_text(json.dumps(value))
        with self.assertRaisesRegex(RuntimeError, 'identity'):
            kernel.verify(self.stage, self.manifest)

    def test_writable_or_privileged_modes_and_special_files_are_rejected(self):
        module = self.mods / 'kernel/drivers/fixture.ko'
        for mode in (0o666, 0o4755):
            module.chmod(mode)
            self.reject('metadata')
        module.chmod(0o644)
        fifo = self.mods / 'kernel/drivers/fifo'
        os.mkfifo(fifo)
        self.reject('metadata')
