import 'package:test/test.dart';
import 'package:bluewhale_core/bluewhale_core.dart';

void main() {
  group('RoutingSource.toDisplayString', () {
    test('muxed variant formats as muxed address display string', () {
      expect(
        RoutingSource.muxed.toDisplayString(),
        equals('Routed via muxed address (M-address)'),
      );
    });

    test('memo variant formats as memo ID display string', () {
      expect(
        RoutingSource.memo.toDisplayString(),
        equals('Routed via memo ID'),
      );
    });

    test('none variant formats as no routing source display string', () {
      expect(
        RoutingSource.none.toDisplayString(),
        equals('No routing source detected'),
      );
    });
  });

  group('RoutingResult.toDisplayString', () {
    test('muxed source formats with routing ID and base account', () {
      final result = RoutingResult(
        source: RoutingSource.muxed,
        id: BigInt.from(12345),
        destinationBaseAccount: 'GABC123',
        warnings: [],
      );
      expect(
        result.toDisplayString(),
        equals('Muxed routing: ID 12345 -> GABC123'),
      );
    });

    test('muxed source handles null values gracefully', () {
      final result = RoutingResult(
        source: RoutingSource.muxed,
        warnings: [],
      );
      expect(
        result.toDisplayString(),
        equals('Muxed routing: ID unknown -> unknown'),
      );
    });

    test('memo source formats with routing ID', () {
      final result = RoutingResult(
        source: RoutingSource.memo,
        id: BigInt.from(99999),
        warnings: [],
      );
      expect(
        result.toDisplayString(),
        equals('Memo routing: ID 99999'),
      );
    });

    test('memo source handles null values gracefully', () {
      final result = RoutingResult(
        source: RoutingSource.memo,
        warnings: [],
      );
      expect(
        result.toDisplayString(),
        equals('Memo routing: ID unknown'),
      );
    });

    test('none source formats as no routing', () {
      final result = RoutingResult(
        source: RoutingSource.none,
        warnings: [],
      );
      expect(
        result.toDisplayString(),
        equals('No routing detected'),
      );
    });
  });

  const baseG = 'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';
  const muxedAddress =
      'MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACABAAAAAAAAAAEVIG';
  const cAddress = 'CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC';

  group('extractRoutingSync zero-throw safety', () {
    test('C destination returns invalidDestination instead of throwing', () {
      late RoutingResult result;
      expect(
        () => result = extractRoutingSync(
          RoutingInput(destination: cAddress, memoType: 'none'),
        ),
        returnsNormally,
      );
      expect(result.source, RoutingSource.none);
      expect(result.id, isNull);
      expect(result.destinationBaseAccount, isNull);
      expect(result.warnings, [RoutingWarning.invalidDestination]);
    });

    test('C destination with a memo still returns invalidDestination', () {
      final result = extractRoutingSync(
        RoutingInput(destination: cAddress, memoType: 'id', memoValue: '123'),
      );
      expect(result.id, isNull);
      expect(result.source, RoutingSource.none);
      expect(result.warnings, [RoutingWarning.invalidDestination]);
    });

    test('lowercase C destination keeps the non-canonical warning', () {
      final result = extractRoutingSync(
        RoutingInput(destination: cAddress.toLowerCase(), memoType: 'none'),
      );
      expect(
        result.warnings.map((w) => w.code),
        [WarningCode.nonCanonicalAddress, WarningCode.invalidDestination],
      );
    });

    for (final destination in [
      cAddress,
      '${cAddress.substring(0, cAddress.length - 1)}A',
      'SBZVMB74Z76QZ3ZOY7UTDFYKMEGKW5XFJEB6PFKBF4UYSSWHG4EDH7PY',
      'NOTANADDRESS',
      'bob*example.com',
    ]) {
      test('does not throw for "$destination"', () {
        expect(
          () => extractRoutingSync(
            RoutingInput(destination: destination, memoType: 'none'),
          ),
          returnsNormally,
        );
      });
    }
  });

  group('RoutingInput.minSeverityLevel', () {
    RoutingResult run(WarningSeverity? level) => extractRoutingSync(
          RoutingInput(
            destination: muxedAddress,
            memoType: 'text',
            memoValue: 'not-a-routing-id',
            minSeverityLevel: level,
          ),
        );

    test('null returns all warnings', () {
      expect(
        run(null).warnings.map((w) => w.code),
        ['memo-ignored', WarningCode.memoTextUnroutable],
      );
    });

    test('info returns all warnings', () {
      expect(
        run(WarningSeverity.info).warnings.map((w) => w.code),
        ['memo-ignored', WarningCode.memoTextUnroutable],
      );
    });

    test('warn drops informational warnings', () {
      expect(
        run(WarningSeverity.warn).warnings.map((w) => w.code),
        [WarningCode.memoTextUnroutable],
      );
    });

    test('error drops info and warn warnings', () {
      expect(run(WarningSeverity.error).warnings, isEmpty);
    });

    test('filtering does not change routing fields', () {
      final all = run(null);
      final filtered = run(WarningSeverity.error);
      expect(filtered.destinationBaseAccount, all.destinationBaseAccount);
      expect(filtered.id, all.id);
      expect(filtered.source, all.source);
    });

    test('error-level invalidDestination survives the error threshold', () {
      final result = extractRoutingSync(
        RoutingInput(
          destination: cAddress.toLowerCase(),
          memoType: 'none',
          minSeverityLevel: WarningSeverity.error,
        ),
      );
      expect(result.warnings, [RoutingWarning.invalidDestination]);
    });

    test('async extractRouting applies the filter to added warnings', () async {
      final result = await extractRouting(
        RoutingInput(
          destination: baseG,
          memoType: 'none',
          minSeverityLevel: WarningSeverity.error,
        ),
        fetchMemoRequirement: (_) async => true,
      );
      expect(result.warnings, [RoutingWarning.missingRequiredMemo]);
    });
  });

  group('WarningSeverity', () {
    test('tryParse maps wire strings', () {
      expect(WarningSeverity.tryParse('info'), WarningSeverity.info);
      expect(WarningSeverity.tryParse('warn'), WarningSeverity.warn);
      expect(WarningSeverity.tryParse('error'), WarningSeverity.error);
      expect(WarningSeverity.tryParse('fatal'), isNull);
    });
  });
}
