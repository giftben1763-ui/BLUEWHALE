import 'package:bluewhale_core/bluewhale_core.dart';
import 'package:test/test.dart';

void main() {
  const baseG = 'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';
  const muxedAddress =
      'MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACABAAAAAAAAAAEVIG';

  group('extractRoutingSync', () {
    test('decodes muxed routing when no external memo is present', () {
      final result = extractRoutingSync(
        RoutingInput(destination: muxedAddress, memoType: 'none'),
      );

      expect(result.destinationBaseAccount, baseG);
      expect(result.id, BigInt.parse('9007199254740993'));
      expect(result.source, RoutingSource.muxed);
      expect(result.warnings, isEmpty);
      expect(result.destinationError, isNull);
    });

    test('prefers external memo over muxed routing and emits memo-ignored warning', () {
      final result = extractRoutingSync(
        RoutingInput(
          destination: muxedAddress,
          memoType: 'id',
          memoValue: '42',
        ),
      );

      expect(result.destinationBaseAccount, baseG);
      expect(result.id, BigInt.from(42));
      expect(result.source, RoutingSource.memo);
      expect(result.destinationError, isNull);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first.code, 'memo-ignored');
    });

    test('keeps muxed decode valid when external memo is unroutable', () {
      final result = extractRoutingSync(
        RoutingInput(
          destination: muxedAddress,
          memoType: 'text',
          memoValue: 'not-a-routing-id',
        ),
      );

      expect(result.destinationBaseAccount, baseG);
      expect(result.id, isNull);
      expect(result.source, RoutingSource.none);
      expect(result.destinationError, isNull);
      expect(
        result.warnings.map((warning) => warning.code),
        ['memo-ignored', 'MEMO_TEXT_UNROUTABLE'],
      );
    });

    test('preserves existing non-muxed memo routing behavior', () {
      final result = extractRoutingSync(
        RoutingInput(
          destination: baseG,
          memoType: 'id',
          memoValue: '100',
        ),
      );

      expect(result.destinationBaseAccount, baseG);
      expect(result.id, BigInt.from(100));
      expect(result.source, RoutingSource.memo);
      expect(result.warnings, isEmpty);
      expect(result.destinationError, isNull);
    });

    test('returns structured result with INVALID_DESTINATION warning for C-addresses (#77)', () {
      const cAddress = 'CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC';
      final result = extractRoutingSync(
        RoutingInput(destination: cAddress, memoType: 'none'),
      );

      expect(result.source, RoutingSource.none);
      expect(result.destinationBaseAccount, isNull);
      expect(result.id, isNull);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first.code, 'INVALID_DESTINATION');
      expect(result.warnings.first.severity, 'error');
    });

    test('returns structured destinationError for empty destination (#77)', () {
      final result = extractRoutingSync(
        RoutingInput(destination: '', memoType: 'none'),
      );

      expect(result.source, RoutingSource.none);
      expect(result.destinationBaseAccount, isNull);
      expect(result.id, isNull);
      expect(result.destinationError, isNotNull);
    });
  });

  group('extractRouting (async)', () {
    test('decodes muxed routing when no external memo is present', () async {
      await expectLater(
        extractRouting(RoutingInput(destination: muxedAddress, memoType: 'none')),
        completion(predicate((RoutingResult result) =>
            result.destinationBaseAccount == baseG &&
            result.id == BigInt.parse('9007199254740993') &&
            result.source == RoutingSource.muxed &&
            result.warnings.isEmpty &&
            result.destinationError == null)),
      );
    });

    test('prefers external memo over muxed routing and emits memo-ignored warning', () async {
      await expectLater(
        extractRouting(RoutingInput(
          destination: muxedAddress,
          memoType: 'id',
          memoValue: '42',
        )),
        completion(predicate((RoutingResult result) =>
            result.destinationBaseAccount == baseG &&
            result.id == BigInt.from(42) &&
            result.source == RoutingSource.memo &&
            result.destinationError == null &&
            result.warnings.length == 1 &&
            result.warnings.first.code == 'memo-ignored')),
      );
    });

    test('keeps muxed decode valid when external memo is unroutable', () async {
      await expectLater(
        extractRouting(RoutingInput(
          destination: muxedAddress,
          memoType: 'text',
          memoValue: 'not-a-routing-id',
        )),
        completion(predicate((RoutingResult result) =>
            result.destinationBaseAccount == baseG &&
            result.id == null &&
            result.source == RoutingSource.none &&
            result.destinationError == null &&
            result.warnings.length == 2 &&
            result.warnings[0].code == 'memo-ignored' &&
            result.warnings[1].code == 'MEMO_TEXT_UNROUTABLE')),
      );
    });

    test('preserves existing non-muxed memo routing behavior', () async {
      await expectLater(
        extractRouting(RoutingInput(
          destination: baseG,
          memoType: 'id',
          memoValue: '100',
        )),
        completion(predicate((RoutingResult result) =>
            result.destinationBaseAccount == baseG &&
            result.id == BigInt.from(100) &&
            result.source == RoutingSource.memo &&
            result.warnings.isEmpty &&
            result.destinationError == null)),
      );
    });

    test('returns structured result with INVALID_DESTINATION warning for C-addresses (#77)', () async {
      const cAddress = 'CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC';
      final result = await extractRouting(
        RoutingInput(destination: cAddress, memoType: 'none'),
      );

      expect(result.source, RoutingSource.none);
      expect(result.destinationBaseAccount, isNull);
      expect(result.id, isNull);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first.code, 'INVALID_DESTINATION');
      expect(result.warnings.first.severity, 'error');
    });

    test('returns structured destinationError for empty destination (#77)', () async {
      final result = await extractRouting(
        RoutingInput(destination: '', memoType: 'none'),
      );

      expect(result.source, RoutingSource.none);
      expect(result.destinationBaseAccount, isNull);
      expect(result.id, isNull);
      expect(result.destinationError, isNotNull);
    });
  });
}
