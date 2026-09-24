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

The current runner opens stdout and stderr evidence files before invoking
strace/bwrap, so the installer inherits writable descriptors to host-side
files even though the evidence directory is rebound read-only inside the
namespace. A future runner must not give the command writable descriptors to
host evidence files. Capture command output through pipes, have the trusted
parent write the logs after reading them, close all unrelated descriptors, and
bound output size. Keep strace's output descriptor private to the tracer and
verify it is not inherited by the installer. Any inability to preserve these
conditions invalidates the event.

### Complete write observation and escape detection

The current parser recognizes a hand-maintained subset of file and descriptor
syscalls. Unknown, unfinished, malformed, or unresolved trace records cannot
be silently skipped in production mode. The observation policy must cover
pathname mutations, descriptor writes, shared writable mappings, metadata and
xattr changes, links/renames, truncation/allocation, and mount operations;
every changed path in the before/after tree must reconcile to an observed
installer operation or an explicitly documented generated-state action.

`io_uring` is a known gap: kernel-mediated operations may not appear as the
underlying file syscalls in a ptrace trace. Deny `io_uring_setup` through a
verified seccomp policy for the initial implementation, or use an independently
validated observer that accounts for its operations. Apply the same rule to
any other write mechanism the trace cannot fully observe. Treat unresolved
relative dirfds, descriptor paths, absolute/relative symlink escapes, and
writes outside the selected target as event failures. A detected escape
attempt invalidates the event even when the kernel denied the write.

Compare complete target snapshots before and after capture. The event must
record added, removed, and changed files, symlinks, metadata, and generated
state; a syscall trace cannot substitute for that reconciliation, and a tree
diff cannot prove which command caused a change without a quiescent target.

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
2. **Alp package database projection:** a supported Alp API may import a
   validated package manifest and event reference under Alp's normal DB lock
   and journal guard. Existing `alp adopt-base` validates a package-files
   manifest against live file/symlink state and writes a protected `lfs-base`
   record. It does not consume the M04 event schema or prove that the recorded
   install command ran. Do not edit `db.json` directly or treat `adopt-base` as
   the canonical event ledger.

Before any import API is used, define and test a strict conversion contract:
the package, version, source hash, recipe hash, package-file manifest, and
event ID must agree; all referenced artifacts must hash correctly; the event
must have successful status and no escape attempts; final live paths must
match the manifest; conflicts and replacements must be explicit; and repeated
imports must be idempotent. The import writes the Alp projection through Alp's
public API while preserving the separately hashed canonical event.

## Required one-package Linux fixture validation

Before any candidate-rootfs replay, run a single synthetic package install on
a disposable Linux fixture with the production-intended bwrap/strace/seccomp
configuration. The probe must exercise regular files, symlinks, directory
metadata, descriptor writes, rename/unlink, xattrs where supported, and a
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
   filesystem, bwrap, strace, and seccomp versions intended for replay.
4. The install-event schema, ordered ledger writer, and supported Alp import
   API are implemented and tested. The event-to-manifest conversion and
   reconciliation are deterministic; imports never use raw DB mutation.
5. One real package replay into the disposable clone passes build/test,
   confinement, event verification, final-tree reconciliation, and import
   checks. Preserve its logs, snapshots, source/recipe identities, event ID,
   and artifact hashes before considering the next Chapter 8 package.

Passing these gates permits a reviewed candidate replay; it does not itself
close M04. M04 still requires the full ordered package-event coverage and final
rootfs ownership reconciliation defined in the [install-capture checklist](m04-install-capture-checklist-2026-09-24.md).
