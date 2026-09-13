#!/bin/sh
# Tests an ALREADY COMPILED binary. Does not compile, transpile, or substitute Python.
set -eu
if [ "$#" -ne 1 ]; then
  echo 'Usage: check_compiled_output.sh /absolute/path/to/approved-MIND-built-binary' >&2
  exit 64
fi
case "$1" in /*) ;; *) echo 'Provide an absolute binary path.' >&2; exit 64;; esac
[ -x "$1" ] || { echo 'Executable not found.' >&2; exit 66; }
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
out=$(mktemp)
trap 'rm -f "$out"' EXIT HUP INT TERM
"$1" > "$out"
diff -u "$dir/EXPECTED_OUTPUT_NOT_EXECUTED.txt" "$out"
echo 'Compiled-output comparison PASS. Record compiler/source/binary hashes separately.'
