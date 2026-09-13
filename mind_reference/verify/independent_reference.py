#!/usr/bin/env python3
"""Independent reference implementation of the PR-25 finite admission model.

WRITTEN FROM THE SPEC COMMENTS in src/pr25_reference.mind (header block), NOT
transliterated from its function bodies. This is deliberate: the defect the
PR-25 v0.4 audit found was a shared-helper oracle -- the model and its checker
called the same admission helper, so mutating the implementation moved the
oracle with it. An oracle derived from the implementation cannot detect that
the implementation is wrong.

Emits a rolling digest over every (state, event) pair -- 8192 encodings x 27
events = 221,184 transitions -- for comparison against the MIND binary built
from src/pr25_parity_digest.mind.

Baseline only (mutant = 0). Per-mutant parity is NOT covered; see README.
"""

MOD = 1000000007


def impl_normal(s: int) -> bool:
    """All nine normal-admission prerequisite flags (bits 0..8) set."""
    return all((s // (2 ** i)) % 2 == 1 for i in range(9))


def protection(s: int) -> int:
    """Recovery-readiness bit (8) absent => NO_ASSURED_OUTPUT, else PROTECTIVE."""
    if (s // 256) % 2 == 0:
        return 3
    return 2


def step(s: int, event: int) -> int:
    """State = flags + 1024*permit + 4096*binding. Result = 4*next + output."""
    if not (0 <= s < 8192) or not (0 <= event < 27):
        return -1
    flags = s % 1024
    permit = (s // 1024) % 4
    binding = s // 4096
    output = 0

    if event == 0:                                    # issue
        if permit in (0, 3) and impl_normal(s):
            permit, binding = 1, 1
    elif event == 1:                                  # start
        if permit == 1 and impl_normal(s) and binding == 1:
            permit, output = 2, 1
    elif event == 2:                                  # continue
        if permit == 2 and impl_normal(s) and binding == 1:
            output = 1
    elif event == 3:                                  # finish
        if permit == 2:
            permit = 3
    elif event == 4:                                  # replay (baseline: refused)
        pass
    elif event == 5:                                  # protect
        if permit != 0:
            permit = 3
        binding = 0
        output = protection(s)
    elif event == 6:                                  # discard
        if permit == 1:
            permit, binding = 0, 0
    else:                                             # invalidate/restore flag i
        field = (event - 7) // 2
        value = (event - 7) % 2
        weight = 2 ** field
        flags = flags - ((flags // weight) % 2) * weight + value * weight
        if value == 0 and field < 9:
            binding = 0
        changed = flags + 1024 * permit + 4096 * binding
        if permit == 2 and not impl_normal(changed):
            permit = 3
            output = protection(changed)

    return 4 * (flags + 1024 * permit + 4096 * binding) + output


def parity_digest() -> int:
    h = 0
    for s in range(8192):
        for e in range(27):
            h = (h * 31 + step(s, e) + 7) % MOD
    return h


def parity_records():
    """Emit every (state, event) -> result record in defined order, one per line.

    GATE 5 diffs these records individually. The rolling digest below is kept
    only as a cheap smoke check: a checksum admits constructed collisions and
    therefore cannot establish transition-by-transition equality.
    """
    out = []
    for s in range(8192):
        for e in range(27):
            out.append(step(s, e))
    return out


if __name__ == "__main__":
    import sys

    if "--digest" in sys.argv:
        print(parity_digest())
    else:
        sys.stdout.write("\n".join(str(r) for r in parity_records()) + "\n")
