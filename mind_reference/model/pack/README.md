# PR-25 packer

A MIND program that reads the text output of the exporter (`../`, `export.txt`) on
standard input and writes the five binary files that the article at
https://star.ga/research/pr25 loads. It holds no model logic: it parses the `C`, `S`
and `T` lines and packs their numbers. The counts (states, transitions, events) come
from the `C` line of the input. It builds with the public `mindc 0.10.4` release on the
native backend.

```
Mind.toml
src/main.mind        the two passes (counts, then packing) and the file writes
src/lines.mind       reads standard input, splits it into lines of numbers
src/emit.mind        byte stores, full writes, the error message
PACK_SHA256SUMS.txt  SHA-256 of the five files
```

## Build and run

From the repository root, with the compiler at `mindc-0.10.4/` (commands in
`../../README.md`, section Reproduce) and `export.txt` made as in `../README.md`:

```sh
MINDC="$PWD/mindc-0.10.4/mindc"
cd mind_reference/model/pack
"$MINDC" check
"$MINDC" build --backend native
./target/debug/pr25pack < ../export.txt 3>states.u16le.bin 4>depth.u8.bin 5>flags.u8.bin 6>parent.u16le_u8.bin 7>transitions.u16le.bin
sha256sum -c PACK_SHA256SUMS.txt
```

Expected: `check` and `build` exit 0; the binary is 25,760 bytes with SHA-256
`3fef2d54392dfc5876c270a3f179ef1b3573f1b8850321616823dbb3c4b689f4` (two clean builds
give the same bytes; a record of one build, not a pin); the program exits 0;
`sha256sum -c` prints `OK` for each of the five files.

## The five files

| fd | File | Bytes | Per state (3,078) | SHA-256 |
|---|---|---|---|---|
| 3 | `states.u16le.bin` | 6,156 | 13-bit encoding, u16 little-endian | `83b72734bcd23970138ed65aee92c9c3d05142ab6efaff2f067a76b2b7441a0b` |
| 4 | `depth.u8.bin` | 3,078 | search depth, u8 | `84b6d10a6d1309c27f79ba1171a5711af6c0a496e0e826260e0ba91003295d9b` |
| 5 | `flags.u8.bin` | 3,078 | flag column of the `S` line, u8 | `865f877b78497300505dfd56e5e5e9475253598535486c7a04afd9e335a6a501` |
| 6 | `parent.u16le_u8.bin` | 9,234 | parent index, u16 LE (65535 = none); parent event, u8 (255 = none) | `ad1cbe03060c8e19cacdd93fd01d818ed6746b6e6557c3bd4641d06f8d2216fe` |
| 7 | `transitions.u16le.bin` | 166,212 | for events 0..26: next index + 4096 x output, u16 LE | `e3f6bf653b3a38dd5cd6274e3d494a7da9c8e5bb1ed170f556fe9331fba0c8ab` |

The article's data manifest, https://star.ga/data/pr25/manifest.json , lists these
five files with these SHA-256 values.

## Errors

On a fault the program writes `pr25pack: error <code> line <line>` to standard error
(line 0: the whole input) and exits with the code: 1 read error, 2 input over 8 MiB,
3 malformed line, 4 `C` line missing, repeated or out of range, 5 count of `S` or `T`
lines differs from the `C` line, 6 bad `S` line, 7 bad `T` line, 8 count of `T` values
differs from the `C` line, 9 short write on fd 3..7. It writes no byte before every
line is checked. The shell redirections of the command above create the five files
before the program starts, so after a refused input (codes 1 to 8) the five files are
empty.

## Check it

From the repository root:

```sh
MINDC="$PWD/mindc-0.10.4/mindc" ./mind_reference/verify/run_pack_gate.sh
```

The gate builds the exporter and this program twice each from clean folders on the
native backend and compares the binaries, runs the exporter and checks the SHA-256 of
its output, packs it, runs `sha256sum -c PACK_SHA256SUMS.txt`, checks the five file
sizes, and checks that eleven kinds of bad input give their error codes (each of the
codes 1 to 9 at least once: for example a truncated input, a malformed line, a wrong
count in the `C` line, a short `S` or `T` line, a closed fd 7). It uses no node and no
python.

## Bounds

- The files of the live article were first packed by a script outside this
  repository. This program gives the same bytes, and the gate proves it: the values in
  `PACK_SHA256SUMS.txt` are the SHA-256 of the live files.
- The files hold logical reference-model results. They are not simulation, hardware
  validation, certification, or a physical robot safety proof.
