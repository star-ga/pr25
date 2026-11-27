# PR-25 native exporter

A MIND program that searches every reachable state of the PR-25 finite reference
model and prints each record as text. It builds with the public `mindc 0.10.4`
release on the **native backend** (`mindc build --backend native`). The compiler
reports `via the pure-MIND native-ELF backend (zero MLIR/LLVM/clang)`; the build
also finishes with an empty `PATH` (command in "Build and run"), so it starts no tool
that it must find on `PATH`. The files outside this folder that need the MLIR route
are listed in `../README.md`; their MIND sources are unchanged.

```
Mind.toml
src/model.mind     the model rule: a token-level copy of ../src/pr25_reference.mind
src/props.mind     two property checkers (separated oracle; checker that shares the model helper)
src/variants.mind  the 15 graph variants: search, first counterexample, changed records
src/out.mind       table helpers and a buffered number writer
src/pins.mind      pinned digests of the transition tables of the 16 rule sets
mkpins.sh          writes src/pins.mind from the H and G lines of one run of the exporter
src/main.mind      enumeration, flag column, printing, digest self-check
TOKEN_COPY_RECEIPT.txt   every line of model.mind that differs from the public source
```

## The model copy

`src/model.mind` writes bool values as `i64` because the native backend of
0.10.4 refuses a bool value outside a direct condition. `!x` is written as
`(x == 0)`, `fn` as `pub fn`, and `main` as `run_reference_checks`; two header
lines say so. `TOKEN_COPY_RECEIPT.txt` lists every changed line. It is the output
of `diff ../src/pr25_reference.mind src/model.mind`, run in this folder. The
copy is not proven equal to the public source by anything except that diff and the
gate below.

## Build and run

In the root of a fresh clone, fetch and check the compiler release first; it goes
to `mindc-0.10.4/` in the repository root (commands in `../README.md`, section
Reproduce). Then, from the repository root:

```sh
MINDC="$PWD/mindc-0.10.4/mindc"
cd mind_reference/model
"$MINDC" check
"$MINDC" build --backend native
./target/debug/pr25export > export.txt
sha256sum export.txt
```

To show that the build needs no tool on `PATH`, build with an empty `PATH` and
compare the binary (the compiler is given by its full path):

```sh
env -i PATH=/nonexistent "$MINDC" build --backend native; echo $?
sha256sum target/debug/pr25export
```

Expected: exit status 0 and the same binary SHA-256 as below. This shows that the
build does not look up a tool on `PATH`; it does not show how the compiler is
written inside.

Expected: `mindc --version` prints `mind 0.10.4` on its first line; `check` and `build` exit 0 (`check`
also prints a note that 3 `.mind` files below this folder are not in its source
set: they are the files of `pack/`, a separate package); the
binary is 85,683 bytes with SHA-256
`7a6614cf2c153b530897a8968b6d5b6adbeaf7c874778f7be14a57f20177fabb` (two clean builds
give the same bytes); the program exits 0; `export.txt` is 594,043 bytes, 6,279
lines, with SHA-256

```
4b228f500b68f57d2f5f773527f9933fdf7225ee4f0b995604f55bdaf4d954b6
```

The binary hash is a record of one build, not a pin: the gate pins the output.

## What it prints

One tagged line per item, numbers separated by one space.

| Lines | Meaning |
|---|---|
| first 5 | the five counts of `../EXPECTED_OUTPUT.txt`: `3078`, `83106`, `271453`, `302`, `42` |
| `S` x 3,078 | state: index, 13-bit encoding, depth, parent index, parent event, ten flags, permit, binding, flag column |
| `T` x 3,078 | transitions of that state for events 0..26, each as `4 * next index + output` (83,106 records) |
| `H` | two digests of the whole index-form transition table |
| `M`, `O`, `P`, `R` x 15 | per variant 1..15: full graph size and first counterexample of the separated oracle (`M`); the same for the checker that shares the model helper (`O`); first property hit per transition (`P`); number of records that differ from the baseline (`R`) |
| `Q` x 11 | per property code 1..11: number of the 15 graph variants whose first hit is that property, and the sum of the `P` counts of that property |
| `C` | counts of the exported data: `C 3078 83106 27 15 27 42` (states, transitions, events, graph variants, fold variants, variants) |
| `D` x 27 | the 27 fold variants, each with its detected flag |
| `X` | `X 27 15 6 42 33`: detected by the fold, by the separated oracle on graphs, by the shared-helper checker on graphs, and the two totals |
| `G` x 16 | digest of the full 8,192 x 27 transition table of each rule set (baseline and 15 variants) |
| `K` | `K 0`: number of digests that differ from `src/pins.mind`; the program exits 6 when it is not 0 |

Expected summary lines: `X 27 15 6 42 33` and `K 0`. For variants 7 to 15 the
shared-helper checker prints `O m 3088 83376 0 0 0` (no hit in 3,088 states and 83,376
transitions); the separated oracle finds a counterexample for each of them.

## Check it

```sh
MINDC="$PWD/mindc-0.10.4/mindc" ./mind_reference/verify/run_native_export_gate.sh
```

The script builds twice and compares the binaries, runs the program twice, compares
the output with the pinned SHA-256, the first five lines with `EXPECTED_OUTPUT.txt`
and the summary lines, and then runs the **Python leg**: it compares every state, all
83,106 transitions, the per-variant lines (the `M`, `O`, `R` and `P` lines of the 15
graph variants, with the property codes) and the total lines (`Q`, `C`, `X`) with the
public Python model in `../../reference_model/`. It prints the count of compared
values (423). The script fails closed when a tool or an input is
missing. The Python leg is a cross-language comparison with the v0.4 Python model;
a later version replaces it with a MIND comparison.

## Regenerate the pins

`src/pins.mind` holds the digests that the program checks itself against. To write it
again from one run of the exporter:

```sh
./mkpins.sh export.txt > src/pins.mind
```

The script reads the `H` and `G` lines of `export.txt`. The gate fails when the output differs from its pinned SHA-256.

## What this does not show

- It is a logical reference model. It is not a simulation, hardware validation,
  certification, or a physical robot safety proof.
- The number 25 is not claimed complete or minimal. The 42 faulty variants are a
  selected set; detecting them is not a coverage figure.
- The compiler `mindc` is written in Rust. A Rust-hosted compiler that compiles
  MIND source is not a self-hosted compiler.
- Equality with the Python model is shown for the items the gate compares. It is
  same operator, same machine, not third-party review.
- `X` counts, `O` lines and `P` lines depend on the variant definitions in
  `src/variants.mind` and `src/props.mind`; property numbers are labels of the
  public Python checkers.
