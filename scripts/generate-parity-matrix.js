#!/usr/bin/env node
/**
 * generate-parity-matrix.js
 *
 * Checks for exported symbols (functions, classes, types) across the
 * TypeScript, Go, and Dart SDKs and outputs a Markdown feature-parity
 * table.  The table is then embedded in
 * docs/concepts/design-principles.mdx between two sentinel comments so
 * the file can be regenerated idempotently.
 *
 * Usage:
 *   node scripts/generate-parity-matrix.js          # write to doc
 *   node scripts/generate-parity-matrix.js --print  # print to stdout only
 */

"use strict";

const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const DESIGN_PRINCIPLES_DOC = path.join(
  ROOT,
  "docs",
  "concepts",
  "design-principles.mdx"
);

// ─── sentinel markers ────────────────────────────────────────────────────────
const BEGIN_MARKER = "<!-- PARITY_MATRIX_BEGIN -->";
const END_MARKER = "<!-- PARITY_MATRIX_END -->";

// ─── feature definitions ────────────────────────────────────────────────────
//
// Each entry describes one cross-platform capability.  The `check` object
// maps an SDK identifier to a list of file glob patterns or explicit file
// paths that must contain at least one of the `symbols` exported.
//
// Checks are done with simple regex-based text search so the script has
// zero npm dependencies.

const FEATURES = [
  {
    name: "Address detection (`Detect` / `detectAddress`)",
    description: "Classify a raw string as G, M, or C address",
    checks: {
      ts: {
        files: ["packages/core-ts/src/address/detect.ts"],
        symbols: ["detectAddress", "export function detect"],
      },
      go: {
        files: ["packages/core-go/address/detect.go"],
        symbols: ["func Detect("],
      },
      dart: {
        files: ["packages/core-dart/lib/src/address/detect.dart"],
        symbols: ["detectAddress(", "AddressKind detect"],
      },
    },
  },
  {
    name: "Address parsing (`Parse` / `parse`)",
    description: "Full parse into a typed result with warnings",
    checks: {
      ts: {
        files: ["packages/core-ts/src/address/parse.ts"],
        symbols: ["export function parse"],
      },
      go: {
        files: ["packages/core-go/address/parse.go"],
        symbols: ["func Parse("],
      },
      dart: {
        files: ["packages/core-dart/lib/src/address/parse.dart"],
        symbols: ["ParsedAddress parse(", "ParsedAddress", "export"],
      },
    },
  },
  {
    name: "Address validation (`Validate` / `validate`)",
    description: "Boolean validity check for a Stellar address",
    checks: {
      ts: {
        files: ["packages/core-ts/src/address/validate.ts"],
        symbols: ["export function validate", "export function isValid"],
      },
      go: {
        files: ["packages/core-go/address/validate.go"],
        symbols: ["func Validate(", "func IsValid("],
      },
      dart: {
        files: ["packages/core-dart/lib/src/address/validate.dart"],
        symbols: ["bool validate(", "bool isValid("],
      },
    },
  },
  {
    name: "Muxed address encoding",
    description: "Encode a G-address + uint64 ID into an M-address",
    checks: {
      ts: {
        files: ["packages/core-ts/src/muxed/encode.ts"],
        symbols: ["export function encodeMuxed", "export function encode"],
      },
      go: {
        files: ["packages/core-go/muxed/encode.go"],
        symbols: ["func EncodeMuxed(", "func Encode("],
      },
      dart: {
        files: ["packages/core-dart/lib/src/muxed/encode.dart"],
        symbols: ["encodeMuxed(", "String encode("],
      },
    },
  },
  {
    name: "Muxed address decoding",
    description: "Decode an M-address back to G-address + uint64 ID",
    checks: {
      ts: {
        files: ["packages/core-ts/src/muxed/decode.ts"],
        symbols: ["export function decodeMuxed", "export function decode"],
      },
      go: {
        files: ["packages/core-go/muxed/decode.go"],
        symbols: ["func DecodeMuxed(", "func Decode("],
      },
      dart: {
        files: ["packages/core-dart/lib/src/muxed/decode.dart"],
        symbols: ["decodeMuxed(", "DecodedMuxedAddress decode"],
      },
    },
  },
  {
    name: "Routing extraction (`extractRouting`)",
    description: "Resolve deposit routing ID from address + memo",
    checks: {
      ts: {
        files: ["packages/core-ts/src/routing/extract.ts"],
        symbols: ["export function extractRouting"],
      },
      go: {
        files: ["packages/core-go/routing/extract.go"],
        symbols: ["func ExtractRouting("],
      },
      dart: {
        files: ["packages/core-dart/lib/src/routing/extract.dart"],
        symbols: ["Future<RoutingResult> extractRouting(", "RoutingResult extractRoutingSync("],
      },
    },
  },
  {
    name: "Precision-safe routing ID (`SafeRoutingId`)",
    description: "Lossless uint64 wrapper for JS/Flutter Web",
    checks: {
      ts: {
        files: ["packages/core-ts/src/routing/safeRoutingId.ts"],
        symbols: ["export class SafeRoutingId"],
      },
      go: {
        files: ["packages/core-go/routing/result.go"],
        symbols: ["type RoutingID struct", "func NewRoutingID("],
      },
      dart: {
        files: ["packages/core-dart/lib/src/routing/safe_routing_id.dart"],
        symbols: ["class SafeRoutingId"],
      },
    },
  },
  {
    name: "Routing ID JSON as string",
    description: "routingId serializes as a decimal string, never a raw integer",
    checks: {
      ts: {
        files: ["packages/core-ts/src/routing/safeRoutingId.ts"],
        symbols: ["toJSON()", "toString()"],
      },
      go: {
        files: ["packages/core-go/routing/result.go"],
        symbols: ["MarshalJSON"],
      },
      dart: {
        files: ["packages/core-dart/lib/src/routing/routing_result.dart"],
        symbols: ["idString", "get idString"],
      },
    },
  },
  {
    name: "Warning system",
    description: "Structured, non-throwing warnings on edge cases",
    checks: {
      ts: {
        files: ["packages/core-ts/src/address/types.ts"],
        symbols: ["WarningCode", "Warning"],
      },
      go: {
        files: ["packages/core-go/address/warnings.go"],
        symbols: ["type Warning struct", "Warn"],
      },
      dart: {
        files: ["packages/core-dart/lib/src/routing/routing_result.dart"],
        symbols: ["class RoutingWarning"],
      },
    },
  },
  {
    name: "SEP-0029 memo requirement check",
    description: "Flag when a destination account requires a routing memo",
    checks: {
      ts: {
        files: ["packages/core-ts/src/routing/memoRequirement.ts"],
        symbols: ["MISSING_REQUIRED_MEMO", "memoRequirement", "extractRoutingWith"],
      },
      go: {
        files: ["packages/core-go/routing/extract.go"],
        symbols: ["ExtractRoutingWithMemoRequirement(", "WarnMissingRequiredMemo"],
      },
      dart: {
        files: ["packages/core-dart/lib/src/routing/extract.dart"],
        symbols: ["fetchMemoRequirement", "missingRequiredMemo"],
      },
    },
  },
  {
    name: "Spec test-vector runner",
    description: "Consume vectors.json to validate implementation",
    checks: {
      ts: {
        files: ["packages/core-ts/src/spec"],
        symbols: ["spec", "vectors", "runSpec"],
        directory: true,
      },
      go: {
        files: ["packages/core-go/spec/vectors_test.go"],
        symbols: ["TestVectors", "spec_version"],
      },
      dart: {
        files: ["packages/core-dart/test/spec_runner_test.dart"],
        symbols: ["spec", "vectors"],
      },
    },
  },
  {
    name: "URI / SEP-0007 routing extraction",
    description: "Extract routing info from a SEP-0007 payment URI",
    checks: {
      ts: {
        files: ["packages/core-ts/src/routing/extractFromURI.ts"],
        symbols: ["extractFromURI", "extractRoutingFromURI"],
      },
      go: {
        files: ["packages/core-go/routing/uri.go"],
        symbols: ["func ExtractFromURI(", "func ParseURI("],
      },
      dart: {
        files: ["packages/core-dart/lib/src"],
        symbols: ["extractFromUri", "extractRoutingFromUri"],
        directory: true,
      },
    },
  },
];

// ─── helpers ─────────────────────────────────────────────────────────────────

/**
 * Returns true if any file in `filePaths` exists and contains at least one
 * of the given symbol strings.
 */
function checkSymbols(filePaths, symbols, isDirectory) {
  const absolutePaths = filePaths.map((f) => path.join(ROOT, f));

  if (isDirectory) {
    // For directory checks we search all files recursively
    for (const dir of absolutePaths) {
      if (!fs.existsSync(dir)) continue;
      if (searchDirectory(dir, symbols)) return true;
    }
    return false;
  }

  for (const absPath of absolutePaths) {
    if (!fs.existsSync(absPath)) continue;
    const content = fs.readFileSync(absPath, "utf8");
    if (symbols.some((sym) => content.includes(sym))) return true;
  }
  return false;
}

function searchDirectory(dir, symbols) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return false;
  }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (searchDirectory(full, symbols)) return true;
    } else if (entry.isFile()) {
      try {
        const content = fs.readFileSync(full, "utf8");
        if (symbols.some((sym) => content.includes(sym))) return true;
      } catch {
        // ignore unreadable files
      }
    }
  }
  return false;
}

const YES = "✅";
const NO = "❌";

// ─── build matrix ────────────────────────────────────────────────────────────

function buildMatrix() {
  const rows = [];

  for (const feature of FEATURES) {
    const tsOk = checkSymbols(
      feature.checks.ts.files,
      feature.checks.ts.symbols,
      feature.checks.ts.directory
    );
    const goOk = checkSymbols(
      feature.checks.go.files,
      feature.checks.go.symbols,
      feature.checks.go.directory
    );
    const dartOk = checkSymbols(
      feature.checks.dart.files,
      feature.checks.dart.symbols,
      feature.checks.dart.directory
    );

    rows.push({
      name: feature.name,
      description: feature.description,
      ts: tsOk,
      go: goOk,
      dart: dartOk,
    });
  }

  return rows;
}

// ─── render table ────────────────────────────────────────────────────────────

function renderTable(rows) {
  const lines = [];
  lines.push(`<!-- Generated by scripts/generate-parity-matrix.js — do not edit manually -->`);
  lines.push(`<!-- Last generated: ${new Date().toISOString().slice(0, 10)} -->`);
  lines.push("");
  lines.push("### Cross-Platform Feature Parity");
  lines.push("");
  lines.push("The table below is auto-generated by `scripts/generate-parity-matrix.js`.");
  lines.push("Run `node scripts/generate-parity-matrix.js` to refresh it after adding a feature.");
  lines.push("");
  lines.push("| Feature | Description | TypeScript | Go | Dart/Flutter |");
  lines.push("| ------- | ----------- | :--------: | :-: | :----------: |");

  for (const row of rows) {
    const ts = row.ts ? YES : NO;
    const go = row.go ? YES : NO;
    const dart = row.dart ? YES : NO;
    lines.push(`| ${row.name} | ${row.description} | ${ts} | ${go} | ${dart} |`);
  }

  lines.push("");

  // Summary counts
  const tsCount = rows.filter((r) => r.ts).length;
  const goCount = rows.filter((r) => r.go).length;
  const dartCount = rows.filter((r) => r.dart).length;
  const total = rows.length;

  lines.push(
    `> **Parity summary:** TypeScript ${tsCount}/${total} · Go ${goCount}/${total} · Dart/Flutter ${dartCount}/${total}`
  );
  lines.push("");

  return lines.join("\n");
}

// ─── embed in doc ────────────────────────────────────────────────────────────

function embedInDoc(tableMarkdown) {
  if (!fs.existsSync(DESIGN_PRINCIPLES_DOC)) {
    console.error(`Target doc not found: ${DESIGN_PRINCIPLES_DOC}`);
    process.exit(1);
  }

  const original = fs.readFileSync(DESIGN_PRINCIPLES_DOC, "utf8");
  const block = `${BEGIN_MARKER}\n${tableMarkdown}${END_MARKER}`;

  let updated;
  if (original.includes(BEGIN_MARKER)) {
    // Replace existing block
    const startIdx = original.indexOf(BEGIN_MARKER);
    const endIdx = original.indexOf(END_MARKER);
    if (endIdx === -1) {
      console.error("Found BEGIN_MARKER but not END_MARKER — manual fix needed.");
      process.exit(1);
    }
    updated =
      original.slice(0, startIdx) +
      block +
      original.slice(endIdx + END_MARKER.length);
  } else {
    // Append at end
    updated = original.trimEnd() + "\n\n" + block + "\n";
  }

  fs.writeFileSync(DESIGN_PRINCIPLES_DOC, updated, "utf8");
  console.log(`✅ Parity matrix embedded in ${path.relative(ROOT, DESIGN_PRINCIPLES_DOC)}`);
}

// ─── main ─────────────────────────────────────────────────────────────────────

(function main() {
  const printOnly = process.argv.includes("--print");

  const rows = buildMatrix();
  const tableMarkdown = renderTable(rows);

  if (printOnly) {
    process.stdout.write(tableMarkdown + "\n");
    return;
  }

  embedInDoc(tableMarkdown);

  // Print a quick summary to stdout for CI logs
  const tsCount = rows.filter((r) => r.ts).length;
  const goCount = rows.filter((r) => r.go).length;
  const dartCount = rows.filter((r) => r.dart).length;
  const total = rows.length;
  console.log(
    `Parity summary: TypeScript ${tsCount}/${total} · Go ${goCount}/${total} · Dart/Flutter ${dartCount}/${total}`
  );
})();
