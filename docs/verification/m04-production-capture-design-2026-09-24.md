# M04 production install capture design — 24 September 2026

**Status: design only.** This document specifies prerequisites for a future
Linux capture prototype. It does not certify the current runner, record an
observed install, change `/mnt/lfs`, or close M04. The current capture script
is fixture-only; the evidence-bundle verifier checks declared structure and
artifact hashes, not whether an install actually occurred.

## Security and observation boundary

Run initial integration only against a marked, disposable Linux fixture or a
hash-pinned clone of a candidate rootfs. Never relax the current refusal of
`/`, `/mnt/lfs`, or its descendants to enable a production run. A future
candidate runner must create an isolated mount namespace with the host tree
read-only and exactly one explicitly selected target root writable. Keep the
capture evidence store outside that writable target and read-only to the
installer. Do not expose host build directories, credentials, package caches,
or network access unless the package recipe has a documented requirement and
the exception is narrowly scoped.

Bubblewrap is the write boundary; strace is supporting evidence. The runner
must check that namespace setup succeeded before starting the package command,
and fail closed if it cannot establish the requested binds, user/UID mapping,
or process isolation. The capture record must identify the host, kernel,
bwrap/strace versions, namespace options, target identity, and any allowed
exceptions. A trace alone is not confinement.

### Evidence-log file descriptors

The current fixture runner now sends stdout/stderr through pipes and has the
parent stream 64 KiB chunks to evidence files opened after the traced process
starts; this avoids inheriting writable regular log descriptors. Its combined
Windows-host capture/adapter/reconciler/evidence-verifier suite passes 46 tests
and skips 4. **The integrated Linux strace/bwrap confinement probe has not been
run**, including the real descendant-pipe test, so this remains a partial
descriptor mitigation, not a production boundary. A future runner must still
close unrelated descriptors, bound output size, and keep strace's output
descriptor private to the tracer and verify it is not inherited by the
installer. Any inability to preserve these conditions invalidates the event.

### Snapshot metadata and identity

The fixture runner emits the reconciler's `alpbahOS.m04-reconcile-snapshot/v2`
envelope with a persisted fixture `root_id`. Each entry fingerprints the
readable xattr set, `security.capability`, and non-directory hardlink count and
group identity; xattr inspection errors fail closed. The xattr tests use mocks
on this Windows host, so real Linux xattr, ACL, capability, and hardlink
behavior has not been validated. `root_id` is a continuity label, not an
authenticated rootfs identity: copying the fixture also copies that label.
Snapshot traversal and content/metadata reads remain path-based and are not
race-safe or mount-boundary-safe. This schema enrichment therefore does not
make the runner production-ready or authenticate a rootfs snapshot.

### Complete write observation and escape detection

The current parser recognizes a hand-maintained subset of file and descriptor
syscalls. Unknown, unfinished, malformed, or unresolved trace records cannot
be silently skipped in production mode. The observation policy must cover
pathname mutations, descriptor writes, shared writable mappings, metadata and
xattr changes, links/renames, truncation/allocation, and mount operations;
every changed path in the before/after tree must reconcile to an observed
installer operation or an explicitly documented generated-state action.

`io_uring` is a known gap: kernel-mediated operations may not appear as the
underlying file syscalls in a ptrace trace. The fixture runner now supplies
Bubblewrap a native cBPF seccomp filter that returns `EPERM` for
`io_uring_setup`, saves the exact filter bytes as a hashed event artifact, and
requires the adapter to verify those bytes. The trace still requests
`io_uring_setup`; observing an attempt records an `observation_violation` and
invalidates the event, even when seccomp denied it. Unit tests verify the
program encoding, recorded architecture, and adapter enforcement, but Linux
integration has not verified that Bubblewrap installs the filter on the intended descendants or
that the traced syscall is observable under the target kernel. This is a
concrete hardening step, not production readiness. Apply the same rule to any
other write mechanism the trace cannot fully observe. Treat unresolved
relative dirfds, descriptor paths, absolute/relative symlink escapes, and
writes outside the selected target as event failures. A detected escape
attempt invalidates the event even when the kernel denied the write.

The event must record added, removed, and changed files, symlinks, metadata,
and generated state. A syscall trace cannot substitute for reconciliation,
and a tree diff cannot prove which command caused a change without a quiescent
target. A complete before/after tree inventory is the reference method, but
79 full-rootfs pairs plus final reconciliation may cause unacceptable I/O and
metadata pressure. Before a candidate replay, measure this cost against a
representative disposable tree on the same filesystem. If it is infeasible,
use a complete per-event delta mechanism (for example, a validated filesystem
layer or journal) that records replacements, deletions, and metadata changes;
then compare one complete baseline and final inventory against the ordered
deltas. A partial syscall allowlist or unvalidated trace is not an acceptable
substitute. If neither complete method fits the measured environment, stop
before replay.

### Mount and race constraints

Reject a target containing nested mounts or mount crossings before snapshot,
execution, and final reconciliation. The walker must not recurse into a mount
outside the selected target; record and compare mount identities (for example,
via mount IDs) across the entire run. Do not let the installer create or alter
mounts in the target namespace unless that behavior is explicitly part of the
recipe and separately tested.

The current path-based lstat/walk/resolve sequence is vulnerable to concurrent
path replacement and does not establish a stable mount boundary. Production
capture requires a quiescent target and exclusive capture lock, descriptor-
relative traversal, and no-follow/beneath resolution for paths (such as
`openat2` with appropriate `RESOLVE_BENEATH` and `RESOLVE_NO_MAGICLINKS`
constraints where available). Recheck file identity and metadata before and
after hashing. If these guarantees cannot be established on the target kernel
or filesystem, stop rather than downgrade checks.

## Event ledger and Alp database projection

Keep two records with distinct jobs:

1. **Canonical ordered install-event ledger:** append-only evidence in official
   LFS Chapter 8 order. Each event binds package/version, source and recipe
   identities, exact command/environment, exit status, test/build logs, trace,
   before/after snapshots, changed paths, and hashes of all artifacts. It
   records replacements as ordered transitions and classifies shared,
   generated, configuration, and machine-specific state. This ledger is the
   M04 evidence record; a stage manifest or Alp DB row is not a substitute.
2. **Alp package database projection:** existing `alp adopt-base` validates a
   package-files manifest against live file/symlink state and writes a
   protected `lfs-base` record under Alp's DB lock and pending-journal guard.
   It does not consume M04 events, store event IDs or recipe hashes, or prove
   that an install command ran. It rejects already-claimed paths and requires
   each manifest entry to match the current live rootfs. Therefore do not call
   it once per historical event in replay order: later package replacements
   would conflict, and earlier versions may no longer match live paths.
   Preserve install/replacement history and the event-to-package mapping in
   the canonical ledger. After full replay and conflict-free final-owner
   reconciliation, derive Alp manifests containing only each package's
   surviving files and symlinks, then adopt those final projections. Record
   each Alp manifest hash's event/recipe references in a separately hashed
   mapping, or extend Alp's supported public importer before claiming those
   references are stored in its DB. Never edit `db.json` directly or treat
   `adopt-base` as the canonical event ledger.

For the final-owner projection, define and test a strict conversion contract:
the package, version, source hash, recipe hash, final package-file manifest,
and its contributing event IDs must agree; all referenced artifacts must hash
correctly; every contributing event must have successful status and no escape
attempts; final live paths must match the manifest; and replacements must be
explicit. Repeated imports must be idempotent. The import writes only the
protected Alp projection through Alp's public API; the separately hashed
canonical event ledger retains full chronological provenance.

## Required one-package Linux fixture validation

Before any candidate-rootfs replay, run a single synthetic package install on
a disposable Linux fixture with the production-intended bwrap/strace/seccomp
configuration, including the recorded io_uring-deny filter. The probe must
exercise regular files, symlinks, directory metadata, descriptor writes,
rename/unlink, xattrs where supported, and a
shared writable mapping. It must also attempt writes to host sentinels using
absolute paths, `..`, symlink traversal, relative paths, dirfd-relative calls,
and inherited output descriptors. Include a nested-mount probe and an
`io_uring` attempt.

Accept the test only when all of these are recorded and independently checked:

- intended fixture changes match the full before/after diff and package-file
  manifest;
- trace entries are parsed completely; unknown/unresolved write records and
  path escapes fail the capture;
- host sentinels and host-side evidence files remain unchanged by the child;
- mount IDs/boundaries are unchanged and no snapshot traverses outside the
  fixture;
- `io_uring` is denied (or its writes are demonstrably observed);
- a forced mid-install failure leaves a clearly failed, non-importable event
  and recovery/retry behavior is deterministic;
- the evidence bundle verifier accepts the successful event and rejects
  tampered, incomplete, mismatched, or failed-event fixtures.

This validates the sandbox and event format on a fixture only. It is not an
M04 package install and must not be counted among the 79 package events.

## Gates before candidate replay

Do not replay a package into a candidate rootfs until all gates below have
evidence:

1. The active GCC test runner has exited; its final summaries, exit status, and
   logs are preserved. No overlapping build, package install, mount, or NBD
   operation is running.
2. A disposable candidate rootfs clone/checkpoint is identified by a verified
   hash, with adequate space and a tested restore path. The original `/mnt/lfs`
   remains untouched during the first replay.
3. The one-package Linux fixture validation above passes on the same kernel,
   filesystem, bwrap, strace, and seccomp versions intended for replay; a
   representative full-tree inventory/delta feasibility measurement also
   shows adequate I/O time and storage headroom for all events.
4. The install-event schema and ordered ledger writer are implemented and
   tested. Select and test either final-owner manifests imported by existing
   `adopt-base` with a separately hashed event-reference map, or a supported
   Alp importer that stores the references. Conversion and reconciliation
   must be deterministic; imports never use raw DB mutation.
5. One real package replay into the disposable clone passes build/test,
   confinement, event verification, complete-delta reconciliation, and final
   projection dry-run. Preserve its logs, snapshots/deltas, source/recipe
   identities, event ID, and artifact hashes before considering the next
   Chapter 8 package.

Passing these gates permits a reviewed candidate replay; it does not itself
close M04. M04 still requires the full ordered package-event coverage and final
rootfs ownership reconciliation defined in the [install-capture checklist](m04-install-capture-checklist-2026-09-24.md).
