# Gate log — verbatim output

Run 2026-09-13T20:20Z on x86-64 Linux (kernel 7.0.0), from a fresh anonymous
clone of the public repository.

Gates 4 and 5 were repaired in this revision after an external reviewer
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
