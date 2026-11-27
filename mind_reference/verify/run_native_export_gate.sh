#!/usr/bin/env bash
# PR-25 native exporter gate. Builds model/ with the public mindc 0.10.4 release on the
# NATIVE backend (the compiler reports zero MLIR/LLVM/clang; see model/README.md), twice
# from clean folders, runs it, pins the SHA-256
# of its raw output, and compares every state, all 83,106 transitions, the per-variant lines
# (M, O, R, P, with the property codes) and the total lines (Q, C, X) with the public Python
# model in ../../reference_model (the Python leg). It prints the count of compared values.
# Usage: MINDC=/path/to/mindc-0.10.4/mindc ./verify/run_native_export_gate.sh
# Exit 0 only when every gate passes; exit 2 when a tool or input is missing.
set -euo pipefail

OUT_SHA="4b228f500b68f57d2f5f773527f9933fdf7225ee4f0b995604f55bdaf4d954b6"
X_LINE="X 27 15 6 42 33"

[ -n "${MINDC:-}" ] && [ -x "$MINDC" ] || { echo "FAIL: set MINDC to the mindc 0.10.4 release binary"; exit 2; }
for t in python3 sha256sum cmp diff nice mktemp head; do
  command -v "$t" >/dev/null || { echo "FAIL: missing tool: $t"; exit 2; }
done
R="$(cd "$(dirname "$0")/.." && pwd)"
for f in "$R/model/Mind.toml" "$R/model/src/main.mind" "$R/EXPECTED_OUTPUT.txt" "$R/../reference_model/pr25_verify.py"; do
  [ -f "$f" ] || { echo "FAIL: missing input: $f"; exit 2; }
done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok(){ echo "  PASS  $1"; pass=$((pass+1)); }
no(){ echo "  FAIL  $1"; fail=$((fail+1)); }

echo "== mindc =="
VER="$("$MINDC" --version | head -1)"; echo "$VER"
[ "$VER" = "mind 0.10.4" ] || { echo "FAIL: need mind 0.10.4, got: $VER"; exit 2; }

build(){ # <name> -> echoes the binary path, or returns nonzero
  local d="$W/$1"; mkdir -p "$d"; cp -r "$R/model/Mind.toml" "$R/model/src" "$d/"
  # Explicit propagation: a failed check or build must not leave a stale binary to accept.
  if ! ( cd "$d" && "$MINDC" check >/dev/null && nice -n 15 "$MINDC" build --backend native >/dev/null ); then
    echo "BUILD FAILED for $1" >&2; return 1
  fi
  local out="$d/target/debug/pr25export"
  [ -x "$out" ] || { echo "NO EXECUTABLE produced for $1" >&2; return 1; }
  echo "$out"
}

echo "== GATE 1: check + build, native backend =="
A="$(build a)" && ok "builds on the native backend ($(stat -c%s "$A") bytes)" || { no "native build"; echo; echo "TOTALS: pass=$pass fail=$fail"; exit 1; }

echo "== GATE 2: two clean builds, byte-identical =="
B="$(build b)" || B=""
if [ -n "$B" ] && cmp -s "$A" "$B"; then ok "binaries equal ($(sha256sum "$A" | cut -c1-16))"; else no "builds differ or second build failed"; fi

echo "== GATE 3: run, pinned output SHA-256, summary lines =="
set +e; nice -n 15 "$A" > "$W/o1.txt"; rc1=$?; nice -n 15 "$A" > "$W/o2.txt"; rc2=$?; set -e
[ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ] && cmp -s "$W/o1.txt" "$W/o2.txt" \
  && ok "two runs exit 0, identical output" || no "exit codes $rc1/$rc2 or runs differ"
got="$(sha256sum "$W/o1.txt" | cut -d' ' -f1)"
[ "$got" = "$OUT_SHA" ] && ok "output SHA-256 equals the pin (${got:0:16})" || no "output SHA-256 $got differs from the pin"
head -5 "$W/o1.txt" | diff -q - "$R/EXPECTED_OUTPUT.txt" >/dev/null \
  && ok "first 5 lines equal EXPECTED_OUTPUT.txt (3078 / 83106 / 271453 / 302 / 42)" || no "first 5 lines differ from EXPECTED_OUTPUT.txt"
grep -qx "$X_LINE" "$W/o1.txt" && grep -qx "K 0" "$W/o1.txt" \
  && ok "summary lines '$X_LINE' and 'K 0' present" || no "summary lines differ"

echo "== GATE 4: Python leg, states, 83,106 transitions, per-variant lines, total lines =="
# Python is only a comparison here, on a scratch copy of the public reference_model.
cp -r "$R/../reference_model" "$W/refmodel"
if python3 -I - "$W/refmodel" "$W/o1.txt" <<'PY'
import sys
from collections import deque
refdir, outfile = sys.argv[1], sys.argv[2]
sys.path.insert(0, refdir)
import pr25_verify as v
m = v.m
fails = []
def check(ok, what):
    print(('    ok   ' if ok else '    FAIL ') + what)
    if not ok: fails.append(what)
lines = [l.split() for l in open(outfile).read().splitlines()]
S = [list(map(int, l[1:])) for l in lines if l[0] == 'S']
T = {int(l[1]): list(map(int, l[2:])) for l in lines if l[0] == 'T'}
OUT = {o: i for i, o in enumerate(v.OUTPUTS)}
n0 = v.pack(m.State())
order, dep, par, prow, q = [n0], {n0: 0}, {n0: None}, {}, deque([n0])
while q:
    n = q.popleft(); s = v.unpack(n); row = []
    for i, e in enumerate(v.EVENT_NAMES):
        ns, o = m.step(s, e); nn = v.pack(ns); row.append((nn, OUT[o]))
        if nn not in dep:
            dep[nn] = dep[n] + 1; par[nn] = (n, i); order.append(nn); q.append(nn)
    prow[n] = row
encs = [r[1] for r in S]
check(encs == sorted(order) and len(S) == len(T) == 3078, 'state list equals the Python reachable set (%d states, ascending)' % len(order))
idx = {e: i for i, e in enumerate(encs)}
bad = 0
for r in S:
    i, e, d, pi, pe = r[0], r[1], r[2], r[3], r[4]
    want = (-1, -1) if par[e] is None else (idx[par[e][0]], par[e][1])
    if d != dep[e] or (pi, pe) != want: bad += 1
check(bad == 0, 'depth, parent state and parent event of every state equal the Python search (differences %d)' % bad)
bad = 0; total = 0
for i, e in enumerate(encs):
    vals = T[i]
    for k in range(27):
        total += 1
        nxt, out = idx[prow[e][k][0]], prow[e][k][1]
        if len(vals) != 27 or vals[k] != 4 * nxt + out: bad += 1
check(bad == 0 and total == 83106, 'all %d (state, event) transition records equal the Python step (differences %d)' % (total, bad))
# per variant: every per-variant line (M, O, R, P) and the total lines (Q, C) of the exporter
# against the public Python model. compared counts every value that is compared.
PROPS = ('invalid_output_code', 'normal_output_without_current_conditions', 'invalidated_permit_reused',
         'normal_output_on_unpermitted_event', 'start_without_ready_permit', 'continue_without_active_permit',
         'consumed_permit_replayed', 'invalid_post_grant_state', 'active_authority_retained_after_invalidation',
         'available_protective_output_blocked', 'unavailable_recovery_claimed')
code = lambda name: PROPS.index(name) + 1 if name else 0
saved = m.normal_ok
SUP = ('omit_commit_recheck', 'omit_context_check', 'omit_continuation_recheck',
       'allow_consumed_replay', 'recovery_requires_mission_authority', 'recovery_requires_logging')
def setup(k):
    m.normal_ok = saved
    if k <= 6: return SUP[k - 1]
    drop = v.FIELD_NAMES[k - 7]
    m.normal_ok = lambda s, d=drop: all(getattr(s, f) for f in v.FIELD_NAMES[:9] if f != d)
    return None
def variant_graph(mut):
    """Reachable states of the variant, with the first oracle property of every transition."""
    st = m.State(); seen = {st}; qq = deque([st]); counts = [0] * 12; differ = 0
    while qq:
        s = qq.popleft()
        for e in v.EVENT_NAMES:
            ns, o = m.step(s, e, mut)
            cur = m.normal_ok; m.normal_ok = saved
            bs, bo = m.step(s, e, None)
            m.normal_ok = cur
            if (v.pack(ns), o) != (v.pack(bs), bo): differ += 1
            counts[code(v.oracle_violation(s, e, ns, o))] += 1
            if ns not in seen: seen.add(ns); qq.append(ns)
    return len(seen), 27 * len(seen), counts, differ
def events_of(r): return [v.EVENT_NAMES.index(e) for e in r['trace']]
byTag = {t: {} for t in 'MORP'}
for l in lines:
    if l[0] in byTag: byTag[l[0]][int(l[1])] = list(map(int, l[2:]))
compared = 0
bad = {'M': [], 'O': [], 'R': [], 'P': []}
firstHit = [0] * 12; hitSum = [0] * 12; sep = old = 0
for k in range(1, 16):
    mut = setup(k)
    st, ed, counts, differ = variant_graph(mut)
    g = v.graph_check(mut); t = events_of(g)
    expM = [st, ed, 1, code(g['property']), len(t)] + t
    expP = counts[1:]
    c = m.check_model(mut)
    expO = ([c['states_discovered'], c['transitions_checked'], 1, code(c['property']), len(events_of(c))] + events_of(c)
            if c['status'] == 'COUNTEREXAMPLE' else [c['reachable_states'], c['transitions_checked'], 0, 0, 0])
    for tag, exp in (('M', expM), ('O', expO), ('R', [differ]), ('P', expP)):
        compared += len(exp)
        if byTag[tag].get(k) != exp: bad[tag].append(k)
    sep += g['status'] == 'COUNTEREXAMPLE'; old += c['status'] == 'COUNTEREXAMPLE'
    firstHit[code(g['property'])] += 1
    hitSum = [a + b for a, b in zip(hitSum, counts)]
m.normal_ok = saved
for tag, what in (('M', 'separated oracle: states, transitions, found, property code, trace'),
                  ('O', 'original checker: states, transitions, found, property code, trace (3,088 / 83,376 and no hit for 7..15)'),
                  ('R', 'records that differ from the baseline'),
                  ('P', 'first property hit per transition, 11 property counts')):
    check(not bad[tag], 'variants 1..15, %s lines: %s (bad: %s)' % (tag, what, bad[tag]))
Q = {int(l[1]): list(map(int, l[2:])) for l in lines if l[0] == 'Q'}
expQ = {p: [firstHit[p], hitSum[p]] for p in range(1, 12)}
compared += 22
check(Q == expQ, 'total lines Q 1..11: first-hit variants and hit transitions per property equal the Python sums')
vm = m.verdict_mutations(); fold = sum(1 for r in vm if r['caught'])
Dl = [l for l in lines if l[0] == 'D']
check(len(Dl) == 27 == len(vm) and all(l[2] == '1' for l in Dl) and fold == 27, 'fold variants: 27 listed, all detected, as in the Python model')
Cl = [list(map(int, l[1:])) for l in lines if l[0] == 'C']
expC = [len(order), 27 * len(order), 27, 15, 27, 42]
compared += 6
check(Cl == [expC], 'total line C: states, transitions, events, graph variants, fold variants, variants equal the Python counts')
Xl = [l for l in lines if l[0] == 'X'][0][1:]
compared += 5
check(list(map(int, Xl)) == [fold, sep, old, fold + sep, fold + old], 'X line equals the Python counts (fold, separated, original, totals)')
check(sep == 15, 'every graph variant has a separated-oracle hit')
print('compared values (per-variant and total lines): %d' % compared)
sys.exit(1 if fails else 0)
PY
then ok "Python leg: every compared item equal"; else no "Python leg: a comparison failed"; fi

echo; echo "TOTALS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
