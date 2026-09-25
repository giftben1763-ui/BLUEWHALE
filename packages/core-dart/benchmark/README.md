# Benchmarks

`address_benchmark.dart` measures G and M address parsing throughput with
[`package:benchmark_harness`](https://pub.dev/packages/benchmark_harness). It
compares the Dart VM with the JavaScript that Flutter Web ships.

Each benchmark cycles through 256 generated addresses (fixed seed). The M
fixtures use muxed IDs from `0` up to `2^64 - 1`, including values on both
sides of `Number.MAX_SAFE_INTEGER`.

| Benchmark | What it measures |
|---|---|
| `detect(G)` / `detect(M)` | Prefix check, Base32 decode, CRC-16, version/length check |
| `StellarAddress.parse(G)` | `detect` plus object construction |
| `StellarAddress.parse(M)` | `detect` plus muxed decode (BigInt ID, base G re-encode) |
| `MuxedAddress.decode(M)` | Muxed decode alone, with no checksum validation |

## Running

From `packages/core-dart`:

```sh
# Dart VM, JIT
dart run benchmark/address_benchmark.dart

# Dart VM, AOT (what Flutter mobile/desktop release builds use)
dart compile exe benchmark/address_benchmark.dart -o build/bench
./build/bench

# JavaScript (what Flutter Web release builds use)
dart compile js -O2 benchmark/address_benchmark.dart -o build/bench.js
node build/bench.js
```

Each run prints a Markdown table you can paste below.

## Results

Recorded 2026-09-25: Dart SDK 3.13.4, Node.js 24.21.0 (V8), Linux x64,
2 vCPU Intel Xeon Platinum 8370C @ 2.80GHz. Repeated runs varied by about 3%.

| Benchmark | VM JIT (ops/s) | VM AOT (ops/s) | dart2js + Node (ops/s) | JS vs AOT |
|---|---:|---:|---:|---:|
| `detect(G)` | 306,601 | 315,870 | 391,437 | 1.24× |
| `detect(M)` | 259,460 | 262,726 | 321,473 | 1.22× |
| `StellarAddress.parse(G)` | 308,894 | 311,996 | 390,393 | 1.25× |
| `StellarAddress.parse(M)` | 110,354 | 111,640 | 130,081 | 1.17× |
| `MuxedAddress.decode(M)` | 190,422 | 179,741 | 240,150 | 1.34× |

Per operation, that is about 2.5–3.9 µs to validate an address and
7.7–9.1 µs for a full M parse.

### Takeaways

- **Flutter Web does not slow parsing down.** The dart2js output was 17–34%
  *faster* than the VM on this machine. The work here is mostly string
  handling (case folding, alphabet lookups), which V8 does well.
- **JIT and AOT perform about the same**, so the numbers from `dart run`
  are a good guide for release mobile and desktop builds.
- **M parsing costs about 3× G parsing.** Decoding the 64-bit ID and
  re-encoding the base `G…` address account for the extra time. Even so, a
  single core handles more than 100k M addresses per second.
- These are single-machine numbers. Browser engines other than V8, and
  low-end phones, will differ. Re-run on your target hardware before relying
  on the absolute values.
