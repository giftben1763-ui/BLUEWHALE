// ignore_for_file: prefer_const_constructors
import 'package:test/test.dart';
import 'package:bluewhale_core/bluewhale_core.dart';

void main() {
  // ─── RoutingWarning equality ──────────────────────────────────────────────

  group('RoutingWarning operator== and hashCode', () {
    test('identical instances are equal', () {
      const w = RoutingWarning(
        code: 'memo-ignored',
        severity: 'info',
        message: 'Memo ignored for muxed address',
      );
      expect(w == w, isTrue);
    });

    test('two warnings with same fields are equal', () {
      const a = RoutingWarning(
        code: 'memo-ignored',
        severity: 'info',
        message: 'Memo ignored for muxed address',
      );
      const b = RoutingWarning(
        code: 'memo-ignored',
        severity: 'info',
        message: 'Memo ignored for muxed address',
      );
      expect(a, equals(b));
    });

    test('two warnings with same fields have the same hashCode', () {
      const a = RoutingWarning(
        code: 'memo-ignored',
        severity: 'info',
        message: 'Memo ignored for muxed address',
      );
      const b = RoutingWarning(
        code: 'memo-ignored',
        severity: 'info',
        message: 'Memo ignored for muxed address',
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    test('warnings with different codes are not equal', () {
      const a = RoutingWarning(code: 'memo-ignored', severity: 'info', message: 'x');
      const b = RoutingWarning(code: 'contract-sender', severity: 'info', message: 'x');
      expect(a, isNot(equals(b)));
    });

    test('warnings with different severities are not equal', () {
      const a = RoutingWarning(code: 'memo-ignored', severity: 'info', message: 'x');
      const b = RoutingWarning(code: 'memo-ignored', severity: 'warn', message: 'x');
      expect(a, isNot(equals(b)));
    });

    test('warnings with different messages are not equal', () {
      const a = RoutingWarning(code: 'memo-ignored', severity: 'info', message: 'A');
      const b = RoutingWarning(code: 'memo-ignored', severity: 'info', message: 'B');
      expect(a, isNot(equals(b)));
    });

    test('predefined static constant memoIgnored equals itself', () {
      expect(RoutingWarning.memoIgnored, equals(RoutingWarning.memoIgnored));
    });

    test('predefined static constants have stable hashCode', () {
      expect(
        RoutingWarning.memoIgnored.hashCode,
        equals(RoutingWarning.memoIgnored.hashCode),
      );
    });

    test('warning is not equal to a different type', () {
      const w = RoutingWarning(code: 'x', severity: 'info', message: 'y');
      // ignore: unrelated_type_equality_checks
      expect(w == 'not-a-warning', isFalse);
    });
  });

  // ─── RoutingResult equality ──────────────────────────────────────────────

  group('RoutingResult operator== and hashCode', () {
    test('identical instances are equal', () {
      final r = RoutingResult(
        source: RoutingSource.none,
        warnings: [],
      );
      expect(r == r, isTrue);
    });

    test('two minimal none-source results with no id or warnings are equal', () {
      final a = RoutingResult(source: RoutingSource.none, warnings: []);
      final b = RoutingResult(source: RoutingSource.none, warnings: []);
      expect(a, equals(b));
    });

    test('equal results have the same hashCode', () {
      final a = RoutingResult(source: RoutingSource.none, warnings: []);
      final b = RoutingResult(source: RoutingSource.none, warnings: []);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('results with same muxed source, id, base account and no warnings are equal', () {
      const base = 'GA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLT7AV7Y6S33Z6S3CHBAAAAAAAAAAAAABQD2';
      final a = RoutingResult(
        source: RoutingSource.muxed,
        id: BigInt.from(12345),
        destinationBaseAccount: base,
        warnings: [],
      );
      final b = RoutingResult(
        source: RoutingSource.muxed,
        id: BigInt.from(12345),
        destinationBaseAccount: base,
        warnings: [],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('results with same memo source, id, and warnings are equal', () {
      const warning = RoutingWarning(
        code: 'memo-ignored',
        severity: 'info',
        message: 'Memo ignored for muxed address',
      );
      final a = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(99),
        warnings: [warning],
      );
      final b = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(99),
        warnings: [warning],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('results differ when sources differ', () {
      final a = RoutingResult(source: RoutingSource.muxed, warnings: []);
      final b = RoutingResult(source: RoutingSource.memo, warnings: []);
      expect(a, isNot(equals(b)));
    });

    test('results differ when ids differ', () {
      final a = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(1),
        warnings: [],
      );
      final b = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(2),
        warnings: [],
      );
      expect(a, isNot(equals(b)));
    });

    test('results differ when one has id and the other does not', () {
      final a = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(1),
        warnings: [],
      );
      final b = RoutingResult(source: RoutingSource.memo, warnings: []);
      expect(a, isNot(equals(b)));
    });

    test('results differ when destinationBaseAccount differs', () {
      final a = RoutingResult(
        source: RoutingSource.muxed,
        destinationBaseAccount: 'GABC',
        warnings: [],
      );
      final b = RoutingResult(
        source: RoutingSource.muxed,
        destinationBaseAccount: 'GDEF',
        warnings: [],
      );
      expect(a, isNot(equals(b)));
    });

    test('results differ when one has destinationBaseAccount and the other does not', () {
      final a = RoutingResult(
        source: RoutingSource.muxed,
        destinationBaseAccount: 'GABC',
        warnings: [],
      );
      final b = RoutingResult(source: RoutingSource.muxed, warnings: []);
      expect(a, isNot(equals(b)));
    });

    test('results differ when warnings list length differs', () {
      const w = RoutingWarning(code: 'x', severity: 'info', message: 'y');
      final a = RoutingResult(source: RoutingSource.none, warnings: [w]);
      final b = RoutingResult(source: RoutingSource.none, warnings: []);
      expect(a, isNot(equals(b)));
    });

    test('results differ when warnings content differs', () {
      final a = RoutingResult(
        source: RoutingSource.none,
        warnings: [
          const RoutingWarning(code: 'a', severity: 'info', message: 'm'),
        ],
      );
      final b = RoutingResult(
        source: RoutingSource.none,
        warnings: [
          const RoutingWarning(code: 'b', severity: 'info', message: 'm'),
        ],
      );
      expect(a, isNot(equals(b)));
    });

    test('results with multiple identical warnings are equal', () {
      const w1 = RoutingWarning(code: 'a', severity: 'info', message: 'x');
      const w2 = RoutingWarning(code: 'b', severity: 'warn', message: 'y');
      final a = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(7),
        warnings: [w1, w2],
      );
      final b = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(7),
        warnings: [w1, w2],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('results with same warnings in different order are not equal', () {
      const w1 = RoutingWarning(code: 'a', severity: 'info', message: 'x');
      const w2 = RoutingWarning(code: 'b', severity: 'warn', message: 'y');
      final a = RoutingResult(
        source: RoutingSource.memo,
        warnings: [w1, w2],
      );
      final b = RoutingResult(
        source: RoutingSource.memo,
        warnings: [w2, w1],
      );
      expect(a, isNot(equals(b)));
    });

    test('results with same destinationError code are equal', () {
      final a = RoutingResult(
        source: RoutingSource.none,
        warnings: [],
        destinationError: DestinationError(code: 'ERR_BAD', message: 'bad'),
      );
      final b = RoutingResult(
        source: RoutingSource.none,
        warnings: [],
        destinationError: DestinationError(code: 'ERR_BAD', message: 'different message'),
      );
      // equality only checks destinationError.code, not message
      expect(a, equals(b));
    });

    test('results with different destinationError codes are not equal', () {
      final a = RoutingResult(
        source: RoutingSource.none,
        warnings: [],
        destinationError: DestinationError(code: 'ERR_A', message: 'x'),
      );
      final b = RoutingResult(
        source: RoutingSource.none,
        warnings: [],
        destinationError: DestinationError(code: 'ERR_B', message: 'x'),
      );
      expect(a, isNot(equals(b)));
    });

    test('result with destinationError is not equal to one without', () {
      final a = RoutingResult(
        source: RoutingSource.none,
        warnings: [],
        destinationError: DestinationError(code: 'ERR', message: 'x'),
      );
      final b = RoutingResult(source: RoutingSource.none, warnings: []);
      expect(a, isNot(equals(b)));
    });

    // ─── Precision: uint64 boundary values ─────────────────────────────────

    test('results with large uint64 ids at uint64 max are equal', () {
      final maxUint64 = BigInt.parse('18446744073709551615');
      final a = RoutingResult(
        source: RoutingSource.muxed,
        id: maxUint64,
        destinationBaseAccount: 'GA',
        warnings: [],
      );
      final b = RoutingResult(
        source: RoutingSource.muxed,
        id: maxUint64,
        destinationBaseAccount: 'GA',
        warnings: [],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('results differ when one id is above js safe integer and the other is not', () {
      // 2^53 = 9007199254740992 — one above MAX_SAFE_INTEGER
      final unsafe = BigInt.parse('9007199254740993');
      final safe = BigInt.parse('9007199254740991');
      final a = RoutingResult(
        source: RoutingSource.memo,
        id: unsafe,
        warnings: [],
      );
      final b = RoutingResult(
        source: RoutingSource.memo,
        id: safe,
        warnings: [],
      );
      expect(a, isNot(equals(b)));
    });

    // ─── Use in Set / Map (depends on hashCode contract) ───────────────────

    test('identical RoutingResult values deduplicate in a Set', () {
      final a = RoutingResult(
        source: RoutingSource.muxed,
        id: BigInt.from(42),
        destinationBaseAccount: 'GA1',
        warnings: [],
      );
      final b = RoutingResult(
        source: RoutingSource.muxed,
        id: BigInt.from(42),
        destinationBaseAccount: 'GA1',
        warnings: [],
      );
      final set = <RoutingResult>{a, b};
      expect(set.length, equals(1));
    });

    test('different RoutingResult values are both retained in a Set', () {
      final a = RoutingResult(
        source: RoutingSource.muxed,
        id: BigInt.from(1),
        warnings: [],
      );
      final b = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(2),
        warnings: [],
      );
      final set = <RoutingResult>{a, b};
      expect(set.length, equals(2));
    });

    test('RoutingResult can be used as a Map key', () {
      final key = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(123),
        warnings: [],
      );
      final lookup = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(123),
        warnings: [],
      );
      final map = <RoutingResult, String>{key: 'found'};
      expect(map[lookup], equals('found'));
    });

    // ─── Immutability: warnings list is unmodifiable ────────────────────────

    test('mutating the original warnings list does not affect RoutingResult', () {
      final mutable = <RoutingWarning>[
        const RoutingWarning(code: 'a', severity: 'info', message: 'x'),
      ];
      final result = RoutingResult(source: RoutingSource.none, warnings: mutable);
      mutable.add(
        const RoutingWarning(code: 'b', severity: 'warn', message: 'y'),
      );
      // The result's internal list should still have length 1
      expect(result.warnings.length, equals(1));
    });

    test('RoutingResult warnings list is unmodifiable', () {
      final result = RoutingResult(
        source: RoutingSource.none,
        warnings: [
          const RoutingWarning(code: 'x', severity: 'info', message: 'y'),
        ],
      );
      expect(
        () => result.warnings.add(
          const RoutingWarning(code: 'z', severity: 'warn', message: 'w'),
        ),
        throwsUnsupportedError,
      );
    });
  });

  // ─── RoutingResult.idString ──────────────────────────────────────────────

  group('RoutingResult.idString', () {
    test('idString returns null when no id is set', () {
      final r = RoutingResult(source: RoutingSource.none, warnings: []);
      expect(r.idString, isNull);
    });

    test('idString returns decimal string for small id', () {
      final r = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(42),
        warnings: [],
      );
      expect(r.idString, equals('42'));
    });

    test('idString is exact for uint64 max', () {
      final r = RoutingResult(
        source: RoutingSource.muxed,
        id: BigInt.parse('18446744073709551615'),
        warnings: [],
      );
      expect(r.idString, equals('18446744073709551615'));
    });

    test('idString is exact for value above JS MAX_SAFE_INTEGER', () {
      // 2^53 + 1 — would be silently truncated by JS Number
      final r = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.parse('9007199254740993'),
        warnings: [],
      );
      expect(r.idString, equals('9007199254740993'));
    });
  });

  // ─── RoutingResult.safeId ────────────────────────────────────────────────

  group('RoutingResult.safeId', () {
    test('safeId returns null when no id is set', () {
      final r = RoutingResult(source: RoutingSource.none, warnings: []);
      expect(r.safeId, isNull);
    });

    test('safeId value matches id as string', () {
      final r = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(777),
        warnings: [],
      );
      expect(r.safeId?.value, equals('777'));
    });

    test('safeId is exact for uint64 max', () {
      final r = RoutingResult(
        source: RoutingSource.muxed,
        id: BigInt.parse('18446744073709551615'),
        warnings: [],
      );
      expect(r.safeId?.value, equals('18446744073709551615'));
    });
  });
}
