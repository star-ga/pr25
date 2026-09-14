#!/usr/bin/env bash
# PR-25 pure-MIND gate runner. Builds from source and runs every gate.
#
# Requires an mlir-build-enabled mindc plus the separately provisioned project
# CPU runtime for Gates 1-6. Gate 7 itself uses the public single-file
# --emit-shared path and does not require that project runtime package.
set -euo pipefail

MINDC="${MINDC:-$HOME/mind/target/release/mindc}"
[ -x "$MINDC" ] || { echo "FAIL: no mindc at $MINDC (need --features mlir-build)"; exit 2; }
R="$(cd "$(dirname "$0")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok(){ echo "  PASS  $1"; pass=$((pass+1)); }
no(){ echo "  FAIL  $1"; fail=$((fail+1)); }

echo "== mindc =="; "$MINDC" --version

build(){ # <src> <name> -> echoes binary path, or returns nonzero
  local d="$W/$2"; mkdir -p "$d/src"; cp "$1" "$d/src/main.mind"
  printf '[package]\nname = "%s"\nversion = "0.4.0"\n' "$2" > "$d/Mind.toml"
  if ! ( cd "$d" && "$MINDC" check src/main.mind && nice -n 15 "$MINDC" build >/dev/null ); then
    echo "BUILD FAILED for $2 ($1)" >&2
    return 1
  fi
  local out="$d/target/debug/$2"
  [ -x "$out" ] || { echo "NO EXECUTABLE produced for $2" >&2; return 1; }
  echo "$out"
}

echo "== GATE 1: check + native build =="
REF="$(build "$R/src/pr25_reference.mind" pr25ref)"
[ -x "$REF" ] && ok "reference builds natively ($(stat -c%s "$REF") bytes)" || no "reference build"

echo "== GATE 2: output vs EXPECTED_OUTPUT.txt =="
"$REF" > "$W/out.txt"
diff -u "$R/EXPECTED_OUTPUT.txt" "$W/out.txt" >/dev/null \
  && ok "5/5 counts exact" || { no "output mismatch"; diff -u "$R/EXPECTED_OUTPUT.txt" "$W/out.txt" || true; }

echo "== GATE 3: run-to-run determinism (10x) =="
n=$(for i in $(seq 10); do "$REF" | sha256sum; done | sort -u | wc -l)
[ "$n" -eq 1 ] && ok "1 distinct output hash over 10 runs" || no "nondeterministic ($n hashes)"

echo "== GATE 4: rebuild byte-identity =="
h1=$(sha256sum "$REF" | cut -d' ' -f1)
REF2="$(build "$R/src/pr25_reference.mind" pr25ref2)"
h2=$(sha256sum "$REF2" | cut -d' ' -f1)
REF_TARGET="$(dirname "$(dirname "$REF")")"
case "$REF_TARGET" in
  */target) ;;
  *) echo "FAIL: unexpected build layout: $REF_TARGET"; exit 2 ;;
esac
rm -rf "$REF_TARGET"
[ -e "$REF" ] && { echo "FAIL: rebuild cleanup did not remove $REF"; exit 2; }
REF3="$(build "$R/src/pr25_reference.mind" pr25ref)"
h3=$(sha256sum "$REF3" | cut -d' ' -f1)
[ "$h1" = "$h3" ] && ok "byte-identical across clean rebuild (${h1:0:16})" || no "rebuild differs: $h1 vs $h3"

echo "== GATE 5: cross-language parity, all 221,184 transition records =="
PAR="$(build "$R/src/pr25_parity_digest.mind" pr25par)"
set +e
"$PAR" > "$W/mind_records.txt"; par_rc=$?
python3 "$R/verify/independent_reference.py" > "$W/ref_records.txt"; ref_rc=$?
set -e
mind_n=$(wc -l < "$W/mind_records.txt")
ref_n=$(wc -l < "$W/ref_records.txt")
if [ "$par_rc" -ne 0 ] || [ "$ref_rc" -ne 0 ]; then
  no "parity: nonzero exit (MIND=$par_rc reference=$ref_rc)"
elif [ "$mind_n" -ne 221184 ] || [ "$ref_n" -ne 221184 ]; then
  no "parity: wrong record count (MIND=$mind_n reference=$ref_n, expected 221184)"
elif diff -q "$W/mind_records.txt" "$W/ref_records.txt" >/dev/null; then
  ok "221184/221184 transition records identical (8192 x 27)"
else
  no "parity MISMATCH: $(diff "$W/mind_records.txt" "$W/ref_records.txt" | grep -c '^<') differing records"
  diff "$W/mind_records.txt" "$W/ref_records.txt" | head -10 || true
fi

echo "== GATE 6: supplied comparison script =="
"$R/verify/check_compiled_output.sh" "$REF3" >/dev/null && ok "check_compiled_output.sh" || no "check_compiled_output.sh"

echo "== GATE 7: canonical malformed-input boundary parity =="
if MINDC="$MINDC" "$R/verify/run_malformed_gate.sh" > "$W/malformed_gate.log"; then
  ok "7000/7000 native MIND boundary classifications identical; negative control detected"
else
  no "malformed-input boundary gate"
  cat "$W/malformed_gate.log"
fi

echo; echo "TOTALS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
