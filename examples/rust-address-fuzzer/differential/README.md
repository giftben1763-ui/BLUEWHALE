# Differential address harness (TS vs Go vs Dart)

`rust-address-fuzzer` only exercises Rust's `prism-core`. This harness feeds
the **same** randomized, mutated addresses into the `detect` + `parse`
implementations of `core-ts`, `core-go` and `core-dart` and logs every input
on which the SDKs disagree.

```bash
pnpm install                                   # TS adapter is bundled with esbuild (via tsup)
node scripts/differential-fuzz.js              # 10,000 inputs, random seed
node scripts/differential-fuzz.js --seed 42    # reproducible run
node scripts/differential-fuzz.js --corpus inputs.txt --compare-errors
```

Missing toolchains (`go`, `dart`) are skipped with a warning unless
`--require-all` (or an explicit `--langs`) is passed. Mismatches are written
as JSON Lines to `examples/rust-address-fuzzer/findings/differential-mismatches.jsonl`
(override with `--out`); each entry records the input, the mutator that
produced it, the seed and the raw per-language outcome. The process exits `1`
when any mismatch is found.

## What is compared

For every input the harness compares, per language:

| Field            | Meaning                                                   |
|------------------|-----------------------------------------------------------|
| `detect`         | `G`, `M`, `C` or `null` for anything invalid              |
| `parse.ok`       | whether `parse` accepted the input                        |
| `parse.kind`     | parsed kind                                               |
| `parse.address`  | canonical (upper-case) address                            |
| `parse.baseG`    | M-addresses only: underlying G-address                    |
| `parse.muxedId`  | M-addresses only: decimal muxed ID                        |
| `parse.error`    | error code, only with `--compare-errors`                  |

Error codes are opt-in because the SDKs do not yet share a single error
taxonomy (e.g. core-dart reports `UNKNOWN_PREFIX` for every failure).

## Mutators

Seeds are valid, correctly checksummed G / M / C StrKeys. Each input is either
a mutated seed (`replaceChar`, `junkChar`, `insertChar`, `deleteChar`,
`swapAdjacent`, `truncate`, `extend`, `lowercaseAll`, `lowercaseOne`,
`changePrefix`, `whitespace`, `identity`) or a synthesized edge case with a
*valid checksum* (`wrongLength`, `foreignVersion`, `crossKind`, `unusedBits`),
plus `empty` and `garbage`. 20% of inputs receive a second stacked mutation.

## Adapters

Every adapter reads one JSON string per line on stdin and writes one JSON
outcome per line on stdout:

```json
{"detect":"M","parse":{"ok":true,"kind":"M","address":"M...","baseG":"G...","muxedId":"42","error":null}}
```

| Language | Adapter                    | How it is run                                          |
|----------|----------------------------|--------------------------------------------------------|
| TS       | `ts_adapter.ts`            | bundled from `packages/core-ts/src` with esbuild       |
| Go       | `go_adapter/`              | `go build` (module `replace`s `packages/core-go`)      |
| Dart     | `dart_adapter.dart`        | `dart --packages=packages/core-dart/.dart_tool/...`    |

To add a language, write an adapter that speaks the same protocol and
register it in `prepareAdapters` in `scripts/differential-fuzz.js`.
