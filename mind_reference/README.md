# PR-25 reference model — independent MIND implementation

This directory contains a second implementation of the finite PR-25
admission/permit model, written in [MIND](https://github.com/star-ga/mind) and
compiled to a native executable. It does not replace `../reference_model/`;
the Python files remain the digest-pinned artifacts behind the Verification
Note.

## Transition parity

The two implementations enumerate 8,192 state encodings × 27 events =
**221,184 transitions**. Gate 5 compares every encoded transition result
record-by-record:

```text
221184/221184 transition records identical (8192 x 27)
```

An earlier checksum-only gate was insufficient because distinct transcripts can
share a rolling digest. The current gate asserts both process exit statuses,
record counts, and exact transcript equality.

## Malformed-input boundary

The Python verifier also has 19 malformed **Python-object** tests. Objects such
as `None`, dictionaries, floats/NaN, and Python's bool/int alias are
language-specific and are not fabricated as MIND `i64` values.

PR-25 therefore uses a shared canonical descriptor boundary for cross-language
checking. A descriptor carries entry shape, applicability kind/code, and verdict
kind/code. Structural refusals are evaluated before semantic admission and every
refusal has a coded reason.

`src/pr25_malformed_boundary.mind` and
`verify/malformed_reference.py` independently classify an exhaustive bounded
corpus of **7,000 canonical descriptors**. Gate 7 compares all 7,000 records in
defined order and then intentionally corrupts one reference record; the gate
must observe that mismatch. The original 19 Python-object cases remain separate
language-boundary tests.

## Reproduce

The MIND source is checked against MIND 0.10.2. Source reproduction pins the
compiler to commit:

```text
1a1b8cf04efcaa8d8dcb408709990d38025cacdd
```

Build it with:

```sh
git clone https://github.com/star-ga/mind
cd mind
git checkout --detach 1a1b8cf04efcaa8d8dcb408709990d38025cacdd
cargo build --release --features mlir-build --bin mindc
```

Native builds also require `mlir-opt`, `mlir-translate`, and `clang` on `PATH`.
Then run:

```sh
MINDC=/path/to/mindc ./verify/run_gates.sh
```

GitHub Actions performs the Python and native-MIND verification from a fresh
checkout. The CI run records the compiler source commit, generated dependency
lock hash, and compiler binary hash used for that execution.

## Gates

| # | Gate | Required result |
|---|------|-----------------|
| 1 | `mindc check` + native build | native executable produced |
| 2 | Output vs `EXPECTED_OUTPUT.txt` | 5/5 counts exact |
| 3 | Run-to-run determinism (10×) | 1 distinct output hash |
| 4 | Clean rebuild byte-identity | hashes identical |
| 5 | Cross-language transition parity | 221184/221184 identical |
| 6 | Compiled-output comparison | PASS |
| 7 | Canonical malformed-input parity | 7000/7000 identical + negative control detected |

## Files

```text
src/pr25_reference.mind              finite model
src/pr25_reference_AS_RECEIVED.mind  original received source
src/pr25_parity_digest.mind          emits transition records
src/pr25_malformed_boundary.mind     canonical boundary classifier
verify/run_gates.sh                  verification gates
verify/independent_reference.py      independent transition reference
verify/malformed_reference.py        independent boundary reference
verify/check_compiled_output.sh      output comparison
docs/CHANGES_TO_SOURCE.md            source-edit record
docs/token_diff.py                   token-level edit check
EXPECTED_OUTPUT.txt                  expected summary counts
GATE_LOG.md                          recorded native gate evidence
```

## Scope

The evidence supports the finite logical model only. It does not verify the 25
physical requirement families, establish robot safety, or constitute
certification. The model omits sensor truth, plant dynamics, actuator lag,
stopping distance, scheduling, cryptography, persistent replay state, and other
application-specific physical obligations.

## Known open items

1. **Per-mutant transition parity.** The complete baseline transition transcript
   is cross-checked. Mutants 1–15 are detected by MIND property checks, but their
   entire transition relations are not each compared with a separately written
   cross-language mutant specification.
2. **Language-specific parser/type hazards.** Shared canonical boundary semantics
   are cross-checked. Raw parser/runtime hazards that exist only in one language
   remain tests of that language's input boundary rather than fake equivalents.
