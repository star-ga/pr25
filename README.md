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
| `reference_model/` | — | Executable finite reference model (see status below) |

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

## Reference model — status

The reference model referenced by the Verification Note (`pr25_model_check.py`,
`pr25_verify.py`, their result JSON files and the SHA-256 manifest) is **not yet
published in this repository**. See `reference_model/STATUS.md`.

Until those files are present, the counts above are reported by the Verification
Note rather than reproducible from this repository. We would rather say that
plainly than describe evidence as reproducible before it can be reproduced.

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
