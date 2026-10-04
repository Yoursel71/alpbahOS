import ast
import re
from pathlib import Path
import tempfile
import unittest


RUNNER = Path(__file__).resolve().parents[1] / 'scripts/infra-base-guest-run.py'
TREE = ast.parse(RUNNER.read_text())
FUNCTION = next(node for node in TREE.body
                if isinstance(node, ast.FunctionDef)
                and node.name == 'use_staged_file_magic_compiler')
MODULE = ast.Module(body=[FUNCTION], type_ignores=[])
ast.fix_missing_locations(MODULE)
NAMESPACE = {'Path': Path, 're': re, 'os': __import__('os')}
exec(compile(MODULE, str(RUNNER), 'exec'), NAMESPACE)
use_staged_file_magic_compiler = NAMESPACE['use_staged_file_magic_compiler']


class StagedFileMagicCompilerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.build = self.root / 'build/base-file'
        (self.build / 'magic').mkdir(parents=True)
        self.stage = self.root / 'stage/base-file'
        self.compiler = self.stage / 'usr/bin/file'
        self.compiler.parent.mkdir(parents=True)
        self.compiler.write_text('#!/bin/sh\nexit 0\n')
        self.compiler.chmod(0o755)
        (self.stage / 'usr/lib').mkdir()
        self.command = ['/usr/sbin/runuser', '-u', 'lfs', '--', 'env',
                        'LC_ALL=C', 'CFLAGS=-O2', 'make', '-j8']

    def tearDown(self):
        self.temporary.cleanup()

    def rewrite(self):
        return use_staged_file_magic_compiler(
            self.command, self.build, build_dir=self.build, stage_root=self.stage)

    def test_cross_make_uses_matching_staged_native_file(self):
        (self.build / 'magic/Makefile').write_text('FILE_COMPILE = file\n')
        result = self.rewrite()
        self.assertIn('LD_LIBRARY_PATH=' + str(self.stage / 'usr/lib'), result)
        self.assertIn('FILE_COMPILE=' + str(self.compiler), result)
        self.assertEqual(result.count('FILE_COMPILE=' + str(self.compiler)), 1)

    def test_configured_executable_suffix_uses_staged_native_file(self):
        (self.build / 'magic/Makefile').write_text(
            'FILE_COMPILE = file${EXEEXT}\n')
        result = self.rewrite()
        self.assertIn('LD_LIBRARY_PATH=' + str(self.stage / 'usr/lib'), result)
        self.assertIn('FILE_COMPILE=' + str(self.compiler), result)

    def test_native_make_is_unchanged(self):
        (self.build / 'magic/Makefile').write_text(
            'FILE_COMPILE = $(top_builddir)/src/file\n')
        self.assertEqual(self.rewrite(), self.command)

    def test_non_file_build_is_unchanged(self):
        (self.build / 'magic/Makefile').write_text('FILE_COMPILE = file\n')
        self.assertEqual(use_staged_file_magic_compiler(
            self.command, self.root / 'build/other',
            build_dir=self.build, stage_root=self.stage), self.command)

    def test_missing_staged_compiler_fails_closed(self):
        (self.build / 'magic/Makefile').write_text('FILE_COMPILE = file\n')
        self.compiler.unlink()
        with self.assertRaisesRegex(RuntimeError, 'staged native file compiler'):
            self.rewrite()


if __name__ == '__main__':
    unittest.main()
