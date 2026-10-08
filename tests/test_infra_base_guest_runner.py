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
TCL_FUNCTION = next(node for node in TREE.body
                    if isinstance(node, ast.FunctionDef)
                    and node.name == 'tcl_stub_archive_chmod')
EXPECT_FUNCTION = next(node for node in TREE.body
                       if isinstance(node, ast.FunctionDef)
                       and node.name == 'expect_lfs_tcl_sysroot')
EXPECT_TCLSH_FUNCTION = next(node for node in TREE.body
                             if isinstance(node, ast.FunctionDef)
                             and node.name == 'expect_tclsh_command')
EXPECT_MAKE_FUNCTION = next(node for node in TREE.body
                            if isinstance(node, ast.FunctionDef)
                            and node.name == 'expect_make_tclsh')
BINUTILS_FUNCTION = next(node for node in TREE.body
                         if isinstance(node, ast.FunctionDef)
                         and node.name == 'binutils_lfs_zlib_environment')
GMP_FUNCTION = next(node for node in TREE.body
                    if isinstance(node, ast.FunctionDef)
                    and node.name == 'gmp_gcc15_configure_compatibility')
MATH_FUNCTION = next(node for node in TREE.body
                     if isinstance(node, ast.FunctionDef)
                     and node.name == 'native_math_dependency_environment')
GLIBC_PARALLEL_FUNCTION = next(node for node in TREE.body
                               if isinstance(node, ast.FunctionDef)
                               and node.name == 'parallel_glibc_tests')
MODULE = ast.Module(body=[FUNCTION, NCURSES_FUNCTION, TCL_FUNCTION, NCURSES_DOC_FUNCTION,
                          EXPECT_FUNCTION, EXPECT_TCLSH_FUNCTION, EXPECT_MAKE_FUNCTION,
                          BINUTILS_FUNCTION, GMP_FUNCTION, MATH_FUNCTION,
                          GLIBC_PARALLEL_FUNCTION],
                     type_ignores=[])
ast.fix_missing_locations(MODULE)
NAMESPACE = {'Path': Path, 're': re, 'os': __import__('os')}
exec(compile(MODULE, str(RUNNER), 'exec'), NAMESPACE)
use_staged_file_magic_compiler = NAMESPACE['use_staged_file_magic_compiler']
readline_ncurses_environment = NAMESPACE['readline_ncurses_environment']
ncurses_doc_parent_setup = NAMESPACE['ncurses_doc_parent_setup']
tcl_stub_archive_chmod = NAMESPACE['tcl_stub_archive_chmod']
expect_lfs_tcl_sysroot = NAMESPACE['expect_lfs_tcl_sysroot']
expect_tclsh_command = NAMESPACE['expect_tclsh_command']
expect_make_tclsh = NAMESPACE['expect_make_tclsh']
binutils_lfs_zlib_environment = NAMESPACE['binutils_lfs_zlib_environment']
gmp_gcc15_configure_compatibility = NAMESPACE['gmp_gcc15_configure_compatibility']
native_math_dependency_environment = NAMESPACE['native_math_dependency_environment']
parallel_glibc_tests = NAMESPACE['parallel_glibc_tests']


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

    def test_readline_link_gets_direct_staged_search_paths(self):
        env = {'PATH': '/tools/bin', 'LIBRARY_PATH': '/existing/lib'}
        command = ['make', '-j8', 'SHLIB_LIBS=-lncursesw']
        updated = readline_ncurses_environment(
            command, self.build, env,
            build_dir=self.build, stage_root=self.stage)
        expected = (f'SHLIB_LIBS=-L{self.stage}/usr/lib32 '
                    f'-L{self.stage}/usr/lib -lncursesw')
        self.assertIs(updated, env)
        self.assertEqual(command[-1], expected)
        self.assertEqual(env['LIBRARY_PATH'], '/existing/lib')

    def test_readline_updates_each_matching_link_variable(self):
        command = ['make', 'SHLIB_LIBS=-lncursesw', 'SHLIB_LIBS=-lncursesw']
        readline_ncurses_environment(
            command, self.build, {}, build_dir=self.build, stage_root=self.stage)
        self.assertTrue(all(arg.startswith('SHLIB_LIBS=-L') for arg in command[1:]))

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


class TclStubArchiveChmodTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.build = self.root / 'build/base-tcl/unix'
        self.build.mkdir(parents=True)
        self.stage = self.root / 'stage/base-tcl'
        library = self.stage / 'usr/lib'
        library.mkdir(parents=True)
        self.stub_archive = library / 'libtclstub8.6.a'
        self.stub_archive.write_bytes(b'archive')
        self.command = ['runuser', '-u', 'lfs', '--', 'env', 'chmod', '644',
                        str(library / 'libtcl8.6.a')]

    def tearDown(self):
        self.temporary.cleanup()

    def test_only_tcl_build_chmod_is_mapped_to_existing_stub_archive(self):
        result = tcl_stub_archive_chmod(
            self.command, self.build, build_dir=self.build, stage_root=self.stage)
        self.assertEqual(result[-1], str(self.stub_archive))
        self.assertEqual(self.command[-1], str(self.stage / 'usr/lib/libtcl8.6.a'))

    def test_unrelated_command_and_build_directory_are_unchanged(self):
        self.assertEqual(tcl_stub_archive_chmod(
            ['chmod', '644', '/tmp/other.a'], self.build,
            build_dir=self.build, stage_root=self.stage), ['chmod', '644', '/tmp/other.a'])
        self.assertEqual(tcl_stub_archive_chmod(
            self.command, self.root / 'build/other',
            build_dir=self.build, stage_root=self.stage), self.command)

    def test_missing_stub_archive_fails_closed(self):
        self.stub_archive.unlink()
        with self.assertRaisesRegex(RuntimeError, 'Tcl stub archive staging layout'):
            tcl_stub_archive_chmod(
                self.command, self.build, build_dir=self.build, stage_root=self.stage)


class ExpectTclSysrootTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.build = self.root / 'build/base-expect'
        self.build.mkdir(parents=True)
        self.libdir = self.root / 'usr/lib'
        self.includedir = self.root / 'usr/include'
        self.libdir.mkdir(parents=True)
        self.includedir.mkdir(parents=True)
        (self.root / 'usr/bin').mkdir(parents=True)
        (self.root / 'usr/lib').mkdir(parents=True, exist_ok=True)
        (self.root / 'usr/lib/tcl8.6').mkdir(parents=True)
        (self.libdir / 'tclConfig.sh').write_text("TCL_LIB_SPEC='-L/usr/lib -ltcl8.6'\n")
        (self.libdir / 'libtcl8.6.so').write_bytes(b'tcl shared library')
        (self.libdir / 'libtclstub8.6.a').write_bytes(b'tcl stub archive')
        (self.includedir / 'tcl.h').write_text('/* Tcl public header */\n')
        (self.root / 'usr/lib/ld-linux-x86-64.so.2').write_text('loader')
        (self.root / 'usr/lib/ld-linux-x86-64.so.2').chmod(0o755)
        (self.root / 'usr/bin/tclsh8.6').write_text('tclsh')
        (self.root / 'usr/bin/tclsh8.6').chmod(0o755)
        (self.root / 'usr/lib/tcl8.6/init.tcl').write_text('# Tcl library')
        self.command = ['runuser', '-u', 'lfs', '--', 'env', 'LC_ALL=C',
                        './configure', '--prefix=/usr', '--with-tcl=/usr/lib',
                        '--with-tclinclude=/usr/include']

    def tearDown(self):
        self.temporary.cleanup()

    def rewrite(self, command=None, env=None, cwd=None):
        return expect_lfs_tcl_sysroot(
            self.command if command is None else command,
            self.build if cwd is None else cwd,
            {'PATH': '/srv/lfs/tools/bin', **(env or {})},
            lfs_root=self.root, build_dir=self.build)

    def test_expect_configure_probes_tcl_inside_the_target_root(self):
        result, env, applied = self.rewrite()
        self.assertTrue(applied)
        self.assertIn('--with-tcl=' + str(self.libdir), result)
        self.assertIn('--with-tclinclude=' + str(self.includedir), result)
        self.assertIn('CC=gcc --sysroot=' + str(self.root), result)
        self.assertEqual(env['LDFLAGS'], '-L' + str(self.libdir))
        self.assertNotIn('LD_LIBRARY_PATH', env)
        self.assertEqual(self.command[-2:], ['--with-tcl=/usr/lib',
                                             '--with-tclinclude=/usr/include'])

    def test_expect_configure_removes_inherited_library_path_from_builder(self):
        result, env, applied = self.rewrite(env={
            'LD_LIBRARY_PATH': '/existing/lib', 'LDFLAGS': '-Wl,--as-needed'})
        self.assertTrue(applied)
        self.assertEqual(result, ['runuser', '-u', 'lfs', '--', 'env',
                                  'CC=gcc --sysroot=' + str(self.root), 'LC_ALL=C',
                                  './configure', '--prefix=/usr', '--with-tcl=' + str(self.libdir),
                                  '--with-tclinclude=' + str(self.includedir)])
        self.assertEqual(env['LDFLAGS'], '-L' + str(self.libdir))
        self.assertNotIn('LD_LIBRARY_PATH', env)

    def test_expect_configure_replaces_an_inherited_compiler_assignment(self):
        command = self.command.copy()
        command.insert(command.index('./configure'), 'CC=gcc')
        result, _, applied = self.rewrite(command=command)
        self.assertTrue(applied)
        self.assertEqual(result.count('CC=gcc --sysroot=' + str(self.root)), 1)
        self.assertNotIn('CC=gcc', result)

    def test_expect_configure_requires_the_target_stub_archive(self):
        (self.libdir / 'libtclstub8.6.a').unlink()
        with self.assertRaisesRegex(RuntimeError, 'stub archive are missing'):
            self.rewrite()

    def test_expect_patch_does_not_leak_target_library_path_into_runuser(self):
        patch = ['runuser', '-u', 'lfs', '--', 'patch', '-Np1', '-i', 'expect.patch']
        result, env, applied = self.rewrite(command=patch)
        self.assertFalse(applied)
        self.assertEqual(result, patch)
        self.assertNotIn('LD_LIBRARY_PATH', env)

    def test_expect_make_uses_loader_command_without_poisoning_builder_tools(self):
        command = ['runuser', '-u', 'lfs', '--', 'env', 'LC_ALL=C', 'make', '-j4']
        result, env, applied = self.rewrite(command=command)
        tclsh_command = ('TCL_LIBRARY=' + str(self.libdir / 'tcl8.6') + ' '
                         + str(self.libdir / 'ld-linux-x86-64.so.2')
                         + ' --library-path ' + str(self.libdir) + ' '
                         + str(self.root / 'usr/bin/tclsh8.6') + ' '
                         + str(self.build / '.alp-tclsh-bootstrap.tcl'))
        result = expect_make_tclsh(result, self.build, tclsh_command, build_dir=self.build)
        self.assertFalse(applied)
        self.assertEqual(result[7], 'TCLSH_PROG=' + tclsh_command)
        self.assertEqual(result[8:], command[7:])
        self.assertNotIn('LD_LIBRARY_PATH', env)

    def test_target_tclsh_bootstrap_clears_ld_library_path_for_child_processes(self):
        self.build.mkdir(parents=True, exist_ok=True)
        command = expect_tclsh_command(self.build, self.root)
        bootstrap = self.build / '.alp-tclsh-bootstrap.tcl'
        self.assertEqual(bootstrap.stat().st_mode & 0o777, 0o644)
        self.assertEqual(bootstrap.read_text(),
                         'set test_script [lindex $argv 0]\n'
                         'if {$test_script eq ""} { error "missing test script" }\n'
                         'set argv [lrange $argv 1 end]\n'
                         'set argc [llength $argv]\n'
                         'set argv0 $test_script\n'
                         'unset -nocomplain env(LD_LIBRARY_PATH)\n'
                         f'set env(TCL_LIBRARY) {{{self.libdir / "tcl8.6"}}}\n'
                         'source $test_script\n')
        self.assertTrue(command.startswith('TCL_LIBRARY=' + str(self.libdir / 'tcl8.6') + ' '))
        self.assertIn(' --library-path ' + str(self.libdir) + ' ', command)
        self.assertTrue(command.endswith(str(bootstrap)))

    def test_other_workdirs_are_unchanged(self):
        result, env, applied = self.rewrite(cwd=self.root / 'build/other')
        self.assertFalse(applied)
        self.assertEqual(result, self.command)
        self.assertEqual(env['PATH'], '/srv/lfs/tools/bin')
        self.assertNotIn('LD_LIBRARY_PATH', env)

    def test_missing_tcl_config_fails_closed(self):
        (self.libdir / 'tclConfig.sh').unlink()
        with self.assertRaisesRegex(RuntimeError, 'Tcl config, headers, shared library or stub archive'):
            self.rewrite()

    def test_unexpected_configure_arguments_fail_closed(self):
        command = list(self.command)
        command[-1] = '--with-tclinclude=/wrong/include'
        with self.assertRaisesRegex(RuntimeError, 'arguments differ from the pinned Tcl recipe'):
            self.rewrite(command)


class BinutilsLfsZlibEnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.build = self.root / 'build/base-binutils/build'
        self.build.mkdir(parents=True)
        self.lfs = self.root / 'lfs'
        include = self.lfs / 'usr/include'
        include.mkdir(parents=True)
        (include / 'zlib.h').write_text('/* staged LFS zlib header */\n')
        library_dir = self.lfs / 'stage/base-zlib/usr/lib'
        library_dir.mkdir(parents=True)
        (library_dir / 'libz.so.1.3.1').write_bytes(b'ELF test stub')
        (library_dir / 'libz.so').symlink_to('libz.so.1.3.1')
        self.command = ['/usr/sbin/runuser', '-u', 'lfs', '--', 'env',
                        'LC_ALL=C', 'CFLAGS=-O2', 'make', '-j4']

    def tearDown(self):
        self.temporary.cleanup()

    def test_only_binutils_gets_staged_lfs_headers_as_fallback(self):
        result = binutils_lfs_zlib_environment(
            self.command, self.build, build_dir=self.build, lfs_root=self.lfs)
        self.assertEqual(result[5], 'CC=gcc -idirafter ' + str(self.lfs / 'usr/include'))
        self.assertEqual(result[6], 'CXX=g++ -idirafter ' + str(self.lfs / 'usr/include'))
        self.assertEqual(result[7], 'LDFLAGS=-L' + str(self.lfs / 'stage/base-zlib/usr/lib'))
        self.assertNotIn('CC=gcc -I' + str(self.lfs / 'usr/include'), result)
        self.assertEqual(result[8:], self.command[5:])
        unchanged = binutils_lfs_zlib_environment(
            self.command, self.root / 'build/other', build_dir=self.build, lfs_root=self.lfs)
        self.assertEqual(unchanged, self.command)

    def test_binutils_test_gets_native_debug_paths_and_staged_zlib(self):
        original = ("env -u SOURCE_DATE_EPOCH make CFLAGS='-O2 -g0' "
                    "CXXFLAGS='-O2 -g0' -j1 -k check")
        script = ('set +e\n' + original + '\nmake_exit=$?\nset -e\n'
                  'python3 /opt/alp-infra/scripts/infra/test-policy.py binutils')
        command = self.command[:5] + ['bash', '-euc', script]
        result = binutils_lfs_zlib_environment(
            command, self.build, build_dir=self.build, lfs_root=self.lfs)
        adapted = result[-1]
        self.assertNotIn(original, adapted)
        self.assertIn("LIBRARY_PATH=" + str(self.lfs / 'stage/base-zlib/usr/lib'), adapted)
        self.assertIn("LD_LIBRARY_PATH=" + str(self.lfs / 'stage/base-zlib/usr/lib'), adapted)
        self.assertIn("CFLAGS_FOR_TARGET='-g -O2 -g0'", adapted)
        self.assertIn("CXXFLAGS_FOR_TARGET='-g -O2 -g0 -D_GNU_SOURCE'", adapted)

    def test_binutils_test_adapter_fails_closed_on_recipe_drift(self):
        command = self.command[:5] + [
            'bash', '-euc', 'make check\npython3 test-policy.py binutils']
        with self.assertRaisesRegex(RuntimeError, 'differs from the pinned recipe'):
            binutils_lfs_zlib_environment(
                command, self.build, build_dir=self.build, lfs_root=self.lfs)

    def test_missing_zlib_header_fails_closed(self):
        (self.lfs / 'usr/include/zlib.h').unlink()
        with self.assertRaisesRegex(RuntimeError, 'zlib headers or shared library are missing'):
            binutils_lfs_zlib_environment(
                self.command, self.build, build_dir=self.build, lfs_root=self.lfs)

    def test_missing_zlib_shared_library_fails_closed(self):
        (self.lfs / 'stage/base-zlib/usr/lib/libz.so').unlink()
        with self.assertRaisesRegex(RuntimeError, 'zlib headers or shared library are missing'):
            binutils_lfs_zlib_environment(
                self.command, self.build, build_dir=self.build, lfs_root=self.lfs)

    def test_linker_search_directory_cannot_shadow_builder_libc(self):
        builder_shadow = self.lfs / 'stage/base-zlib/usr/lib/libc.so'
        builder_shadow.write_text('GROUP (/usr/lib/libc.so.6)\n')
        with self.assertRaisesRegex(RuntimeError, 'Builder-shadowing system libraries'):
            binutils_lfs_zlib_environment(
                self.command, self.build, build_dir=self.build, lfs_root=self.lfs)

    def test_unexpected_runner_or_existing_compiler_fails_closed(self):
        with self.assertRaisesRegex(RuntimeError, 'unexpected runner command'):
            binutils_lfs_zlib_environment(['env', 'make'], self.build,
                                           build_dir=self.build, lfs_root=self.lfs)
        command = self.command.copy(); command.insert(5, 'CC=gcc')
        with self.assertRaisesRegex(RuntimeError, 'compiler or linker flags already have an explicit override'):
            binutils_lfs_zlib_environment(command, self.build,
                                           build_dir=self.build, lfs_root=self.lfs)
        command = self.command.copy(); command.insert(5, 'LDFLAGS=-L/usr/lib')
        with self.assertRaisesRegex(RuntimeError, 'compiler or linker flags already have an explicit override'):
            binutils_lfs_zlib_environment(command, self.build,
                                           build_dir=self.build, lfs_root=self.lfs)
        command = self.command.copy(); command.insert(5, 'CXX=g++')
        with self.assertRaisesRegex(RuntimeError, 'compiler or linker flags already have an explicit override'):
            binutils_lfs_zlib_environment(command, self.build,
                                           build_dir=self.build, lfs_root=self.lfs)


class GmpGcc15ConfigureCompatibilityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.build = self.root / 'build/base-gmp'
        self.build.mkdir(parents=True)
        self.command = ['/usr/sbin/runuser', '-u', 'lfs', '--', 'sed', '-i',
                        '/long long t1;/,+1s/()/(...)/', 'configure']

    def tearDown(self):
        self.temporary.cleanup()

    def test_gcc12_skips_gcc15_only_prototype_edit(self):
        result, message = gmp_gcc15_configure_compatibility(
            self.command, self.build, '12.2.0', build_dir=self.build)
        self.assertEqual(result, ['/usr/bin/true'])
        self.assertEqual(message,
                         'BUILD_ADAPTER gmp-gcc15-sed=skipped guest-gcc=12.2.0')

    def test_gcc15_keeps_pinned_configure_edit(self):
        result, message = gmp_gcc15_configure_compatibility(
            self.command, self.build, '15.1.0', build_dir=self.build)
        self.assertEqual(result, self.command)
        self.assertEqual(message,
                         'BUILD_ADAPTER gmp-gcc15-sed=kept guest-gcc=15.1.0')

    def test_other_package_commands_are_unchanged(self):
        result, message = gmp_gcc15_configure_compatibility(
            ['make', '-j4'], self.build, '12.2.0', build_dir=self.build)
        self.assertEqual(result, ['make', '-j4'])
        self.assertIsNone(message)

    def test_other_build_directories_are_unchanged(self):
        result, message = gmp_gcc15_configure_compatibility(
            self.command, self.root / 'build/other', '12.2.0', build_dir=self.build)
        self.assertEqual(result, self.command)
        self.assertIsNone(message)

    def test_unparseable_compiler_version_fails_closed(self):
        with self.assertRaisesRegex(RuntimeError, 'could not parse the guest GCC version'):
            gmp_gcc15_configure_compatibility(
                self.command, self.build, 'GNU GCC', build_dir=self.build)


class NativeMathDependencyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        for name, header, library in (('gmp', 'gmp.h', 'libgmp'),
                                      ('mpfr', 'mpfr.h', 'libmpfr'),
                                      ('mpc', 'mpc.h', 'libmpc'),
                                      ('zlib', 'zlib.h', 'libz')):
            prefix = self.root / ('stage/base-' + name) / 'usr'
            (prefix / 'include').mkdir(parents=True)
            (prefix / 'lib').mkdir()
            (prefix / 'include' / header).write_text('/* dependency header */\n')
            (prefix / 'lib' / (library + '.so.1')).write_bytes(b'ELF fixture')
            (prefix / 'lib' / (library + '.so')).symlink_to(library + '.so.1')
        self.command = ['/usr/sbin/runuser', '-u', 'lfs', '--', 'env',
                        'LC_ALL=C', 'CFLAGS=-O2', './configure', '--prefix=/usr']

    def tearDown(self):
        self.temporary.cleanup()

    def rewrite(self, package='mpfr', command=None):
        path = self.root / ('build/base-' + package)
        if package == 'gcc':
            path /= 'build'
        return native_math_dependency_environment(
            self.command if command is None else command, path, lfs_root=self.root)

    def test_mpfr_configure_and_tests_find_only_staged_gmp(self):
        stage = self.root / 'stage/base-gmp/usr'
        for tail in (['./configure', '--prefix=/usr'], ['make', 'check']):
            result = self.rewrite(command=self.command[:7] + tail)
            self.assertIn('CPPFLAGS=-I' + str(stage / 'include'), result)
            self.assertIn('LDFLAGS=-L' + str(stage / 'lib'), result)
            self.assertIn('LD_LIBRARY_PATH=' + str(stage / 'lib'), result)
            self.assertEqual(result[-len(tail):], tail)
            self.assertNotIn('-I' + str(self.root / 'usr/include'), ' '.join(result))

    def test_mpc_and_gcc_find_all_required_staged_libraries(self):
        for package, names in (('mpc', ('gmp', 'mpfr')),
                               ('gcc', ('gmp', 'mpfr', 'mpc', 'zlib'))):
            result = self.rewrite(package)
            self.assertIn('LD_LIBRARY_PATH=' + ':'.join(
                str(self.root / ('stage/base-' + name) / 'usr/lib')
                for name in names), result)
        command = list(self.command); command[2] = 'tester'
        self.assertEqual(self.rewrite('gcc', command)[2], 'tester')

    def test_other_package_and_pre_action_are_unchanged(self):
        self.assertEqual(self.rewrite('gmp'), self.command)
        pre = self.command[:4] + ['sed', '-i', 'pattern', 'configure']
        self.assertEqual(self.rewrite(command=pre), pre)

    def test_explicit_override_and_unknown_runner_are_rejected(self):
        for value in ('CPPFLAGS=-I/other', 'LDFLAGS=-L/other',
                      'LD_LIBRARY_PATH=/other', 'LIBRARY_PATH=/other'):
            with self.assertRaisesRegex(RuntimeError, 'explicit override'):
                self.rewrite(command=self.command[:5] + [value] + self.command[5:])
        command = list(self.command); command[2] = 'other'
        with self.assertRaisesRegex(RuntimeError, 'unexpected runner'):
            self.rewrite(command=command)

    def test_missing_header_and_escaped_library_are_rejected(self):
        stage = self.root / 'stage/base-gmp/usr'
        (stage / 'include/gmp.h').unlink()
        with self.assertRaisesRegex(RuntimeError, 'header missing'):
            self.rewrite()
        (stage / 'include/gmp.h').write_text('restored')
        outside = self.root / 'outside.so'; outside.write_bytes(b'ELF')
        (stage / 'lib/libgmp.so').unlink()
        (stage / 'lib/libgmp.so').symlink_to(outside)
        with self.assertRaisesRegex(RuntimeError, 'escapes its stage'):
            self.rewrite()

    def test_shadowing_system_files_and_aliased_directory_are_rejected(self):
        stage = self.root / 'stage/base-gmp/usr'
        for relative in ('lib/libc.so', 'include/stdlib.h'):
            path = stage / relative; path.write_text('shadow')
            with self.assertRaisesRegex(RuntimeError, 'Builder-shadowing'):
                self.rewrite()
            path.unlink()
        real = stage / 'real-include'
        (stage / 'include').rename(real)
        (stage / 'include').symlink_to(real, target_is_directory=True)
        with self.assertRaisesRegex(RuntimeError, 'directory missing or aliased'):
            self.rewrite()


class ParallelGlibcTests(unittest.TestCase):
    def test_all_tests_and_policy_remain_in_the_four_job_command(self):
        script = ('set +e; make -k check with-lld=; make_exit=$?; set -e; '
                  'python3 /opt/alp-infra/scripts/infra/test-policy.py glibc '
                  '--build . --make-exit "$make_exit" --output glibc-test-policy.json')
        command = ['bash', '-euc', script]
        result = parallel_glibc_tests(command, '/srv/lfs/build/base-glibc/build')
        self.assertEqual(result[:2], command[:2])
        self.assertEqual(result[2], script.replace('make -k check', 'make -j4 -k check'))
        self.assertEqual(parallel_glibc_tests(command, '/other'), command)
        with self.assertRaisesRegex(RuntimeError, 'differs from the pinned recipe'):
            parallel_glibc_tests(['bash', '-euc', script.replace('make -k', 'make -j1 -k')],
                                 '/srv/lfs/build/base-glibc/build')


if __name__ == '__main__':
    unittest.main()
