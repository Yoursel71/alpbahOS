# CPU-BASELINE-03: ISA audit of the kernel modules (2026-11-07)

Scope: the 4989 `.ko` files under `/mnt/lfs13/usr/lib/modules/7.1.8-alpbahos` (kernel rebuilt with CONFIG_BINFMT_MISC=y). Tool: `scripts/lfs-blfs/cpu-baseline/audit-isa.sh`, run with the `.ko` paths as file arguments. Logs are outside the repo: `scratch-lfs-bench/lfs13-logs/cpu03-2026-11-07/` (`ko-list.txt`, `audit-ko-before.out`, `audit-ko-after.out`, `audit-main-after.out`).

Kernel source used for the gate checks: `/mnt/lfs13/sources/linux-7.1.8`. Its `.config` has `CONFIG_X86_NATIVE_CPU` unset, and `arch/x86/Makefile:171` sets `-march=x86-64 -mtune=generic`.

## 1. Result

| Run | Summary line | RC |
|---|---|---|
| Before (rebuilt modules, no new entries) | `audit: 4989 file(s) scanned, 12 with nonvariant AVX/BMI hits (0 hit(s) allowlisted, 15869 unallowed)` | 1 |
| After (46 exact-symbol entries added) | `audit: 4989 file(s) scanned, 1 with nonvariant AVX/BMI hits (15837 hit(s) allowlisted, 32 unallowed)` | 1 |
| Main tree after (`/mnt/lfs13/usr/lib lib32 bin sbin boot`) | `audit: 2487 file(s) scanned, 0 with nonvariant AVX/BMI hits (10867 hit(s) allowlisted, 0 unallowed)` | 0 |

- The count is 4989, not 4990: `fs/binfmt_misc.ko` is built in now, so there is no module file for it. It had no hits.
- The 32 unallowed hits are all in one module, `arch/x86/kvm/kvm.ko` (section 3). The module-run goal AUDIT_RC=0 is NOT met, on purpose: that path is ungated.
- The main-tree run prints two `WARN stale allowlist entry` lines for the `_blake2` and `_hmac` `malloc_raw` entries (allowlist lines 15 and 18). They are not new; the ch10 run shows the same two warnings.

## 2. Gate evidence per module (11 modules allowlisted)

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

Notes on the crypto gates:
- The init functions return `-ENODEV` before `crypto_register_*`. A module whose init fails is unloaded, so its code is not reachable on a CPU without the feature. The helpers are reached only from the registered skcipher callbacks. The audit cannot see that, because the callbacks are address-taken.
- For cast5, cast6, twofish and camellia-avx, the gate tests XSTATE SSE|YMM (`cpu_has_xfeatures`, `arch/x86/kernel/fpu/xstate.c:130`) and does not test `X86_FEATURE_AVX` by name. The YMM state can be enabled in XCR0 only on AVX hardware, so this implies AVX. That is reasoning from the architecture, not a test.

## 3. Finding (not allowlisted): kvm.ko emulator AVX path is ungated

`arch/x86/kvm/kvm.ko` has 32 hits, all `vmovdqa` with `%ymm` registers, 16 in `writeback` and 16 in `__decode_register_operand`. They are real VEX-256 instructions in `.text` (objdump, kvm.ko offsets 0x501de to 0x51080).

Path, from source:
1. `arch/x86/kvm/fpu.h:20-47` and wrappers `:164-175`: `_kvm_read_avx_reg` and `_kvm_write_avx_reg` run `vmovdqa %ymmN` on the host. The wrappers only call `kvm_fpu_get` and `kvm_fpu_put`. There is no CPU-feature check.
2. `arch/x86/kvm/emulate.c:4976-4987`: a `0xc4` or `0xc5` prefix goes to `x86_decode_avx()` (`:4779`). That function checks the prefix and VEX fields, not `boot_cpu_has(X86_FEATURE_AVX)`.
3. `emulate.c:1084-1088` (`__decode_register_operand`, OP_YMM) and `:1803-1804` (`writeback`, OP_YMM) call the AVX register helpers. The only check is the opcode's `Avx` flag (`:5083-5084`).
4. Trigger: a guest `#UD` is intercepted. VMX has `UD_VECTOR` in the default exception bitmap (`vmx/vmx.c:898`) and routes it to `handle_ud` (`vmx.c:5285`, `x86.c:8055`), which calls `kvm_emulate_instruction`. SVM sets the `#UD` intercept unconditionally (`svm/svm.c:1140`).

Consequence (static analysis, not reproduced): on a host without AVX, for example a Nehalem or Westmere Intel CPU with VMX, or a K10-era AMD CPU with SVM, a guest that executes a VEX instruction with an `Avx`-flagged opcode makes the host run `vmovdqa %ymm` in kernel mode, which raises `#UD` in the host. On AVX hosts the host instructions are valid. Whether the emulator should accept VEX for a guest whose CPUID has no AVX is a separate question (the emulator does not check guest CPUID either). Not verified.

Proposed fix (not applied; needs a kernel rebuild and a test on a non-AVX VMX host):
- In `arch/x86/kvm/emulate.c` `x86_decode_avx()`, before the VEX decode, add a host check that takes the existing `ud` path when AVX is absent or OSXSAVE is off:
  `if (!boot_cpu_has(X86_FEATURE_AVX) || !boot_cpu_has(X86_FEATURE_OSXSAVE)) goto ud;`
- Follow-up: check the guest's AVX and XCR0 state in the same place.
- A Kconfig change is not the fix: KVM has to run on these generic x86-64 hosts.
- After the patch, rebuild `kvm.ko` (`make M=arch/x86/kvm`), re-run the audit, and add allowlist lines for `writeback` and `__decode_register_operand` that cite the new check at `emulate.c:<line>`. The audit cannot see the gate by itself.

## 4. Runtime proof: skipped

The proof would need a QEMU boot with `-cpu qemu64` and either a one-shot unit or an explicit `modprobe` in the guest, because the crypto modules load only when requested. That was not done in this pass; the static gate evidence above is the basis. Predicted but unverified: on qemu64 (no AVX), the six crypto modules return `-ENODEV` at init.

## 5. Tool change

`audit-isa.sh` has a new opt-in flag, `--include-ko`, which adds `*.ko` to the directory scan. The default is unchanged, so the main-tree run (`usr/lib` contains `usr/lib/modules`) still skips modules. The test `test_directory_scan_skips_ko_unless_include_ko` covers both cases. `tests/test_audit_isa.py`: 16 tests, OK.

The tool still does not exclude SVM mnemonics (vmrun, vmload, vmsave, vmmcall). The kvm-amd and vmmcall entries are allowlisted instead of changing the rule, which would also hide the module list.

## 6. Unverified

- The gates were checked in the source tree `/mnt/lfs13/sources/linux-7.1.8`, taken to be the tree the module build used. I checked `.config` and the arch Makefile, not the build log flags (no `V=1` log).
- The mapping from each `__pfx_` altinstr label to its call site is inferred from the objdump section scan and the macro definitions. It was not traced per call site.
- The kvm.ko ungated path is static analysis only.

## 7. Status

CPU-BASELINE-03 stays OPEN: 11 of 12 modules are closed with gate evidence, and kvm.ko is an open finding. Next: decide on the `emulate.c` patch in section 3, apply and test it on a non-AVX host, then add the two allowlist lines.
