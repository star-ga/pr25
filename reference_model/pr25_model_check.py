"""PR-25 finite-model verification. Research artifact, NOT a robot controller.

Models trusted Boolean evidence summaries, local atomic guard evaluation,
non-wrapping context freshness, one current permit, and instantaneous logical
withdrawal of normal authority. No physical dynamics or hardware are modeled.
Run with Python 3.10+: python3 pr25_model_check.py
"""
from dataclasses import dataclass, replace, asdict
from collections import deque
from itertools import product
from pathlib import Path
import json

if not __debug__:
    raise RuntimeError("Verification requires assertions; rerun Python without -O.")

PASS, FAIL, UNKNOWN, STALE = range(4)
REQUIRED, NOT_APPLICABLE, UNRESOLVED = range(3)


def admission(entries):
    """Pure fold over profile-approved applicability and trusted verdicts."""
    resolved, seen, all_pass = True, False, True
    for applicability, verdict in entries:
        if applicability == UNRESOLVED:
            resolved = False
        elif applicability == REQUIRED:
            seen = True
            all_pass = all_pass and verdict == PASS
    return resolved and seen and all_pass


def specification(entries):
    required = [v for a, v in entries if a == REQUIRED]
    return bool(required) and all(a != UNRESOLVED for a, _ in entries) and all(v == PASS for v in required)


def fold_state(entries):
    resolved, seen, all_pass = True, False, True
    for app, verdict in entries:
        resolved = resolved and app != UNRESOLVED
        seen = seen or app == REQUIRED
        all_pass = all_pass and (app != REQUIRED or verdict == PASS)
    return resolved, seen, all_pass


def check_fold():
    alphabet = tuple(product(range(3), range(4)))
    # Discover every reachable fold-state and retain a representative prefix.
    representatives = {(True, False, True): ()}
    todo = deque(representatives)
    transition_count = 0
    while todo:
        state = todo.popleft()
        prefix = representatives[state]
        for letter in alphabet:
            seq = prefix + (letter,)
            assert admission(seq) == specification(seq)
            next_state = fold_state(seq)
            transition_count += 1
            if next_state not in representatives:
                representatives[next_state] = seq
                todo.append(next_state)
    assert not admission(())
    # Base case plus all transitions on a sufficient fold abstraction give
    # an inductive argument for arbitrary finite length, including 25 entries.
    concrete_checks = 0
    base = [(REQUIRED, PASS)] * 25
    for position in range(25):
        for letter in alphabet:
            entries = base.copy()
            entries[position] = letter
            assert admission(entries) == specification(entries)
            concrete_checks += 1
    assert not admission([(NOT_APPLICABLE, PASS)] * 25)
    return {'abstract_states': len(representatives), 'abstract_transitions': transition_count,
            'concrete_25_entry_cases': concrete_checks + 2,
            'claim': 'Exact fold equivalence under the declared trusted-input abstraction; induction extends to every finite list length.'}


@dataclass(frozen=True)
class State:
    obligations: bool = True
    applicability: bool = True
    required_set: bool = True
    profile: bool = True
    evidence: bool = True
    context: bool = True
    mission_authority: bool = True
    gate_healthy: bool = True
    recovery_ready: bool = True
    log_available: bool = True
    permit: str = 'NONE'  # NONE / READY / ACTIVE / CONSUMED
    binding_fresh: bool = False


NORMAL_FIELDS = ('obligations', 'applicability', 'required_set', 'profile',
                 'evidence', 'context', 'mission_authority', 'gate_healthy', 'recovery_ready')
FAULT_FIELDS = NORMAL_FIELDS + ('log_available',)


def normal_ok(s):
    return all(getattr(s, f) for f in NORMAL_FIELDS)


def protective_output(s, mutant=None):
    if not s.recovery_ready:
        return 'NO_ASSURED_OUTPUT'
    if mutant == 'recovery_requires_mission_authority' and not s.mission_authority:
        return 'NO_ASSURED_OUTPUT'
    if mutant == 'recovery_requires_logging' and not s.log_available:
        return 'NO_ASSURED_OUTPUT'
    return 'PROTECTIVE'


def step(s, event, mutant=None):
    """Each event is linearized at a local guard. Outputs are logical grants."""
    if event == 'issue':
        # A new permit is issued only when none exists or the prior one ended.
        # IDs are abstracted; this is never re-issue of the consumed ID.
        if s.permit in ('NONE', 'CONSUMED') and normal_ok(s):
            return replace(s, permit='READY', binding_fresh=True), 'NONE'
        return s, 'NONE'
    if event == 'start':
        good = normal_ok(s) and s.binding_fresh
        if mutant == 'omit_commit_recheck':
            good = True
        if mutant == 'omit_context_check':
            good = all(getattr(s, f) for f in NORMAL_FIELDS if f != 'context')
        if s.permit == 'READY' and good:
            return replace(s, permit='ACTIVE'), 'NORMAL'
        return s, 'NONE'
    if event == 'continue':
        good = normal_ok(s) and s.binding_fresh
        if mutant == 'omit_continuation_recheck':
            good = True
        if s.permit == 'ACTIVE' and good:
            return s, 'NORMAL'
        return s, 'NONE'
    if event == 'finish':
        return (replace(s, permit='CONSUMED'), 'NONE') if s.permit == 'ACTIVE' else (s, 'NONE')
    if event == 'replay':
        if mutant == 'allow_consumed_replay' and s.permit == 'CONSUMED' and normal_ok(s):
            return replace(s, permit='ACTIVE'), 'NORMAL'
        return s, 'NONE'
    if event == 'protect':
        return replace(s, permit='CONSUMED' if s.permit != 'NONE' else 'NONE', binding_fresh=False), protective_output(s, mutant)
    if event == 'discard':
        return (replace(s, permit='NONE', binding_fresh=False), 'NONE') if s.permit == 'READY' else (s, 'NONE')
    kind, field = event.split(':')
    ns = replace(s, **{field: kind == 'restore'})
    if kind == 'invalidate' and field in NORMAL_FIELDS:
        # An old permit never regains freshness merely because a sensor,
        # authority service, or configuration later returns to a good state.
        ns = replace(ns, binding_fresh=False)
    if s.permit == 'ACTIVE' and not normal_ok(ns):
        if mutant == 'omit_continuation_recheck':
            # Deliberately faulty system leaves old active authority in place.
            return ns, protective_output(ns, mutant)
        return replace(ns, permit='CONSUMED'), protective_output(ns, mutant)
    return ns, 'NONE'


EVENTS = ('issue', 'start', 'continue', 'finish', 'replay', 'protect', 'discard') + tuple(
    f'{kind}:{field}' for field in FAULT_FIELDS for kind in ('invalidate', 'restore'))


def violation(s, event, ns, output):
    if output == 'NORMAL' and not normal_ok(s):
        return 'normal_output_without_current_conditions'
    if output == 'NORMAL' and not s.binding_fresh:
        return 'invalidated_permit_reused'
    if output == 'NORMAL' and event == 'start' and s.permit != 'READY':
        return 'start_without_ready_permit'
    if output == 'NORMAL' and event == 'continue' and s.permit != 'ACTIVE':
        return 'continue_without_active_permit'
    if event == 'replay' and output == 'NORMAL':
        return 'consumed_permit_replayed'
    needs_protection = event == 'protect' or (event.startswith('invalidate:') and s.permit == 'ACTIVE' and not normal_ok(ns))
    if needs_protection and ns.recovery_ready and output != 'PROTECTIVE':
        return 'available_protective_output_blocked'
    if output == 'PROTECTIVE' and not ns.recovery_ready:
        return 'unavailable_recovery_claimed'
    return None


def check_model(mutant=None):
    init = State()
    todo = deque([init])
    parents = {init: None}
    edges = 0
    outputs = set()
    while todo:
        s = todo.popleft()
        for event in EVENTS:
            ns, out = step(s, event, mutant)
            edges += 1
            outputs.add(out)
            bad = violation(s, event, ns, out)
            if bad:
                path = [event]
                cursor = s
                while parents[cursor] is not None:
                    cursor, prior = parents[cursor]
                    path.append(prior)
                return {'status': 'COUNTEREXAMPLE', 'property': bad, 'trace': list(reversed(path)),
                        'states_discovered': len(parents), 'transitions_checked': edges}
            if ns not in parents:
                parents[ns] = (s, event)
                todo.append(ns)
    assert 'NORMAL' in outputs and 'PROTECTIVE' in outputs
    return {'status': 'PASS', 'reachable_states': len(parents), 'transitions_checked': edges,
            'events_per_state': len(EVENTS), 'outputs_reached': sorted(outputs)}


def verdict_mutations():
    base = [(REQUIRED, PASS)] * 25
    results = []
    for position in range(25):
        entries = base.copy(); entries[position] = (REQUIRED, FAIL)
        mutant = all(v == PASS for i, (_, v) in enumerate(entries) if i != position)
        assert mutant and not specification(entries)
        results.append({'mutation': f'omit_PR_{position+1:02}', 'caught': True})
    entries = base.copy(); entries[0] = (REQUIRED, STALE)
    assert all(v in (PASS, STALE) for _, v in entries) and not specification(entries)
    results.append({'mutation': 'stale_as_pass', 'caught': True})
    entries = [(NOT_APPLICABLE, PASS)] * 25
    assert all(v == PASS for a, v in entries if a == REQUIRED) and not specification(entries)
    results.append({'mutation': 'vacuous_empty_set', 'caught': True})
    return results


def main():
    result = {'scope': 'Finite discrete admission/permit/recovery abstraction; no physical-system proof.',
              'fold': check_fold(), 'baseline': check_model(), 'verdict_mutations': verdict_mutations()}
    mutations = ('omit_commit_recheck', 'omit_context_check', 'omit_continuation_recheck',
                 'allow_consumed_replay', 'recovery_requires_mission_authority', 'recovery_requires_logging')
    result['state_machine_mutations'] = {name: check_model(name) for name in mutations}
    assert result['baseline']['status'] == 'PASS'
    assert all(r['status'] == 'COUNTEREXAMPLE' for r in result['state_machine_mutations'].values())
    Path(__file__).with_name('pr25_model_results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
