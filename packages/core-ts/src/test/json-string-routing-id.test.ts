/**
 * json-string-routing-id.test.ts
 *
 * Verifies that routingId is always serialized as a JSON quoted decimal string
 * and never as a raw integer literal.
 *
 * Rationale (issue #79):
 *   JavaScript represents all numbers as IEEE-754 doubles.  Any integer above
 *   Number.MAX_SAFE_INTEGER (2^53 - 1 = 9007199254740991) cannot be represented
 *   exactly, so JSON.stringify-ing a large routingId as a bare number would
 *   silently corrupt Stellar muxed-account IDs that exceed that boundary.
 *
 *   The fix is to serialize routingId as a string (e.g. "18446744073709551615")
 *   so the receiver is forced to parse it with BigInt and keeps the full uint64
 *   precision intact.
 */
import { describe, it, expect } from "vitest";
import { SafeRoutingId } from "../routing/safeRoutingId";
import { extractRouting } from "../routing/extract";

// Well-known G-address from spec/vectors.json (muxed_encode cases).
const G_ADDRESS = "GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI";

// M-address derived from G_ADDRESS with routing ID 42 (used in extract.test.ts).
import { encodeMuxed } from "../muxed/encode";
const M_ADDRESS_ID_42 = encodeMuxed(G_ADDRESS, 42n);

// Number.MAX_SAFE_INTEGER + 1 — not representable as a JS Number.
const ABOVE_SAFE = "9007199254740993";

// uint64 max — the largest legal Stellar routing ID.
const UINT64_MAX = "18446744073709551615";

// ─── SafeRoutingId.toJSON ─────────────────────────────────────────────────────

describe("SafeRoutingId.toJSON — JSON string serialization", () => {
  it("serializes a small ID as a quoted string, not a number", () => {
    const id = new SafeRoutingId("42");
    const json = JSON.stringify({ routingId: id });
    expect(json).toBe('{"routingId":"42"}');
  });

  it("serializes ID above MAX_SAFE_INTEGER as a quoted string without truncation", () => {
    const id = new SafeRoutingId(ABOVE_SAFE);
    const json = JSON.stringify({ routingId: id });
    expect(json).toBe(`{"routingId":"${ABOVE_SAFE}"}`);

    // Verify the raw JSON contains a string value, not a float/int
    const parsed = JSON.parse(json);
    expect(typeof parsed.routingId).toBe("string");
    expect(parsed.routingId).toBe(ABOVE_SAFE);
  });

  it("serializes uint64 max as a quoted string without truncation", () => {
    const id = new SafeRoutingId(UINT64_MAX);
    const json = JSON.stringify({ routingId: id });
    expect(json).toBe(`{"routingId":"${UINT64_MAX}"}`);

    const parsed = JSON.parse(json);
    expect(typeof parsed.routingId).toBe("string");
    expect(parsed.routingId).toBe(UINT64_MAX);
  });

  it("serializes zero as '0', not as integer 0", () => {
    const id = new SafeRoutingId("0");
    const json = JSON.stringify({ routingId: id });
    expect(json).toBe('{"routingId":"0"}');
  });

  it("toJSON() returns a string, never a number", () => {
    const testCases = ["0", "1", "9007199254740991", ABOVE_SAFE, UINT64_MAX];
    for (const tc of testCases) {
      const id = new SafeRoutingId(tc);
      expect(typeof id.toJSON()).toBe("string");
      expect(id.toJSON()).toBe(tc);
    }
  });

  it("round-trips through JSON.stringify / JSON.parse as the same decimal string", () => {
    const id = new SafeRoutingId(UINT64_MAX);
    const serialized = JSON.stringify(id);
    const deserialized: string = JSON.parse(serialized);
    expect(deserialized).toBe(UINT64_MAX);
    // Re-construct from the deserialized string — must be lossless
    const reconstructed = new SafeRoutingId(deserialized);
    expect(reconstructed.toString()).toBe(UINT64_MAX);
  });
});

// ─── SafeRoutingId.toString ───────────────────────────────────────────────────

describe("SafeRoutingId.toString — canonical decimal string", () => {
  it("toString returns the same decimal digits as the constructor input", () => {
    expect(new SafeRoutingId("123").toString()).toBe("123");
    expect(new SafeRoutingId(123n).toString()).toBe("123");
  });

  it("toString for uint64 max is exact", () => {
    expect(new SafeRoutingId(UINT64_MAX).toString()).toBe(UINT64_MAX);
  });

  it("toString for value above MAX_SAFE_INTEGER is exact", () => {
    expect(new SafeRoutingId(ABOVE_SAFE).toString()).toBe(ABOVE_SAFE);
  });
});

// ─── extractRouting routingId type check ────────────────────────────────────

describe("extractRouting — routingId is a string or BigInt (never raw number)", () => {
  it("routingId from M-address is truthy and not a Number type", () => {
    const result = extractRouting({
      destination: M_ADDRESS_ID_42,
      memoType: "none",
      memoValue: null,
      sourceAccount: null,
    });
    // routingId should be a bigint or string, never a JS number
    expect(result.routingId).not.toBeNull();
    expect(typeof result.routingId).not.toBe("number");
  });

  it("routingId from MEMO_ID is not a JS Number type", () => {
    const result = extractRouting({
      destination: G_ADDRESS,
      memoType: "id",
      memoValue: "9007199254740993",
      sourceAccount: null,
    });
    expect(result.routingId).not.toBeNull();
    expect(typeof result.routingId).not.toBe("number");
  });

  it("routingId can be serialized to JSON as a string via BigInt.toString()", () => {
    const result = extractRouting({
      destination: G_ADDRESS,
      memoType: "id",
      memoValue: UINT64_MAX,
      sourceAccount: null,
    });
    expect(result.routingId).not.toBeNull();

    // Convert routingId to a stable decimal string for JSON embedding.
    const asString =
      typeof result.routingId === "bigint"
        ? result.routingId.toString()
        : String(result.routingId);

    expect(asString).toBe(UINT64_MAX);

    // When manually building a JSON payload, the string form should not
    // be a number literal.
    const payload = JSON.stringify({ id: asString });
    const parsed = JSON.parse(payload);
    expect(typeof parsed.id).toBe("string");
    expect(parsed.id).toBe(UINT64_MAX);
  });

  it("null routingId serializes as null, not as 0", () => {
    const result = extractRouting({
      destination: G_ADDRESS,
      memoType: "none",
      memoValue: null,
      sourceAccount: null,
    });
    expect(result.routingId).toBeNull();
    const payload = JSON.stringify({ id: result.routingId });
    expect(payload).toBe('{"id":null}');
  });
});
