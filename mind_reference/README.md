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
8,192 state encodings x 27 events = **221,184 transitions** — and their
digests agree:

```
MIND        596895410
independent 596895410
```

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
| 5 | **Cross-language parity, all 221,184 transitions** | `596895410 == 596895410` |
| 6 | Supplied comparison script | PASS |

Verbatim output, with source and binary digests, is in `GATE_LOG.md`.

## Files

```
src/pr25_reference.mind              the model, compiling
src/pr25_reference_AS_RECEIVED.mind  the original, byte-for-byte (does not compile)
src/pr25_parity_digest.mind          full transition-relation digest
verify/run_gates.sh                  all six gates
verify/independent_reference.py      spec-derived comparison implementation
verify/check_compiled_output.sh      output comparison
docs/CHANGES_TO_SOURCE.md            every edit to the received source, with proof
docs/token_diff.py                   mechanical proof the edit was formatting-only
EXPECTED_OUTPUT.txt                  expected counts
GATE_LOG.md                          verbatim gate output + digests
```

## What this evidence licenses

**Can be said:** the PR-25 finite reference model exists as pure MIND source,
compiles natively, executes to the expected counts, is deterministic run-to-run,
is byte-identical across clean rebuilds, and agrees with an independently
written reference on all 221,184 modeled transitions.

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
