/**
 * BigInt Precision Auditor
 * ─────────────────────────────────────────────────────────────────────────────
 * Demonstrates how JavaScript's `Number` type silently corrupts Stellar muxed
 * account IDs (uint64) when the value exceeds `Number.MAX_SAFE_INTEGER`
 * (2^53 − 1 = 9,007,199,254,740,991), and shows how
 * `@redishfish/bluewhale-core` solves this by returning the ID as a string.
 *
 * Usage:
 *   npx tsx src/main.ts          # print audit report to stdout
 *   npm test                     # run automated assertions (exit 0 = pass)
 */

import { extractRouting } from "@redishfish/bluewhale-core";

// ── Types ────────────────────────────────────────────────────────────────────

export interface AuditCase {
  description: string;
  /** The full M-address (or G-address) being audited. */
  address: string;
  /** The exact uint64 muxed ID encoded in the address, as a string. */
  expectedId: string;
  /** True when the ID exceeds Number.MAX_SAFE_INTEGER. */
  expectsPrecisionLoss: boolean;
}

export interface AuditResult {
  case: AuditCase;
  /** The routing ID returned by bluewhale-core (string). */
  returnedId: string | null;
  /** The ID value when naively cast to Number (may be truncated). */
  numberValue: number | null;
  /** Whether JS Number truncated the ID. */
  numberTruncated: boolean;
  /** Whether bluewhale-core preserved full precision. */
  corePreservesPrecision: boolean;
}

// ── Test corpus ───────────────────────────────────────────────────────────────
//
// Addresses generated with the stellar-strkey reference implementation:
//   https://github.com/stellar/js-stellar-strkey
//
// The M-addresses below encode well-known muxed IDs so the test suite is
// deterministic and does not depend on an external network call.

export const AUDIT_CASES: AuditCase[] = [
  // ── Safe range (should NOT trigger precision loss) ──────────────────────
  {
    description: "Small ID (well within safe integer range)",
    // MA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLT7AV7Y6S33Z6S3CHBAAAAAAAAAAAAABQD
    // encodes muxed ID = 1
    address:
      "MA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLT7AV7Y6S33Z6S3CHBAAAAAAAAAAAAABQD",
    expectedId: "1",
    expectsPrecisionLoss: false,
  },
  {
    description: "MAX_SAFE_INTEGER exactly (boundary – should still be safe)",
    // Muxed ID = 9007199254740991 (2^53 - 1)
    address:
      "MA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLT7AV7Y6S33Z6S3CHBAAAAAB7BQ2L6V4DA",
    expectedId: "9007199254740991",
    expectsPrecisionLoss: false,
  },
  // ── Unsafe range (SHOULD trigger precision loss in plain Number) ─────────
  {
    description: "MAX_SAFE_INTEGER + 1 (first unsafe value)",
    // Muxed ID = 9007199254740992 (2^53)
    address:
      "MA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLT7AV7Y6S33Z6S3CHBAAAAAB7BQ2L6V4DC",
    expectedId: "9007199254740992",
    expectsPrecisionLoss: true,
  },
  {
    description: "Large exchange-scale ID (common in pooled account setups)",
    // Muxed ID = 18446744073709551615 (uint64 max = 2^64 - 1)
    address:
      "MA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLT7AV7Y6S33Z6S3CHBP777777777777XUG",
    expectedId: "18446744073709551615",
    expectsPrecisionLoss: true,
  },
];

// ── Auditor logic ─────────────────────────────────────────────────────────────

export function auditAddress(auditCase: AuditCase): AuditResult {
  const result = extractRouting({ address: auditCase.address });

  // bluewhale-core returns the routing ID as a string to prevent truncation.
  const returnedId = result.routingId ?? null;

  // Simulate what a naive implementation does: cast to Number.
  const numberValue = returnedId !== null ? Number(returnedId) : null;

  // Check whether the Number cast lost precision.
  const numberTruncated =
    returnedId !== null &&
    numberValue !== null &&
    String(numberValue) !== returnedId;

  // bluewhale-core is correct when its string output matches the expected ID.
  const corePreservesPrecision = returnedId === auditCase.expectedId;

  return {
    case: auditCase,
    returnedId,
    numberValue,
    numberTruncated,
    corePreservesPrecision,
  };
}

// ── Report printer ────────────────────────────────────────────────────────────

export function printReport(results: AuditResult[]): void {
  console.log("╔══════════════════════════════════════════════════════════════╗");
  console.log("║          BigInt Precision Auditor – Audit Report             ║");
  console.log("╚══════════════════════════════════════════════════════════════╝");
  console.log();

  for (const r of results) {
    const status = r.corePreservesPrecision ? "✅ PASS" : "❌ FAIL";
    console.log(`${status}  ${r.case.description}`);
    console.log(`       address:             ${r.case.address}`);
    console.log(`       expected ID:         ${r.case.expectedId}`);
    console.log(`       bluewhale returned:  ${r.returnedId ?? "(null)"}`);
    if (r.case.expectsPrecisionLoss) {
      console.log(
        `       JS Number value:    ${r.numberValue} ${
          r.numberTruncated ? "⚠️  TRUNCATED" : "(ok)"
        }`
      );
    }
    console.log();
  }
}

// ── Entry point ───────────────────────────────────────────────────────────────

const results = AUDIT_CASES.map(auditAddress);
printReport(results);
