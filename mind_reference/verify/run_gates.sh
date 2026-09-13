#!/usr/bin/env bash
# PR-25 pure-MIND gate runner. Builds from source and runs every gate.
#
# Requires an mlir-build-enabled mindc. A default-feature mindc FAILS with
#   error[build][E5003]: public CPU executable requires every source module
#   to compile natively; refusing to link a runtime-JIT fallback object
# Build one with:  cargo build --release --features mlir-build --bin mindc
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
  # Explicitly propagate compiler failure. Without this a failed check/build
  # could leave an earlier executable in place and the path would still echo,
  # letting a stale binary be accepted as a fresh build.
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
# name differs between the two projects, so compare the reference against itself
# rebuilt in place. $REF is <proj>/target/debug/<name>; two dirname calls give
# <proj>/target, which is exactly the directory to remove. Appending a further
# /target (as an earlier revision did) deleted nothing, left a warm target dir,
# and made this gate compare a hash to itself.
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
# Record-by-record diff. A rolling-checksum comparison is NOT sufficient:
#   h = (31*h + result + 7) mod 1e9+7
# admits constructed collisions (e.g. +1 on one record and -31 on the next
# cancel exactly), so equal digests do not establish equal transcripts.
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

echo; echo "TOTALS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
