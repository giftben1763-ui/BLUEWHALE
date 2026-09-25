/**
 * Severity thresholding (minSeverityLevel) parity suite.
 *
 * The same table is asserted in core-go (routing/severity_test.go) and
 * core-dart (test/severity_test.dart) so that all three SDKs filter warnings
 * identically: info = 0, warn = 1, error = 2.
 */
import { describe, it, expect } from "vitest";
import {
  extractRouting,
  filterBySeverity,
  severityWeight,
  SEVERITY_ORDER,
} from "../routing/extract";
import type { Warning, WarningSeverity } from "../address/types";

const G_ADDRESS = "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI";
const C_SOURCE = "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC";

const MIXED: Warning[] = [
  { code: "MEMO_IGNORED_FOR_MUXED", severity: "info", message: "info" },
  {
    code: "NON_CANONICAL_ROUTING_ID",
    severity: "warn",
    message: "warn",
    normalization: { original: "007", normalized: "7" },
  },
  {
    code: "INVALID_DESTINATION",
    severity: "error",
    message: "error",
    context: { destinationKind: "C" },
  },
];

const codes = (warnings: { code: string }[]) => warnings.map((w) => w.code);

describe("severity weights", () => {
  it("uses the normative ordering info=0, warn=1, error=2", () => {
    expect(SEVERITY_ORDER).toEqual({ info: 0, warn: 1, error: 2 });
    expect(severityWeight("info")).toBe(0);
    expect(severityWeight("warn")).toBe(1);
    expect(severityWeight("error")).toBe(2);
  });

  it("treats unknown or missing severities as info", () => {
    expect(severityWeight("fatal")).toBe(0);
    expect(severityWeight("")).toBe(0);
    expect(severityWeight(undefined)).toBe(0);
  });
});

describe("filterBySeverity", () => {
  const table: [WarningSeverity, string[]][] = [
    ["info", ["MEMO_IGNORED_FOR_MUXED", "NON_CANONICAL_ROUTING_ID", "INVALID_DESTINATION"]],
    ["warn", ["NON_CANONICAL_ROUTING_ID", "INVALID_DESTINATION"]],
    ["error", ["INVALID_DESTINATION"]],
  ];

  it.each(table)("minSeverity=%s keeps %j", (min, expected) => {
    expect(codes(filterBySeverity(MIXED, min))).toEqual(expected);
  });

  it("treats an unknown threshold as info", () => {
    expect(codes(filterBySeverity(MIXED, "bogus"))).toEqual(codes(MIXED));
  });
});

describe("extractRouting minSeverityLevel", () => {
  const cases: [string, Parameters<typeof extractRouting>[0], Record<WarningSeverity, string[]>][] = [
    [
      "G + MEMO_TEXT '007' (warn)",
      { destination: G_ADDRESS, memoType: "text", memoValue: "007", sourceAccount: null },
      { info: ["NON_CANONICAL_ROUTING_ID"], warn: ["NON_CANONICAL_ROUTING_ID"], error: [] },
    ],
    [
      "contract source (info)",
      { destination: G_ADDRESS, memoType: "id", memoValue: "1", sourceAccount: C_SOURCE },
      { info: ["CONTRACT_SENDER_DETECTED"], warn: [], error: [] },
    ],
  ];

  for (const [name, input, expected] of cases) {
    for (const min of ["info", "warn", "error"] as WarningSeverity[]) {
      it(`${name} @ ${min}`, () => {
        const result = extractRouting({ ...input, minSeverityLevel: min });
        expect(codes(result.warnings)).toEqual(expected[min]);
      });
    }
  }

  it("defaults to info when minSeverityLevel is omitted", () => {
    const result = extractRouting(cases[0][1]);
    expect(codes(result.warnings)).toEqual(["NON_CANONICAL_ROUTING_ID"]);
  });
});
