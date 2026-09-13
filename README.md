# PR-25 — The 25 Robot Commandments

**Candidate assurance requirement families for consequential robot actuation.**

Public technical paper, verification note, and reference model.
Version 0.4 · 13 September 2026 · STARGA

---

## The central requirement

**NO UNADMITTED CONSEQUENTIAL ACTION.**

Within a declared operating domain, fault model and trust boundary, commanded
consequential actuation must remain covered by a currently valid normal or
protective contract.

For normal authority, every applicable hard obligation due at that decision
point must PASS. FAIL, UNKNOWN or STALE does not confer normal authority. A
missing required obligation is not permission. "Not applicable" requires a
justified operating-profile decision.

Denying normal authority is not the same as removing power. A moving robot may
need to brake; a manipulator may need to retain a load. Protective behaviour
needs its own valid contract, operating envelope and response bound.

---

## Contents

| File | Pages | What it is |
|---|---|---|
| `PR25_Public_Technical_Paper_v0.4.pdf` | 18 | All 25 requirement families, admission rules, evidence requirements, physical-assurance boundaries, worked example, validation plan, open proof obligations, 16 references |
| `PR25_Verification_Note_v0.4.pdf` | 3 | What was executed, the verification weakness found and repaired, exact counts, source hashes, reproduction commands, limits |
| `PR25_Public_Brief_v0.4.pdf` | 4 | Short introduction and the complete 25-family index |
| `reference_model/` | — | Executable finite reference model (Python) — runnable, standard library only |
| `mind_reference/` | — | Independent implementation of the same model in MIND, compiled natively |

---

## What the evidence covers

The accompanying finite reference model has **3,078 reachable states**,
exhaustively enumerated over **27 events each**. The strengthened verification
suite detects all **42 explicitly selected faulty variants**.

The audit found and repaired a real verification weakness: the original model
and its property checker called the same `normal_ok` helper, so weakening that
shared helper weakened both the implementation and the test's definition of
correctness. The repaired oracle states the expected conditions separately. The
unmodified baseline still passes.

**These are logical reference-model results.** They are not simulation,
hardware validation, certification, or a physical robot safety proof. The paper
keeps three claims distinct — admission integrity, modeled physical
preservation, and application assurance — and each requires its own evidence.

The number 25 organises this edition. It is **not** claimed to be a complete or
mathematically minimal basis.

---

## Reference model — reproduce it yourself

The executable finite reference model is in `reference_model/`, published
byte-unchanged from the audited source.

```sh
cd reference_model
python3 pr25_model_check.py                        # original checker, unchanged
python3 pr25_verify.py --output /tmp/verified.json # strengthened verifier
```

Python 3.10 or later. Standard library only, no dependencies. Do not pass `-O`:
the original module refuses optimized mode, because its checks are assertions.
A nonzero exit is a failed run, not an inconclusive pass.

`pr25_model_check.py` overwrites its adjacent `pr25_model_results.json`; run it
in a copy if you want to preserve the recorded bytes.

| File | What it is |
|---|---|
| `pr25_model_check.py` | Original checker, unchanged |
| `pr25_model_results.json` | Original recorded results |
| `pr25_verify.py` | v0.4 strengthened verifier (separately stated oracle) |
| `verified_results.json` | Executed v0.4 results |
| `ORIGINAL_README.md` | Historical source explanation |
| `README_v0.4.md` | v0.4 reference-model notes |

Source digests, as pinned in the Verification Note:

```
e5b69731fa56e4b0223a6c847c5a46cf23d834052d3b71403b37f3fb93311fe8  pr25_model_check.py
49f6c73b7cd35f9d7e90be91d4b632edfe83d71718cb554f80d418e532b8d710  pr25_model_results.json
f886e034955b6143cf6c3673363a8293814f25bde523d1ac5d5a1ac1187ac740  pr25_verify.py
```

These are integrity checks. They are not signatures, certification, or evidence
about the physical truth of any input.

**Interpreter note.** The Verification Note's run used CPython 3.13.5. The
recorded `verified_results.json` embeds that interpreter version, so a run on a
different supported interpreter reproduces every check and every count while
differing in that metadata field. The model counts do not depend on the
interpreter version.

---

## Two implementations, one model

The same finite model is implemented twice, in two languages, by two separate
paths:

| | `reference_model/` | `mind_reference/` |
|---|---|---|
| Language | Python | MIND |
| Role | The audited artifact — every number in the Verification Note was produced by this code, and its bytes are digest-pinned | An independent implementation, compiled to a native executable |
| Run | `python3 pr25_verify.py` | `./verify/run_gates.sh` |

Both were run over the entire encoded transition relation — 8,192 state
encodings x 27 events = **221,184 transitions** — and agree:

```
MIND        596895410
independent 596895410
```

The comparison implementation used for that check was written from the
specification, not transliterated from the code under test. This is the
complement to the shared-helper repair described above: that fix removed a
shared *oracle* dependency within one implementation; this removes the shared
*implementation* dependency entirely.

Cross-language agreement is evidence that the model's behaviour is a property
of the specification rather than of one language, one runtime, or one author's
reading. It is **not** third-party certification — same operator, same machine.

See `mind_reference/README.md` for gates, digests and reproduction.

---

## Reviewing this work

We welcome concrete counterexamples. A useful submission identifies:

- the operating profile and its assumptions
- the affected family, or the missing responsibility
- the initial state and the sequence of events
- the output or physical outcome that contradicts the claim

Please distinguish a flaw in the requirements from a violated assumption, an
implementation defect, or an inadequate validation argument.

**Counterexamples should improve the registry — not be forced into it.**

Open an issue, or use the discussion tab.

---

## Scope

PR-25 is an implementation-neutral requirements proposal. It does not depend on
a particular product, provider, programming language or implementation design.
It is not a safety certificate, and no certification or endorsement by any cited
organisation is implied.

© 2026 STARGA, Inc. Documents released for public review and comment.
