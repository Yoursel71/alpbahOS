# M04 transaction writer prototype

`m04-package-install-transaction.py` is an experiment for disposable Linux
fixture directories only. It requires an exact `.m04-fixture-root` marker and
refuses `/`, `/mnt/lfs`, and paths below `/mnt/lfs`. Do not point it at Builder,
an image, or a VM. It is not integrated with Alp and is not production-ready.

The experiment turns one staged tree into an observable transaction: it checks
the current path state and ownership claims, writes backups and a durable
write-ahead journal before changing package paths, atomically replaces files
or symlinks, recaptures the live result, then appends a fixture-local ledger
record and marks the journal committed. A path collision requires a policy
entry pinning the exact prior object fingerprint and prior ledger owner. A
recovery pass is idempotent; an interrupted transaction is committed only if
the ledger record and every postimage match, otherwise the previous ledger and
path preimages are restored. Before rollback, the writer verifies every backup
and current target object. If a backup is corrupt or a target/ledger has an
unexpected third-party edit, recovery refuses and leaves current state
untouched; it does not claim that rollback always succeeds.

Use only a trusted, quiescent disposable fixture root and stage. Keep the
replacement policy quiescent while it is read; parsing and its recorded SHA-256
use the same pinned byte snapshot, checked for changes during the read. The
advisory lock serializes this writer only; it cannot stop another process from changing
paths outside this tool. Path traversal uses ordinary path-based syscalls, not
dirfd-relative atomic traversal, so concurrent path replacement remains a
TOCTOU risk. The transaction and its payload/backup directories use mode
0700, and the writer fsyncs the new transaction-directory entries and journal
before package-path replacements.

Directories are shared, never package-owned, and target parent directories
must already exist. Supported package objects are regular files and symlinks.
The writer fails closed for special files, hardlinked files, nonempty xattrs
(including capabilities), unreadable state, or symlinked target parents. It
does not model ACLs, filesystem flags, SELinux labels, file capabilities,
hardlink groups, package-generated mutable indexes, config-file merge policy,
or packages whose install step writes outside its stage. Source and recipe
hashes are recorded assertions, not independently authenticated inputs. A
successful fixture transaction is not proof of LFS package provenance, Alp
ownership, safe removal, or M04 completion.

Linux-only tests use disposable `TemporaryDirectory` roots. Run with:

```sh
python3 -m unittest discover -s tests -p 'test_m04_package_install_transaction.py' -v
```

The tests inject simulated crashes around journal writes, path replacement,
live verification, and the ownership-record commit boundary, then run recovery
twice. They do not simulate physical power loss or validate performance on the
real rootfs. Fsync ordering is checked by code inspection and fixture tests;
storage-device behavior under actual power loss remains unverified. A process
death during preparation may leave an orphan transaction directory, and a
death during same-directory temporary-file construction may leave a hidden
temporary file; neither case is yet cleaned automatically. Atomic rename keeps
the destination object at its previous value until replacement succeeds.
