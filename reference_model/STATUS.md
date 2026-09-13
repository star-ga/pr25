# Reference model — publication status

**Status: NOT YET PUBLISHED in this repository.**

The PR-25 Verification Note (v0.4) documents an executed finite reference-model
check and gives reproduction commands against these paths:

    reference_model/pr25_model_check.py      original checker, unchanged
    reference_model/pr25_model_results.json  original recorded results
    reference_model/pr25_verify.py           v0.4 strengthened verifier
    reference_model/verified_results.json    executed v0.4 results
    reference_model/ORIGINAL_README.md       historical source explanation

Those files are **not present here yet.** Until they are, the counts in the
Verification Note (3,078 reachable states; 27 events per state; 42 of 42
selected faulty variants detected; 221,184 transition comparisons; 271,453
bounded admission sequences; 19 malformed-input rejections) are **reported by
that note, not reproducible from this repository.**

This file exists so the gap is visible rather than inferred from a missing
directory. The Verification Note records these source digests, which any
published copy must match:

    pr25_model_check.py
    e5b69731fa56e4b0223a6c847c5a46cf23d834052d3b71403b37f3fb93311fe8

    pr25_model_results.json
    49f6c73b7cd35f9d7e90be91d4b632edfe83d71718cb554f80d418e532b8d710

    pr25_verify.py
    f886e034955b6143cf6c3673363a8293814f25bde523d1ac5d5a1ac1187ac740

Digests identify exact bytes. They are not signatures, certification, or
evidence about the physical truth of any input.

When the files are added, this file is replaced by the reproduction
instructions from the Verification Note §1.
