# CPU-BASELINE-03: ISA audit of the kernel modules (2026-11-07)

Scope: the 4989 `.ko` files under `/mnt/lfs13/usr/lib/modules/7.1.8-alpbahos` (kernel rebuilt with CONFIG_BINFMT_MISC=y). Tool: `scripts/lfs-blfs/cpu-baseline/audit-isa.sh`, run with the `.ko` paths as file arguments. Logs are outside the repo: `scratch-lfs-bench/lfs13-logs/cpu03-2026-11-07/` (`ko-list.txt`, `audit-ko-before.out`, `audit-ko-after.out`, `audit-ko-kvmfix.out`, `audit-ko-final.out`, `audit-main-after.out`, `audit-main-final.out`, and `kvm-fix/` for the patch, build log and checks).

Kernel source used for the gate checks: `/mnt/lfs13/sources/linux-7.1.8`. Its `.config` has `CONFIG_X86_NATIVE_CPU` unset, and `arch/x86/Makefile:171` sets `-march=x86-64 -mtune=generic`.

## 1. Result

| Run | Summary line | RC |
|---|---|---|
| Before (rebuilt modules, no new entries) | `audit: 4989 file(s) scanned, 12 with nonvariant AVX/BMI hits (0 hit(s) allowlisted, 15869 unallowed)` | 1 |
| After 46 exact-symbol entries (no kvm fix yet) | `audit: 4989 file(s) scanned, 1 with nonvariant AVX/BMI hits (15837 hit(s) allowlisted, 32 unallowed)` | 1 |
| After the local kvm fix, before the two kvm entries | `audit: 4989 file(s) scanned, 1 with nonvariant AVX/BMI hits (15837 hit(s) allowlisted, 32 unallowed)` | 1 |
| Final module run (46 + 2 entries, with the kvm fix; 48 in total) | `audit: 4989 file(s) scanned, 0 with nonvariant AVX/BMI hits (15869 hit(s) allowlisted, 0 unallowed)` | 0 |
| Final main tree (`/mnt/lfs13/usr/lib lib32 bin sbin boot`) | `audit: 2487 file(s) scanned, 0 with nonvariant AVX/BMI hits (10867 hit(s) allowlisted, 0 unallowed)` | 0 |

- The count is 4989, not 4990: `fs/binfmt_misc.ko` is built in now, so there is no module file for it. It had no hits.
- The main-tree run prints two `WARN stale allowlist entry` lines for the `_blake2` and `_hmac` `malloc_raw` entries (allowlist lines 15 and 18). They are not new; the ch10 run shows the same two warnings.

## 2. Gate evidence per module (11 modules, plus the kvm.ko fix)

Each allowlist line names one exact function, and its reason gives the gate as file:line. A function is listed only when a gate covers it.

| Module | Hits | Functions (hits) | Gate (source) | Reached only through |
|---|---|---|---|---|
| crypto/serpent-avx2.ko | 6538 | `__serpent_enc_blk16` 3229, `__serpent_dec_blk16` 3245, `serpent_ecb_enc_16way` 18, `serpent_ecb_dec_16way` 18, `serpent_cbc_dec_16way` 28 | `serpent_avx2_glue.c:98-105` (AVX2, OSXSAVE, XSTATE SSE\|YMM; `-ENODEV`) | `serpent_algs`, registered at `:108` only after the gate |
| crypto/cast6-avx-x86_64.ko | 2288 | `__cast6_enc_blk8` 1116, `__cast6_dec_blk8` 1117, `cast6_ecb_enc_8way` 16, `cast6_ecb_dec_8way` 16, `cast6_cbc_dec_8way` 23 | `cast6_avx_glue.c:97-100` (XSTATE SSE\|YMM; `-ENODEV`) | `cast6_algs`, registered at `:103` |
| crypto/cast5-avx-x86_64.ko | 1448 | `__cast5_enc_blk16` 694, `__cast5_dec_blk16` 696, `cast5_ecb_enc_16way` 16, `cast5_ecb_dec_16way` 16, `cast5_cbc_dec_16way` 26 | `cast5_avx_glue.c:97-100` (XSTATE SSE\|YMM; `-ENODEV`) | `cast5_algs`, registered at `:103` |
| crypto/twofish-avx-x86_64.ko | 1499 | `__twofish_enc_blk8` 722, `__twofish_dec_blk8` 722, `twofish_ecb_enc_8way` 16, `twofish_ecb_dec_8way` 16, `twofish_cbc_dec_8way` 23 | `twofish_avx_glue.c:107-109` (XSTATE SSE\|YMM; `-ENODEV`) | `twofish_algs`, registered at `:112` |
| crypto/camellia-aesni-avx2.ko | 1995 | `roundsm32_*` 198 x2, `__camellia_enc_blk32` 736, `__camellia_dec_blk32` 736, `camellia_ecb_enc_32way` 36, `camellia_ecb_dec_32way` 36, `camellia_cbc_dec_32way` 55 | `camellia_aesni_avx2_glue.c:102-113` (AVX, AVX2, AES, OSXSAVE, XSTATE; `-ENODEV`) | `camellia_algs`, registered at `:116` |
| crypto/camellia-aesni-avx-x86_64.ko | 1937 | `roundsm16_*` 174 x2, `__camellia_enc_blk16` 736, `__camellia_dec_blk16` 736, `camellia_ecb_enc_16way` 34, `camellia_ecb_dec_16way` 34, `camellia_cbc_dec_16way` 49 | `camellia_aesni_avx_glue.c:103-113` (AVX, AES, OSXSAVE, XSTATE; `-ENODEV`) | `camellia_algs`, registered at `:116`. Its `_16way` symbols are EXPORT_SYMBOL_GPL (`:22-28`), but a module whose init fails is unloaded, so the exports do not exist without the gate |
| kvm/kvm-amd.ko | 6 | `svm_prepare_switch_to_guest` 1 (vmsave), `__svm_vcpu_run` 4 (vmload, vmrun, vmsave), `__svm_sev_es_vcpu_run` 1 (vmrun) | `svm.c:518-521` (`svm_check_processor_compat` returns `-EIO` unless `X86_FEATURE_SVM`, checked at `svm.c:494`); device table `svm.c:65-69` | vCPU run calls at `svm.c:4422-4425`, which need an enabled SVM module. These are SVM instructions, not AVX. The audit's VEX rule matches any v-mnemonic, and its VMX exclusion list has no vmrun, vmload, vmsave or vmmcall |
| drivers/gpu/drm/vmwgfx/vmwgfx.ko | 14 | `__pfx_vmw_resource_relocations_apply` (objdump label of `.altinstr_replacement`) | `vmmcall` is patched in only with `X86_FEATURE_VMW_VMMCALL`, set at `vmware.c:396-397`; macro `VMWARE_HYPERCALL`, `vmware.h:93-96` | Alternative replacement bytes, not `.text`. Objdump finds no `vmmcall` in `.text` of this module |
| drivers/ptp/ptp_vmw.ko | 1 | `__pfx_ptp_vmw_adjtime` | same as vmwgfx (`vmware.h:93-96`, `vmware.c:396-397`) | altinstr only |
| drivers/ptp/ptp_kvm.ko | 1 | `__pfx_kvm_hypercall2.constprop.0` | `KVM_HYPERCALL` ALTERNATIVE, `arch/x86/include/asm/kvm_para.h:21-22`; `X86_FEATURE_VMMCALL` is set only by AMD and Hygon (`arch/x86/kernel/cpu/amd.c:677`, `hygon.c:168`) | altinstr only |
| lib/crypto/libcurve25519.ko | 110 | `fmul` 20, `fmul2` 40, `fsqr` 14, `fsqr2` 28, `point_double` 4, `point_add_and_double` 4 (all `mulx`) | `lib/crypto/x86/curve25519.h:1593` and `:1602` branch on static key `curve25519_use_bmi2_adx`; the key is enabled only if BMI2 and ADX are boot CPU features (`:1611-1612`) | `curve25519_arch` and `base_arch` only |
| arch/x86/kvm/kvm.ko | 32 | `writeback` 16, `__decode_register_operand` 16 (`vmovdqa %ymmN`) | Local host gate `arch/x86/kvm/emulate.c:4789-4790` (new, section 3). Guest-side checks: `emulate.c:5133-5135` (orig 5126-5128) and `:5315-5321` (orig 5308-5314) | Emulator path for VEX guest instructions only; see section 3 |

Notes on the crypto gates:
- The init functions return `-ENODEV` before `crypto_register_*`. A module whose init fails is unloaded, so its code is not reachable on a CPU without the feature. The helpers are reached only from the registered skcipher callbacks. The audit cannot see that, because the callbacks are address-taken.
- For cast5, cast6, twofish and camellia-avx, the gate tests XSTATE SSE|YMM (`cpu_has_xfeatures`, `arch/x86/kernel/fpu/xstate.c:130`) and does not test `X86_FEATURE_AVX` by name. The YMM state can be enabled in XCR0 only on AVX hardware, so this implies AVX. That is reasoning from the architecture, not a test.

## 3. kvm.ko: the emulator AVX path, and the local fix

What the code does. `arch/x86/kvm/fpu.h` (`_kvm_read_avx_reg` and `_kvm_write_avx_reg`) runs `vmovdqa %ymmN` on the host. `emulate.c` reaches it from `__decode_register_operand` (OP_YMM operand, `:1084-1088`) and from `writeback` (OP_YMM, `:1803-1804`). The VEX prefix is decoded by `x86_decode_avx()` (`:4779`), called from `x86_decode_insn` at `:4987`. Before the fix, nothing checked host AVX on this path.

Why the normal guest #UD path is not affected (static analysis, from the source):
- A guest #UD is intercepted (VMX: `UD_VECTOR` in the default bitmap, `vmx/vmx.c:898`; SVM: `svm.c:1140`) and goes to `handle_ud` (`x86.c:8055`), which calls the emulator with `EMULTYPE_TRAP_UD`.
- `x86_decode_insn` returns `EMULATION_FAILED` for `EMULTYPE_TRAP_UD` when the opcode lacks `EmulateOnUD` (`emulate.c:5133-5135`, orig 5126-5128). That check runs before `decode_modrm` and `decode_operand`, so `__decode_register_operand` is not reached for VEX opcodes on this path.

Paths that do reach the host `ymm` read before the guest XCR0 check (`emulate.c:5315-5321`, orig 5308-5314):
1. `EMULTYPE_TRAP_UD_FORCED`, used when the `force_emulation_prefix` module parameter is set (`x86.c:178-179`, `:8057`). It defaults to 0 and is a debug option.
2. Emulation of invalid guest state on VMX CPUs without unrestricted-guest support. Big-real-mode guest code then goes through the full emulator, and `x86_decode_avx` has no host AVX check. Which CPUs lack unrestricted guest was not checked against Intel's feature list; the earlier estimate of Nehalem and older is unverified.
3. Page-fault and MMIO emulation is not a problem: the guest already executed the VEX instruction in hardware, so the host has AVX.

Consequence, with the above paths: on a host without AVX, paths 1 and 2 can run the host `vmovdqa %ymm` and take a host `#UD`. The probability is low (a debug option, or a specific old VMX CPU in real-mode emulation). Not reproduced; no non-AVX host was available.

Local fix (applied to the build tree; patch in `scripts/rebuild/ch10/patches/kvm-emulate-host-avx-gate.patch`):

```
if (!boot_cpu_has(X86_FEATURE_AVX))
        goto ud;
```

at the start of `x86_decode_avx()`. The existing `ud:` label (`emulate.c:4856`) sets the `ud` opcode and returns, so the instruction is treated as #UD. The guest XCR0 check is unchanged. The check tests only `X86_FEATURE_AVX`; it does not test OSXSAVE. This is a local patch and is worth reporting upstream (KVM).

How it is applied: `scripts/rebuild/ch10/02-kernel-build.sh` applies `/sources/kvm-emulate-host-avx-gate.patch` before `.config` is copied. The patch file is staged to `/sources` the same way as `kernel-7.1.8.config`. The step is idempotent: a reverse dry-run detects an applied patch (tested on a scratch copy: first run applied, second run detected). The build script was not re-run in full; the patch was applied by hand to the build tree and the rebuild was incremental.

Build and verification:
- Incremental rebuild in the chroot (`make -j16 modules`, then `make modules_install`), log `kvm-fix/build.log`, RC=0. Compiled: `arch/x86/kvm/emulate.o`, `kvm.o`, `kvm.ko` only. `kvm-intel.ko` and `kvm-amd.ko` were not rebuilt; `modules_install` reinstalled them.
- `vmlinuz-7.1.8-alpbahos` and `arch/x86/boot/bzImage` are unchanged (md5 `5cab8f7ced4424dde1007d5f77ad1dfc` before and after). The kernel image needs no rebuild because `kvm` is a module.
- vermagic: `modinfo -F vermagic kvm.ko` = `7.1.8-alpbahos SMP preempt mod_unload ` (with a trailing space). The pre-fix `kvm.ko` was overwritten and its vermagic was not captured; `kvm-intel.ko`, not rebuilt, has the same string, so the vermagic is unchanged in practice.
- Initrd `/mnt/lfs13/boot/initrd.img-7.1.8` contains no kvm entry (checked with sudo, zstd, cpio). It was not regenerated.
- The disk image built earlier from `/mnt/lfs13` still carries the old `kvm.ko`. It is stale and needs a rebuild before any release.

## 4. Runtime proof: skipped

The proof would need a QEMU boot with `-cpu qemu64` and either a one-shot unit or an explicit `modprobe` in the guest, because the crypto modules load only when requested. That was not done. The static gate evidence above is the basis. Predicted but unverified: on qemu64 (no AVX), the six crypto modules return `-ENODEV` at init.

## 5. Tool change

`audit-isa.sh` has a new opt-in flag, `--include-ko`, which adds `*.ko` to the directory scan. The default is unchanged, so the main-tree run (`usr/lib` contains `usr/lib/modules`) still skips modules. The test `test_directory_scan_skips_ko_unless_include_ko` covers both cases. `tests/test_audit_isa.py`: 16 tests, OK.

The tool still does not exclude SVM mnemonics (vmrun, vmload, vmsave, vmmcall). The kvm-amd and vmmcall entries are allowlisted instead of changing the rule, which would also hide the module list.

## 6. Unverified

- The gates were checked in the source tree `/mnt/lfs13/sources/linux-7.1.8`, taken to be the tree the module build used. I checked `.config` and the arch Makefile, not the full build log flags.
- The mapping from each `__pfx_` altinstr label to its call site is inferred from the objdump section scan and the macro definitions. It was not traced per call site.
- The kvm.ko analysis (section 3) is static only. Neither the original hazard nor the fix was reproduced on a non-AVX host. The fix is compiled but not executed or disassembled.
- Pre-fix vermagic of kvm.ko was not captured (see section 3).

## 7. Status

CPU-BASELINE-03: DONE on static evidence, with the local kvm patch. Module run RC=0 and main tree RC=0. Open follow-ups: rebuild the disk image (stale kvm.ko), report the KVM patch upstream, and run the runtime checks in section 4 when a QEMU slot is available.
