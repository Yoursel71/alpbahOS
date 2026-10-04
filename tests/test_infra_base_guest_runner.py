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
NCURSES_FUNCTION = next(node for node in TREE.body
                        if isinstance(node, ast.FunctionDef)
                        and node.name == 'readline_ncurses_environment')
NCURSES_DOC_FUNCTION = next(node for node in TREE.body
                            if isinstance(node, ast.FunctionDef)
                            and node.name == 'ncurses_doc_parent_setup')
MODULE = ast.Module(body=[FUNCTION, NCURSES_FUNCTION, NCURSES_DOC_FUNCTION], type_ignores=[])
ast.fix_missing_locations(MODULE)
NAMESPACE = {'Path': Path, 're': re, 'os': __import__('os')}
exec(compile(MODULE, str(RUNNER), 'exec'), NAMESPACE)
use_staged_file_magic_compiler = NAMESPACE['use_staged_file_magic_compiler']
readline_ncurses_environment = NAMESPACE['readline_ncurses_environment']
ncurses_doc_parent_setup = NAMESPACE['ncurses_doc_parent_setup']


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


class ReadlineNcursesLinkPathTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.build = self.root / 'build/base-readline'
        self.build.mkdir(parents=True)
        self.stage = self.root / 'stage/base-ncurses'
        for suffix in ('usr/lib', 'usr/lib32'):
            (self.stage / suffix).mkdir(parents=True)

    def tearDown(self):
        self.temporary.cleanup()

    def test_readline_link_gets_both_staged_abis_and_preserves_existing_path(self):
        env = {'PATH': '/tools/bin', 'LIBRARY_PATH': '/existing/lib'}
        updated = readline_ncurses_environment(
            ['make', '-j8', 'SHLIB_LIBS=-lncursesw'], self.build, env,
            build_dir=self.build, stage_root=self.stage)
        self.assertEqual(updated['LIBRARY_PATH'],
                         f'{self.stage}/usr/lib:{self.stage}/usr/lib32:/existing/lib')
        self.assertEqual(env['LIBRARY_PATH'], '/existing/lib')

    def test_unrelated_command_and_directory_are_unchanged(self):
        env = {'PATH': '/tools/bin'}
        self.assertIs(readline_ncurses_environment(
            ['make', '-j8'], self.build, env,
            build_dir=self.build, stage_root=self.stage), env)
        self.assertIs(readline_ncurses_environment(
            ['make', '-j8', 'SHLIB_LIBS=-lncursesw'], self.root / 'build/other', env,
            build_dir=self.build, stage_root=self.stage), env)

    def test_missing_abi_library_directory_fails_closed(self):
        (self.stage / 'usr/lib32').rmdir()
        with self.assertRaisesRegex(RuntimeError, 'staged Ncurses library directory'):
            readline_ncurses_environment(
                ['make', 'SHLIB_LIBS=-lncursesw'], self.build, {},
                build_dir=self.build, stage_root=self.stage)


class NcursesDocumentationStageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.stage = self.root / 'stage/base-ncurses'
        self.stage.mkdir(parents=True)
        self.build = self.root / 'build/base-ncurses'
        (self.build / 'doc').mkdir(parents=True)
        self.command = ['runuser', '-u', 'lfs', '--', 'env', 'CFLAGS=-O2',
                        'cp', '-a', str(self.build / 'doc'),
                        str(self.stage / 'usr/share/doc/ncurses-6.5-20250809')]

    def tearDown(self):
        self.temporary.cleanup()

    def test_missing_doc_parent_is_created_with_build_owner(self):
        setup = ncurses_doc_parent_setup(
            self.command, stage_root=self.stage, build_root=self.build)
        parent = self.stage / 'usr/share/doc'
        self.assertEqual(setup, [['mkdir', '-p', str(parent)],
                                 ['chown', f'{self.build.stat().st_uid}:{self.build.stat().st_gid}',
                                  str(parent)]])

    def test_existing_doc_parent_must_be_real_and_owned_by_builder(self):
        parent = self.stage / 'usr/share/doc'
        parent.mkdir(parents=True)
        self.assertEqual(ncurses_doc_parent_setup(
            self.command, stage_root=self.stage, build_root=self.build), [])
        parent.rmdir()
        parent.symlink_to(self.root)
        with self.assertRaisesRegex(RuntimeError, 'unexpected owner or type'):
            ncurses_doc_parent_setup(self.command, stage_root=self.stage, build_root=self.build)

    def test_only_the_pinned_ncurses_doc_copy_is_adjusted(self):
        self.assertEqual(ncurses_doc_parent_setup(
            ['cp', '-a', '/other/doc', '/other/stage/doc'],
            stage_root=self.stage, build_root=self.build), [])


if __name__ == '__main__':
    unittest.main()
