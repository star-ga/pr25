# PR-25 v0.4 executable reference evidence

Read `../PR25_Verification_Note_v0.4.pdf` or its Markdown source first.

Run `python3 pr25_verify.py --output verified_results.json` using Python 3.10+,
without `-O`. It uses the standard library, preserves the original transition
source, independently states the admission properties, and exits nonzero on a
failed check. The original checker and original results remain unchanged for
historical reproduction. `ORIGINAL_README.md` belongs to that original artifact.

The strengthened harness catches the documented shared-helper oracle weakness,
checks a separate transition specification, constructs reachability witnesses,
checks the finite admission fold, and tests the explicitly selected mutants.
No listed physical challenge, deployment claim, or commercial implementation is
verified by this program. These source files expose the abstract reference model,
not a private implementation architecture.
