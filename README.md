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
| `mind_reference/` | — | Independent MIND implementation plus cross-language gates |

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
python3 pr25_model_check.py
python3 pr25_verify.py --output /tmp/verified.json
```

Python 3.10 or later. Standard library only, no dependencies. Do not pass `-O`:
the original module refuses optimized mode because its checks are assertions.
A nonzero exit is a failed run, not an inconclusive pass.

The three Python artifact digests remain those pinned in the Verification Note.

---

## Two implementations, one model

The same finite model is implemented through separate Python and MIND paths.
The complete baseline encoded transition relation — 8,192 state encodings × 27
events = **221,184 transitions** — is compared record-by-record:

```text
221184/221184 transition records identical (8192 x 27)
```

An earlier checksum-only comparison was insufficient because distinct
transcripts can share a rolling digest. The current gate compares every record,
checks both exit statuses, and asserts the exact record count.

PR-25 also defines a shared canonical malformed-input descriptor boundary. The
MIND and Python implementations independently classify **7,000 bounded
shape/type/code descriptors**, structural refusals before semantic admission,
with explicit refusal codes. The gate compares all records and contains a
negative control that must detect deliberate transcript corruption. Python-only
runtime-object hazards remain separately tested at the Python boundary rather
than being presented as fake MIND equivalents.

See `mind_reference/README.md` for the native build, compiler pin, gates, scope,
and remaining open items.

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
