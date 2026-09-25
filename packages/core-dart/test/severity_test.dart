// Severity thresholding (minSeverityLevel) parity suite.
//
// The same table is asserted in core-ts (src/test/severity.test.ts) and
// core-go (routing/severity_test.go) so that all three SDKs filter warnings
// identically: info = 0, warn = 1, error = 2.
import 'package:bluewhale_core/bluewhale_core.dart';
import 'package:test/test.dart';

void main() {
  const baseG = 'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';
  const contractSource =
      'CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC';

  List<String> codes(List<RoutingWarning> warnings) =>
      warnings.map((w) => w.code).toList();

  group('severity weights', () {
    test('uses the normative ordering info=0, warn=1, error=2', () {
      expect(severityOrder, {'info': 0, 'warn': 1, 'error': 2});
      expect(severityWeight(WarningSeverity.info), 0);
      expect(severityWeight(WarningSeverity.warn), 1);
      expect(severityWeight(WarningSeverity.error), 2);
    });

    test('treats unknown or missing severities as info', () {
      expect(severityWeight('fatal'), 0);
      expect(severityWeight(''), 0);
      expect(severityWeight(null), 0);
    });
  });

  group('filterBySeverity', () {
    const mixed = [
      RoutingWarning(
          code: WarningCode.memoIgnoredForMuxed, severity: 'info', message: 'info'),
      RoutingWarning(
          code: WarningCode.nonCanonicalRoutingId, severity: 'warn', message: 'warn'),
      RoutingWarning(
          code: WarningCode.invalidDestination, severity: 'error', message: 'error'),
    ];

    final table = <String, List<String>>{
      'info': [
        'MEMO_IGNORED_FOR_MUXED',
        'NON_CANONICAL_ROUTING_ID',
        'INVALID_DESTINATION',
      ],
      'warn': ['NON_CANONICAL_ROUTING_ID', 'INVALID_DESTINATION'],
      'error': ['INVALID_DESTINATION'],
      'bogus': [
        'MEMO_IGNORED_FOR_MUXED',
        'NON_CANONICAL_ROUTING_ID',
        'INVALID_DESTINATION',
      ],
    };

    table.forEach((min, expected) {
      test('minSeverity=$min keeps $expected', () {
        expect(codes(filterBySeverity(mixed, min)), expected);
      });
    });
  });

  group('extractRoutingSync minSeverityLevel', () {
    final cases = <String, (RoutingInput Function(String?), Map<String, List<String>>)>{
      "G + MEMO_TEXT '007' (warn)": (
        (min) => RoutingInput(
              destination: baseG,
              memoType: 'text',
              memoValue: '007',
              minSeverityLevel: min,
            ),
        {
          'info': ['NON_CANONICAL_ROUTING_ID'],
          'warn': ['NON_CANONICAL_ROUTING_ID'],
          'error': [],
        },
      ),
      'contract source (info)': (
        (min) => RoutingInput(
              destination: baseG,
              memoType: 'id',
              memoValue: '1',
              sourceAccount: contractSource,
              minSeverityLevel: min,
            ),
        {
          'info': ['CONTRACT_SENDER_DETECTED'],
          'warn': [],
          'error': [],
        },
      ),
    };

    cases.forEach((name, spec) {
      final (build, expected) = spec;
      for (final min in ['info', 'warn', 'error']) {
        test('$name @ $min', () {
          expect(codes(extractRoutingSync(build(min)).warnings), expected[min]);
        });
      }
    });

    test('defaults to info when minSeverityLevel is omitted', () {
      final result = extractRoutingSync(
        RoutingInput(destination: baseG, memoType: 'text', memoValue: '007'),
      );
      expect(codes(result.warnings), ['NON_CANONICAL_ROUTING_ID']);
    });
  });
}
