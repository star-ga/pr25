# Gate log — verbatim output

Historical record of the 2026-09-13 run with mind 0.10.2 (the sections before the 2026-11-26 entry). With mind 0.10.4 this source builds only through the MLIR route. The Provenance hashes are of the files at that run; later commits changed two of the listed files (the gate runner, and the opening sentence of the docstring of the comparison implementation), see `git log`.

Run 2026-09-13T20:20Z on x86-64 Linux (kernel 7.0.0), from a fresh anonymous
clone of the public repository.

Gates 4 and 5 were repaired in this revision after a review
demonstrated that both could pass without establishing their claim. See
"Falsifiability" below: each repaired gate was mutation- or fault-tested and
observed to go red.

## Provenance

```
compiler binary   sha256 390fa5792d707e7a7807b2243d9c5954e28d53ca2cc3e90dd91746ab6793fc53
compiler version  mind 0.10.2, features: mlir-build
source received   sha256 542532c9a03d5dc3006f33bea2fb1006bc4637eae270683d77b548186f93b265
source compiled   sha256 18bf2915a81e73b3166593254fefcb3d34e03bdc574ea7e1cd5fbfd04e8fba47
parity source     sha256 89e703c93803d95704db5c01b6e62dfecfffb6e0c8bf3d524d4919099632cb09
gate runner       sha256 3183d5fb50b0f71929ce1775e629d72b06dcf160e8b22c9d9109bbf03924b155
comparison impl   sha256 0d5cda7d9d4e9df78625f420593c11fb641ae037350df84c2a8814cfddce21a6
binary            sha256 b85bf2c9de888785851ece965d8f4167a2a039555c5f719c7e91d7c39412a585
target            x86-64 ELF PIE, glibc, 50280 bytes
```

The compiler binary hash pins the executable, not the compiler source commit
and dependency set required to reproduce it. `star-ga/mind` is a moving branch.
Rebuilding the toolchain from a clean environment is a stronger test than this.

## `verify/run_gates.sh`

```
== mindc ==
mind 0.10.2
core-ir=1.0
== GATE 1: check + native build ==
  PASS  reference builds natively (50280 bytes)
== GATE 2: output vs EXPECTED_OUTPUT.txt ==
  PASS  5/5 counts exact
== GATE 3: run-to-run determinism (10x) ==
  PASS  1 distinct output hash over 10 runs
== GATE 4: rebuild byte-identity ==
  PASS  byte-identical across clean rebuild (b85bf2c9de888785)
== GATE 5: cross-language parity, all 221,184 transition records ==
  PASS  221184/221184 transition records identical (8192 x 27)
== GATE 6: supplied comparison script ==
  PASS  check_compiled_output.sh

TOTALS: pass=6 fail=0
```

Exit status 0.

## Falsifiability

A gate that cannot fail is not a gate. Both repaired gates were tested by
injecting the defect they are meant to catch.

### Gate 5 — the reviewer's digest-cancelling counterexample

The previous revision compared one rolling checksum per side,
`h = (31*h + result + 7) mod 1e9+7`. Perturbing record *(state 8, event 0)* by
`+1` and record *(state 8, event 1)* by `-31` cancels exactly
(`31*(+1) + (-31) = 0`), so two different transcripts produced the same digest
and the gate passed. That exact mutation was injected into the MIND parity
source and the repaired gate run:

```
== GATE 5: cross-language parity, all 221,184 transition records ==
  FAIL  parity MISMATCH: 2 differing records
217,218c217,218
< 33
< 1
---
> 32
> 32

TOTALS: pass=5 fail=1
```

The gate goes red and names both differing records.

### Gate 4 — injected rebuild failure

The previous revision's cleanup removed `<proj>/target/target`, a path that
never exists, so the in-place rebuild reused a warm target directory and the
gate compared a hash to itself. A compiler stand-in was used to fail the
in-place rebuild while leaving the earlier executable on disk:

```
== GATE 4: rebuild byte-identity ==
INJECTED REBUILD CHECK FAILURE
BUILD FAILED for pr25ref (src/pr25_reference.mind)
```

Exit status 1. The runner aborts rather than accepting a stale binary. Against
the previous revision the same injection produced `TOTALS: pass=6 fail=0` and
exit status 0.

Note that the byte-identity *result* was unchanged by the repair: the rebuild
hash is `b85bf2c9de888785` both before and after. The binary was reproducible;
the old gate simply never established it.

## 2026-11-26: native exporter gate (`verify/run_native_export_gate.sh`)

Compiler: the public mindc 0.10.4 release (`mind 0.10.4`, archive SHA-256 `b887ddedaa03a5a5d7124456d4b433bce5782b66d9dacac58c9dcf9083dc8003`, compiler binary SHA-256 `eb0b96d6f0f52c65199df22824e31a93b27119bff60dc239f530a36c28bc0502`), native backend only. x86-64 Linux.

Command: `MINDC=<path>/mindc-0.10.4/mindc ./verify/run_native_export_gate.sh`

Result: TOTALS pass=7 fail=0, exit 0. The Python leg compares the per-variant lines (M, O, R, P) and the total lines (Q, C, X) of the exporter, 423 values. Verbatim output; the compiler progress lines that name a scratch folder are left out:

```
== mindc ==
mind 0.10.4
== GATE 1: check + build, native backend ==
  PASS  builds on the native backend (85683 bytes)
== GATE 2: two clean builds, byte-identical ==
  PASS  binaries equal (7a6614cf2c153b53)
== GATE 3: run, pinned output SHA-256, summary lines ==
  PASS  two runs exit 0, identical output
  PASS  output SHA-256 equals the pin (4b228f500b68f57d)
  PASS  first 5 lines equal EXPECTED_OUTPUT.txt (3078 / 83106 / 271453 / 302 / 42)
  PASS  summary lines 'X 27 15 6 42 33' and 'K 0' present
== GATE 4: Python leg, states, 83,106 transitions, per-variant lines, total lines ==
    ok   state list equals the Python reachable set (3078 states, ascending)
    ok   depth, parent state and parent event of every state equal the Python search (differences 0)
    ok   all 83106 (state, event) transition records equal the Python step (differences 0)
    ok   variants 1..15, M lines: separated oracle: states, transitions, found, property code, trace (bad: [])
    ok   variants 1..15, O lines: original checker: states, transitions, found, property code, trace (3,088 / 83,376 and no hit for 7..15) (bad: [])
    ok   variants 1..15, R lines: records that differ from the baseline (bad: [])
    ok   variants 1..15, P lines: first property hit per transition, 11 property counts (bad: [])
    ok   total lines Q 1..11: first-hit variants and hit transitions per property equal the Python sums
    ok   fold variants: 27 listed, all detected, as in the Python model
    ok   total line C: states, transitions, events, graph variants, fold variants, variants equal the Python counts
    ok   X line equals the Python counts (fold, separated, original, totals)
    ok   every graph variant has a separated-oracle hit
compared values (per-variant and total lines): 423
  PASS  Python leg: every compared item equal

TOTALS: pass=7 fail=0
```

Mutation check of the Python leg, on scratch copies of the repository. Each change was made in `model/src/variants.mind`, one at a time; the gate exits 1 and the Python leg names the line kind:

- one `P` value of variant 3 raised by 1: `FAIL variants 1..15, P lines: ... (bad: [3])`
- the `R` value of variant 9 raised by 1: `FAIL variants 1..15, R lines: ... (bad: [9])`
- the total `Q` value of property 4 raised by 1: `FAIL total lines Q 1..11: ...`

## 2026-11-26: pack gate (`verify/run_pack_gate.sh`)

Compiler: the public mindc 0.10.4 release (`mind 0.10.4`, compiler binary SHA-256 `eb0b96d6f0f52c65199df22824e31a93b27119bff60dc239f530a36c28bc0502`), native backend only, for the exporter and the packer. x86-64 Linux. The gate runs no node and no python.

Command: `MINDC=<path>/mindc-0.10.4/mindc ./verify/run_pack_gate.sh`

Result: `TOTALS: pass=23 fail=0`, exit 0. Gate 4 runs eleven refusal cases (bad input, and a closed fd 0 or fd 7) and checks each error code 1 to 9 at least once. Packer binary (`model/pack`, `pr25pack`): 25,760 bytes, SHA-256 `3fef2d54392dfc5876c270a3f179ef1b3573f1b8850321616823dbb3c4b689f4` (two clean builds equal). The five files equal the pins in `model/pack/PACK_SHA256SUMS.txt`. Verbatim output; the compiler progress lines that name a scratch folder are left out:

```
== mindc ==
mind 0.10.4
== GATE 1: exporter and packer, check + build, native backend, twice each ==
  PASS  exporter: two clean native builds, equal binaries (85683 bytes, 7a6614cf2c153b53)
  PASS  packer: two clean native builds, equal binaries (25760 bytes, 3fef2d54392dfc58)
== GATE 2: run the exporter, pinned output SHA-256 ==
  PASS  exporter exits 0
  PASS  output SHA-256 equals the pin (4b228f500b68f57d)
== GATE 3: pack, five files against PACK_SHA256SUMS.txt ==
  PASS  packer exits 0
  PASS  the pinned list holds 5 files
states.u16le.bin: OK
depth.u8.bin: OK
flags.u8.bin: OK
parent.u16le_u8.bin: OK
transitions.u16le.bin: OK
  PASS  sha256sum -c: all five files equal the pins
  PASS  states.u16le.bin is 6156 bytes
  PASS  depth.u8.bin is 3078 bytes
  PASS  flags.u8.bin is 3078 bytes
  PASS  parent.u16le_u8.bin is 9234 bytes
  PASS  transitions.u16le.bin is 166212 bytes
== GATE 4: the packer refuses each kind of bad input with its own error code ==
  PASS  last 100 lines removed: exit 4, pr25pack: error 4 line 0
  PASS  two spaces in line S 7: exit 3, pr25pack: error 3 line 13
  PASS  C line repeated: exit 4, pr25pack: error 4 line 6262
  PASS  C line says 3077 states: exit 5, pr25pack: error 5 line 0
  PASS  line S 5 one number short: exit 6, pr25pack: error 6 line 11
  PASS  line T 2 one value short: exit 7, pr25pack: error 7 line 3086
  PASS  line T 0 next index 3078: exit 7, pr25pack: error 7 line 3084
  PASS  C line says 83105 transitions: exit 8, pr25pack: error 8 line 0
  PASS  input over 8 MiB: exit 2, pr25pack: error 2 line 0
  PASS  fd 0 closed: exit 1, pr25pack: error 1 line 0
  PASS  fd 7 closed: exit 9, pr25pack: error 9 line 0

TOTALS: pass=23 fail=0
```

## 2026-11-26: artifact gate (`verify/run_artifact_gate.sh`)

Compiler: the public mindc 0.10.4 release (`mind 0.10.4`, compiler binary SHA-256 `eb0b96d6f0f52c65199df22824e31a93b27119bff60dc239f530a36c28bc0502`). x86-64 Linux. The gate runs no node and no python.

Command: `MINDC=<path>/mindc-0.10.4/mindc ./verify/run_artifact_gate.sh`

Result: `TOTALS: pass=21 fail=0`, exit 0. Artifact `pr25.mic3`: 101,641 bytes, SHA-256 `cc69f21c943bc10f384660fa647b9496e2698161da73356b1fdd1dae778013e3`; plain body 9,461 bytes; MAP 92,180 bytes, 1,254 entries (6 of the compiler, 1,248 under `ga.star.pr25.`). The trace hash covers the IR body only; the records are pinned by the file SHA-256. Verbatim output:

```
== mindc ==
mind 0.10.4
== GATE 1: records.txt form ==
  PASS  ends with a line feed
  PASS  1248 lines, each 'ga.star.pr25.<key>=<value>' (no empty line)
  PASS  no carriage return
  PASS  keys unique and in byte order
  PASS  line count equals namespace_entries of ARTIFACT_FACTS.txt
== GATE 2: two clean builds, byte-identical ==
  PASS  artifacts equal (101641 bytes) and bodies equal
== GATE 3: SHA-256 pins ==
pr25.mic3: OK
pr25.body.mic3: OK
  PASS  pr25.mic3 and pr25.body.mic3 equal ARTIFACT_SHA256SUMS.txt
  PASS  the pinned list holds 2 files
== GATE 4: mindc verify, trace hash ==
  PASS  mindc verify exits 0 and prints 'trace_hash_valid: yes'
  PASS  trace hash equals ARTIFACT_FACTS.txt (993a9ac50b9c7133)
  PASS  trace hash equals the SHA-256 of the plain body (kind mic3-bytes)
  PASS  mindc inspect exits 0 and prints 'attested: YES'
== GATE 5: plain body is the first part, MAP at the offset ==
  PASS  the first 9461 bytes of the artifact equal the plain body
  PASS  byte at offset 9461 is 0x4D (MAP sentinel)
  PASS  sizes equal the facts: artifact 101641, body = MAP offset 9461, MAP 92180
== GATE 6: the MAP holds every line of records.txt ==
  PASS  'ga.star.pr25.' occurs 1248 times in the MAP part, once per line of records.txt
  PASS  the build with no records has the same body and 6 compiler entries
  PASS  MAP entry count 6 + 1248 = 1254 equals the facts
  PASS  the artifact equals body + 0x4D + count + the 6 compiler entries + one string entry per line, in line order
  PASS  one record changed by one character: a different artifact SHA-256
  PASS  the same change leaves the trace hash unchanged: the records are pinned by the file SHA-256, not by the trace hash

TOTALS: pass=21 fail=0
```

Mutation proofs, each in a scratch copy, every one red (exit 1); the unmutated copy is green (`TOTALS: pass=21 fail=0`):

- one character of one record value changed: `FAIL  sha256sum -c: a file differs from its pin`
- one record line removed: `FAIL  1247 lines, facts say 1248`
- one hex digit of the artifact pin changed: `FAIL  sha256sum -c: a file differs from its pin`
- a record `evidence_chain.x=1` added: the compiler refuses it, ``mindc: error[emit-evidence]: application evidence key `evidence_chain.x` uses the reserved `evidence_chain.` namespace``, and `FAIL  build a: mindc refused the records`
- one token of `model/src/model.mind` changed (`while i < 9` to `while i < 8`): `FAIL  trace hash '967d2a9051b0f71ce8328f1d2bd4514344758e656a31077b1227f75bfd076cd0' differs from the facts`
