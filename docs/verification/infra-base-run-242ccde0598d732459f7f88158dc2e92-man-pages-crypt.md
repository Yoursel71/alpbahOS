# 8 October 2026 — Man-pages crypt-page exclusion and actual Libcap success

Run `242ccde0598d732459f7f88158dc2e92`, launched after `84adaff`, installed 24 packages, including Libcap. The previous Libcap fix ran exactly twice in its m32 build/staging commands; the native tests, m32 library build and Alp-owned installation completed. Exported `libcap.installed.json` reports PASS, SHA-256 `dfac75561efb610110e893d91e40e4dfd14f1c2f04aa14bd34ef9e86231ea019`. The package archive and manifest were independently rehashed after shutdown and match the live guest receipts:

- Archive SHA-256 `c38f1319ebd096b145f3ecfaa1811c42f12576c3a420618f707ce6227a4c2b77`.
- Manifest SHA-256 `7b8e16638e4eec9be73c813f79e2b800f8a1999afa8e4a2b17b16f6aa678b3ef`.

Libxcrypt then built its native and m32 payloads and produced its staged archive/manifest. Native tests report 43 total, 32 PASS, 11 SKIP, 0 FAIL. The installer correctly refused ownership conflicts with Man-pages:

```text
RuntimeError: Payload ownership missing/conflicting: /usr/share/man/man3/crypt.3
```

Comparing the exported manifests found exactly two overlapping nondirectory payloads: `/usr/share/man/man3/crypt.3` and `crypt_r.3`. The pinned LFS chapter explicitly removes these from Man-pages because Libxcrypt provides newer documentation. The existing recipe already declares this removal, but uses `find {source}/man3 ... -type f -name crypt* -delete`. The actual Man-pages 6.15 archive has `man3 -> man/man3`; GNU find's default traversal does not follow the command-line symlink. The command silently succeeded without removing either page, and both were installed and claimed by Man-pages.

The guest adapter now validates that exact internal source alias and substitutes the canonical `man/man3` directory in the existing removal command. It requires the two exact regular source pages and rejects unknown commands, changed aliases, escaping/aliased directories and changed crypt-page payload selection. The deletion remains confined to the disposable source tree under the unprivileged lfs user. The later package installer and Alp ownership checks are unchanged. No accepted stage or Alp database is edited to bypass the conflict, and no recipe/source/toolchain input or test policy changed. Actual fresh guest installation of Libxcrypt still needs the next run; Coreutils/GCC and full Base remain unproven.

Validation:

- 66 focused guest-runner tests PASS. The regression composes the actual Man-pages recipe, reproduces the original find no-op on a contained source alias, then verifies that only the two Libxcrypt pages are removed; unrelated crypt API documentation is retained. Negative cases reject alias escape, symlink pages, unexpected page names and command drift.
- Full `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v`: 387 tests, 2 skipped, PASS in 93.283 seconds. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-man-pages-crypt-20261008.log`, SHA-256 `95459e20fa0436b6c246f74582e9bf9dbd410f88ac92159306db878b1fc9f395`.
- An unprivileged probe extracted the actual checksum-verified Man-pages source into a temporary directory, reproduced the original no-op, applied the adapter and ran the pinned documentation-only DESTDIR installation. Both conflict pages are absent; all other 3,011 nondirectory entries match the prior actual guest manifest byte-for-byte or symlink-target-for-target. The temporary source and DESTDIR were removed. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/man-pages-crypt-exclusion-probe-20261008.json`, SHA-256 `a2e89e96e922f2f48fea1fe4d0717d54c3ae6a436fe3372b6a02fa2a9dade1fd`. This does not prove the next complete guest stage.
- Runner SHA-256 `192d2148869e44ebbbd6038f607430a5bbdad4948edc02737c12f9ad659ea206`; canonical input remains `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`. Space guard and `git diff --check` PASS. No independent agent review was performed.

The controller shut the VM down cleanly and both current failed qcow2 images passed `qemu-img check`. Evidence root: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/242ccde0598d732459f7f88158dc2e92/`:

- `base.log`: SHA-256 `8d507cc0cea1e6edea26c3895f74ff985ce00600638f9fb2fd695b00c475e5d3`.
- `guest-base-partial/libxcrypt/base-libxcrypt.log`: SHA-256 `8b83444b08f4d089ff4cb55a6ddf21652cffb5a6fbad46e4ebaff2dadc7dec74`.
- `guest-base-partial/man-pages/base-man-pages.log`: SHA-256 `136d36dd9ccd035afc1d1cdc3d2800b9acf8527399b2c5fd6d5da56421d72df3`.
- `base.host.jsonl`: SHA-256 `83a1b248b8d273872bb90b12a234d6175013d23fdd30b81d693ca86d813b3b05`; 352 samples, zero errors/kernel faults, maximum CPU temperature 61.875°C. Minimum free bytes: root 50,210,230,272; SSD 27,880,177,664; HDD/data 75,024,044,032. Every disk remained above 15% free. Throttle counters were unavailable.

Glibc's exported archive and manifest were independently rehashed again: `7815dcff6630a5ab34debc6b8c9c62114b1653781f0dc68457388301ce6a7b98` and `21cc505e0d8694e4e73a1469d93828116268166681f9edd753871a8dcdd112eb`, matching the previous fresh attempts. This is Glibc package-byte repetition only. The failed run has no complete Base acceptance or checkpoint; kernel, BLFS, Plasma/GL, ISO and full repeat-byte acceptance remain open.

The prior failed `2a3ebdbc5a291130cff95c10e84bcc0f` leaf overlay pair at `preserved-overlays-1791454260011266689` was removed under the user's unused-artifact cleanup authorization. A first metadata scan aborted without deletion when an ephemeral unittest image disappeared; after the full suite exited successfully, a quiescent rescan checked all 91 managed qcow2 metadata records and found no backing references to these leaves. Both checks, hashes and exact file stat identity were recorded and rechecked before removal. Reclaimed allocated bytes: 7,743,414,272. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-unused-overlay-2a3ebdbc5a291130cff95c10e84bcc0f-20261008.json`, SHA-256 `1f4928708bcf091a6171be6aeb4ac70b74e6eeade97b202b73fca25d25307337`. The current failed images and accepted checkpoints remain intact.

The documentation checker reports the same 31 historical findings; this new report is not flagged. This is not clean documentation acceptance. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-doc-check-man-pages-crypt-20261008.log`.

Next: commit/push this verified source-path correction and evidence, then launch one fresh persistent Base stage from the accepted toolchain checkpoint. User applications, CPU settings, accepted checkpoints and important milestones remain protected.
