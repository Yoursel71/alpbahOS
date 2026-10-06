import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import base_plan
import guest_base
from package_stage import recipe_working_directory, test_identity_guard, validate_recipe

REPO = Path(__file__).resolve().parents[1]


class BaseInventoryTests(unittest.TestCase):
    def fixture(self, root):
        (root / 'manifests').mkdir()
        shutil.copyfile(REPO / 'manifests/infra-sources.json', root / 'manifests/infra-sources.json')
        shutil.copyfile(REPO / 'manifests/lfs-base-12.4-systemd.json', root / 'manifests/lfs-base-12.4-systemd.json')
        shutil.copytree(REPO / 'recipes/base', root / 'recipes/base')
        return root / 'manifests/lfs-base-12.4-systemd.json'

    def test_exact_79_ordered_packages_resolve_to_pinned_archives(self):
        plan = base_plan.load(REPO)
        self.assertEqual(len(plan), 79)
        self.assertEqual([row['order'] for row in plan], list(range(1, 80)))
        self.assertEqual(len({row['name'] for row in plan}), 79)
        self.assertEqual(len({row['source_id'] for row in plan}), 79)
        self.assertTrue(all(row['source']['sha256'] and row['source']['size'] > 0 for row in plan))
        substitutions = {'stage': '/tmp/stage', 'source': '/tmp/source', 'lfs': '/tmp/lfs',
                         'jobs': 4, 'build_triplet': 'x86_64-pc-linux-gnu'}
        for row in plan:
            recipe = row.get('recipe_data')
            if not recipe:
                continue
            for step in ('pre', 'compile', 'test', 'stage', 'post_stage'):
                for command in recipe.get(step, []):
                    for argument in command:
                        argument.format(**substitutions)
        self.assertEqual(sum(row['recipe'] != 'pending' for row in plan), 79)
        substitutions = {'stage': '/srv/lfs/stage/dry', 'source': '/srv/lfs/build/dry',
                         'lfs': '/srv/lfs', 'jobs': 4, 'build_triplet': 'x86_64-unknown-linux-gnu'}
        for row in plan:
            recipe = row.get('recipe_data')
            if recipe is None:
                continue
            for field in ('pre', 'compile', 'test', 'stage', 'post_stage'):
                for command in recipe.get(field, []):
                    for argument in command:
                        argument.format(**substitutions)
        self.assertEqual(plan[0]['recipe_data']['stage'], [['make', '-R', 'GIT=false', 'prefix=/usr', 'DESTDIR={stage}', 'install']])
        self.assertEqual(plan[1]['recipe_data']['stage'][0][1:], ['-Dm644', '{source}/services', '{stage}/etc/services'])
        self.assertEqual(plan[3]['recipe_data']['stage'][3][0:2], ['env', 'CFLAGS=-m32 -O2 -g0 -ffile-prefix-map={source}=/usr/src/zlib -fdebug-prefix-map={source}=/usr/src/zlib'])
        self.assertEqual(plan[3]['recipe_data']['requires'], ['man-pages', 'iana-etc', 'glibc'])
        openssl = next(row['recipe_data'] for row in plan if row['name'] == 'openssl')
        self.assertIn('linux-x86', openssl['post_stage'][3])
        self.assertIn('--libdir=lib32', openssl['post_stage'][3])
        self.assertEqual(openssl['post_stage'][5], ['make', '-j1', 'DESTDIR={stage}/.m32', 'install'])
        libffi = next(row['recipe_data'] for row in plan if row['name'] == 'libffi')
        self.assertIn('--without-gcc-arch', libffi['compile'][0])
        self.assertIn(['make', '-j{jobs}', 'check'], libffi['test'])
        self.assertTrue(any(command[:2] == ['env', 'CC=gcc -m32']
                            and '--libdir=/usr/lib32' in command for command in libffi['post_stage']))
        self.assertIn(['make', '-j{jobs}', 'check'], libffi['post_stage'])
        self.assertTrue(any(command[:2] == ['cp', '-a']
                            and command[-2:] == ['{stage}/.m32/usr/lib32/.', '{stage}/usr/lib32/']
                            for command in libffi['post_stage']))
        self.assertFalse(any('-mx32' in word or '--with-gcc-arch=native' in word
                             for step in ('compile', 'test', 'stage', 'post_stage')
                             for command in libffi.get(step, []) for word in command))
        groff = next(row['recipe_data'] for row in plan if row['name'] == 'groff')
        self.assertEqual(groff['compile'][0], ['env', 'PAGE=A4', './configure', '--prefix=/usr'])
        self.assertEqual(groff['test'], [['make', '-j{jobs}', 'check']])
        self.assertIn(['make', '-j1', 'DESTDIR={stage}', 'install'], groff['stage'])
        self.assertEqual(groff['requires'], ['glibc', 'perl', 'zlib'])
        iproute2 = next(row['recipe_data'] for row in plan if row['name'] == 'iproute2')
        self.assertEqual(iproute2['pre'], [['sed', '-i', '/ARPD/d', 'Makefile'],
                                           ['rm', '-fv', 'man/man8/arpd.8']])
        self.assertIn(['make', '-j{jobs}', 'NETNS_RUN_DIR=/run/netns'], iproute2['compile'])
        self.assertIn(['make', '-j1', 'SBINDIR=/usr/sbin', 'DESTDIR={stage}', 'install'], iproute2['stage'])
        self.assertEqual(iproute2['test'], [])
        gettext = next(row['recipe_data'] for row in plan if row['name'] == 'gettext')
        self.assertEqual(gettext['test'], [['make', '-j{jobs}', 'check']])
        dbus = next(row['recipe_data'] for row in plan if row['name'] == 'dbus')
        self.assertTrue(any('--libdir=/usr/lib32' in word for command in dbus['post_stage'] for word in command))
        self.assertFalse(any('-mx32' in word for command in dbus['post_stage'] for word in command))
        library_copy = next(command for command in dbus['post_stage'] if command and command[0] == 'find')
        self.assertIn('-type', library_copy)
        self.assertIn('l', library_copy)
        libelf = next(row['recipe_data'] for row in plan if row['name'] == 'libelf')
        self.assertIn(['make', '-j{jobs}', 'check'], libelf['post_stage'])
        self.assertTrue(any('--host=i686-pc-linux-gnu' in command for command in libelf['post_stage']))
        grub = next(row['recipe_data'] for row in plan if row['name'] == 'grub')
        self.assertEqual(grub['test'], [])
        e2fsprogs = next(row['recipe_data'] for row in plan if row['name'] == 'e2fsprogs')
        self.assertEqual(e2fsprogs['working_directories']['compile'], 'build')
        self.assertEqual(e2fsprogs['working_directories']['post_stage'], 'build')
        self.assertIn('../lib/et/com_err.texinfo', next(command for command in e2fsprogs['post_stage'] if command and command[0] == 'makeinfo'))
        shadow = next(row['recipe_data'] for row in plan if row['name'] == 'shadow')
        path_edit = next(command for command in shadow['pre'] if command[0] == 'sed' and '-e' in command
                         and any('/PATH=' in argument for argument in command))
        rendered_path_edit = [arg.format(stage='/tmp/stage', source='/tmp/source', lfs='/tmp/lfs', jobs=4)
                              for arg in path_edit]
        self.assertIn('/PATH=/{s@/sbin:@@;s@/bin:@@}', rendered_path_edit)
        self.assertIn('deferred to full LFS-root integration', shadow['validation'])
        perl = next(row['recipe_data'] for row in plan if row['name'] == 'perl')
        self.assertIn('BUILD_ZLIB=False', perl['compile'][0])
        self.assertIn(['env', 'TEST_JOBS={jobs}', 'make', 'test_harness'], perl['test'])
        python = next(row['recipe_data'] for row in plan if row['name'] == 'python')
        self.assertEqual(python['prerequisites'], [{'directory': 'python-docs', 'source': 'python-3.13.7-docs-html.tar.bz2'}])
        self.assertEqual(python['post_stage'][-1][-2:], ['{source}/python-docs/.', '{stage}/usr/share/doc/python-3.13.7/html/'])
        ncurses = next(row['recipe_data'] for row in plan if row['name'] == 'ncurses')
        self.assertIn(['env', 'CC=gcc -m32', 'CXX=g++ -m32', './configure', '--prefix=/usr',
                       '--host=i686-pc-linux-gnu', '--libdir=/usr/lib32', '--mandir=/usr/share/man',
                       '--with-shared', '--without-debug', '--without-normal', '--with-cxx-shared',
                       '--enable-pc-files', '--with-pkg-config-libdir=/usr/lib32/pkgconfig'], ncurses['stage'])
        self.assertIn(['install', '-m644', 'infra-libncurses-form-linker-script',
                       '{stage}/usr/lib32/libform.so'], ncurses['stage'])
        self.assertFalse(any('-mx32' in word for step in ('compile', 'stage', 'post_stage')
                             for command in ncurses.get(step, []) for word in command))
        self.assertIn('no test pass is claimed', ncurses['validation'])
        systemd = next(row['recipe_data'] for row in plan if row['name'] == 'systemd')
        self.assertEqual(systemd['prerequisites'], [{'directory': 'systemd-man-pages', 'source': 'systemd-man-pages-257.8.tar.xz'}])
        self.assertIn(['env', 'PKG_CONFIG_PATH=/usr/lib32/pkgconfig', 'CC=gcc -m32', 'CXX=g++ -m32',
                       'LANG=en_US.UTF-8', 'meson', 'setup', '..', '--prefix=/usr', '--libdir=/usr/lib32',
                       '--buildtype=release', '-D', 'default-dnssec=no', '-D', 'firstboot=false', '-D',
                       'install-tests=false', '-D', 'ldconfig=false', '-D', 'sysusers=false', '-D',
                       'rpmmacrosdir=no', '-D', 'homed=disabled', '-D', 'userdb=false', '-D', 'man=disabled',
                       '-D', 'mode=release'], systemd['stage'])
        self.assertEqual(systemd['test_user'], 'root')
        self.assertEqual(len(systemd['test']), 1)
        self.assertEqual(systemd['test'][0][:2], ['bash', '-euc'])
        self.assertIn('trap restore EXIT', systemd['test'][0][2])
        self.assertIn('ninja test', systemd['test'][0][2])
        self.assertIn('restores the original file', systemd['validation'])
        self.assertFalse(any('-mx32' in word for step in ('compile', 'stage', 'post_stage')
                             for command in systemd.get(step, []) for word in command))
        coreutils = next(row['recipe_data'] for row in plan if row['name'] == 'coreutils')
        self.assertEqual(coreutils['basis']['sha256'],
                         'b2ecac2f8dfc1ebc716ff6f91f01f6e78521c6d2243cb9b1df02bdd1786ed541')
        self.assertEqual(coreutils['patches'], [
            {'source': 'coreutils-9.7-upstream_fix-1.patch', 'strip': 1},
            {'source': 'coreutils-9.7-i18n-1.patch', 'strip': 1},
        ])
        self.assertEqual(coreutils['test_user'], 'root')
        self.assertIn('make NON_ROOT_USERNAME=tester check-root', coreutils['test'][0][2])
        self.assertIn('runuser -u tester', coreutils['test'][0][2])
        self.assertIn('trap cleanup_group EXIT', coreutils['test'][0][2])
        self.assertIn('{stage}/usr/sbin/chroot', coreutils['stage'][2])
        util_linux = next(row['recipe_data'] for row in plan if row['name'] == 'util-linux')
        self.assertEqual(util_linux['basis']['sha256'],
                         'd0a6aad684bf6ea1dd2fcc6fe4a611ec923db8b643c5d7098858e9bed9547008')
        self.assertEqual(util_linux['post_stage'][1][:4],
                         ['env', 'PKG_CONFIG_PATH=/usr/lib32/pkgconfig',
                          'NCURSESW6_CONFIG=/bin/false', 'CC=gcc -m32'])
        self.assertIn('--libdir=/usr/lib32', util_linux['post_stage'][1])
        self.assertEqual(util_linux['post_stage'][5][-2:],
                         ['{stage}/.m32/usr/lib32/.', '{stage}/usr/lib32/'])
        self.assertIn('trap restore EXIT', util_linux['test'][0][2])
        self.assertIn('runuser -u tester', util_linux['test'][0][2])
        glibc = next(row['recipe_data'] for row in plan if row['name'] == 'glibc')
        self.assertEqual(glibc['basis']['sha256'],
                         '2e0963fd6ac1a86b623037f1fb778989ba8ec5eba281bf88074a8740e63c9830')
        self.assertEqual(glibc['patches'], [{'source': 'glibc-2.42-fhs-1.patch', 'strip': 1}])
        self.assertEqual(glibc['configure_build_guess'], 'scripts/config.guess')
        self.assertEqual(glibc['test_policy'], 'glibc')
        self.assertEqual(glibc['test_user'], 'root')
        self.assertIn('make -k check', glibc['test'][0][2])
        self.assertIn('CC=gcc -m32', glibc['stage'][2])
        self.assertIn('CXX=g++ -m32', glibc['stage'][2])
        self.assertIn('--host=i686-pc-linux-gnu', glibc['stage'][2])
        self.assertIn('--build={build_triplet}', glibc['stage'][2])
        self.assertEqual(glibc['stage'][6][-2:], ['{stage}/.m32/usr/lib32/.', '{stage}/usr/lib32/'])
        self.assertFalse(any('-mx32' in word for step in ('compile', 'test', 'stage', 'post_stage')
                             for command in glibc.get(step, []) for word in command))
        gcc = next(row['recipe_data'] for row in plan if row['name'] == 'gcc')
        self.assertEqual(gcc['basis']['sha256'],
                         '473f1b6097fe51655d02ac9660d0e9b67d620e35d628e50f3c0925df8becfeff')
        self.assertIn('--with-multilib-list=m64,m32', gcc['compile'][0])
        self.assertEqual(gcc['test_user'], 'tester')
        self.assertEqual(gcc['test_policy'], 'gcc')
        self.assertIn('make -k check', gcc['test'][0][2])
        self.assertIn('gcc --build . --make-exit', gcc['test'][0][2])
        self.assertTrue(any('{build_triplet}' in word for command in gcc['post_stage'] for word in command))
        self.assertFalse(any('-mx32' in word for step in ('pre', 'compile', 'test', 'stage', 'post_stage')
                             for command in gcc.get(step, []) for word in command))
        binutils = next(row['recipe_data'] for row in plan if row['name'] == 'binutils')
        self.assertEqual(binutils['basis']['sha256'],
                         'ff9e545c5c54617e3433dfd8f5392ffcecfdafc15b1ae1ca8725a48212a4168d')
        self.assertTrue(binutils['separate_build'])
        self.assertEqual(binutils['working_directories'],
                         {'compile': 'build', 'test': 'build', 'stage': 'build', 'post_stage': 'build'})
        self.assertEqual(binutils['test_policy'], 'binutils')
        self.assertIn('make -j{jobs} -k check', binutils['test'][0][2])
        self.assertIn('binutils --build . --make-exit', binutils['test'][0][2])
        self.assertTrue(all(path.startswith('{stage}/') for path in binutils['post_stage'][0][2:]))
        pkgconf = next(row['recipe_data'] for row in plan if row['name'] == 'pkgconf')
        self.assertEqual(set(pkgconf['build_files']), {
            'infra-alp-personalities/i686-pc-linux-gnu.personality',
            'infra-alp-personalities/x86_64-pc-linux-gnu.personality'})
        self.assertNotIn('x86_64-pc-linux-gnux32.personality', pkgconf['build_files'])
        xml_parser = next(row['recipe_data'] for row in plan if row['name'] == 'xml-parser')
        self.assertEqual(xml_parser['requires'], ['expat', 'perl'])
        self.assertEqual(xml_parser['source'], 'XML-Parser-2.47.tar.gz')
        self.assertEqual(xml_parser['stage'][0], ['make', '-j1', 'DESTDIR={stage}', 'install'])
        kbd = next(row['recipe_data'] for row in plan if row['name'] == 'kbd')
        self.assertEqual(kbd['requires'], ['glibc', 'sed'])
        self.assertEqual(kbd['patches'], [{'source': 'kbd-2.8.0-backspace-1.patch', 'strip': 1}])
        self.assertEqual(kbd['compile'][0], ['./configure', '--prefix=/usr', '--disable-vlock'])
        self.assertIn('comments out make check', kbd['validation'])
        texinfo = next(row['recipe_data'] for row in plan if row['name'] == 'texinfo')
        self.assertEqual(texinfo['requires'], ['findutils', 'glibc', 'perl', 'sed'])
        self.assertEqual(texinfo['test'], [['make', 'check']])
        self.assertEqual(texinfo['stage'][1], ['make', '-j1', 'DESTDIR={stage}', 'TEXMF=/usr/share/texmf', 'install-tex'])
        tcl = next(row['recipe_data'] for row in plan if row['name'] == 'tcl')
        self.assertEqual(tcl['working_directories'], {'compile': 'unix', 'stage': 'unix', 'test': 'unix'})
        self.assertEqual(tcl['prerequisites'], [{'directory': 'tcl-html', 'source': 'tcl8.6.16-html.tar.gz'}])
        expect = next(row['recipe_data'] for row in plan if row['name'] == 'expect')
        self.assertEqual(expect['patches'], [{'source': 'expect-5.45.4-gcc15-1.patch', 'strip': 1}])
        dejagnu = next(row['recipe_data'] for row in plan if row['name'] == 'dejagnu')
        self.assertTrue(dejagnu['separate_build'])
        self.assertEqual(dejagnu['working_directories'], {
            'compile': 'build', 'stage': 'build', 'test': 'build'})
        intltool = next(row['recipe_data'] for row in plan if row['name'] == 'intltool')
        self.assertEqual(intltool['requires'], ['glibc', 'perl', 'xml-parser'])
        autoconf = next(row['recipe_data'] for row in plan if row['name'] == 'autoconf')
        self.assertEqual(autoconf['stage'][0], ['make', '-j1', 'DESTDIR={stage}', 'install'])
        automake = next(row['recipe_data'] for row in plan if row['name'] == 'automake')
        self.assertEqual(automake['test'], [['make', '-j4', 'check']])
        bash = next(row['recipe_data'] for row in plan if row['name'] == 'bash')
        self.assertEqual(bash['test_user'], 'tester')
        self.assertEqual(bash['test_locale'], 'C.UTF-8')
        self.assertEqual(bash['requires'], ['glibc', 'ncurses', 'readline', 'expect'])
        libxcrypt = next(row['recipe_data'] for row in plan if row['name'] == 'libxcrypt')
        self.assertIn(['env', 'CC=gcc -m32', './configure', '--prefix=/usr', '--host=i686-pc-linux-gnu',
                       '--libdir=/usr/lib32', '--enable-hashes=strong,glibc', '--enable-obsolete-api=glibc',
                       '--disable-static', '--disable-failure-tokens'], libxcrypt['stage'])
        self.assertFalse(any('-mx32' in word or '/usr/libx32' in word
                             for step in ('pre', 'compile', 'test', 'stage', 'post_stage')
                             for command in libxcrypt.get(step, []) for word in command))
        for name in ('bzip2', 'file', 'lz4', 'xz', 'zstd', 'gdbm', 'expat', 'kmod', 'attr', 'acl', 'readline', 'libcap', 'libtool', 'libxcrypt'):
            recipe = next(row['recipe_data'] for row in plan if row['name'] == name)
            words = [word for step in ('pre', 'compile', 'test', 'stage', 'post_stage')
                     for command in recipe.get(step, []) for word in command]
            self.assertTrue(any('-m32' in word for word in words), name)
            self.assertFalse(any('-mx32' in word for word in words), name)
            self.assertEqual(recipe['basis']['commit'], base_plan.BOOK_COMMIT)
        bzip2 = next(row['recipe_data'] for row in plan if row['name'] == 'bzip2')
        m32_makefile_compilers = [command[2] for command in bzip2['post_stage']
                                  if command[:2] == ['sed', '-e']
                                  and len(command) > 2 and 'Makefile' in command[-1]]
        self.assertEqual(len(m32_makefile_compilers), 2)
        self.assertTrue(all('x86_64-lfs-linux-gnu-gcc -m32' in command
                            for command in m32_makefile_compilers))

    def test_source_manifest_drift_stops_inventory_resolution(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); inventory = self.fixture(root)
            sources = root / 'manifests/infra-sources.json'
            sources.write_bytes(sources.read_bytes() + b' ')
            with self.assertRaisesRegex(RuntimeError, 'source pin changed'):
                base_plan.load(root)

    def test_order_duplicate_and_missing_recipe_state_are_rejected(self):
        for mutation, message in (
            (lambda data: data['packages'][1].update(order=1), 'order/identity/recipe state'),
            (lambda data: data['packages'][1].update(name=data['packages'][0]['name']), 'order/identity/recipe state'),
            (lambda data: data['packages'][0].update(recipe='recipes/base/not-man-pages.json'), 'recipe path invalid'),
            (lambda data: data['packages'].pop(), 'schema/count/status invalid')):
            with self.subTest(message=message), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); inventory = self.fixture(root)
                value = json.loads(inventory.read_bytes()); mutation(value)
                inventory.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
                with self.assertRaisesRegex(RuntimeError, message):
                    base_plan.load(root)

    def test_missing_reused_or_wrong_version_source_is_rejected(self):
        for mutation in (
            lambda value: value['packages'][0].update(source_id='missing.tar.xz'),
            lambda value: value['packages'][1].update(source_id=value['packages'][0]['source_id']),
            lambda value: value['packages'][0].update(version='99.99')):
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory); inventory = self.fixture(root)
                value = json.loads(inventory.read_bytes()); mutation(value)
                inventory.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
                with self.assertRaises(RuntimeError):
                    base_plan.load(root)

    def test_missing_auxiliary_patch_or_document_source_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); inventory = self.fixture(root)
            value = json.loads(inventory.read_bytes())
            value['packages'][2]['auxiliary_source_ids'] = ['not-pinned.patch']
            inventory.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
            with self.assertRaisesRegex(RuntimeError, 'auxiliary source references invalid'):
                base_plan.load(root)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); self.fixture(root)
            recipe_path = root / 'recipes/base/tcl.json'
            recipe = json.loads(recipe_path.read_bytes())
            recipe['prerequisites'][0]['source'] = recipe['source']
            recipe_path.write_text(json.dumps(recipe, indent=2, sort_keys=True) + '\n')
            with self.assertRaisesRegex(RuntimeError, 'recipe/package/source/authorization binding invalid: tcl'):
                base_plan.load(root)

    def test_recipe_cannot_depend_on_a_later_or_unknown_package(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); self.fixture(root)
            recipe_path = root / 'recipes/base/zlib.json'
            recipe = json.loads(recipe_path.read_bytes()); recipe['requires'] = ['future-package']
            recipe_path.write_text(json.dumps(recipe, indent=2, sort_keys=True) + '\n')
            with self.assertRaisesRegex(RuntimeError, 'recipe/package/source/authorization binding invalid'):
                base_plan.load(root)

    def test_recipe_book_basis_commit_and_chapter_hash_are_pinned(self):
        for field, value in (('commit', 'f' * 40), ('sha256', 'f' * 64),
                             ('file', 'chapter08/current.xml')):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); self.fixture(root)
                recipe_path = root / 'recipes/base/file.json'
                recipe = json.loads(recipe_path.read_bytes())
                recipe['basis'][field] = value
                recipe_path.write_text(json.dumps(recipe, indent=2, sort_keys=True) + '\n')
                with self.assertRaisesRegex(RuntimeError, 'recipe/package/source/authorization binding invalid'):
                    base_plan.load(root)

    def test_lfs_tester_tests_use_a_bounded_user_identity(self):
        plan = base_plan.load(REPO)
        provision = (REPO / 'scripts/infra/guest-provision.sh').read_text()
        self.assertIn('id tester >/dev/null 2>&1 || useradd -m -s /bin/bash tester', provision)
        for name in ('gawk', 'findutils', 'make', 'bash'):
            recipe = next(row['recipe_data'] for row in plan if row['name'] == name)
            self.assertEqual(recipe['test_user'], 'tester')
            self.assertTrue(recipe['test'])
            self.assertFalse(any(command[0] in ('chown', 'su') for command in recipe['test']))
            base_plan.validate_recipe(recipe, recipe['jobs'])
        root_owned = dict(next(row['recipe_data'] for row in plan if row['name'] == 'gawk'))
        root_owned['test_user'] = 'root'
        validate_recipe(root_owned, root_owned['jobs'])
        invalid = dict(root_owned)
        invalid['test_user'] = 'nobody'
        with self.assertRaisesRegex(RuntimeError, 'test_user'):
            base_plan.validate_recipe(invalid, invalid['jobs'])
        invalid = dict(next(row['recipe_data'] for row in plan if row['name'] == 'bash'))
        invalid['test_locale'] = 'C.utf8-unreviewed'
        with self.assertRaisesRegex(RuntimeError, 'test_locale'):
            base_plan.validate_recipe(invalid, invalid['jobs'])

    def test_root_or_tester_test_requires_guest_root_coordinator(self):
        from unittest.mock import patch
        for identity in ('root', 'tester'):
            recipe = {'test_user': identity, 'test': [['true']]}
            with self.subTest(identity=identity), patch('package_stage.os.geteuid', return_value=1000):
                with self.assertRaisesRegex(RuntimeError, 'guest root coordinator'):
                    test_identity_guard(recipe)
            with self.subTest(identity=identity), patch('package_stage.os.geteuid', return_value=0):
                test_identity_guard(recipe)
        test_identity_guard({'test_user': 'root', 'test': []})

    def test_ninja_job_cap_is_bounded_and_injected_as_environment(self):
        plan = base_plan.load(REPO)
        recipe = next(row['recipe_data'] for row in plan if row['name'] == 'ninja')
        self.assertEqual(recipe['environment'], {'NINJAJOBS': '4'})
        validate_recipe(recipe, recipe['jobs'])
        invalid = dict(recipe, environment={'NINJAJOBS': '4;touch /tmp/unsafe'})
        with self.assertRaisesRegex(RuntimeError, 'NINJAJOBS'):
            validate_recipe(invalid, invalid['jobs'])

    def test_binutils_uses_lfs_zlib_headers_from_unchrooted_builder(self):
        plan = base_plan.load(REPO)
        recipe = next(row['recipe_data'] for row in plan if row['name'] == 'binutils')
        self.assertEqual(recipe['environment'], {'CPPFLAGS': '-I/srv/lfs/usr/include'})
        validate_recipe(recipe, recipe['jobs'])
        invalid = dict(recipe, environment={'CPATH': '/srv/lfs/usr/include'})
        with self.assertRaisesRegex(RuntimeError, 'environment name'):
            validate_recipe(invalid, invalid['jobs'])

    def test_recipe_working_directories_are_bounded_and_symlink_free(self):
        plan = base_plan.load(REPO)
        recipe = next(row['recipe_data'] for row in plan if row['name'] == 'gawk')
        valid = dict(recipe, working_directories={'compile': 'unix'})
        base_plan.validate_recipe(valid, valid['jobs'])
        for unsafe in ('../outside', '/tmp', 'unix\\escape'):
            invalid = dict(recipe, working_directories={'compile': unsafe})
            with self.subTest(path=unsafe), self.assertRaisesRegex(RuntimeError, 'working directory'):
                base_plan.validate_recipe(invalid, invalid['jobs'])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'unix').mkdir()
            (root / 'unix/nested').mkdir()
            self.assertEqual(recipe_working_directory(root, valid, 'compile'), root / 'unix')
            (root / 'alias').symlink_to(root / 'unix', target_is_directory=True)
            for unsafe in ('alias', 'alias/nested'):
                invalid = dict(recipe, working_directories={'compile': unsafe})
                with self.subTest(path=unsafe), self.assertRaisesRegex(RuntimeError, 'symlink'):
                    recipe_working_directory(root, invalid, 'compile')

    def test_intltool_pinned_pre_command_escapes_perl_variable_brace(self):
        plan = base_plan.load(REPO)
        recipe = next(row['recipe_data'] for row in plan if row['name'] == 'intltool')
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'intltool-update.in'
            path.write_text(r'x=\${name}' + '\n')
            command = [arg.format(stage='/tmp/stage', source='/tmp/build', lfs='/tmp/lfs', jobs=4)
                       for arg in recipe['pre'][0][:-1] + [str(path)]]
            subprocess.run(command, check=True)
            self.assertEqual(path.read_text(), r'x=\$\{name}' + '\n')


class GuestBaseRunnerTests(unittest.TestCase):
    def test_runner_resolves_exact_canonical_chapter8_recipe_sequence(self):
        plan = base_plan.load(REPO)
        resolved = guest_base.recipes(plan)
        self.assertEqual(len(resolved), 79)
        self.assertEqual(resolved[0]['name'], 'man-pages')
        self.assertEqual(resolved[-1]['name'], 'e2fsprogs')
        self.assertEqual([recipe['name'] for recipe in resolved],
                         [row['name'] for row in plan])

    def test_runner_rejects_incomplete_recipe_plan(self):
        plan = base_plan.load(REPO)
        with self.assertRaisesRegex(RuntimeError, 'package count'):
            guest_base.recipes(plan[:-1])
        missing = [dict(row) for row in plan]
        missing[0].pop('recipe_data')
        with self.assertRaisesRegex(RuntimeError, 'recipe missing'):
            guest_base.recipes(missing)

    def test_saved_bundle_refuses_changed_binding_before_using_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'built.json').write_text(json.dumps({
                'binding': {'inputs_sha256': 'a' * 64}, 'result': 'BUILT', 'built': {}}))
            recipe = {'name': 'glibc'}
            with self.assertRaisesRegex(RuntimeError, 'inputs changed'):
                guest_base.saved_bundle(recipe, root, {'inputs_sha256': 'b' * 64})


if __name__ == '__main__':
    unittest.main()
