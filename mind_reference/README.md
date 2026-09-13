# PR-25 reference model — independent MIND implementation

This directory holds a **second, independent implementation** of the PR-25
finite admission/permit model, written in [MIND](https://github.com/star-ga/mind)
and compiled to a native executable.

It does **not** replace `../reference_model/` (Python). The Verification Note
pins SHA-256 digests to those Python bytes, and every number recorded in the
Note was produced by that code. This directory exists because **two
implementations, in two languages, agreeing on every modeled transition is
stronger evidence than either one alone.**

## The result

Both implementations were run over the entire encoded transition relation —
8,192 state encodings x 27 events = **221,184 transitions** — and every
transition record was compared individually:

```
221184/221184 transition records identical (8192 x 27)
```

The comparison is record-by-record, not a checksum. An earlier revision of this
gate compared a single rolling digest, `h = (31*h + result + 7) mod 1e9+7`, on
each side. That is **not** sufficient: the reduction admits constructed
collisions — `+1` on one record and `-31` on the next cancel exactly — so equal
digests do not establish equal transcripts. An external reviewer demonstrated
this with a two-record counterexample. The gate now diffs all 221,184 records,
asserts the exact record count, and checks both processes' exit statuses.

The comparison implementation (`verify/independent_reference.py`) was written
from the specification comments in the MIND source header, **not** transliterated
from the MIND function bodies. That matters: a reference derived from the code
under test shares its blind spots. This one does not.

## Reproduce

Requires an `mlir-build`-enabled `mindc`:

```sh
git clone https://github.com/star-ga/mind
cd mind && cargo build --release --features mlir-build --bin mindc
```

A default-feature `mindc` will **fail** with `error[build][E5003]` — `mlir-build`
is not in `default`.

Then:

```sh
MINDC=/path/to/mindc ./verify/run_gates.sh
```

## Gates

| # | Gate | Result |
|---|------|--------|
| 1 | `mindc check` + native build | ELF PIE, 50,280 bytes |
| 2 | Output vs `EXPECTED_OUTPUT.txt` | 5/5 counts exact |
| 3 | Run-to-run determinism (10x) | 1 distinct output hash |
| 4 | Rebuild byte-identity (clean rebuild) | `b85bf2c9de888785` |
| 5 | **Cross-language parity, all 221,184 transition records** | 221184/221184 identical |
| 6 | Supplied comparison script | PASS |

Verbatim output, with source and binary digests, is in `GATE_LOG.md`.

## Files

```
src/pr25_reference.mind              the model, compiling
src/pr25_reference_AS_RECEIVED.mind  the original, byte-for-byte (does not compile)
src/pr25_parity_digest.mind          emits all 221,184 transition records
verify/run_gates.sh                  all six gates
verify/independent_reference.py      spec-derived comparison implementation
                                     (records by default; --digest for the
                                     legacy checksum, kept as a smoke check)
verify/check_compiled_output.sh      output comparison
docs/CHANGES_TO_SOURCE.md            every edit to the received source, with proof
docs/token_diff.py                   mechanical proof the edit was formatting-only
EXPECTED_OUTPUT.txt                  expected counts
GATE_LOG.md                          verbatim gate output + digests
```

## What this evidence licenses

**Can be said:** the PR-25 finite reference model exists as pure MIND source,
compiles natively, executes to the expected counts, is deterministic run-to-run,
is byte-identical across clean rebuilds, and agrees record-for-record with an
independently written reference on all 221,184 modeled transitions.

Both of these gates are falsifiable, and that was demonstrated rather than
asserted. Gate 5 was mutation-tested with the reviewer's exact digest-cancelling
counterexample (`+1` / `-31` on two adjacent records): the gate goes red and
names both differing records. Gate 4 was fault-tested by injecting a compiler
failure into the in-place rebuild: the runner aborts with a nonzero exit instead
of accepting a stale binary.

**Cannot be said:** that the 25 physical requirement families are verified;
that a robot is safe; or that this is third-party certification. The model has
ten trusted Boolean summaries, four permit states and a freshness bit. The 25
verdict positions are logical slots, not the physical semantics of PR-01…PR-25.
No sensor truth, plant dynamics, actuator lag, stopping distance, scheduling,
cryptography or persistent replay state is modeled. Expiry is an abstract
invalidation event, not elapsed physical time.

## Known open items

1. **Per-mutant parity.** Gate 5 covers the baseline (`mutant = 0`) only.
   Mutants 1–15 exist in the source; each mutant's transition relation is not
   individually cross-verified.
2. **Malformed-input comparison.** The Python side rejects 19 malformed
   examples via a strict helper; there is no cross-language equivalent here.
3. **Compiler pin.** `MINDC` is built from the `star-ga/mind` default branch,
   which moves. `GATE_LOG.md` records the compiler binary hash and version, but
   not the compiler source commit and dependency set needed to recreate that
   binary from a clean environment. Rebuilding the toolchain from scratch is a
   stronger test than a fresh PR-25 checkout on a provisioned machine.
