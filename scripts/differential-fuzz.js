#!/usr/bin/env node
/**
 * Differential address fuzzer: TS vs Go vs Dart.
 *
 * Generates randomized, mutated Stellar addresses (G / M / C seeds plus
 * checksum, length, version, alphabet, casing and whitespace mutations),
 * pipes every input through the `detect` + `parse` adapters of each SDK and
 * logs any input where one language disagrees with another.
 *
 * Adapters live in examples/rust-address-fuzzer/differential/ and speak a
 * shared line protocol: stdin = one JSON string per line, stdout = one JSON
 * outcome per line:
 *
 *   { "detect": "G"|"M"|"C"|null,
 *     "parse": { "ok", "kind", "address", "baseG", "muxedId", "error" } }
 *
 * Usage:
 *   node scripts/differential-fuzz.js [options]
 *
 * Options:
 *   --count N          number of generated inputs (default 10000)
 *   --seed N           PRNG seed for reproducible runs (default: random)
 *   --langs a,b,c      subset of ts,go,dart (default: all available)
 *   --corpus FILE      newline-delimited inputs to use instead of generating
 *                      (e.g. inputs captured from rust-address-fuzzer)
 *   --out FILE         JSONL mismatch log (default:
 *                      examples/rust-address-fuzzer/findings/differential-mismatches.jsonl)
 *   --compare-errors   also require identical parse error codes
 *   --require-all      fail instead of skipping when a toolchain is missing
 *   --dart PATH        dart executable (default: $DART or "dart")
 *   --go PATH          go executable (default: $GO or "go")
 *
 * Exit code: 0 when all languages agree, 1 on any mismatch, 2 on harness error.
 */
"use strict";

const { spawnSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const DIFF_DIR = path.join(ROOT, "examples", "rust-address-fuzzer", "differential");
const DEFAULT_OUT = path.join(
  ROOT,
  "examples",
  "rust-address-fuzzer",
  "findings",
  "differential-mismatches.jsonl"
);
const ALL_LANGS = ["ts", "go", "dart"];

// ── CLI ──────────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const opts = {
    count: 10000,
    seed: null,
    langs: null,
    corpus: null,
    out: DEFAULT_OUT,
    compareErrors: false,
    requireAll: false,
    dart: process.env.DART || "dart",
    go: process.env.GO || "go",
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const next = () => {
      if (i + 1 >= argv.length) fail(`missing value for ${arg}`);
      return argv[++i];
    };
    switch (arg) {
      case "--count": opts.count = Number.parseInt(next(), 10); break;
      case "--seed": opts.seed = Number.parseInt(next(), 10) >>> 0; break;
      case "--langs": opts.langs = next().split(",").map((s) => s.trim()).filter(Boolean); break;
      case "--corpus": opts.corpus = path.resolve(next()); break;
      case "--out": opts.out = path.resolve(next()); break;
      case "--compare-errors": opts.compareErrors = true; break;
      case "--require-all": opts.requireAll = true; break;
      case "--dart": opts.dart = next(); break;
      case "--go": opts.go = next(); break;
      case "-h":
      case "--help":
        console.log(fs.readFileSync(__filename, "utf8").split("*/")[0]);
        process.exit(0);
        break;
      default:
        fail(`unknown option ${arg}`);
    }
  }
  if (!Number.isInteger(opts.count) || opts.count <= 0) fail("--count must be a positive integer");
  if (opts.seed === null) opts.seed = (Math.random() * 0x100000000) >>> 0;
  for (const lang of opts.langs ?? []) {
    if (!ALL_LANGS.includes(lang)) fail(`unknown language "${lang}"`);
  }
  return opts;
}

class HarnessError extends Error {}

function fail(message) {
  throw new HarnessError(message);
}

// ── Deterministic PRNG (mulberry32) ──────────────────────────────────────────

function mulberry32(seed) {
  let a = seed >>> 0;
  return function next() {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ── StrKey encoding (mirrors examples/rust-address-fuzzer/src/generate.rs) ───

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
const VERSION = { G: 6 << 3, M: 12 << 3, C: 2 << 3, S: 18 << 3, T: 19 << 3, X: 23 << 3 };

function crc16(bytes) {
  let crc = 0;
  for (const byte of bytes) {
    crc ^= byte << 8;
    for (let i = 0; i < 8; i++) {
      crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
    }
  }
  return crc;
}

function base32Encode(bytes) {
  let out = "";
  let bits = 0;
  let value = 0;
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out += ALPHABET[(value >>> bits) & 31];
    }
    value &= (1 << bits) - 1;
  }
  if (bits > 0) out += ALPHABET[(value << (5 - bits)) & 31];
  return out;
}

function encodeStrKey(versionByte, payload) {
  const data = [versionByte, ...payload];
  const crc = crc16(data);
  return base32Encode([...data, crc & 0xff, crc >>> 8]);
}

// ── Input generation ─────────────────────────────────────────────────────────

function makeGenerator(rand) {
  const int = (n) => Math.floor(rand() * n);
  const pick = (arr) => arr[int(arr.length)];
  const bytes = (n) => Array.from({ length: n }, () => int(256));
  const JUNK = ["0", "1", "8", "9", "!", "-", "=", " ", "\t", "\u0000", "é", "ß", "*", "/"];

  function seed(kind = pick(["G", "G", "M", "M", "C"])) {
    const payloadLen = kind === "M" ? 40 : 32;
    return encodeStrKey(VERSION[kind], bytes(payloadLen));
  }

  const mutators = {
    identity: (s) => s,
    replaceChar: (s) => {
      const i = int(s.length);
      return s.slice(0, i) + pick(ALPHABET) + s.slice(i + 1);
    },
    junkChar: (s) => {
      const i = int(s.length);
      return s.slice(0, i) + pick(JUNK) + s.slice(i + 1);
    },
    insertChar: (s) => {
      const i = int(s.length + 1);
      return s.slice(0, i) + pick(ALPHABET) + s.slice(i);
    },
    deleteChar: (s) => {
      const i = int(s.length);
      return s.slice(0, i) + s.slice(i + 1);
    },
    swapAdjacent: (s) => {
      const i = int(s.length - 1);
      return s.slice(0, i) + s[i + 1] + s[i] + s.slice(i + 2);
    },
    truncate: (s) => s.slice(0, int(s.length)),
    extend: (s) => s + Array.from({ length: 1 + int(8) }, () => pick(ALPHABET)).join(""),
    lowercaseAll: (s) => s.toLowerCase(),
    lowercaseOne: (s) => {
      const i = int(s.length);
      return s.slice(0, i) + s[i].toLowerCase() + s.slice(i + 1);
    },
    changePrefix: (s) => pick(["G", "M", "C", "S", "T", "X", "A", "g", "m", "c"]) + s.slice(1),
    whitespace: (s) => pick([" ", "\t", "\n", ""]) + s + pick([" ", "\t", "\r", ""]),
    // Correct checksum over a payload of the wrong length for the version byte.
    wrongLength: () => {
      const kind = pick(["G", "M", "C"]);
      const base = kind === "M" ? 40 : 32;
      return encodeStrKey(VERSION[kind], bytes(base + pick([-2, -1, 1, 2, 8])));
    },
    // Correct checksum under a version byte that is not a routable kind.
    foreignVersion: () => encodeStrKey(pick([VERSION.S, VERSION.T, VERSION.X, int(256)]), bytes(32)),
    // M-length payload encoded under a G or C version byte.
    crossKind: () => encodeStrKey(pick([VERSION.G, VERSION.C]), bytes(40)),
    // Flip the final character so the unused trailing Base32 bits are non-zero.
    unusedBits: () => {
      const s = seed(pick(["G", "M", "C"]));
      const last = ALPHABET.indexOf(s[s.length - 1]);
      return s.slice(0, -1) + ALPHABET[(last ^ (1 + int(3))) & 31];
    },
    empty: () => "",
    garbage: () => Array.from({ length: int(80) }, () => pick(ALPHABET + JUNK.join(""))).join(""),
  };
  const names = Object.keys(mutators);

  return function generate() {
    const name = pick(names);
    let input = mutators[name](seed());
    // Occasionally stack a second mutation to reach deeper states.
    let mutator = name;
    if (rand() < 0.2 && input.length > 1) {
      const second = pick(["replaceChar", "lowercaseOne", "deleteChar", "insertChar", "whitespace"]);
      input = mutators[second](input);
      mutator = `${name}+${second}`;
    }
    return { input, mutator };
  };
}

// ── Adapters ─────────────────────────────────────────────────────────────────

function commandExists(cmd, args = ["--version"]) {
  const res = spawnSync(cmd, args, { stdio: "ignore" });
  return !res.error && res.status === 0;
}

function resolveEsbuild() {
  const coreTs = path.join(ROOT, "packages", "core-ts");
  const tsupDir = path.dirname(require.resolve("tsup/package.json", { paths: [coreTs] }));
  return require(require.resolve("esbuild", { paths: [tsupDir] }));
}

function prepareAdapters(opts, buildDir) {
  const adapters = {};
  const wanted = opts.langs ?? ALL_LANGS;
  const missing = [];

  if (wanted.includes("ts")) {
    try {
      const esbuild = resolveEsbuild();
      const outfile = path.join(buildDir, "ts_adapter.cjs");
      esbuild.buildSync({
        entryPoints: [path.join(DIFF_DIR, "ts_adapter.ts")],
        bundle: true,
        platform: "node",
        format: "cjs",
        outfile,
        logLevel: "error",
      });
      adapters.ts = { cmd: process.execPath, args: [outfile], cwd: ROOT };
    } catch (error) {
      missing.push(`ts (${error.message.split("\n")[0]}; run \`pnpm install\` first)`);
    }
  }

  if (wanted.includes("go")) {
    if (commandExists(opts.go, ["version"])) {
      const binary = path.join(buildDir, os.platform() === "win32" ? "go_adapter.exe" : "go_adapter");
      const res = spawnSync(opts.go, ["build", "-o", binary, "."], {
        cwd: path.join(DIFF_DIR, "go_adapter"),
        encoding: "utf8",
      });
      if (res.status === 0) {
        adapters.go = { cmd: binary, args: [], cwd: ROOT };
      } else {
        missing.push(`go (build failed: ${(res.stderr || "").trim()})`);
      }
    } else {
      missing.push(`go (executable "${opts.go}" not found)`);
    }
  }

  if (wanted.includes("dart")) {
    const coreDart = path.join(ROOT, "packages", "core-dart");
    const packageConfig = path.join(coreDart, ".dart_tool", "package_config.json");
    if (!commandExists(opts.dart)) {
      missing.push(`dart (executable "${opts.dart}" not found)`);
    } else {
      const pubGet = spawnSync(opts.dart, ["pub", "get"], { cwd: coreDart, encoding: "utf8" });
      if (pubGet.status !== 0 || !fs.existsSync(packageConfig)) {
        missing.push(`dart (\`dart pub get\` failed in packages/core-dart)`);
      } else {
        adapters.dart = {
          cmd: opts.dart,
          args: [`--packages=${packageConfig}`, path.join(DIFF_DIR, "dart_adapter.dart")],
          cwd: ROOT,
        };
      }
    }
  }

  for (const reason of missing) {
    const msg = `skipping ${reason}`;
    if (opts.requireAll || opts.langs) fail(msg);
    console.warn(`differential-fuzz: ${msg}`);
  }
  if (Object.keys(adapters).length < 2) {
    fail(`need at least two languages to compare, got: ${Object.keys(adapters).join(", ") || "none"}`);
  }
  return adapters;
}

function runAdapter(lang, adapter, inputs) {
  const payload = inputs.map((s) => JSON.stringify(s)).join("\n") + "\n";
  const res = spawnSync(adapter.cmd, adapter.args, {
    cwd: adapter.cwd,
    input: payload,
    encoding: "utf8",
    maxBuffer: 512 * 1024 * 1024,
  });
  if (res.error || res.status !== 0) {
    fail(`${lang} adapter failed (status ${res.status}): ${res.error?.message ?? res.stderr}`);
  }
  const lines = res.stdout.split("\n").filter((l) => l.length > 0);
  if (lines.length !== inputs.length) {
    fail(`${lang} adapter returned ${lines.length} results for ${inputs.length} inputs`);
  }
  return lines.map((l) => JSON.parse(l));
}

// ── Comparison ───────────────────────────────────────────────────────────────

function normalize(outcome, compareErrors) {
  const p = outcome.parse;
  return {
    detect: outcome.detect ?? null,
    parse: p.ok
      ? { ok: true, kind: p.kind, address: p.address, baseG: p.baseG ?? null, muxedId: p.muxedId ?? null }
      : compareErrors
        ? { ok: false, error: p.error ?? null }
        : { ok: false },
  };
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const buildDir = fs.mkdtempSync(path.join(os.tmpdir(), "bluewhale-differential-"));

  try {
    const adapters = prepareAdapters(opts, buildDir);
    const langs = Object.keys(adapters);

    let cases;
    if (opts.corpus) {
      cases = fs
        .readFileSync(opts.corpus, "utf8")
        .split(/\r?\n/)
        .filter((l) => l.length > 0)
        .map((input) => ({ input, mutator: "corpus" }));
    } else {
      const generate = makeGenerator(mulberry32(opts.seed));
      cases = Array.from({ length: opts.count }, generate);
    }
    const inputs = cases.map((c) => c.input);

    console.log(
      `differential-fuzz: ${inputs.length} inputs, seed=${opts.seed}, langs=${langs.join(",")}` +
        (opts.compareErrors ? ", comparing error codes" : "")
    );

    const results = {};
    for (const lang of langs) {
      const start = Date.now();
      results[lang] = runAdapter(lang, adapters[lang], inputs);
      console.log(`  ${lang.padEnd(4)} ${inputs.length} results in ${Date.now() - start} ms`);
    }

    const mismatches = [];
    const byMutator = {};
    for (let i = 0; i < inputs.length; i++) {
      const normalized = langs.map((lang) => JSON.stringify(normalize(results[lang][i], opts.compareErrors)));
      if (normalized.every((n) => n === normalized[0])) continue;

      const entry = {
        index: i,
        seed: opts.seed,
        mutator: cases[i].mutator,
        input: inputs[i],
        results: Object.fromEntries(langs.map((lang) => [lang, results[lang][i]])),
      };
      mismatches.push(entry);
      byMutator[entry.mutator] = (byMutator[entry.mutator] ?? 0) + 1;
    }

    fs.mkdirSync(path.dirname(opts.out), { recursive: true });
    fs.writeFileSync(opts.out, mismatches.map((m) => JSON.stringify(m)).join("\n") + (mismatches.length ? "\n" : ""));

    if (mismatches.length === 0) {
      console.log(`differential-fuzz: OK, all ${langs.length} languages agree on ${inputs.length} inputs`);
      return 0;
    }

    console.log(`differential-fuzz: ${mismatches.length} mismatching inputs (log: ${path.relative(ROOT, opts.out)})`);
    for (const [mutator, count] of Object.entries(byMutator).sort((a, b) => b[1] - a[1])) {
      console.log(`  ${String(count).padStart(6)}  ${mutator}`);
    }
    for (const m of mismatches.slice(0, 5)) {
      console.log(`\n  input ${JSON.stringify(m.input)} (${m.mutator})`);
      for (const lang of langs) {
        console.log(`    ${lang.padEnd(4)} ${JSON.stringify(normalize(m.results[lang], opts.compareErrors))}`);
      }
    }
    return 1;
  } finally {
    fs.rmSync(buildDir, { recursive: true, force: true });
  }
}

try {
  process.exitCode = main();
} catch (error) {
  if (!(error instanceof HarnessError)) throw error;
  console.error(`differential-fuzz: ${error.message}`);
  process.exitCode = 2;
}
