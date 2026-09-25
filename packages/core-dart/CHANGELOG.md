# Changelog — bluewhale_core (Dart)

All notable changes to this package are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Releases are coordinated with `spec/vectors.json` `spec_version`: see
[Changelogs & release versioning](../../CONTRIBUTING.md#changelogs--release-versioning).

## [Unreleased]

## [1.2.0] - 2026-09-24

Implements spec `1.2.0`.

### Added

- `RoutingInput.minSeverityLevel` plus `WarningSeverity`, `severityOrder`,
  `severityWeight` and `filterBySeverity` using the normative weights
  `info = 0`, `warn = 1`, `error = 2`. `extractRoutingSync` / `extractRouting`
  filter warnings by the threshold (default `info`).

### Fixed

- Contract senders (`C...` source account) now emit the spec warning code
  `CONTRACT_SENDER_DETECTED` instead of `contract-sender`.

## [1.1.0] - 2026-08-27

### Added

- **Flutter Web precision safety for 64-bit routing IDs.**
  - Added `SafeRoutingId`, a BigInt-backed wrapper that parses, validates,
    compares, and serializes MEMO_ID / muxed routing IDs as exact decimal
    strings — never through `int`/JS `Number` — so IDs above
    `Number.MAX_SAFE_INTEGER` (`2^53 - 1`) up to the uint64 ceiling
    (`2^64 - 1`) are never silently truncated in browser contexts.
  - Added conditional-compilation platform probe: `isWebJsRuntime` is
    `true` only when compiled to JavaScript (Flutter Web / dart2js / DDC).
  - Added web-safe accessors on `RoutingResult`: `idString` (exact canonical
    decimal string) and `safeId` (`SafeRoutingId` wrapper).
  - `SafeRoutingId.fromInt` refuses values above `Number.MAX_SAFE_INTEGER`
    on web builds instead of propagating an already-truncated JS `Number`.
  - MEMO_ID / MEMO_TEXT uint64 range validation now goes through the
    string-exact `SafeRoutingId` parser (behavior unchanged on all platforms).
  - New Flutter Web test vectors (`test/web_compat/routing_id_web_test.dart`,
    run with `dart test test/web_compat --platform chrome`) covering the
    2^53-1, 2^53, 2^53+1, 2^63-1, 2^63, and 2^64-1 boundary IDs through
    memo extraction, muxed decode, and JSON serialization.

## [1.0.0] - 2026-04-23

### Added

- Initial release of the Bluewhale for Dart and Flutter.
- Support for G, M, and C address detection and validation.
- Support for SEP-0023 Muxed Address encoding and decoding.
- Routing extraction logic for reconciling incoming payments.
