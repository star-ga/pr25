#!/usr/bin/env python3
"""Execute the MIND malformed-boundary classifier through a native shared library.

Usage:
  python3 check_malformed_shared.py /absolute/path/to/pr25_malformed.so

The MIND function is invoked for every one of the 7,000 canonical descriptors.
Expected verdicts come from malformed_reference.py, an independent implementation.
The script also proves its comparison can fail by corrupting one expected record.
"""
from __future__ import annotations

import ctypes
import importlib.util
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
REFERENCE = HERE / "malformed_reference.py"


def load_reference():
    spec = importlib.util.spec_from_file_location("pr25_malformed_reference", REFERENCE)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load malformed reference")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def descriptor_stream():
    for shape_code in range(5):
        for app_kind in range(5):
            for app_value in range(-2, 5):
                for verdict_kind in range(5):
                    for verdict_value in range(-2, 6):
                        yield shape_code, app_kind, app_value, verdict_kind, verdict_value


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_malformed_shared.py /absolute/path/to/lib.so", file=sys.stderr)
        return 64
    so = Path(sys.argv[1]).resolve()
    if not so.is_file():
        print(f"shared library not found: {so}", file=sys.stderr)
        return 66

    ref = load_reference()
    lib = ctypes.CDLL(str(so))
    fn = lib.boundary_verdict
    fn.argtypes = [ctypes.c_int64] * 5
    fn.restype = ctypes.c_int64

    actual: list[int] = []
    expected: list[int] = []
    first_mismatch = None
    for idx, desc in enumerate(descriptor_stream()):
        got = int(fn(*desc))
        want = int(ref.boundary_verdict(*desc))
        actual.append(got)
        expected.append(want)
        if got != want and first_mismatch is None:
            first_mismatch = (idx, desc, got, want)

    if len(actual) != 7000:
        raise RuntimeError(f"descriptor count mismatch: {len(actual)}")
    if first_mismatch is not None:
        idx, desc, got, want = first_mismatch
        raise RuntimeError(
            f"MIND/Python malformed-boundary mismatch at case {idx} {desc}: "
            f"MIND={got} reference={want}"
        )

    # Falsifiability: the comparator must detect a changed expected transcript.
    mutant = expected.copy()
    mutant[0] = mutant[0] + 1
    mismatches = [i for i, (a, b) in enumerate(zip(actual, mutant, strict=True)) if a != b]
    if mismatches != [0]:
        raise RuntimeError(f"negative control failed: mismatches={mismatches[:10]}")

    print("PASS: 7000/7000 native MIND malformed-boundary classifications identical")
    print("PASS: negative control detected at canonical case 0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
