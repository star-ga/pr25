# PR-25 finite-model verification

Research artifact accompanying the PR-25 engineering revision, 13 September 2026.

This package checks selected properties of a finite admission/permit/protection model. It is not a robot controller, a proof of the physical semantics of all 25 requirement families, or a whole-system safety certificate.

## Reproduce

Use Python 3.10 or later, without optimization flags:

```sh
python3 pr25_model_check.py
```

The script uses only the standard library. It checks assertions, prints the results, and replaces the adjacent `pr25_model_results.json`. Do not use `python -O`, which disables assertions.

## Executed results

| Item | Result |
|---|---|
| Reachable supervisor states | 3,078 |
| Transitions checked | 83,106 |
| Events per state | 27 |
| Baseline safety-property violations | None in the complete reachable finite state space |
| Reachable outputs | NONE, NORMAL, PROTECTIVE, NO_ASSURED_OUTPUT |
| Admission accumulator | 6 reachable states; 72 transitions |
| Additional concrete admission cases | 302, including 25-entry cases and empty-required-set cases |
| Selected verdict mutants | 27 of 27 detected |
| Selected supervisor mutants | 6 of 6 detected |

The 27 verdict mutants comprise omission of each indexed obligation (25 cases), accepting STALE, and admitting an empty required set. These use constructed counterexamples. The six supervisor mutants are explored by breadth-first search until a shortest counterexample is found. Their traces are in the JSON. The combined 33/33 result describes this deliberately selected mutation set; it does not estimate general fault coverage.

## Admission proposition

Admission is true exactly when applicability is resolved for every entry, at least one entry is required, and every required verdict is PASS. NOT_APPLICABLE is trusted profile input; this function does not authorize an N/A decision. Inputs are assumed to be members of the declared finite enumerations. A production parser must reject malformed inputs before calling an evaluator.

The accumulator has three meanings for each processed prefix: all applicability dispositions are resolved; some entry is required; all required entries are PASS. The empty-prefix base case and the update for each of the 12 possible input letters preserve these meanings. Their conjunction therefore equals the independent set-based definition for every finite length, including 25. The script explores all reachable accumulator states with representative prefixes and checks all next letters. This is an explicit inductive argument plus executable checks, not a proof-assistant-certified theorem.

## Supervisor and properties

Ten Boolean state summaries abstract obligations, applicability, a nonempty required set, approved profile, evidence, context, mission authority, gate health, recovery readiness, and logging. Permit states are NONE, READY, ACTIVE, and CONSUMED. A separate binding flag is permanently invalidated for that permit by relevant dependency changes. Restoring good conditions does not revive the old binding; a new permit must be issued.

The 27 events issue, start, continue, finish, replay, protect, discard, or invalidate/restore each Boolean summary. Every event is atomic at a local guard. The finite graph is exhausted by breadth-first search. The checker verifies:

- NORMAL requires every current normal condition and a fresh permit binding.
- Start requires READY; continuation requires ACTIVE.
- Replay never grants NORMAL.
- Requested or triggered protection is granted when recovery readiness holds, including when mission authority or logging is unavailable.
- PROTECTIVE is never asserted when the modeled recovery-readiness premise is false.

If recovery readiness is lost during active operation, the model exposes NO_ASSURED_OUTPUT. This deliberately prevents an unsupported claim that some safe physical action must always exist. Recovery readiness is an assumption, not a controller feasibility proof.

## Counterexample examples

- Omit execution recheck: issue, invalidate obligations, start.
- Omit continuation recheck: issue, start, invalidate obligations, continue.
- Require mission authority for protection: invalidate mission authority, protect.
- Require logging for protection: invalidate logging, protect.

The baseline rejects the faulty normal grants and permits the available protective grants. Reaching both NORMAL and PROTECTIVE establishes basic non-vacuity; useful real-world task completion is not measured.

## Scope and proof gap

All evidence summaries are trusted. Expiry is a Boolean invalidation event, not a timed automaton. Context and binding abstract version changes and a single current permit; no wrapping counters, identifier collisions, concurrent distributed owners, cryptographic verification, crash-persistent ledger, or reboot reconciliation are implemented. Outputs are logical grants, not actuator motion. Authority withdrawal is instantaneous in logical time. Gate health is a trusted summary; the code does not prove that faulty hardware enforces itself.

This package does not model robot dynamics, contact, sensor-error distributions, state-estimator soundness, scheduling, actuation delay, stopping, recovery feasibility, attacks, privacy operations, adaptation, or physical truth of outcomes. Each of the 25 obligation positions can block admission, but its underlying physical predicate is not proved here.

The trust base includes this custom checker, its property definitions, the abstraction, Python, and assertion execution. No independent proof certificate is supplied. A production assurance effort should encode an agreed model in an independently reviewed verification tool and prove/refute the refinement from implementation and hardware into that model.

## Conditional physical theorem: obligation, not completed proof

Let S be a physical hard safety set and K a subset from which the designated protective controller maintains S. If the initial possible state is in K; every admitted normal segment stays in S throughout its uncertainty- and delay-inclusive reachable tube and retains handover states in K; the protective controller maintains S under the declared faults; the implemented guard, timing and actuators refine those models; and the stated environmental assumptions hold or their loss is detected before safe handover becomes infeasible, then the trajectory remains in S over the claimed interval.

The proof argument composes continuous-time segment guarantees by induction over normal/protective transitions. Unbounded-time claims also need time divergence; eventual recovery needs a separate progress argument. None of those physical premises is discharged by this finite supervisor model. The accompanying engineering PDF specifies the required evidence.
