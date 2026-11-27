# PR-25 records in a mic@3 artifact

`pr25.mic3` is the model rule `../src/model.mind`, compiled by the public `mindc 0.10.4`
release to a mic@3 artifact with an evidence MAP. The MAP holds the six
`evidence_chain.*` entries of the compiler and 1,248 string entries of our own, under the
key prefix `ga.star.pr25.`: the 1,247 records of the five data tables of the article at
https://star.ga/research/pr25, one record per entry, and one format entry.

The artifact is not committed. `../../verify/run_artifact_gate.sh` builds it from
`../src/model.mind` and `records.txt` and checks it against the pins in this folder.

```
records.txt               one KEY=VALUE line per MAP entry of our own (1,248 lines, 90,614 bytes)
ARTIFACT_SHA256SUMS.txt   SHA-256 of pr25.mic3 and of its plain body pr25.body.mic3
ARTIFACT_FACTS.txt        sizes, MAP offset, entry counts, trace hash
```

## Format "PR-25 records, version 1"

1. Every record is one MAP entry with a string value. The key is `ga.star.pr25.`, then the
   document name, a dot and the path. The document names are `events`, `families`,
   `manifest`, `properties` and `variants` (the five tables). One more entry,
   `ga.star.pr25.format`, has the value `s1`.
2. The path is the list of segments from the root of the document to one leaf, joined by
   dots. A member of an object gives its name as the segment; every name in the five tables
   matches `[A-Za-z0-9_-]+`, so no escape rule is needed. An element of an array gives `#`
   and its index in decimal, padded with zeros to the width of the largest index of that
   array, so the byte order of the keys is the order of the array.
3. The value is one type letter and a text: `s` and the string (a backslash is written
   `\\`, a line feed `\n`, a carriage return `\r`; nothing else changes); `i` and the
   integer in decimal; `n` and the number text of the source when it is not an integer;
   `b1` or `b0` for true or false; `z` for null; `a` for an empty array; `o` for an empty
   object. A non-empty array or object gives no entry of its own.
4. The mapping is lossless for the values: every leaf, every array order and every member
   name is in the MAP. The MAP keeps its keys in byte order, so it does not keep the order
   of the members inside an object (an order that JSON gives no meaning). We rebuilt the
   five tables from the MAP block of the built artifact: all five equal the published
   files as values. With the member order of the published files, and their writer
   (`JSON.stringify` with indent 1, or indent 2 for `manifest`; a final line feed on all
   files but `events`), the rebuilt files equal the published files byte for byte.

`records.txt` lists the entries in the byte order of their keys, one per line, in UTF-8,
with a final line feed and no empty line. The text after the first `=` of a line is the
value. A JSON form of these tables is no longer needed to read them: each record is one
line of `records.txt` and one entry of the artifact.

## Build

From the repository root, with the compiler at `mindc-0.10.4/` (commands in
`../../README.md`, section Reproduce):

```sh
MINDC="$PWD/mindc-0.10.4/mindc"
cd mind_reference/model/artifact
mapfile -t L < records.txt
A=(); for l in "${L[@]}"; do A+=(--evidence-attr "$l"); done
"$MINDC" ../src/model.mind --emit-evidence pr25.mic3 "${A[@]}"
"$MINDC" ../src/model.mind --emit-mic3 pr25.body.mic3
sha256sum -c ARTIFACT_SHA256SUMS.txt
"$MINDC" verify pr25.mic3
"$MINDC" inspect pr25.mic3
```

Each record is one argument of a bash array, so spaces, quotes, `=` and letters outside
ASCII reach the compiler unchanged. `sha256sum -c` prints `OK` for both files.
`mindc verify` exits 0 and prints, among other lines:

```
trace_hash_valid: yes
```

`mindc inspect` exits 0 and decodes the body; one of its lines is:

```
attested:         YES
```

The gate: `MINDC="$PWD/mindc-0.10.4/mindc" ./mind_reference/verify/run_artifact_gate.sh`
(from the repository root; no node and no python).

## What is attested

The trace hash attests the IR body only; the records are MAP entries outside it, and this
artifact is not signed, so the records are pinned only by the SHA-256 of the whole file in
`ARTIFACT_SHA256SUMS.txt`. `mindc verify` says so itself: "provenance
(substrate/toolchain/parent) is NOT authenticated — these MAP fields sit outside
trace_hash; sign the artifact and pin --signer-pubkey to authenticate them". The gate shows
it: one record changed by one character gives a different file SHA-256 and the same trace
hash.

## Facts (`ARTIFACT_FACTS.txt`)

```
artifact_bytes 101641
body_bytes 9461
map_offset 9461
map_bytes 92180
map_entries 1254
compiler_map_entries 6
namespace_entries 1248
trace_hash 993a9ac50b9c71339b10f41f81e37ef72285ce07319c9e7c9e1f6b6c2abd6436
```

The MAP starts at byte offset 9461 (the end of the plain body) with the byte 0x4D. Of its
1,254 entries, 6 are the compiler's and 1,248 are under `ga.star.pr25.`. The trace hash is
the SHA-256 of the plain body (kind `mic3-bytes`).

## What the gate proves, and what it does not

It proves: two clean builds give the same bytes; both files equal their pins; `mindc
verify` accepts the artifact; the plain body is the first part of the artifact and the MAP
starts after it; and the whole artifact equals, byte for byte, the plain body, the MAP
sentinel, the entry count, the six entries of a build with no records, and one string
entry per line of `records.txt`, in line order. So the MAP holds every line of
`records.txt`, unchanged, and nothing else of ours.

It does not prove that `records.txt` equals the published tables (the conversion and the
check back were made with tools outside this repository), that a reader decodes the
values as in section 4, or anything about the records beyond the file SHA-256: they are not
covered by the trace hash and the artifact is not signed.

## Where the records come from

From the five data tables of the article at https://star.ga/research/pr25. Their texts are
label text from the Technical Paper, the Brief and the public checkers, and wording of the
article; their computed numbers are output of the exporter in `../` (see `../README.md`).
The `manifest` document names the source of each file (its `source` fields).

These are results of a logical reference model only: not simulation, not hardware
validation, not certification, and not a physical robot safety proof. The 25 families are
candidate requirement families; 25 is not claimed to be complete or minimal.
