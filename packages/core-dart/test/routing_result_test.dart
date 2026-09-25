// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:bluewhale_core/bluewhale_core.dart';
import 'package:test/test.dart';

void main() {
  group('RoutingResult.toJson / fromJson round-trip', () {
    // ------------------------------------------------------------------ //
    // toJson
    // ------------------------------------------------------------------ //

    test('toJson emits correct cross-language JSON keys', () {
      final result = RoutingResult(
        source: RoutingSource.muxed,
        id: BigInt.parse('9007199254740993'),
        destinationBaseAccount:
            'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI',
        warnings: [],
      );

      final json = result.toJson();

      expect(json['routingSource'], equals('muxed'));
      expect(json['routingId'], equals('9007199254740993'));
      expect(
        json['destinationBaseAccount'],
        equals('GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI'),
      );
      expect(json['warnings'], isEmpty);
      expect(json.containsKey('destinationError'), isFalse);
    });

    test('toJson serializes routingId as decimal string (not a number)', () {
      // Ensures values above Number.MAX_SAFE_INTEGER are preserved exactly.
      const aboveMaxSafe = '9007199254740993'; // MAX_SAFE_INTEGER + 2
      final result = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.parse(aboveMaxSafe),
        warnings: [],
      );

      final json = result.toJson();
      expect(json['routingId'], isA<String>());
      expect(json['routingId'], equals(aboveMaxSafe));
    });

    test('toJson emits null routingId when id is absent', () {
      final result = RoutingResult(
        source: RoutingSource.none,
        warnings: [],
      );

      final json = result.toJson();
      expect(json['routingId'], isNull);
    });

    test('toJson includes destinationError when present', () {
      final result = RoutingResult(
        source: RoutingSource.none,
        warnings: [],
        destinationError: DestinationError(
          code: 'INVALID_CHECKSUM',
          message: 'Checksum mismatch',
        ),
      );

      final json = result.toJson();
      expect(json['destinationError'], isNotNull);
      expect(json['destinationError']['code'], equals('INVALID_CHECKSUM'));
      expect(json['destinationError']['message'], equals('Checksum mismatch'));
    });

    test('toJson serializes warnings with code, severity, and message', () {
      final result = RoutingResult(
        source: RoutingSource.muxed,
        warnings: [
          const RoutingWarning(
            code: 'MEMO_PRESENT_WITH_MUXED',
            severity: 'warn',
            message: 'Routing ID found in both M-address and Memo.',
          ),
        ],
      );

      final json = result.toJson();
      final warnings = json['warnings'] as List<dynamic>;
      expect(warnings, hasLength(1));
      expect(warnings[0]['code'], equals('MEMO_PRESENT_WITH_MUXED'));
      expect(warnings[0]['severity'], equals('warn'));
      expect(
        warnings[0]['message'],
        equals('Routing ID found in both M-address and Memo.'),
      );
    });

    // ------------------------------------------------------------------ //
    // fromJson
    // ------------------------------------------------------------------ //

    test('fromJson reconstructs a RoutingResult from a JSON map', () {
      final json = <String, dynamic>{
        'destinationBaseAccount':
            'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI',
        'routingId': '9007199254740993',
        'routingSource': 'muxed',
        'warnings': <dynamic>[],
      };

      final result = RoutingResult.fromJson(json);

      expect(result.source, equals(RoutingSource.muxed));
      expect(result.id, equals(BigInt.parse('9007199254740993')));
      expect(
        result.destinationBaseAccount,
        equals('GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI'),
      );
      expect(result.warnings, isEmpty);
      expect(result.destinationError, isNull);
    });

    test('fromJson handles null routingId', () {
      final json = <String, dynamic>{
        'destinationBaseAccount': null,
        'routingId': null,
        'routingSource': 'none',
        'warnings': <dynamic>[],
      };

      final result = RoutingResult.fromJson(json);

      expect(result.id, isNull);
      expect(result.source, equals(RoutingSource.none));
    });

    test('fromJson parses destinationError correctly', () {
      final json = <String, dynamic>{
        'destinationBaseAccount': null,
        'routingId': null,
        'routingSource': 'none',
        'warnings': <dynamic>[],
        'destinationError': <String, dynamic>{
          'code': 'UNKNOWN_PREFIX',
          'message': 'Address prefix not recognized',
        },
      };

      final result = RoutingResult.fromJson(json);

      expect(result.destinationError, isNotNull);
      expect(result.destinationError!.code, equals('UNKNOWN_PREFIX'));
      expect(
        result.destinationError!.message,
        equals('Address prefix not recognized'),
      );
    });

    test('fromJson parses warnings list', () {
      final json = <String, dynamic>{
        'destinationBaseAccount':
            'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI',
        'routingId': null,
        'routingSource': 'none',
        'warnings': <dynamic>[
          <String, dynamic>{
            'code': 'MEMO_TEXT_UNROUTABLE',
            'severity': 'warn',
            'message': 'MEMO_TEXT was not a valid numeric uint64.',
          },
        ],
      };

      final result = RoutingResult.fromJson(json);

      expect(result.warnings, hasLength(1));
      expect(result.warnings[0].code, equals('MEMO_TEXT_UNROUTABLE'));
      expect(result.warnings[0].severity, equals('warn'));
    });

    test('fromJson falls back to RoutingSource.none for unknown source value',
        () {
      final json = <String, dynamic>{
        'destinationBaseAccount': null,
        'routingId': null,
        'routingSource': 'unknown_future_value',
        'warnings': <dynamic>[],
      };

      final result = RoutingResult.fromJson(json);
      expect(result.source, equals(RoutingSource.none));
    });

    // ------------------------------------------------------------------ //
    // Round-trip (toJson → jsonEncode → jsonDecode → fromJson)
    // ------------------------------------------------------------------ //

    test('full round-trip preserves exact uint64 routing ID above MAX_SAFE_INTEGER',
        () {
      const precisionHazardId = '9007199254740993';
      final original = RoutingResult(
        source: RoutingSource.muxed,
        id: BigInt.parse(precisionHazardId),
        destinationBaseAccount:
            'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI',
        warnings: [],
      );

      // Simulate serialization to a JSON string and back.
      final encoded = jsonEncode(original.toJson());
      final decoded =
          RoutingResult.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      expect(decoded.source, equals(original.source));
      expect(decoded.id, equals(original.id));
      expect(decoded.destinationBaseAccount, equals(original.destinationBaseAccount));
    });

    test('full round-trip with no routing ID', () {
      final original = RoutingResult(
        source: RoutingSource.none,
        warnings: [
          const RoutingWarning(
            code: 'INVALID_DESTINATION',
            severity: 'error',
            message: 'C address is not a valid destination',
          ),
        ],
        destinationError: DestinationError(
          code: 'INVALID_CHECKSUM',
          message: 'Checksum mismatch',
        ),
      );

      final encoded = jsonEncode(original.toJson());
      final decoded =
          RoutingResult.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      expect(decoded.source, equals(RoutingSource.none));
      expect(decoded.id, isNull);
      expect(decoded.warnings, hasLength(1));
      expect(decoded.warnings[0].code, equals('INVALID_DESTINATION'));
      expect(decoded.destinationError!.code, equals('INVALID_CHECKSUM'));
    });

    test('full round-trip for memo routing', () {
      final original = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(100),
        destinationBaseAccount:
            'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI',
        warnings: [],
      );

      final encoded = jsonEncode(original.toJson());
      final decoded =
          RoutingResult.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      expect(decoded.source, equals(RoutingSource.memo));
      expect(decoded.id, equals(BigInt.from(100)));
      expect(decoded.destinationBaseAccount, equals(original.destinationBaseAccount));
    });

    // ------------------------------------------------------------------ //
    // Cross-language JSON key names (Issue #78)
    // ------------------------------------------------------------------ //

    test('JSON keys match Go and TypeScript wire format exactly', () {
      // These are the canonical field names specified in Issue #78:
      // destinationBaseAccount, routingId, routingSource, warnings, destinationError
      final result = RoutingResult(
        source: RoutingSource.muxed,
        id: BigInt.from(42),
        destinationBaseAccount:
            'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI',
        warnings: [
          const RoutingWarning(
            code: 'MEMO_PRESENT_WITH_MUXED',
            severity: 'warn',
            message: 'Routing ID found in both M-address and Memo.',
          ),
        ],
        destinationError: null,
      );

      final json = result.toJson();

      // Verify all 5 canonical keys are present
      expect(json.containsKey('destinationBaseAccount'), isTrue);
      expect(json.containsKey('routingId'), isTrue);
      expect(json.containsKey('routingSource'), isTrue);
      expect(json.containsKey('warnings'), isTrue);
      // destinationError is only included when not null
      expect(json.containsKey('destinationError'), isFalse);

      // Verify values
      expect(json['routingSource'], equals('muxed'));
      expect(json['routingId'], equals('42'));
    });
  });
}
