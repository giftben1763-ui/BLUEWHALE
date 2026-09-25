# Changelog — core-go

All notable changes to this package are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Releases are coordinated with `spec/vectors.json` `spec_version`: see
[Changelogs & release versioning](../../CONTRIBUTING.md#changelogs--release-versioning).

Go module versions are published as git tags of the form
`packages/core-go/vX.Y.Z`.

## [Unreleased]

## [1.2.0] - 2026-09-24

Implements spec `1.2.0`. First versioned release of the Go module; earlier
changes are available in the git history.

### Added

- `RoutingInput.MinSeverityLevel` and `routing.SeverityWeight` /
  `routing.FilterBySeverity` (plus `SeverityInfo`, `SeverityWarn`,
  `SeverityError`) using the normative weights `info = 0`, `warn = 1`,
  `error = 2`. `ExtractRouting` filters warnings by the threshold (default
  `info`).
- The spec vector runner now executes `extract_routing` vectors that carry a
  `sourceAccount` (contract-sender policy).
