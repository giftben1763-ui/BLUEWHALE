/// json_string_routing_id_test.dart
///
/// Verifies that routingId is always serialized as a JSON quoted decimal string
/// and never as a raw integer literal.
///
/// Rationale (issue #79):
///   Flutter Web compiles Dart to JavaScript where every `int` is an
///   IEEE-754 double. Integers above Number.MAX_SAFE_INTEGER (2^53 - 1 =
///   9007199254740991) are silently truncated.  Stellar muxed-account IDs may
///   reach uint64 max (2^64 - 1), so if routingId were serialized as a bare
///   JSON number it would be corrupted on Flutter Web.
///
///   [SafeRoutingId.toJson()] and [RoutingResult.idString] both return the
///   exact decimal string, which forces the receiver to use BigInt parsing.
// ignore_for_file: prefer_const_constructors
import 'dart:convert';
import 'package:test/test.dart';
import 'package:bluewhale_core/bluewhale_core.dart';

void main() {
  // ─── SafeRoutingId.toJson ──────────────────────────────────────────────────

  group('SafeRoutingId.toJson — always returns a decimal string', () {
    test('toJson() returns the exact decimal string for a small value', () {
      final id = SafeRoutingId.parse('42');
      expect(id.toJson(), equals('42'));
    });

    test('toJson() is exact for uint64 max', () {
      const maxUint64 = '18446744073709551615';
      final id = SafeRoutingId.parse(maxUint64);
      expect(id.toJson(), equals(maxUint64));
    });

    test('toJson() is exact for value above JS MAX_SAFE_INTEGER', () {
      // 2^53 + 1 — would be truncated by a JS Number to 9007199254740992
      const aboveSafe = '9007199254740993';
      final id = SafeRoutingId.parse(aboveSafe);
      expect(id.toJson(), equals(aboveSafe));
    });

    test('toJson() returns "0" for zero', () {
      final id = SafeRoutingId.parse('0');
      expect(id.toJson(), equals('0'));
    });

    test('when embedded in jsonEncode the field is a JSON string, not a number', () {
      const maxUint64 = '18446744073709551615';
      final id = SafeRoutingId.parse(maxUint64);

      // Simulate building a JSON payload like a real SDK consumer would.
      final payload = jsonEncode({'routingId': id.toJson()});
      final decoded = jsonDecode(payload) as Map<String, dynamic>;

      expect(decoded['routingId'], isA<String>());
      expect(decoded['routingId'], equals(maxUint64));
    });

    test('round-trips through jsonEncode / jsonDecode without precision loss', () {
      const aboveSafe = '9007199254740993';
      final id = SafeRoutingId.parse(aboveSafe);

      final serialized = jsonEncode(id.toJson());
      final deserialized = jsonDecode(serialized) as String;

      expect(deserialized, equals(aboveSafe));

      // Re-construct from the decoded string — must remain lossless.
      final reconstructed = SafeRoutingId.parse(deserialized);
      expect(reconstructed.value, equals(aboveSafe));
    });
  });

  // ─── RoutingResult.idString ────────────────────────────────────────────────

  group('RoutingResult.idString — JSON-safe decimal string accessor', () {
    test('idString is null when no routing ID was resolved', () {
      final result = RoutingResult(source: RoutingSource.none, warnings: []);
      expect(result.idString, isNull);

      final payload = jsonEncode({'routingId': result.idString});
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      expect(decoded['routingId'], isNull);
    });

    test('idString for a small id is a string, not a number', () {
      final result = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(42),
        warnings: [],
      );
      expect(result.idString, isA<String>());
      expect(result.idString, equals('42'));
    });

    test('idString for uint64 max is exact and is a string', () {
      const maxUint64 = '18446744073709551615';
      final result = RoutingResult(
        source: RoutingSource.muxed,
        id: BigInt.parse(maxUint64),
        destinationBaseAccount: 'GA',
        warnings: [],
      );
      expect(result.idString, isA<String>());
      expect(result.idString, equals(maxUint64));
    });

    test('idString for value above JS MAX_SAFE_INTEGER is exact', () {
      // 2^53 + 1 = 9007199254740993
      const aboveSafe = '9007199254740993';
      final result = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.parse(aboveSafe),
        warnings: [],
      );
      expect(result.idString, equals(aboveSafe));
    });

    test('embedding idString in a JSON payload produces a string field', () {
      const aboveSafe = '9007199254740993';
      final result = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.parse(aboveSafe),
        warnings: [],
      );

      final payload = jsonEncode({'routingId': result.idString});
      final decoded = jsonDecode(payload) as Map<String, dynamic>;

      // Must decode as String, never as num/int/double.
      expect(decoded['routingId'], isA<String>());
      expect(decoded['routingId'], equals(aboveSafe));
    });
  });

  // ─── RoutingResult.safeId ─────────────────────────────────────────────────

  group('RoutingResult.safeId — SafeRoutingId accessor serializes as string', () {
    test('safeId is null when no routing ID was resolved', () {
      final result = RoutingResult(source: RoutingSource.none, warnings: []);
      expect(result.safeId, isNull);
    });

    test('safeId.toJson() is a string for uint64 max', () {
      const maxUint64 = '18446744073709551615';
      final result = RoutingResult(
        source: RoutingSource.muxed,
        id: BigInt.parse(maxUint64),
        warnings: [],
      );
      expect(result.safeId, isNotNull);
      expect(result.safeId!.toJson(), isA<String>());
      expect(result.safeId!.toJson(), equals(maxUint64));
    });

    test('safeId.toJson() is a string for value above JS MAX_SAFE_INTEGER', () {
      const aboveSafe = '9007199254740993';
      final result = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.parse(aboveSafe),
        warnings: [],
      );
      expect(result.safeId!.toJson(), equals(aboveSafe));
    });
  });

  // ─── BigInt precision boundary ────────────────────────────────────────────

  group('BigInt precision — demonstrate why strings are required', () {
    test('BigInt.parse preserves value above JS MAX_SAFE_INTEGER exactly', () {
      // This test documents the BigInt.parse contract: it is exact on all
      // Dart targets including Flutter Web.
      const aboveSafe = '9007199254740993';
      final big = BigInt.parse(aboveSafe);
      expect(big.toString(), equals(aboveSafe));
    });

    test('uint64 max is exactly representable as BigInt', () {
      const maxUint64 = '18446744073709551615';
      final big = BigInt.parse(maxUint64);
      expect(big.toString(), equals(maxUint64));
    });
  });
}
