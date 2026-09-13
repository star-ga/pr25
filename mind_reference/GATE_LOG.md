# Gate log — verbatim output

Run 2026-09-13T18:14:35Z on x86-64 Linux (kernel 7.0.0).

## Provenance

```
compiler binary   sha256 390fa5792d707e7a7807b2243d9c5954e28d53ca2cc3e90dd91746ab6793fc53
compiler version  mind 0.10.2, features: mlir-build
source received   sha256 542532c9a03d5dc3006f33bea2fb1006bc4637eae270683d77b548186f93b265
source compiled   sha256 18bf2915a81e73b3166593254fefcb3d34e03bdc574ea7e1cd5fbfd04e8fba47
binary            sha256 b85bf2c9de888785851ece965d8f4167a2a039555c5f719c7e91d7c39412a585
target            x86-64 ELF PIE, glibc, 50280 bytes
```

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
== GATE 5: cross-language parity, all 221,184 transitions ==
  PASS  MIND 596895410 == independent reference 596895410 (8192 x 27)
== GATE 6: supplied comparison script ==
  PASS  check_compiled_output.sh

TOTALS: pass=6 fail=0
```

## `verify/independent_reference.py`

```
$ python3 verify/independent_reference.py
596895410
```

## `docs/token_diff.py`

```
received tokens : 2707
compiled tokens : 2723
ADDED           : ['{', '}']  counts={'}': 8, '{': 8}
REMOVED         : none

RESULT: formatting-only change PROVEN
```
