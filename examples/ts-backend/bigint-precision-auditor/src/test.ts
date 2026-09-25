/**
 * test.ts – Automated assertion test for the BigInt Precision Auditor
 * ─────────────────────────────────────────────────────────────────────────────
 * Verifies that:
 *   1. IDs above Number.MAX_SAFE_INTEGER are correctly detected as precision-
 *      sensitive by the auditor.
 *   2. @redishfish/bluewhale-core returns those IDs without truncation.
 *   3. IDs within the safe range are handled without false positives.
 *
 * Exit codes:
 *   0 – All assertions passed.
 *   1 – One or more assertions failed.
 *
 * Run with:
 *   npm test
 *   npx tsx src/test.ts
 */

import { AUDIT_CASES, auditAddress, type AuditResult } from "./main.js";

// ── Minimal assertion harness ─────────────────────────────────────────────────

let passed = 0;
let failed = 0;

function assert(condition: boolean, message: string): void {
  if (condition) {
    console.log(`  ✅ ${message}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${message}`);
    failed++;
  }
}

function describe(label: string, fn: () => void): void {
  console.log(`\n▶ ${label}`);
  fn();
}

// ── Test suite ────────────────────────────────────────────────────────────────

console.log("BigInt Precision Auditor – Automated Test Suite");
console.log("═".repeat(52));

// Run all audit cases
const results: AuditResult[] = AUDIT_CASES.map(auditAddress);

// ── Suite 1: bluewhale-core precision preservation ────────────────────────────
describe("bluewhale-core preserves precision for all IDs", () => {
  for (const r of results) {
    assert(
      r.corePreservesPrecision,
      `"${r.case.description}" → returned ${JSON.stringify(r.returnedId)}, expected ${JSON.stringify(r.case.expectedId)}`
    );
  }
});

// ── Suite 2: IDs above MAX_SAFE_INTEGER trigger Number truncation ─────────────
describe("JS Number truncates IDs above MAX_SAFE_INTEGER", () => {
  const unsafeCases = results.filter((r) => r.case.expectsPrecisionLoss);

  assert(
    unsafeCases.length > 0,
    "At least one test case exercises the unsafe integer range"
  );

  for (const r of unsafeCases) {
    assert(
      r.numberTruncated,
      `Number(${r.case.expectedId}) is truncated for "${r.case.description}"`
    );
  }
});

// ── Suite 3: IDs within safe range do NOT trigger Number truncation ───────────
describe("JS Number is safe for IDs within MAX_SAFE_INTEGER", () => {
  const safeCases = results.filter((r) => !r.case.expectsPrecisionLoss);

  assert(
    safeCases.length > 0,
    "At least one test case exercises the safe integer range"
  );

  for (const r of safeCases) {
    assert(
      !r.numberTruncated,
      `Number(${r.case.expectedId}) is NOT truncated for "${r.case.description}"`
    );
  }
});

// ── Suite 4: Returned IDs are never null for M-addresses ─────────────────────
describe("extractRouting returns a non-null routingId for all M-addresses", () => {
  for (const r of results) {
    if (r.case.address.startsWith("M")) {
      assert(
        r.returnedId !== null,
        `routingId is not null for "${r.case.description}"`
      );
    }
  }
});

// ── Suite 5: MAX_SAFE_INTEGER boundary ────────────────────────────────────────
describe("MAX_SAFE_INTEGER boundary is handled correctly", () => {
  const boundaryCase = results.find(
    (r) => r.case.expectedId === String(Number.MAX_SAFE_INTEGER)
  );

  assert(
    boundaryCase !== undefined,
    "MAX_SAFE_INTEGER boundary case exists in the test corpus"
  );

  if (boundaryCase) {
    assert(
      boundaryCase.corePreservesPrecision,
      `bluewhale-core returns exact MAX_SAFE_INTEGER value (${Number.MAX_SAFE_INTEGER})`
    );
    assert(
      !boundaryCase.numberTruncated,
      "Number does NOT truncate MAX_SAFE_INTEGER itself"
    );
  }

  const aboveBoundary = results.find(
    (r) => r.case.expectedId === String(Number.MAX_SAFE_INTEGER + 1)
  );

  assert(
    aboveBoundary !== undefined,
    "MAX_SAFE_INTEGER + 1 case exists in the test corpus"
  );

  if (aboveBoundary) {
    assert(
      aboveBoundary.numberTruncated,
      "Number DOES truncate MAX_SAFE_INTEGER + 1"
    );
    assert(
      aboveBoundary.corePreservesPrecision,
      "bluewhale-core still returns the exact value for MAX_SAFE_INTEGER + 1"
    );
  }
});

// ── Final summary ─────────────────────────────────────────────────────────────

console.log("\n" + "═".repeat(52));
console.log(`Results: ${passed} passed, ${failed} failed`);

if (failed > 0) {
  console.error(`\n${failed} test(s) failed.`);
  process.exit(1);
} else {
  console.log("\nAll tests passed.");
  process.exit(0);
}
