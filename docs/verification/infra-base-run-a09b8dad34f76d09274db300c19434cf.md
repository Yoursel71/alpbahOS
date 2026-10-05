# Base stage interruption: Builder Bash loaded target LFS runtime

Date: 2026-10-05
Run: `a09b8dad34f76d09274db300c19434cf`
Stage: LFS base package sequence, interrupted during Expect configure.

## Finding

The Expect patch now applied successfully: the package log shows the pinned patch changing all expected files. The following `./configure` process then exited 139. The guest kernel identified the faulting executable as Builder `bash`, at instruction pointer `0x2`, on guest CPU 3:

`[ 4608.449197] configure[2396647]: segfault at 2 ip 0000000000000002 ... in bash[...] likely on CPU 3`

The log shows that the configure command inherited `LD_LIBRARY_PATH=/srv/lfs/usr/lib`. This selected the target LFS runtime for Builder's Bash and other tools. The previous correction had moved that variable past `runuser`, which fixed patching but still poisoned Bash. This is a guest environment bug, not evidence of a CPU fault.

## Correction and verification

The Expect adapter now strips `LD_LIBRARY_PATH` from Builder-side commands. Expect `make` calls receive a dedicated `TCLSH_PROG` wrapper that uses the LFS dynamic loader for Tcl, sets the target Tcl script directory, and confines the target library path to Tcl/Expect processes. The focused test suite passes: 23 tests, plus `py_compile` and `git diff --check`.

I also extracted the target loader, Tcl executable, Tcl shared library, and Tcl scripts from the stopped guest image and ran Tcl through the target loader in a temporary directory. It reported `8.6.16` twice (runtime and package version). The wrapper's `TCL_LIBRARY` setting is required for the installed Tcl scripts.

The base stage remains FAIL/incomplete. There is no guest artifact proof, base acceptance, or base checkpoint. The failed overlays were closed and `qemu-img check` reports no errors. A fresh attempt must start from the accepted toolchain checkpoint; neither interrupted run should be resumed.

## Host telemetry

- 453 samples; no reported monitor errors, host kernel faults, or MCE entries.
- CPU temperature ranged 36.0–58.5 C.
- Throttle-counter coverage was unavailable.

These readings do not establish overclock stability, but the precise process fault is explained by the incompatible Builder/TARGET library environment. The next run remains monitored.

## Evidence hashes

- Guest base log: `8894d630f9a2d53afbc1ad0e2963d00041eae1ae2b24dabb120f0956a522ecba`
- Expect package log: `09a2a9f920c77c4dec0696746eed34e607d03af957a7c0f5d00b734d39eefa72`
- Host telemetry: `3c5f50e968f3a76523f85313218ef8a6b958c3bfd644e0abeca190b46403ab9e`
- Guest serial log: `0a9794fa338516b55299d1a01ff69b1c0d066e864f8d27d59ea94d8f938d0e5f`
