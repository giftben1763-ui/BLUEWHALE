/**
 * check-vectors-sync.js
 *
 * Verifies that every SDK package that tracks the spec version is aligned
 * with the `spec_version` field in `spec/vectors.json`.
 *
 * ## Checked packages
 *
 * | Package                         | File                              | Field        |
 * | ------------------------------- | --------------------------------- | ------------ |
 * | @redishfish/bluewhale-spec      | packages/spec/package.json        | version      |
 * | @redishfish/bluewhale-core (TS) | packages/core-ts/package.json     | version      |
 * | bluewhale_core (Dart/Flutter)   | packages/core-dart/pubspec.yaml   | spec_version |
 *
 * ## Go module versioning
 *
 * The Go SDK (`packages/core-go`) follows the standard Go module versioning
 * convention: releases are tagged as Git tags in the form:
 *
 *   packages/core-go/v<major>.<minor>.<patch>
 *   e.g. packages/core-go/v1.0.1
 *
 * Because the Go module version lives in a Git tag rather than a source
 * file, this script cannot check it automatically at development time.
 * To keep the Go SDK in sync with the spec:
 *
 *   1. When `spec_version` is bumped in `spec/vectors.json`, create a
 *      matching Git tag:
 *        git tag packages/core-go/v<new_spec_version>
 *        git push origin packages/core-go/v<new_spec_version>
 *
 *   2. The `verify-parity.yml` CI workflow runs `go test ./...` against
 *      the same spec vectors to confirm behavioral alignment independently
 *      of the version tag.
 *
 * Run:
 *   node scripts/check-vectors-sync.js
 *
 * Exit code 0 = all in sync.  Exit code 1 = at least one mismatch.
 */

"use strict";

const fs = require("fs");
const path = require("path");

const rootDir = path.join(__dirname, "..");
const specPath = path.join(rootDir, "spec", "vectors.json");
const specVersion = JSON.parse(fs.readFileSync(specPath, "utf8")).spec_version;

let hasError = false;

// ─── JSON / package.json checks ──────────────────────────────────────────────

const jsonPackages = [
  path.join("packages", "spec", "package.json"),
  path.join("packages", "core-ts", "package.json"),
];

jsonPackages.forEach((filePath) => {
  const absolutePath = path.join(rootDir, filePath);
  if (!fs.existsSync(absolutePath)) {
    console.warn("Warning: file not found, skipping: " + filePath);
    return;
  }

  const pkg = JSON.parse(fs.readFileSync(absolutePath, "utf8"));
  if (pkg.version !== specVersion) {
    console.error(
      "Mismatch in " +
        filePath +
        ": expected " +
        specVersion +
        ", found " +
        pkg.version
    );
    hasError = true;
  }
});

// ─── Dart / pubspec.yaml check ────────────────────────────────────────────────
//
// The Dart package publishes its own semantic version to pub.dev via the
// `version:` field in pubspec.yaml.  That version may advance independently
// of the spec (e.g. for bug fixes or new Dart-specific features).  To track
// spec alignment separately we read the `spec_version:` field.
//
// Adding the field to pubspec.yaml:
//   spec_version: 1.0.1
//
// If the field is absent the check is skipped with a warning so that existing
// installs continue to work while maintainers add the field.

const dartPubspecPath = path.join(
  rootDir,
  "packages",
  "core-dart",
  "pubspec.yaml"
);

if (!fs.existsSync(dartPubspecPath)) {
  console.warn(
    "Warning: packages/core-dart/pubspec.yaml not found, skipping Dart check."
  );
} else {
  const pubspecContent = fs.readFileSync(dartPubspecPath, "utf8");
  const dartSpecVersion = extractYamlTopLevelValue(
    pubspecContent,
    "spec_version"
  );

  if (dartSpecVersion === null) {
    console.warn(
      "Warning: 'spec_version' field not found in " +
        "packages/core-dart/pubspec.yaml. " +
        "Add 'spec_version: " +
        specVersion +
        "' to track spec alignment."
    );
  } else if (dartSpecVersion !== specVersion) {
    console.error(
      "Mismatch in packages/core-dart/pubspec.yaml: " +
        "spec_version expected " +
        specVersion +
        ", found " +
        dartSpecVersion
    );
    hasError = true;
  }
}

// ─── Go module versioning note ───────────────────────────────────────────────
//
// Go versioning is checked at release time via Git tags; this script cannot
// automate that check.  See the block comment at the top of this file for
// the expected tagging convention.
//
// To verify the current Go SDK is aligned with the running spec version:
//   git tag -l "packages/core-go/v${specVersion}"

// ─── Result ──────────────────────────────────────────────────────────────────

if (hasError) {
  process.exit(1);
}

console.log("All packages are in sync with spec_version: " + specVersion);

// ─── helpers ─────────────────────────────────────────────────────────────────

/**
 * Extracts the value of a top-level YAML key from a YAML string without
 * pulling in a runtime YAML dependency.
 *
 * Only handles simple scalar values on the same line as the key
 * (e.g. `spec_version: 1.0.1`).  Returns null if the key is not found.
 *
 * @param {string} content - Full YAML file content.
 * @param {string} key     - Top-level key name to look for.
 * @returns {string|null}
 */
function extractYamlTopLevelValue(content, key) {
  // Match lines like:  key: value   or  key: "value"  or  key: '1.0.1'
  // The caret (^) ensures only top-level keys (no leading spaces) match.
  const re = new RegExp(
    "^" + escapeRegExp(key) + ":\\s*[\"']?([^\"'#\\r\\n]+)[\"']?",
    "m"
  );
  const match = content.match(re);
  if (!match) return null;
  return match[1].trim();
}

/**
 * Escapes a string for safe use in a RegExp literal.
 *
 * @param {string} s
 * @returns {string}
 */
function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
