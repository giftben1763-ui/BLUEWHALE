# StrKey: what we implement and what we take from `stellar/go`

This package uses StrKey in two ways. It decodes addresses with its own
code, and it uses `github.com/stellar/go/strkey` as the reference to test
against.

## What lives where

| Concern | Implementation |
| --- | --- |
| Decoding G / M / C addresses (`address.DecodeStrKey`, `Detect`, `Parse`) | In-house: `address/strkey.go` (base32 + version byte + checksum) and `address/crc16.go` (CRC-16/XModem) |
| Encoding base G-addresses from muxed payloads (`address.EncodeStrKey`) | In-house: `address/strkey.go` |
| Decoding muxed addresses (`muxed.DecodeMuxed`) | In-house, via `address.DecodeStrKey` |
| Encoding muxed addresses (`muxed.EncodeMuxed`) | `github.com/stellar/go/strkey.MuxedAccount` |
| Conformance | Tests check the in-house codec against `stellar/go/strkey` byte for byte (`address/strkey_test.go`), plus the shared vectors in `spec/vectors.json` |

## Why decode ourselves

- **Allocation control on the hot path.** `address.Parse` runs once per
  incoming payment. The in-house decoder reuses a single base32 encoding
  value, checks the address prefix with byte comparisons, keeps scratch
  buffers on the stack, and returns preallocated error values. Each call
  makes 1–2 heap allocations. See the benchmarks in `README.md`.
- **One decoder for all three kinds.** `stellar/go/strkey.Decode` expects
  the caller to know the version byte up front. Routing input can be a G, M
  or C address, so `Detect` and `Parse` need to identify the kind while
  decoding.
- **Errors that match across languages.** Failures map to the error codes
  the TypeScript and Dart packages also use (`INVALID_CHECKSUM`,
  `INVALID_BASE32`, `INVALID_LENGTH`, `UNKNOWN_PREFIX`). The shared spec
  vectors test those codes.

## Why still depend on `stellar/go`

- `muxed.EncodeMuxed` delegates to `strkey.MuxedAccount`, so the M-addresses
  we produce come from the same code the rest of the Stellar Go ecosystem
  uses.
- The reference implementation is the check on our decoder. If the two ever
  disagree, `TestStrKeyMatchesStellarGo` fails.

Most Stellar Go projects already depend on `github.com/stellar/go`, so this
library does not add a new dependency for them.
