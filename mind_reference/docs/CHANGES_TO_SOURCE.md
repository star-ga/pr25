# Every change made to the received `.mind` source

`src/pr25_reference_AS_RECEIVED.mind` is the handoff original, byte-for-byte
(sha256 `542532c9a03d5dc3006f33bea2fb1006bc4637eae270683d77b548186f93b265`,
verified against the handoff `SHA256SUMS.txt`). It does **not** compile.

`src/pr25_reference.mind` is the compiling version
(sha256 `18bf2915a81e73b3166593254fefcb3d34e03bdc574ea7e1cd5fbfd04e8fba47`).

## What was wrong

`mindc check` returned `fmt::drift` at line 21, then 33 — the parser rejects
the file before type-checking. Two causes:

1. **Compressed one-line blocks** — `while i < n { x = x * 2; i = i + 1; }`
2. **`else if` chains** — this `mindc` wants `else { if ... }`

Also: `-> bool` is sugar. The formatter rewrites `return true` → `return 1`
and `return false` → `return 0`. `bool` is i64 underneath.

## Proof the change is semantics-preserving

Token diff, comments stripped and `true`/`false` normalised to `1`/`0`:

```
orig tokens:      2707
formatted tokens: 2723
ADDED:   ['{', '}']   counts = {'{': 8, '}': 8}
REMOVED: none
```

**8 added brace pairs, nothing removed.** That is exactly the `else if` →
`else { if }` desugaring and nothing else. No identifier, operator, literal or
control-flow token changed.

Reproduce:

```sh
python3 docs/token_diff.py
```

## Why this matters more than it looks

A formatter that silently alters semantics would invalidate every downstream
gate, and "the formatter looked right" is not a property you can rely on. The
change was therefore verified mechanically rather than trusted. The token diff
is the receipt.
