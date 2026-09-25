/**
 * Coordinated release check.
 *
 * Every SDK is released in lockstep with spec/vectors.json `spec_version`:
 *   - packages/spec/vectors.json carries the same spec_version,
 *   - packages/spec, core-ts and core-dart manifests use that exact version,
 *   - core-ts, core-go and core-dart CHANGELOG.md (Keep a Changelog format)
 *     contain an `## [Unreleased]` section and a `## [<spec_version>]` entry.
 *
 * core-go has no manifest version; it is released as the git tag
 * `packages/core-go/v<spec_version>` and tracked through its CHANGELOG.
 */
const fs = require("fs");
const path = require("path");

const rootDir = path.join(__dirname, "..");
const read = (rel) => fs.readFileSync(path.join(rootDir, rel), "utf8");
const exists = (rel) => fs.existsSync(path.join(rootDir, rel));

const specVersion = JSON.parse(read(path.join("spec", "vectors.json"))).spec_version;

const errors = [];

// 1. Published spec package mirrors the normative spec version.
const publishedVectors = path.join("packages", "spec", "vectors.json");
if (exists(publishedVectors)) {
  const published = JSON.parse(read(publishedVectors)).spec_version;
  if (published !== specVersion) {
    errors.push(`${publishedVectors}: spec_version ${published}, expected ${specVersion}`);
  }
}

// 2. Package manifests are versioned in lockstep with the spec.
const manifests = [
  { file: path.join("packages", "spec", "package.json"), version: (s) => JSON.parse(s).version },
  { file: path.join("packages", "core-ts", "package.json"), version: (s) => JSON.parse(s).version },
  {
    file: path.join("packages", "core-dart", "pubspec.yaml"),
    version: (s) => (s.match(/^version:\s*["']?([^\s"']+)/m) || [])[1],
  },
];

for (const { file, version } of manifests) {
  if (!exists(file)) continue;
  const found = version(read(file));
  if (found !== specVersion) {
    errors.push(`${file}: version ${found}, expected ${specVersion}`);
  }
}

// 3. Keep a Changelog entries exist for the release.
const changelogs = [
  path.join("packages", "core-ts", "CHANGELOG.md"),
  path.join("packages", "core-go", "CHANGELOG.md"),
  path.join("packages", "core-dart", "CHANGELOG.md"),
];
const escaped = specVersion.replace(/\./g, "\\.");
const releaseHeading = new RegExp(`^## \\[${escaped}\\] - \\d{4}-\\d{2}-\\d{2}\\s*$`, "m");

for (const file of changelogs) {
  if (!exists(file)) {
    errors.push(`${file}: missing`);
    continue;
  }
  const content = read(file);
  if (!/^## \[Unreleased\]\s*$/m.test(content)) {
    errors.push(`${file}: missing "## [Unreleased]" section`);
  }
  if (!releaseHeading.test(content)) {
    errors.push(`${file}: missing "## [${specVersion}] - YYYY-MM-DD" entry`);
  }
}

if (errors.length > 0) {
  for (const error of errors) console.error("Mismatch: " + error);
  process.exit(1);
}

console.log("All packages are in sync with spec_version: " + specVersion);
