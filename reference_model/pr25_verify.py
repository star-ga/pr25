"""PR-25 v0.4 reference-model audit; NOT a robot controller.

Preserves the supplied transition model. The verification oracle below does not
call its normal_ok helper. All results are finite logical checks, not physical
assurance. Python 3.10+, standard library only. Exit nonzero on any failed check.
Run: python3 pr25_verify.py --output verified_results.json
"""
from __future__ import annotations
import argparse
from collections import deque
from dataclasses import fields
import hashlib
import importlib.util
from itertools import product
import json
from pathlib import Path
import platform
import sys
from typing import Any

HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'pr25_model_check.py'
EXPECTED_SOURCE = 'e5b69731fa56e4b0223a6c847c5a46cf23d834052d3b71403b37f3fb93311fe8'

def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)

require(hashlib.sha256(SOURCE.read_bytes()).hexdigest() == EXPECTED_SOURCE,
        'Reference source hash mismatch; review and version any change.')
spec = importlib.util.spec_from_file_location('pr25_reference', SOURCE)
require(spec is not None and spec.loader is not None, 'Cannot load reference')
m = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = m
spec.loader.exec_module(m)

# Stable model correspondence, not introspection of the implementation's list.
FIELD_NAMES = ('obligations', 'applicability', 'required_set', 'profile',
               'evidence', 'context', 'mission_authority', 'gate_healthy',
               'recovery_ready', 'log_available')
PERMITS = ('NONE', 'READY', 'ACTIVE', 'CONSUMED')
OUTPUTS = ('NONE', 'NORMAL', 'PROTECTIVE', 'NO_ASSURED_OUTPUT')
EVENT_NAMES = ('issue', 'start', 'continue', 'finish', 'replay', 'protect', 'discard') + tuple(
    f'{kind}:{field}' for field in FIELD_NAMES for kind in ('invalidate', 'restore'))


def contract_normal(s: Any) -> bool:
    """Separately stated oracle: never delegates to m.normal_ok."""
    return (s.obligations and s.applicability and s.required_set and s.profile
            and s.evidence and s.context and s.mission_authority
            and s.gate_healthy and s.recovery_ready)


def oracle_violation(s: Any, event: str, ns: Any, out: str) -> str | None:
    if out not in OUTPUTS:
        return 'invalid_output_code'
    if out == 'NORMAL' and not contract_normal(s):
        return 'normal_output_without_current_conditions'
    if out == 'NORMAL' and not s.binding_fresh:
        return 'invalidated_permit_reused'
    if out == 'NORMAL' and event not in ('start', 'continue'):
        return 'normal_output_on_unpermitted_event'
    if out == 'NORMAL' and event == 'start' and s.permit != 'READY':
        return 'start_without_ready_permit'
    if out == 'NORMAL' and event == 'continue' and s.permit != 'ACTIVE':
        return 'continue_without_active_permit'
    if out == 'NORMAL' and (ns.permit != 'ACTIVE' or not ns.binding_fresh
                            or not contract_normal(ns)):
        return 'invalid_post_grant_state'
    if ns.permit == 'ACTIVE' and (not contract_normal(ns) or not ns.binding_fresh):
        return 'active_authority_retained_after_invalidation'
    needs = event == 'protect' or (event.startswith('invalidate:') and s.permit == 'ACTIVE'
                                  and not contract_normal(ns))
    if needs and ns.recovery_ready and out != 'PROTECTIVE':
        return 'available_protective_output_blocked'
    if out == 'PROTECTIVE' and not ns.recovery_ready:
        return 'unavailable_recovery_claimed'
    return None


def pack(s: Any) -> int:
    f = sum(int(getattr(s, name)) << i for i, name in enumerate(FIELD_NAMES))
    return f + PERMITS.index(s.permit)*1024 + int(s.binding_fresh)*4096


def unpack(n: int) -> Any:
    return m.State(**{name: bool((n >> i) & 1) for i, name in enumerate(FIELD_NAMES)},
                   permit=PERMITS[(n//1024) % 4], binding_fresh=bool(n//4096))


def transition_spec(n: int, event: int) -> tuple[int, str]:
    """Separately written arithmetic specification for all 8192 encodings.

    No calls into the implementation, no generated transition table.
    Flags 0..8 are normal prerequisites; flag 9 is log availability.
    """
    f, p, b = n % 1024, (n//1024) % 4, n//4096
    good = f % 512 == 511
    out = 0
    if event == 0:
        if p in (0, 3) and good: p, b = 1, 1
    elif event == 1:
        if p == 1 and good and b == 1: p, out = 2, 1
    elif event == 2:
        if p == 2 and good and b == 1: out = 1
    elif event == 3:
        if p == 2: p = 3
    elif event == 4:
        pass
    elif event == 5:
        if p != 0: p = 3
        b = 0
        out = 2 if (f//256) % 2 else 3
    elif event == 6:
        if p == 1: p, b = 0, 0
    else:
        field, value = (event-7)//2, (event-7) % 2
        weight = 2**field
        f = f - ((f//weight) % 2)*weight + value*weight
        if value == 0 and field < 9: b = 0
        if p == 2 and f % 512 != 511:
            p = 3
            out = 2 if (f//256) % 2 else 3
    return f + 1024*p + 4096*b, OUTPUTS[out]


def graph_check(mutant: str | None = None) -> dict[str, Any]:
    start = m.State()
    q = deque([start]); parents = {start: None}; edges = 0; outputs = set()
    while q:
        s = q.popleft()
        for event in EVENT_NAMES:
            ns, out = m.step(s, event, mutant)
            edges += 1; outputs.add(out)
            bad = oracle_violation(s, event, ns, out)
            if bad is not None:
                path = [event]; c = s
                while parents[c] is not None:
                    c, e = parents[c]; path.append(e)
                return {'status': 'COUNTEREXAMPLE', 'property': bad,
                        'trace': path[::-1], 'states_discovered': len(parents),
                        'transitions_checked': edges}
            if ns not in parents:
                parents[ns] = (s, event); q.append(ns)
    require({'NORMAL','PROTECTIVE'} <= outputs, 'Vacuous graph: missing useful logical output')
    return {'status':'PASS','reachable_states':len(parents),'transitions_checked':edges,
            'events_per_state':len(EVENT_NAMES),'outputs_reached':sorted(outputs)}


def reachable_encoding(n: int) -> bool:
    p, b, good = (n//1024) % 4, n//4096, n % 512 == 511
    if p == 0: return b == 0
    if p == 2: return b == 1 and good
    return b == 0 or good


def witness_events(n: int) -> tuple[str, ...]:
    p, b = (n//1024) % 4, n//4096
    prefix: tuple[str, ...] = ()
    if p == 1:
        prefix = ('issue',) if b else ('issue', 'invalidate:obligations')
    elif p == 2:
        prefix = ('issue','start')
    elif p == 3:
        prefix = ('issue','start','finish') if b else ('issue','protect')
    target = n % 1024
    return prefix + tuple(('restore:' if (target >> i) & 1 else 'invalidate:') + name
                          for i,name in enumerate(FIELD_NAMES)
                          if not b or i == 9)


def check_census() -> dict[str, Any]:
    count = 0; closure = 0; max_witness = 0
    for n in range(8192):
        if not reachable_encoding(n): continue
        s=m.State(); events=witness_events(n)
        for event in events: s,_=m.step(s,event)
        require(pack(s)==n, f'Reachability witness failed {n}')
        count += 1; max_witness=max(max_witness,len(events))
        for event in EVENT_NAMES:
            ns,_=m.step(s,event)
            require(reachable_encoding(pack(ns)),f'Reachability set not closed {n} {event}')
            closure += 1
    require(count==3078 and closure==83106,'Constructive census mismatch')
    return {'constructively_reached_states':count,'closure_transitions':closure,
            'maximum_witness_length':max_witness,
            'method':'Closed candidate set containing the initial state, with a concrete initial-state witness for every member.'}


def strict_admission(entries: object) -> bool:
    """Fail-closed model boundary for finite lists/tuples of declared codes.

    Does not establish authenticity, applicability approval, obligation-ID
    completeness, or physical evidence truth. This is not a production parser.
    """
    if type(entries) not in (list, tuple): return False
    seen = False
    for item in entries:
        if type(item) not in (list, tuple) or len(item) != 2: return False
        a, v = item
        if type(a) is not int or type(v) is not int: return False
        if a < 0 or a > 2 or v < 0 or v > 3: return False
        if a == 2: return False
        if a == 0:
            seen = True
            if v != 0: return False
    return seen


def set_definition(seq: tuple) -> bool:
    return (any(a == 0 for a, _ in seq)
            and not any(a == 2 for a, _ in seq)
            and not any(a == 0 and v != 0 for a, v in seq))


def check_sequences() -> dict[str, Any]:
    alphabet = tuple(product(range(3), range(4)))
    total = 0
    for n in range(6):
        for seq in product(alphabet, repeat=n):
            expect = set_definition(seq)
            require(m.admission(seq) == expect, f'Original fold mismatch at {seq}')
            require(strict_admission(seq) == expect, f'Hardened fold mismatch at {seq}')
            total += 1
    # Malformed cases are extra-domain hardening, not original-model counterexamples.
    malformed = [None, True, 7, '00', {'app':0}, [(0,)], [(0,0,0)], [None],
                 [(0,0),(99,1)], [(-1,0)], [(0,-1)], [(0,4)], [(False,0)],
                 [(0,False)], [(0.0,0)], [(0,0.0)], [(0,float('nan'))],
                 [(0,0),('0',0)], [(0,0),(1,999)]]
    for x in malformed: require(not strict_admission(x), f'Malformed input admitted: {x!r}')
    return {'bounded_sequence_cases':total,'lengths':[0,1,2,3,4,5],
            'alphabet_size':12,'malformed_input_cases':len(malformed),
            'original_case_accounting':{'positional_25_entry_cases':300,
              'all_not_applicable_25_entry_case':1,'empty_sequence_case':1,
              'total_executed':302,'distinct_sequences':278},
            'scope':'Bounded enumeration plus the separately stated fold induction; not a physical predicate proof.'}


def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=HERE/'verified_results.json')
    args=parser.parse_args()
    require(EVENT_NAMES==m.EVENTS,'Event correspondence changed')
    require(tuple(f.name for f in fields(m.State)) == FIELD_NAMES+('permit','binding_fresh'),
            'State correspondence changed')
    baseline=graph_check()
    require(baseline['reachable_states']==3078 and baseline['transitions_checked']==83106,
            'Unexpected baseline graph')
    comparison_count=0
    for n in range(8192):
        s=unpack(n)
        require(pack(s)==n,'State round-trip failed')
        for i,event in enumerate(EVENT_NAMES):
            ns,out=m.step(s,event)
            require((pack(ns),out)==transition_spec(n,i),f'Transition mismatch {n} {event}')
            comparison_count+=1
    old_mutants=('omit_commit_recheck','omit_context_check','omit_continuation_recheck',
                 'allow_consumed_replay','recovery_requires_mission_authority','recovery_requires_logging')
    old_results={name:graph_check(name) for name in old_mutants}
    require(all(v['status']=='COUNTEREXAMPLE' for v in old_results.values()),'Missed original mutant')
    helper_results={}
    saved=m.normal_ok
    try:
        for omitted in FIELD_NAMES[:9]:
            def changed(s: Any, drop: str=omitted) -> bool:
                return all(getattr(s,f) for f in FIELD_NAMES[:9] if f!=drop)
            m.normal_ok=changed
            helper_results[f'omit_shared_{omitted}']=graph_check()
        # Demonstrate the old oracle's common-mode weakness without changing the baseline file.
        m.normal_ok=lambda s: all(getattr(s,f) for f in FIELD_NAMES[:9] if f!='required_set')
        blind=m.check_model()
        require(blind['status']=='PASS','Demonstrated original shared-helper blind spot changed')
    finally:
        m.normal_ok=saved
    require(all(v['status']=='COUNTEREXAMPLE' for v in helper_results.values()),'Missed shared-helper mutant')
    folds=m.check_fold(); verdicts=m.verdict_mutations()
    require(len(verdicts)==27 and all(v['caught'] for v in verdicts),'Verdict mutation failure')
    sequences=check_sequences()
    result={'edition':'PR-25 reference audit v0.4','run_date':'2026-09-13',
      'runtime':f'CPython {platform.python_version()}',
      'reference_source_sha256':EXPECTED_SOURCE,
      'verifier_source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
      'baseline':baseline,'fold':folds,'sequence_checks':sequences,'constructive_census':check_census(),
      'transition_correspondence':{'state_encodings':8192,'events':27,
        'comparisons':comparison_count,'mismatches':0,
        'scope':'All finite encodings, including unreachable states; not physical executions.'},
      'selected_mutations':{'verdict':27,'original_supervisor':6,'shared_helper':9,'detected':42,
        'denominator':42,'original_supervisor_results':old_results,'shared_helper_results':helper_results},
      'demonstrated_original_oracle_blind_spot':{'mutation':'normal_ok omits required_set',
        'old_oracle_result':blind,'new_oracle_result':helper_results['omit_shared_required_set']},
      'limits':['Trusted Boolean summaries; no sensor or physical predicate verification',
        'Atomic local transitions and Boolean freshness; no clock or delay model',
        'One permit; no distributed concurrency, persistent replay ledger, or cryptographic verification',
        'No robot, controller, stopping, scheduling, fault-containment, or deployment validation',
        'Shared Python/runtime/reviewer trust remains; no independent proof certificate'],
      'status':'PASS'}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    print(json.dumps(result,indent=2,sort_keys=True))

if __name__=='__main__':
    main()
