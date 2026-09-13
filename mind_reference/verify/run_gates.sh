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

build(){ # <src> <name> -> echoes binary path
  local d="$W/$2"; mkdir -p "$d/src"; cp "$1" "$d/src/main.mind"
  printf '[package]\nname = "%s"\nversion = "0.4.0"\n' "$2" > "$d/Mind.toml"
  ( cd "$d" && "$MINDC" check src/main.mind && nice -n 15 "$MINDC" build >/dev/null )
  echo "$d/target/debug/$2"
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
# name differs between the two projects, so compare the reference against itself rebuilt in place
rm -rf "$(dirname "$(dirname "$REF")")/target"
REF3="$(build "$R/src/pr25_reference.mind" pr25ref)"
h3=$(sha256sum "$REF3" | cut -d' ' -f1)
[ "$h1" = "$h3" ] && ok "byte-identical across clean rebuild (${h1:0:16})" || no "rebuild differs: $h1 vs $h3"

echo "== GATE 5: cross-language parity, all 221,184 transitions =="
PAR="$(build "$R/src/pr25_parity_digest.mind" pr25par)"
m=$("$PAR"); p=$(python3 "$R/verify/independent_reference.py")
[ "$m" = "$p" ] && ok "MIND $m == independent reference $p (8192 x 27)" \
                || no "parity MISMATCH: MIND $m vs reference $p"

echo "== GATE 6: supplied comparison script =="
"$R/verify/check_compiled_output.sh" "$REF3" >/dev/null && ok "check_compiled_output.sh" || no "check_compiled_output.sh"

echo; echo "TOTALS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
