# M04 rootfs replayability assessment — 24 September 2026

## Decision status

M04 remains open. The project checklist requires an observed install event for
each of the 79 ordered LFS 12.4 Chapter 8 packages, followed by reconciliation
of every final-rootfs path against the ownership ledger or an explicit
non-package classification. A staged manifest or rootfs content match alone
does not prove an install event; see the [M04 capture checklist](m04-install-capture-checklist-2026-09-24.md#m04-evidence-rule).

The first feasible route to evaluate is a **preserved clone of the current
rootfs followed by a controlled package replay**. This can create real,
ordered install events without treating old file contents as historical proof.
It closes M04 only if replay actually rewrites and records every package path,
package-specific post-install actions are captured, and final reconciliation
has no unresolved package-owned paths. A clone is not automatically clean.

## Builder evidence

The 24 September shallow read-only rootfs check found `/mnt/lfs` as the only
full rootfs among the inspected Builder `/mnt` paths. The named candidate paths
`/mnt/base-ro`, `/mnt/alpbahos-clean`, `/mnt/efi-ro`, `/mnt/m2ssh`,
`/mnt/m2candidate`, `/mnt/m1base`, and `/mnt/alpbahos-old` were empty;
`/mnt/alpbahos-root` contained only `boot/`. `findmnt -R /mnt` returned no
mount entries. Thus no known pre-Chapter-8 checkpoint was found in those
locations. This does not claim that every Builder path was searched.

A fresh bounded basename check through the `alp-builder` SSH alias found
top-level build directories for most Chapter 8 packages and direct source
archive basenames for all 79 ordered packages. Six packages with no dedicated
stage script have no matching top-level work directory in that listing:
Packaging, Wheel, Setuptools, Vim, MarkupSafe, and Jinja2. The depth-2 marker
listing also found retained `Makefile`/`config.status` paths for many package
trees (including Glibc, Gettext, Bison, Python, and the systemd-family final
trees), and Ninja's `build.ninja` and `ninja`. Full commands and unabridged
basename outputs are preserved in the [Builder availability log](m04-builder-replay-availability-2026-09-24.log).

These names and configuration markers show that the Builder is not limited to
source archives, but do not prove that build outputs are complete or usable,
that the source and patch identities are correct, that package tests passed,
or that an install target is safe to replay. No contents or hashes were read,
no unbounded recursive scan or `du` was run, and no Builder files or active GCC
job were changed by this availability check. The earlier storage audit recorded
60 GiB free under `/mnt/lfs` and 46.98 GiB free in the volume group; capacity
for preserving a candidate plus build trees, sources, logs, and test margin
still needs a fresh measurement after the GCC test terminates.

## Required gates before replay

1. Wait for the exact live GCC test to terminate. Preserve its `.sum`, `.log`,
   runner output, and final summary; resolve the four known
   `gcc.target/i386/pr90579.c` scan failures, then require a successful focused
   and full GCC test run before accepting the GCC stage.
2. Measure Builder `/mnt/lfs`, `build`, `sources`, and logs after the test
   stops. Confirm space for both the preserved original and candidate; extend
   the existing Builder logical volume only if the measured plan requires it.
3. Make a metadata-preserving candidate copy or snapshot, keep the current
   `/mnt/lfs` recoverable, and verify the candidate against a captured baseline
   before changing it. Keep all builds in the Builder `/mnt/lfs` chroot; any
   candidate must be presented at that path through a controlled, logged
   switchover. Do not use Builder `/tmp` for image copies.
4. Replay all 79 packages in the checked order using a real event producer,
   not the current fixture-only transaction writer. Capture complete install
   and post-install commands, source/patch/recipe hashes, environment, exit
   status, test evidence, writes/deletions, metadata, replacements, and logs.
5. Reconcile the candidate tree against the ordered ledger. Classify all
   configuration, generated, runtime, boot, and other non-package paths. Any
   retained Chapter 8 payload with no observed owner leaves M04 open; if the
   clone cannot be reconciled, locate a valid pre-Chapter-8 checkpoint or
   rebuild the base system.
6. Promote a candidate only after every event and reconciliation gate passes.
   On any failure, preserve the failed candidate/evidence and restore the
   original `/mnt/lfs` without changing release or test images.

This assessment is a route decision, not a completed M04 install capture. The
production event producer, replay, ownership database integration, and final
rootfs reconciliation remain outstanding.
