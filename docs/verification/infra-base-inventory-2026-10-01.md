# Native LFS base inventory — 1 October 2026

## Latest update

On 2 October the guest-only ordered Chapter 8 sequence runner was added in `scripts/infra/guest_base.py`. It binds all 79 canonical recipes to current guest boot, inputs, toolchain acceptance and base authorization; it refuses interrupted/non-prefix installs; and its exporter records measured installed payloads plus the actual raw Alp DB. Three runner-focused tests passed. Full host/synthetic suite v42 passed 280 tests with 2 skipped in 93.527 seconds; log SHA-256 `923742014c235f46acbe4d6b8a35605028ea9f366bd1ba98907cdbc9c8f5447d`, receipt SHA-256 `a652feeac9d3553baddb774a76360569cb25bd633bd7aeb10731b9ad018258e4`, input SHA-256 `5d7243bccf669353972422246a59a507d49d964042a7c48fb7d1ab41ffadaac9`. Host `base-run` orchestration, guest transfer verification, stage audit/acceptance and checkpoint wiring remain incomplete. No guest package was built or installed; coverage remains 0/79.

The inventory now has all 79 recipes bound to the pinned MLFS `ml-12.4` Chapter 8 identities. GCC 15.2 binds XML SHA-256 `473f1b6097fe51655d02ac9660d0e9b67d620e35d628e50f3c0925df8becfeff`; its recipe selects only `m64,m32`, applies the book's directory and stack-realignment edits, tests as `tester` with the pinned expected-failure policy, and stages cpp/man/LTO links plus GDB helper relocation. Binutils 2.45, Glibc 2.42, and the other 76 package recipes remain pinned as described below. GCC's cached archive matches source-manifest SHA-256 `438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e`. Glibc's m64 critical test policy and DESTDIR m64/m32 installs, plus the limited documented m32 library/header merge, are declared. Guest package builds and Alp ownership acceptance remain unverified.

`PYTHONPATH=scripts/infra python3 scripts/infra/buildctl.py verify-base-inventory` returned `INVENTORY_AND_RECIPE_COVERAGE_VERIFIED` with 79 packages and 79 recipes; this only confirms declared identity/source/recipe binding. The focused inventory suite passed 12 tests. GCC pre-edits, tester test-wrapper syntax, stage symlink targets, and GDB helper relocation passed fixture checks. Full host/synthetic suite v41 passed 275 tests, 2 skipped, in 100.333 seconds. Log SHA-256 `6774fad5e37681886bca86144cee5478265caa71c2f13fe494a63495b766428c`; receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/state/infra-full-test-suite-v41-20261002.json`, SHA-256 `89019e28471d49107ec79700584a8f473eebf85e4aaaadee9a1c4f8d949df043`; input SHA-256 `ce1076c0b3738131acce235de27717f912eeed0424eca37ca51b39a497653e8b`. No guest build, SBU measurement, root acceptance, base runner, or Phase 1 receipt is proven.

This report records the current worktree inventory and recipe bindings. All 79 LFS 12.4-systemd Chapter 8 package identities and primary source archives, plus 9 auxiliary sources, are pinned in the source manifest. The inventory origin is the read-only copied Chapter 8 package list, SHA-256 `612f7d8bdf54f228910c877b3a0c5d3565ead067c030ab55f9a0df472428fff5`. The fixed book tree is `d7bc803361f445a649d0ca0832219f75b6e68683`.

At an earlier inventory snapshot, 64 recipe/book bindings were present and 15 packages were pending. The current counts are in the latest update above. This verifier checks declared recipe metadata and source provenance only; it does not prove package builds, tests, ownership, or Alp installation.

Inetutils binds the pinned MLFS chapter and moves staged `ifconfig` from `/usr/bin` to `/usr/sbin`; its book-noted intermittent `libls.sh` test is documented. Current recipes contain 22 multilib-capable packages and 52 m64-only packages. The multilib-capable set includes zlib, bzip2, xz, lz4, zstd, file, readline, pkgconf, attr, acl, libcap, libxcrypt, libtool, gdbm, expat, OpenSSL, libelf, libffi, kmod, D-Bus, Ncurses, and Systemd. The m64-only set includes Groff, IPRoute2, XML::Parser, Tcl, Expect, DejaGNU, intltool, Autoconf, Automake, Bash, Shadow, Perl, Python, Kbd, and Texinfo. Pkgconf installs i686 and x86_64 personalities and has no x32 personality. Multilib recipes stage libraries under `/usr/lib32`; OpenSSL performs its pinned second linux-x86 pass after the m64 test/install and copies only the 32-bit library subtree into the package stage. libffi disables processor-native tuning for m64, uses the book’s i686 setting for its m32 pass, and tests both ABIs. Test-only or duplicate m32 helper binaries are kept out of the m64 payload. Gawk, findutils, and make tests run as `tester`; `package_stage.py` temporarily grants that identity to the extracted build tree and restores `lfs:lfs` afterward, including failure paths.

Kbd binds the pinned LFS backspace patch and explicitly omits make check because the pinned Chapter 8 instructions comment it out for known valgrind/chroot/graphical-environment failures. No test pass is claimed. The XML::Parser recipe binds `XML-Parser-2.47.tar.gz` to the pinned LFS 12.4-systemd `chapter08/xml-parser.xml` bytes (`5cf31be76d0d56071f58807c8c64bf3d39b50628e48034e5a0bf8a73f9666b9f`), declares its earlier `expat` and `perl` dependencies, and uses MakeMaker's `DESTDIR` install. Tcl binds both its source and HTML archives; Expect binds the GCC 15 patch; DejaGNU uses the book's dedicated build directory and generates staged HTML/text docs. `package_stage.py` supports per-step directories only within the private build tree and rejects any symlink component; recipe prerequisites must bind to the inventory's auxiliary source pins. The ten focused inventory tests and verifier passed; man-db binds the systemd-book configure options, non-setuid install, declared earlier groff/pager/database libraries and test command. Texinfo binds its pinned Perl-5.42 warning fix, make check, and stage-only optional TeX tree. Vim applies the pinned feature.h/test-list adjustments, runs its documented tester test, and creates vi/man/doc symlinks inside DESTDIR. GMP, MPFR and MPC generate and stage their HTML documentation; GMP enforces the book's 199-PASS minimum. Flit-core, Packaging, Wheel, Setuptools, Ninja, Meson, MarkupSafe, and Jinja2 use local-only Python wheel builds and DESTDIR installs; Ninja embedded builds honor a validated `NINJAJOBS=4`. The book provides no in-scope test suites for these modules, and the Ninja book omits CMake-dependent tests. Procps-ng uses the actual `chapter08/procps.xml` file identity, tester-owned make check, and documents the book's kernel-accounting/chroot test caveats. These recipes are metadata only and have not been guest-built.

Groff 1.23.0 binds MLFS m32-systemd `chapter08/groff.xml`, SHA-256 `3faac14b11858336ade409419f8d89ff3abf6483eee8f30881c0b27a57fb81bb`, with the book’s `PAGE=A4`, `make check`, and staged install. Its source is pinned as `groff-1.23.0.tar.gz` (SHA-256 `6b9757f592b7518b4902eb6af7e54570bdccba37a871fddb2d30ae3863511c13`). The recipe does not build optional packages outside the LFS inventory. IPRoute2 6.16.0 binds `chapter08/iproute2.xml`, SHA-256 `3011c983412f13c79fdd0290496c3fc8208a423e7051b105829b0320187d1b7b`; its pinned source SHA-256 is `5900ccc15f9ac3bf7b7eae81deb5937123df35e99347a7f11a22818482f0a8d0`. The recipe removes the book-excluded arpd target/page, builds with `NETNS_RUN_DIR=/run/netns`, and stages with `SBINDIR=/usr/sbin`. The book states that no working test suite exists; optional non-LFS documentation is omitted.

libffi 3.5.2 binds MLFS m32-systemd `chapter08/libffi.xml`, SHA-256 `78028564e6ea66f37394b43d9d9d3a86616c92999ad9194e2f2637b533b85def`. Its m64 configuration uses `--without-gcc-arch`; the m32 pass uses the book’s `i686` setting, runs `make check`, and stages only `/usr/lib32` under DESTDIR. The temporary m32 DESTDIR is confined to the package stage and removed there; x32 is excluded.

The earlier full host suite v33 passed 274 tests in 87.310 seconds, 2 skipped. Its log SHA-256 is `5625775a5e24c7b05d8957db76f0eef9dea17945baa32c6c3be2bd2025a0fe4f`; it is superseded by v34 above.

The 11 focused inventory tests passed with `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -p 'test_base_plan.py' -v`; the inventory verifier and `git diff --check` also passed. The inventory verifier still reports incomplete coverage by design.

Current inventory row fingerprint SHA-256 (canonical JSON rows of name/order/source_id/version/recipe): `42b1bf0a87b20c8930c1328aa96b08bb8851eb0fd86ccdc0218dc1f65fa117fe`
Current inventory file SHA-256: `7d1107dd11379107202e580ad4aa462127202b4019413ded5f3737c0b2e433d6`
Current source-manifest SHA-256: `0df6f8614ba0b4c335561f69c9458e972be5a738bd3ffa3c6f955ca12b6c8027`
Current build-input SHA-256: `ce1076c0b3738131acce235de27717f912eeed0424eca37ca51b39a497653e8b`
Latest full-suite state: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/state/infra-full-test-suite-v41-20261002.json`, SHA-256 `89019e28471d49107ec79700584a8f473eebf85e4aaaadee9a1c4f8d949df043`.

The Phase 1 acceptance receipt (`artifacts/phase1-acceptance.json`), root cleanup result (`logs/cleanup-root-result.json`), and post-cleanup host audit (`logs/root-host-audit-after.json`) are absent. The recorded two-install raw Alp DB hashes still differ in real-time `installed_at` and `updated_at`; no timestamp normalization or Alp code change was made. No guest build was started. Phase 1 is not accepted.

Pinned Chapter 8 XML SHA-256 values:
- acl: `d81756a4f6e8338990760a903007695fdcb32d5e728e4d076c8ab201fd399fdf`
- attr: `5036c778eaefd8d10cc37e8e034fff2379cd7fed4134e706520068d37088abe8`
- bc: `b1ff66ff058a42331d9deb2a8544eb94c13d636809302f94c3d1adfa9776ca5c`
- bison: `2e1ac9537f49a695412af3dcdb519c74b8c9cd1a62b7594520e597460e755adc`
- bzip2: `fb2e8994a7c222e04aad253a0dccd812b21d01df584dad3653babb6cb69763f9`
- diffutils: `0588df1d7caaa780e795e0995374d6c69b50fae952e261dcbbb76b5bc323d15d`
- expat: `dc7434cf31175b066f4934c69e7dc681d6a14d551e521d75c65b9d668c7efc80`
- file: `9547a82e9d4bf3c4e174dedc70a5b64a7d949fa06bc092bf6bba3f18ebb6c118`
- findutils: `79a63af0e9f451fac785e05e31704acf63ea0abe3eb34315ed59a36fce129c81`
- dejagnu: `1e55fa29f3e82b4284fd031ac603e3d1ccfef7e51529ff80947efcc1e058afd9`
- expect: `1349dc6f453ef7bab820baf3d76008191706b820af4ecac3121406165ee8c92a`
- flex: `74902ad3f6ede79e9c922c62279606809defff4ba9dcbb36ab59338d4a170d1f`
- gawk: `e0062e57c65d3ed85039196398d9ae66f6efb212f525666ac841dce33bcb2158`
- gdbm: `1951a1a97c5fcb87583799e20a0f94169ae5cec5cbe143353278387438b0ad63`
- gperf: `3f94e42a739349238a3122816c633e1bb0393b364900becbd560132e02b6a2dd`
- grep: `2b34b616fcb1b6daacd058c989f065fc84554a7334415da8db24302366b83d07`
- gzip: `2b2042309aa395625848d21dd6e4a5dc601377e598a9c7f6252de0f48d1c1bab`
- iana-etc: `ad05cf83853b61fb6ee8cef86e435a02f261e8cdaf976cbeb1519871cdc2a39f`
- kmod: `35922ba69fdb5aa0a819e2421e13f05252630e6b1d196842a1621ed16fbc452b`
- less: `cb7969087b56e47d2b5f583f86176689b74083062dd9f95220526042259ec351`
- libcap: `a822f0c39c0d8968f5d025122659ae320ffa14645eaccd6cd04195f3364ee7e5`
- libpipeline: `bdd9c934c2af50aed9b8c065f65d803a61bc4c065abaee1d9088d88e97ed09b5`
- libtool: `ecc927f6a58776dac826084985251e432bd555daf052d3299e3b6fae26777f48`
- lz4: `40d9a35c11bff73d937505df2ab529142718620d10711cfc2bf31f30e531ee2c`
- m4: `32d33704233478a59122bf3ef4e26df52719628e0be85111734be4e7562e6980`
- make: `2c95795d631a2d1132ee1148d45623f61e67d5be7b7645e3fa9804f2b8e2e6cc`
- man-pages: `129bbfcb946e2c278a6cdb6777784610a16cf08ddde31679d3f0834d447ebbbe`
- patch: `1414d82eaf9a794442e714fcecdfb383b6285a63c6ec0ab5de9d6279b419aa99`
- pkgconf: `4eeb2adce2209539f4d11a81ab28a836b309c00c2cc62ccfa2196fead2f1822d`
- psmisc: `0215f2f0c3f6d072bbb6f09fba15e202d88d95be17285f0cd25bee3efbe0f050`
- readline: `1e84ab230949c98774ee46e36c293ed1e2005ba421f212d027694169190c5b87`
- sed: `247084eca3813fbd5bbea83ee5c428095492454db6da729fdd51fd76fdf6db0d`
- tar: `fc13763ecd1f9d190ed28d6ee8cdd7d4b40febe0f7a5c1f6d884bfbafb98ca87`
- tcl: `c812fbf3967181391de1972f8a2fa60180506446d34e2f4080df0448356f0261`
- xz: `31fa6c64386f262461a42060d36f95e0d790d4cb381790b6c729f60f2860be8e`
- xml-parser: `5cf31be76d0d56071f58807c8c64bf3d39b50628e48034e5a0bf8a73f9666b9f`
- zlib: `a2fd783b5e821e5cf2e35630b4d6e70e22021bfc6e6308d50695a9c4506e3b8b`
- zstd: `d74d1341d8531397f54368630e97c6c0c3423eb65eef5e67c44aabd17bcc9500`


## Addendum: recipe binding update — 1 October 2026

The pinned MLFS `ml-12.4` Chapter 8 XML hashes for Gettext, elfutils/libelf, GRUB, D-Bus, and e2fsprogs are now bound to recipes. D-Bus and libelf include the documented i686 m32 pass staged under `/usr/lib32`; x32 is excluded. The pinned book defines no separate m32 pass for Gettext, GRUB, or e2fsprogs, so their recipes cover the native build only. Coverage is now **69/79**, with 10 recipes pending. The canonical inventory file SHA-256 is `5f4fc38ec6fb28d31977dcd349d11e3e01e1fff99aecd48d8677597862312bae`; source manifest SHA-256 remains `0df6f8614ba0b4c335561f69c9458e972be5a738bd3ffa3c6f955ca12b6c8027`.

The 11 focused inventory tests passed and the full host/synthetic suite passed 274 tests with 2 skips in 84.793 seconds. Log SHA-256 `013890d42ff6989e74acaf549a1549933506569fe3dbc3656281728ef4708585`; state SHA-256 `3e867841480222bc168117e16d689adc0c10109b0344251147d091fa9cc67ecc`; input SHA-256 `b9524fed44f2f435206b1e2237b1bd9331a1c7405804e42f523caeb2b4857055`. Recipe coverage and host tests do not establish guest package build or Alp ownership acceptance. The Alp DB timestamp discrepancy and privileged host cleanup/audit remain open Phase 1 gates.


The final recipe pass includes both D-Bus m32 shared-object files and their symlinks in the staged `/usr/lib32` payload. Final full-suite rerun after that recipe change: 274 tests, 2 skipped, 84.397 seconds, PASS; log SHA-256 `e53afff1c4485bb7289b2d232a708304f50d3ffc1e1a198c54553be5c8eaeb4a`; state SHA-256 `bbc23f796dc905df3e9af2ea2cdca2b0c6aed14a82d589b6d1fd6f4d4a0f537e`; input SHA-256 `d5b237032fa407d31b626a870bad15e2c1e68d8239d7b294874370e4cbb19b96`.


After binding the e2fsprogs post-stage working directory to its book-required build directory, the focused inventory suite remained 11/11 and the final host/synthetic suite v33 passed 274 tests with 2 skips in 87.310 seconds. Log SHA-256 `5625775a5e24c7b05d8957db76f0eef9dea17945baa32c6c3be2bd2025a0fe4f`; state SHA-256 `1d4a51aed31f613df0a1bdd3d224a102e259b946aa083a9be7900b90c4068c61`; input SHA-256 `d756b79bf4cf661c97df8962844ce6c955a966c7ea4be4dabdce01afc83a022a`.
