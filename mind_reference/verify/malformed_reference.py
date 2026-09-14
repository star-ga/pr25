#!/usr/bin/env python3
"""Independent canonical malformed-input boundary reference for PR-25.

This compares language-neutral descriptor semantics, not Python runtime objects.
Python-specific hazards such as ``None``, dicts, bool/int aliasing, floats and
NaN remain covered by ``reference_model/pr25_verify.py`` at the Python boundary.

By default emits one encoded ``case_index * 16 + verdict`` record for each of
7,000 descriptors in the same defined order as the MIND implementation.
``--mutant flip-first`` intentionally corrupts the first record so the shell
parity gate can prove it is capable of going red.
"""
from __future__ import annotations

import argparse
from collections import Counter

MB_ADMITTED = 1
MB_BAD_SHAPE = 2
MB_BAD_APPLICABILITY_TYPE = 3
MB_BAD_VERDICT_TYPE = 4
MB_BAD_APPLICABILITY_CODE = 5
MB_BAD_VERDICT_CODE = 6
MB_UNRESOLVED_APPLICABILITY = 7
MB_EMPTY_REQUIRED_SET = 8
MB_REQUIRED_NONPASS = 9

EXPECTED_COUNTS = {
    MB_ADMITTED: 1,
    MB_BAD_SHAPE: 5600,
    MB_BAD_APPLICABILITY_TYPE: 1120,
    MB_BAD_VERDICT_TYPE: 224,
    MB_BAD_APPLICABILITY_CODE: 32,
    MB_BAD_VERDICT_CODE: 12,
    MB_UNRESOLVED_APPLICABILITY: 4,
    MB_EMPTY_REQUIRED_SET: 4,
    MB_REQUIRED_NONPASS: 3,
}


def boundary_verdict(
    shape_code: int,
    app_kind: int,
    app_value: int,
    verdict_kind: int,
    verdict_value: int,
) -> int:
    # Structural refusals first.
    if shape_code != 0:
        return MB_BAD_SHAPE
    if app_kind != 0:
        return MB_BAD_APPLICABILITY_TYPE
    if verdict_kind != 0:
        return MB_BAD_VERDICT_TYPE
    if app_value < 0 or app_value > 2:
        return MB_BAD_APPLICABILITY_CODE
    if verdict_value < 0 or verdict_value > 3:
        return MB_BAD_VERDICT_CODE

    # Semantic refusals only after the descriptor is structurally valid.
    if app_value == 2:
        return MB_UNRESOLVED_APPLICABILITY
    if app_value == 1:
        return MB_EMPTY_REQUIRED_SET
    if verdict_value != 0:
        return MB_REQUIRED_NONPASS
    return MB_ADMITTED


def records() -> tuple[list[int], Counter[int]]:
    out: list[int] = []
    counts: Counter[int] = Counter()
    case_index = 0
    for shape_code in range(5):
        for app_kind in range(5):
            for app_value in range(-2, 5):
                for verdict_kind in range(5):
                    for verdict_value in range(-2, 6):
                        verdict = boundary_verdict(
                            shape_code,
                            app_kind,
                            app_value,
                            verdict_kind,
                            verdict_value,
                        )
                        out.append(case_index * 16 + verdict)
                        counts[verdict] += 1
                        case_index += 1
    return out, counts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mutant', choices=('none', 'flip-first'), default='none')
    args = parser.parse_args()

    out, counts = records()
    if len(out) != 7000:
        raise RuntimeError(f'canonical corpus size mismatch: {len(out)}')
    if dict(counts) != EXPECTED_COUNTS:
        raise RuntimeError(f'canonical refusal accounting mismatch: {dict(counts)}')

    if args.mutant == 'flip-first':
        out[0] += 1

    for record in out:
        print(record)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
