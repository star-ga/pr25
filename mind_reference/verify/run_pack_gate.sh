#!/usr/bin/env bash
# PR-25 pack gate. Builds the exporter (model/) and the packer (model/pack/) with the public
# mindc 0.10.4 release on the NATIVE backend (the compiler reports zero MLIR/LLVM/clang; see
# model/README.md), each twice from clean folders, runs the exporter, packs its output into the
# five binary files with the packer and checks them with model/pack/PACK_SHA256SUMS.txt, then
# checks that each kind of bad input gives its own error code (codes 1 to 9 of model/pack/README.md).
# No node and no python: every program in this gate is MIND or a core shell tool.
# Usage: MINDC=/path/to/mindc-0.10.4/mindc ./verify/run_pack_gate.sh
# Exit 0 only when every gate passes; exit 1 on a failed gate; exit 2 when a tool or input is missing.
set -euo pipefail

OUT_SHA="4b228f500b68f57d2f5f773527f9933fdf7225ee4f0b995604f55bdaf4d954b6"
SIZES="states.u16le.bin:6156 depth.u8.bin:3078 flags.u8.bin:3078 parent.u16le_u8.bin:9234 transitions.u16le.bin:166212"

[ -n "${MINDC:-}" ] && [ -x "$MINDC" ] || { echo "FAIL: set MINDC to the mindc 0.10.4 release binary"; exit 2; }
for t in sha256sum cmp nice mktemp head cut stat wc sed cat; do
  command -v "$t" >/dev/null || { echo "FAIL: missing tool: $t"; exit 2; }
done
R="$(cd "$(dirname "$0")/.." && pwd)"
for f in "$R/model/Mind.toml" "$R/model/src/main.mind" "$R/model/pack/Mind.toml" "$R/model/pack/src/main.mind" \
         "$R/model/pack/PACK_SHA256SUMS.txt"; do
  [ -f "$f" ] || { echo "FAIL: missing input: $f"; exit 2; }
done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok(){ echo "  PASS  $1"; pass=$((pass+1)); }
no(){ echo "  FAIL  $1"; fail=$((fail+1)); }
totals(){ echo; echo "TOTALS: pass=$pass fail=$fail"; [ "$fail" -eq 0 ] || exit 1; exit 0; }

echo "== mindc =="
VER="$("$MINDC" --version | head -1)"; echo "$VER"
[ "$VER" = "mind 0.10.4" ] || { echo "FAIL: need mind 0.10.4, got: $VER"; exit 2; }

build(){ # <source folder> <package name> <work name> -> echoes the binary path, or returns nonzero
  local d="$W/$3"; mkdir -p "$d"; cp -r "$1/Mind.toml" "$1/src" "$d/"
  # Explicit propagation: a failed check or build must not leave a stale binary to accept.
  if ! ( cd "$d" && "$MINDC" check >/dev/null && nice -n 15 "$MINDC" build --backend native >/dev/null ); then
    echo "BUILD FAILED for $3" >&2; return 1
  fi
  local out="$d/target/debug/$2"
  [ -x "$out" ] || { echo "NO EXECUTABLE produced for $3" >&2; return 1; }
  echo "$out"
}
twice(){ # <source folder> <package name> <label> -> sets BIN, or ends the gate
  local a b
  a="$(build "$1" "$2" "$2-a")" || { no "$3: native build"; totals; }
  b="$(build "$1" "$2" "$2-b")" || b=""
  if [ -n "$b" ] && cmp -s "$a" "$b"; then
    ok "$3: two clean native builds, equal binaries ($(stat -c%s "$a") bytes, $(sha256sum "$a" | cut -c1-16))"
  else no "$3: builds differ or second build failed"; fi
  BIN="$a"
}

echo "== GATE 1: exporter and packer, check + build, native backend, twice each =="
twice "$R/model" pr25export "exporter"; EXP="$BIN"
twice "$R/model/pack" pr25pack "packer"; PACK="$BIN"

echo "== GATE 2: run the exporter, pinned output SHA-256 =="
if nice -n 15 "$EXP" > "$W/export.txt"; then ok "exporter exits 0"; else no "exporter exit status"; totals; fi
got="$(sha256sum "$W/export.txt" | cut -d' ' -f1)"
[ "$got" = "$OUT_SHA" ] && ok "output SHA-256 equals the pin (${got:0:16})" || no "output SHA-256 $got differs from the pin"

echo "== GATE 3: pack, five files against PACK_SHA256SUMS.txt =="
mkdir -p "$W/packed"
if ( cd "$W/packed" && nice -n 15 "$PACK" < "$W/export.txt" 3>states.u16le.bin 4>depth.u8.bin 5>flags.u8.bin \
       6>parent.u16le_u8.bin 7>transitions.u16le.bin ); then ok "packer exits 0"; else no "packer exit status"; totals; fi
n="$(wc -l < "$R/model/pack/PACK_SHA256SUMS.txt")"
[ "$n" -eq 5 ] && ok "the pinned list holds 5 files" || no "the pinned list holds $n files, not 5"
if ( cd "$W/packed" && sha256sum -c "$R/model/pack/PACK_SHA256SUMS.txt" ); then ok "sha256sum -c: all five files equal the pins"
else no "sha256sum -c: a file differs from its pin"; fi
for p in $SIZES; do
  f="${p%%:*}"; want="${p#*:}"; got="$(stat -c%s "$W/packed/$f" 2>/dev/null || echo 0)"
  [ "$got" = "$want" ] && ok "$f is $want bytes" || no "$f is $got bytes, not $want"
done

echo "== GATE 4: the packer refuses each kind of bad input with its own error code =="
E="$W/export.txt"
variant(){ # <name> <sed script>: a copy of the export with one change; a change that does not apply is a FAIL
  sed "$2" "$E" > "$W/$1.txt"
  if cmp -s "$E" "$W/$1.txt"; then no "$1: the change did not apply"; return 1; fi
}
refused(){ # <label> <expected exit code> <input file> [fd to close: 0 or 7]
  local rc
  set +e
  case "${4:-}" in
    0) ( cd "$W" && "$PACK" <&- 3>/dev/null 4>/dev/null 5>/dev/null 6>/dev/null 7>/dev/null 2>"$W/err.txt" ) ;;
    7) ( cd "$W" && "$PACK" < "$3" 3>/dev/null 4>/dev/null 5>/dev/null 6>/dev/null 7>&- 2>"$W/err.txt" ) ;;
    *) ( cd "$W" && "$PACK" < "$3" 3>/dev/null 4>/dev/null 5>/dev/null 6>/dev/null 7>/dev/null 2>"$W/err.txt" ) ;;
  esac
  rc=$?; set -e
  [ "$rc" -eq "$2" ] && ok "$1: exit $rc, $(head -1 "$W/err.txt")" || no "$1: exit $rc, not $2 ($(head -1 "$W/err.txt"))"
}
head -n -100 "$E" > "$W/short.txt"
refused "last 100 lines removed" 4 "$W/short.txt"
variant malformed 's/^S 7 /S 7  /' && refused "two spaces in line S 7" 3 "$W/malformed.txt"
variant twoc '/^C /p' && refused "C line repeated" 4 "$W/twoc.txt"
variant cstates 's/^C 3078 /C 3077 /' && refused "C line says 3077 states" 5 "$W/cstates.txt"
variant sshort 's/^\(S 5 .*\) [0-9]*$/\1/' && refused "line S 5 one number short" 6 "$W/sshort.txt"
variant tshort 's/^\(T 2 .*\) [0-9]*$/\1/' && refused "line T 2 one value short" 7 "$W/tshort.txt"
variant tnext 's/^T 0 0 /T 0 12312 /' && refused "line T 0 next index 3078" 7 "$W/tnext.txt"
variant ctrans 's/^C 3078 83106 /C 3078 83105 /' && refused "C line says 83105 transitions" 8 "$W/ctrans.txt"
{ cat "$E"; head -c 8388608 /dev/zero; } > "$W/big.txt"
refused "input over 8 MiB" 2 "$W/big.txt"
refused "fd 0 closed" 1 "" 0
refused "fd 7 closed" 9 "$E" 7
totals
