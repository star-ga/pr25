#!/usr/bin/env bash
# Write src/pins.mind from the H and G lines of one run of the exporter.
# Usage: ./mkpins.sh <exporter output> > src/pins.mind
# The pins are a self-check: a changed rule line changes a digest and the program exits 6.
set -e
awk '
 $1=="H" {ha=$2; hb=$3}
 $1=="G" {g[$2]=$3; n++}
 END {
  if (n!=16 || ha=="") { print "mkpins: H or G lines missing" > "/dev/stderr"; exit 1 }
  print "// Pinned digests of the transition tables, written by mkpins.sh from the H and G lines of the exporter output."
  print "pub fn pin_full(m: i64) -> i64 {"
  for (m=0; m<=15; m++) { printf "    if m == %d {\n        return %s;\n    }\n", m, g[m] }
  print "    return 0 - 1;\n}"
  printf "pub fn pin_table_a() -> i64 {\n    return %s;\n}\n", ha
  printf "pub fn pin_table_b() -> i64 {\n    return %s;\n}\n", hb
 }' "$1"
