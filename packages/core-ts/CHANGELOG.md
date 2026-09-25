# Changelog — @redishfish/bluewhale-core

All notable changes to this package are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Releases are coordinated with `spec/vectors.json` `spec_version`: see
[Changelogs & release versioning](../../CONTRIBUTING.md#changelogs--release-versioning).

## [Unreleased]

## [1.2.0] - 2026-09-24

Implements spec `1.2.0`.

### Added

- `extractRouting` returns `CONTRACT_SENDER_DETECTED` (severity `info`) and
  clears routing state when `sourceAccount` is a Soroban contract (`C...`),
  matching core-go and core-dart.
- Exported `SEVERITY_ORDER`, `severityWeight` and `filterBySeverity` with the
  normative weights `info = 0`, `warn = 1`, `error = 2`.

### Fixed

- An unknown `minSeverityLevel` no longer drops every warning; unknown
  severities now weigh as `info`, identically to Go and Dart.

## [1.0.1] - 2026-04-24

### Changed

- Synced package documentation for the registry release.

## [1.0.0] - 2026-04-23

### Added

- Initial release: G / M / C address detection, parsing and validation,
  SEP-23 muxed encode/decode, and deposit routing extraction.
