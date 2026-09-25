#!/usr/bin/env node
/**
 * compare-prism-vs-ts.mjs
 * ──────────────────────────────────────────────────────────────────────────
 * Differential comparison: prism-core (Rust) vs @redishfish/bluewhale-core (TS).
 *
 * For each address in the corpus / random set, this script:
 *   1. Calls `prism-diff --json` to get prism-core's parse results (JSON-ND).
 *   2. Calls `extractRouting` from @redishfish/bluewhale-core on the same input.
 *   3. Reports any divergence in kind, muxed_id, or base_g.
 *
 * Usage:
 *   # Compare 1000 random addresses
 *   node compare-prism-vs-ts.mjs --random 1000
 *
 *   # Compare addresses from a corpus file
 *   node compare-prism-vs-ts.mjs --corpus /path/to/corpus.txt
 *
 *   # Pass a specific seed for reproducibility
 *   node compare-prism-vs-ts.mjs --random 500 --seed 42
 *
 * Prerequisites:
 *   1. Build prism-diff:
 *      cd examples/prism-core
 *      cargo build --features diff --bin prism-diff
 *
 *   2. Install @redishfish/bluewhale-core:
 *      npm install @redishfish/bluewhale-core
 *      (or: cd packages/core-ts && npm install)
 *
 * Exit codes:
 *   0 – No divergences found.
 *   1 – One or more divergences detected.
 *   2 – Usage / setup error.
 */

import { spawnSync } from "node:child_process";
import { createInterface } from "node:readline";
import { createReadStream } from "node:fs";
import { parseArgs } from "node:util";
import { Readable } from "node:stream";

// ── Argument parsing ─────────────────────────────────────────────────────────

const { values: args } = parseArgs({
  options: {
    random: { type: "string" },
    corpus: { type: "string" },
    seed: { type: "string" },
    verbose: { type: "boolean", default: false },
    help: { type: "boolean", default: false },
  },
});

if (args.help) {
  console.log(`
Usage: node compare-prism-vs-ts.mjs [options]

Options:
  --random <N>       Compare N randomly generated addresses
  --corpus <FILE>    Read addresses from newline-delimited file
  --seed <U64>       Fix PRNG seed for reproducible prism-diff output
  --verbose          Print every comparison result, not just divergences
  --help             Show this message
`);
  process.exit(0);
}

if (!args.random && !args.corpus) {
  console.error("error: specify --random <N> or --corpus <FILE>");
  process.exit(2);
}

// ── Import bluewhale-core ────────────────────────────────────────────────────

let extractRouting;
try {
  // Try the published package first, then fall back to the local workspace path.
  const mod = await import("@redishfish/bluewhale-core").catch(() =>
    import("../../packages/core-ts/src/index.js")
  );
  extractRouting = mod.extractRouting;
} catch (e) {
  console.error(
    "error: could not import @redishfish/bluewhale-core.\n" +
      "Run `npm install @redishfish/bluewhale-core` or build the local package first.\n" +
      String(e)
  );
  process.exit(2);
}

// ── Build prism-diff command ──────────────────────────────────────────────────

const prismBin = new URL(
  "../../target/debug/prism-diff",
  import.meta.url
).pathname;

const prismArgs = ["--json"];
if (args.random) prismArgs.push("--random", args.random);
if (args.corpus) prismArgs.push("--corpus", args.corpus);
if (args.seed) prismArgs.push("--seed", args.seed);

const prismResult = spawnSync(prismBin, prismArgs, {
  encoding: "utf8",
  maxBuffer: 50 * 1024 * 1024, // 50 MB
});

if (prismResult.error) {
  console.error(
    `error: could not spawn prism-diff at ${prismBin}.\n` +
      "Build it first: cd examples/prism-core && cargo build --features diff --bin prism-diff\n" +
      String(prismResult.error)
  );
  process.exit(2);
}

// Stderr from prism-diff contains the statistics summary – forward to stderr.
if (prismResult.stderr) process.stderr.write(prismResult.stderr);

// ── Parse JSON-ND output and compare ─────────────────────────────────────────

const lines = prismResult.stdout.split("\n").filter((l) => l.trim() !== "");

let total = 0;
let divergences = 0;

for (const line of lines) {
  let record;
  try {
    record = JSON.parse(line);
  } catch {
    console.error(`warn: could not parse JSON line: ${line}`);
    continue;
  }

  total++;
  const { input, kind, muxed_id, base_g } = record;

  // Call bluewhale-core TypeScript implementation.
  let tsResult;
  try {
    tsResult = extractRouting({ address: input });
  } catch (e) {
    console.error(
      `DIVERGENCE input=${JSON.stringify(input)}\n` +
        `  prism-core: kind=${kind}\n` +
        `  core-ts:    threw ${e}\n`
    );
    divergences++;
    continue;
  }

  // Normalise the kind label from bluewhale-core to match prism's G/M/C.
  const tsKind = tsAddressKind(tsResult);

  let diff = [];

  if (tsKind !== kind) {
    diff.push(`kind: prism=${kind}, ts=${tsKind}`);
  }

  // Compare muxed_id (only meaningful for M-addresses).
  if (kind === "M") {
    const tsMuxedId = tsResult.routingId ?? null;
    const prismMuxedId = muxed_id !== null ? String(muxed_id) : null;
    if (String(tsMuxedId) !== String(prismMuxedId)) {
      diff.push(
        `muxed_id: prism=${prismMuxedId}, ts=${tsMuxedId}`
      );
    }

    // Compare base G-address.
    const tsBaseG = tsResult.address ?? null;
    if (tsBaseG !== base_g) {
      diff.push(`base_g: prism=${base_g}, ts=${tsBaseG}`);
    }
  }

  if (diff.length > 0) {
    divergences++;
    console.error(
      `DIVERGENCE input=${JSON.stringify(input)}\n  ${diff.join("\n  ")}`
    );
  } else if (args.verbose) {
    console.log(`AGREE ${kind} ${JSON.stringify(input)}`);
  }
}

// ── Summary ──────────────────────────────────────────────────────────────────

console.error(`\nprism-core vs core-ts: ${total} comparisons, ${divergences} divergences`);

process.exit(divergences > 0 ? 1 : 0);

// ── Helper ───────────────────────────────────────────────────────────────────

/**
 * Map a bluewhale-core RoutingResult to the prism-core kind letter (G, M, C).
 * bluewhale-core exposes `addressType` or the raw address prefix.
 */
function tsAddressKind(result) {
  // bluewhale-core returns the normalised G-address in result.address.
  // The original input's prefix determines the kind.
  if (result?.addressType) {
    switch (result.addressType) {
      case "muxed": return "M";
      case "contract": return "C";
      default: return "G";
    }
  }
  // Fallback: inspect the address field prefix.
  const addr = result?.address ?? "";
  if (addr.startsWith("M")) return "M";
  if (addr.startsWith("C")) return "C";
  return "G";
}
