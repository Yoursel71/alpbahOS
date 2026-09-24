# M04 fixture capture adapter — 24 September 2026

`scripts/adapt-m04-capture-event.py` converts one successful fixture capture
event to the existing integrity-only evidence-bundle event shape. It does not
turn capture assertions into proof and does not close any M04 gate.

## Bundle conversion inputs

The runner records package name/version, command, nanosecond timestamps,
source/recipe input paths and hashes, stdout/stderr, syscall trace, and
before/after snapshots. The bundle schema also requires an ordered sequence,
source URL, and recipe identity. Those are not inferred. The adapter requires
an explicit provenance JSON file with this schema:

```json
{
  "schema": "alpbahOS.m04-capture-adapter-provenance/v1",
  "sequence": 1,
  "source_url": "https://example.invalid/source.tar.xz",
  "source_input_path": "/fixture/source.tar.xz",
  "recipe_identity": "explicit recipe identity",
  "recipe_input_path": "/fixture/recipe.sh"
}
```

Both paths must match exactly one input in the capture event; the adapter uses
the recorded hashes and refuses mismatches. The source URL and recipe identity
remain caller assertions. The adapter verifies every referenced capture
artifact using the evidence verifier's stable-read and hash checks. It combines
stdout and stderr into a newly hashed `adapter-output/<event-id>/install.log`,
then maps the trace and snapshots to the verifier's required artifact names.
The resulting one-event index can be checked without strict package coverage;
sequence/identity inputs for a complete bundle remain caller-managed.

Example:

```text
python scripts/adapt-m04-capture-event.py \
  --event fixture/.m04-capture/events/<event-id>/event.json \
  --evidence-root fixture \
  --provenance provenance.json \
  --bundle-index-out fixture/adapted-index.json
python scripts/verify-m04-evidence-bundle.py \
  --index fixture/adapted-index.json --evidence-root fixture
```

The bundle verifier checks structure and artifact integrity only. A successful
conversion is not validation that the source URL or recipe identity is true,
that the command ran as described, or that the trace completely observed it.

## Reconciler conversion is refused

The adapter intentionally does not create reconciler input. The reconciler
requires `write_set_complete=true`, but the current runner's parser silently
skips unknown syscall records, does not deny `io_uring`, uses path-based
snapshots without identity rechecks, and does not establish a quiescent root or
exclusive capture lock. A snapshot diff is not enough to attribute concurrent
changes to the install command. The adapter must not manufacture that
completeness assertion.

The capture event schema is now v3 and includes `observation_violations` plus
a hashed seccomp policy artifact. Bubblewrap receives a cBPF filter that denies
`io_uring_setup` with `EPERM`; the adapter checks the artifact bytes against
the supported architecture's expected policy and carries its hash into the
integrity bundle. The trace still records an attempted `io_uring_setup` and
rejects that event. This policy has unit-level encoding/adapter coverage only;
Linux integration has not yet verified enforcement or descendant inheritance.
It does not make the trace complete.

Before reconciler conversion can be considered, capture must provide a
validated complete write-observation boundary and exclusive/quiescent target
guarantees, and a separate assembly step must supply the full ordered 79-event
chain, baseline/final state, classifications, and independently reviewed
package identity pins. This adapter produces none of those. Linux integration
and the production fixture probes in
[`m04-production-capture-design-2026-09-24.md`](m04-production-capture-design-2026-09-24.md)
remain required.

## Validation

- Windows host: `python -m pytest -q tests/test_m04_capture_event_adapter.py tests/test_m04_evidence_bundle.py tests/test_m04_install_event_capture.py tests/test_m04_final_owner_reconciler.py` — **46 passed, 4 skipped**. This includes a CLI-path fixture test that writes an adapted index and passes it through the existing bundle verifier, plus `io_uring_setup` rejection.
- `python -m py_compile scripts/adapt-m04-capture-event.py` — passed.
- `python docs/handoffs/claude/tools/check_docs.py` — 0 findings.
- `git diff --check` — passed.
