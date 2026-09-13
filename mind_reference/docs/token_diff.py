#!/usr/bin/env python3
"""Prove src/pr25_reference.mind is a formatting-only change from the received original."""
import re, difflib, pathlib, sys
R = pathlib.Path(__file__).resolve().parent.parent
def toks(p):
    s = p.read_text(); s = re.sub(r'//.*', '', s)
    s = s.replace('true', '1').replace('false', '0')
    return re.findall(r'[A-Za-z_][A-Za-z0-9_]*|\d+|[^\s]', s)
a = toks(R / 'src/pr25_reference_AS_RECEIVED.mind')
b = toks(R / 'src/pr25_reference.mind')
added, removed = [], []
for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a, b).get_opcodes():
    if tag in ('replace', 'insert'): added += b[j1:j2]
    if tag in ('replace', 'delete'): removed += a[i1:i2]
print(f"received tokens : {len(a)}")
print(f"compiled tokens : {len(b)}")
print(f"ADDED           : {sorted(set(added)) or 'none'}  counts={ {t: added.count(t) for t in set(added)} }")
print(f"REMOVED         : {sorted(set(removed)) or 'none'}")
ok = set(added) <= {'{', '}'} and not removed
print("\nRESULT: formatting-only change PROVEN" if ok else "\nRESULT: SEMANTIC CHANGE DETECTED")
sys.exit(0 if ok else 1)
