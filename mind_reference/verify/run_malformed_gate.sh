#!/usr/bin/env bash
# Execute the canonical malformed-input boundary gate through native MIND.
# Uses the public single-file --emit-shared path, which links MIND's public
# runtime-support shim and does not require the separately provisioned project runtime.
set -euo pipefail

MINDC="${MINDC:-mindc}"
R="$(cd "$(dirname "$0")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
SO="$W/pr25_malformed_boundary.so"

[ -x "$MINDC" ] || command -v "$MINDC" >/dev/null 2>&1 || {
  echo "FAIL: mindc not found: $MINDC" >&2
  exit 2
}

"$MINDC" "$R/src/pr25_malformed_boundary.mind" --emit-shared "$SO"
test -s "$SO"
python3 "$R/verify/check_malformed_shared.py" "$SO"
echo "shared-library sha256: $(sha256sum "$SO" | cut -d' ' -f1)"
