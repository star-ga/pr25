#!/usr/bin/env bash
# PR-25 artifact gate. Builds model/artifact/pr25.mic3 with the public mindc 0.10.4 release: the
# model rule (model/src/model.mind) as a mic@3 artifact whose evidence MAP carries the compiler's
# own entries and one string entry per line of model/artifact/records.txt (the five tables of the
# article in the format "PR-25 records, version 1"; see model/artifact/README.md). It builds the
# artifact twice from clean folders, checks the SHA-256 pins, `mindc verify`, the body/MAP split,
# and rebuilds the whole artifact byte for byte from the plain body, the compiler-only MAP and
# records.txt. No node and no python: every program in this gate is mindc or a core shell tool.
# The trace hash covers the IR body only. The records sit outside it: in this unsigned artifact
# they are pinned by the SHA-256 of the whole file (ARTIFACT_SHA256SUMS.txt), not by the trace hash.
# Usage: MINDC=/path/to/mindc-0.10.4/mindc ./verify/run_artifact_gate.sh
# Exit 0 only when every gate passes; exit 1 on a failed gate; exit 2 when a tool or input is missing.
set -euo pipefail
export LC_ALL=C   # byte lengths and byte order

[ -n "${MINDC:-}" ] && [ -x "$MINDC" ] || { echo "FAIL: set MINDC to the mindc 0.10.4 release binary"; exit 2; }
for t in sha256sum cmp od stat mktemp head tail cut wc sort grep tr; do
  command -v "$t" >/dev/null || { echo "FAIL: missing tool: $t"; exit 2; }
done
R="$(cd "$(dirname "$0")/.." && pwd)"
A="$R/model/artifact"; SRC="$R/model/src/model.mind"
for f in "$SRC" "$A/records.txt" "$A/ARTIFACT_SHA256SUMS.txt" "$A/ARTIFACT_FACTS.txt"; do
  [ -f "$f" ] || { echo "FAIL: missing input: $f"; exit 2; }
done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok(){ echo "  PASS  $1"; pass=$((pass+1)); }
no(){ echo "  FAIL  $1"; fail=$((fail+1)); }
totals(){ echo; echo "TOTALS: pass=$pass fail=$fail"; [ "$fail" -eq 0 ] || exit 1; exit 0; }
fact(){ command grep -m1 "^$1 " "$A/ARTIFACT_FACTS.txt" | cut -d' ' -f2; }
uleb(){ # <n> -> ULEB128 bytes on stdout
  local n="$1" b hx
  while :; do
    b=$((n & 127)); n=$((n >> 7)); [ "$n" -gt 0 ] && b=$((b | 128))
    printf -v hx '\\x%02x' "$b"; printf "$hx"
    [ "$n" -gt 0 ] || break
  done
}

echo "== mindc =="
VER="$("$MINDC" --version | head -1)"; echo "$VER"
[ "$VER" = "mind 0.10.4" ] || { echo "FAIL: need mind 0.10.4, got: $VER"; exit 2; }

echo "== GATE 1: records.txt form =="
mapfile -t LINES < "$A/records.txt"; N=${#LINES[@]}
[ "$(tail -c1 "$A/records.txt" | od -An -tx1 | tr -d ' ')" = "0a" ] && ok "ends with a line feed" || no "no final line feed"
[ "$(command grep -c -v -E '^ga\.star\.pr25\.[^=]+=.+$' "$A/records.txt" || true)" = "0" ] \
  && ok "$N lines, each 'ga.star.pr25.<key>=<value>' (no empty line)" || no "a line is empty or outside the ga.star.pr25. namespace"
[ "$(tr -cd '\r' < "$A/records.txt" | wc -c)" = "0" ] && ok "no carriage return" || no "a carriage return in records.txt"
cut -d= -f1 "$A/records.txt" | sort -c -u 2>/dev/null && ok "keys unique and in byte order" || no "keys repeat or are out of byte order"
[ "$N" = "$(fact namespace_entries)" ] && ok "line count equals namespace_entries of ARTIFACT_FACTS.txt" || no "$N lines, facts say $(fact namespace_entries)"

ARGS=(); for l in "${LINES[@]}"; do ARGS+=(--evidence-attr "$l"); done
build(){ # <work name> [records as --evidence-attr arguments...] -> pr25.mic3 and pr25.body.mic3 in $W/<name>
  local d="$W/$1"; shift; mkdir -p "$d"; cp "$SRC" "$d/model.mind"
  if ! ( cd "$d" && nice -n 15 "$MINDC" model.mind --emit-evidence pr25.mic3 "$@" >"$d/log" 2>&1 \
         && nice -n 15 "$MINDC" model.mind --emit-mic3 pr25.body.mic3 >>"$d/log" 2>&1 ); then
    echo "    mindc: $(command grep -m1 -i error "$d/log" || tail -1 "$d/log")"; return 1
  fi
}

echo "== GATE 2: two clean builds, byte-identical =="
build a "${ARGS[@]}" || { no "build a: mindc refused the records"; totals; }
build b "${ARGS[@]}" || { no "build b: mindc refused the records"; totals; }
ART="$W/a/pr25.mic3"; BODY="$W/a/pr25.body.mic3"
cmp -s "$ART" "$W/b/pr25.mic3" && cmp -s "$BODY" "$W/b/pr25.body.mic3" \
  && ok "artifacts equal ($(stat -c%s "$ART") bytes) and bodies equal" || no "the two builds differ"

echo "== GATE 3: SHA-256 pins =="
if ( cd "$W/a" && sha256sum -c "$A/ARTIFACT_SHA256SUMS.txt" ); then ok "pr25.mic3 and pr25.body.mic3 equal ARTIFACT_SHA256SUMS.txt"
else no "sha256sum -c: a file differs from its pin"; fi
[ "$(wc -l < "$A/ARTIFACT_SHA256SUMS.txt")" -eq 2 ] && ok "the pinned list holds 2 files" || no "the pinned list does not hold 2 files"

echo "== GATE 4: mindc verify, trace hash =="
set +e; "$MINDC" verify "$ART" > "$W/verify.txt" 2>&1; rc=$?; set -e
TH="$(command grep -m1 '^trace_hash: ' "$W/verify.txt" | tr -s ' ' | cut -d' ' -f2 || true)"
[ "$rc" -eq 0 ] && command grep -qx 'trace_hash_valid: yes' "$W/verify.txt" \
  && ok "mindc verify exits 0 and prints 'trace_hash_valid: yes'" || no "mindc verify exit $rc or no 'trace_hash_valid: yes'"
[ "$TH" = "$(fact trace_hash)" ] && ok "trace hash equals ARTIFACT_FACTS.txt (${TH:0:16})" || no "trace hash '$TH' differs from the facts"
[ "$TH" = "$(sha256sum < "$BODY" | cut -d' ' -f1)" ] && ok "trace hash equals the SHA-256 of the plain body (kind mic3-bytes)" || no "trace hash is not the body SHA-256"
set +e; "$MINDC" inspect "$ART" > "$W/inspect.txt" 2>&1; rc=$?; set -e
[ "$rc" -eq 0 ] && command grep -q '^attested: *YES$' "$W/inspect.txt" && ok "mindc inspect exits 0 and prints 'attested: YES'" || no "mindc inspect exit $rc"

echo "== GATE 5: plain body is the first part, MAP at the offset =="
B=$(stat -c%s "$BODY"); S=$(stat -c%s "$ART")
cmp -s -n "$B" "$BODY" "$ART" && ok "the first $B bytes of the artifact equal the plain body" || no "the plain body is not a prefix"
[ "$(od -An -tx1 -j "$B" -N1 "$ART" | tr -d ' ')" = "4d" ] && ok "byte at offset $B is 0x4D (MAP sentinel)" || no "no 0x4D at offset $B"
[ "$S" = "$(fact artifact_bytes)" ] && [ "$B" = "$(fact body_bytes)" ] && [ "$B" = "$(fact map_offset)" ] && [ $((S - B)) = "$(fact map_bytes)" ] \
  && ok "sizes equal the facts: artifact $S, body = MAP offset $B, MAP $((S - B))" || no "sizes differ from ARTIFACT_FACTS.txt"

echo "== GATE 6: the MAP holds every line of records.txt =="
G="$(tail -c +$((B + 1)) "$ART" | command grep -a -o 'ga\.star\.pr25\.' | wc -l)"
[ "$G" = "$N" ] && ok "'ga.star.pr25.' occurs $G times in the MAP part, once per line of records.txt" || no "'ga.star.pr25.' occurs $G times, records.txt has $N lines"
build base || { no "build of the compiler-only MAP"; totals; }
C0=$(od -An -tu1 -j $((B + 1)) -N1 "$W/base/pr25.mic3" | tr -d ' ')
cmp -s "$BODY" "$W/base/pr25.body.mic3" && [ "$C0" -lt 128 ] \
  && ok "the build with no records has the same body and $C0 compiler entries" || no "the build with no records differs in its body or count"
[ $((C0 + N)) = "$(fact map_entries)" ] && [ "$C0" = "$(fact compiler_map_entries)" ] \
  && ok "MAP entry count $C0 + $N = $((C0 + N)) equals the facts" || no "entry counts differ from the facts"
{ cat "$BODY"; printf 'M'; uleb $((C0 + N)); tail -c +$((B + 3)) "$W/base/pr25.mic3"
  for l in "${LINES[@]}"; do k="${l%%=*}"; v="${l#*=}"; uleb ${#k}; printf '%s' "$k"; printf '\x00'; uleb ${#v}; printf '%s' "$v"; done
} > "$W/rebuilt.mic3"
cmp -s "$W/rebuilt.mic3" "$ART" \
  && ok "the artifact equals body + 0x4D + count + the $C0 compiler entries + one string entry per line, in line order" \
  || no "the artifact is not body + compiler entries + the records (cmp: $(cmp "$W/rebuilt.mic3" "$ART" 2>&1 | head -1))"
CH=("${ARGS[@]}"); CH[1]="${CH[1]}x"
build changed "${CH[@]}" || { no "build with one changed record"; totals; }
CT="$("$MINDC" verify "$W/changed/pr25.mic3" 2>&1 | command grep -m1 '^trace_hash: ' | tr -s ' ' | cut -d' ' -f2 || true)"
[ "$(sha256sum < "$W/changed/pr25.mic3")" != "$(sha256sum < "$ART")" ] && ok "one record changed by one character: a different artifact SHA-256" || no "a changed record leaves the artifact SHA-256 unchanged"
[ "$CT" = "$TH" ] && ok "the same change leaves the trace hash unchanged: the records are pinned by the file SHA-256, not by the trace hash" \
  || no "trace hash changed with a record ('$CT')"

totals
