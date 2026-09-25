// core-ts side of the differential address harness
// (scripts/differential-fuzz.js).
//
// Bundled on the fly by the harness with esbuild, so it imports the address
// modules straight from packages/core-ts/src. Reads newline-delimited JSON
// strings from stdin and writes one JSON outcome per line to stdout in the
// shared adapter format.
import { createInterface } from "node:readline";
import { detect } from "../../../packages/core-ts/src/address/detect";
import { parse } from "../../../packages/core-ts/src/address/parse";
import { AddressParseError } from "../../../packages/core-ts/src/address/errors";

type ParseOutcome = {
  ok: boolean;
  kind: string | null;
  address: string | null;
  baseG: string | null;
  muxedId: string | null;
  error: string | null;
};

function run(input: string) {
  let detected: string | null = null;
  try {
    const kind = detect(input);
    detected = kind === "invalid" ? null : kind;
  } catch {
    detected = null;
  }

  const outcome: ParseOutcome = {
    ok: false,
    kind: null,
    address: null,
    baseG: null,
    muxedId: null,
    error: null,
  };

  try {
    const parsed = parse(input);
    if (parsed.kind === "invalid") {
      outcome.error = parsed.error.code;
    } else {
      outcome.ok = true;
      outcome.kind = parsed.kind;
      outcome.address = parsed.address;
      if (parsed.kind === "M") {
        outcome.baseG = parsed.baseG;
        outcome.muxedId = parsed.muxedId.toString();
      }
    }
  } catch (error) {
    outcome.error =
      error instanceof AddressParseError ? error.code : "EXCEPTION";
  }

  return { detect: detected, parse: outcome };
}

const lines: string[] = [];
const rl = createInterface({ input: process.stdin, crlfDelay: Infinity });
rl.on("line", (line) => {
  if (line.length === 0) return;
  lines.push(JSON.stringify(run(JSON.parse(line) as string)));
});
rl.on("close", () => {
  process.stdout.write(lines.length ? lines.join("\n") + "\n" : "");
});
