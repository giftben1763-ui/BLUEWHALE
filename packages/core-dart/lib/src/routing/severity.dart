/// Warning severity ordering shared across the Bluewhale SDKs.
library;

import 'routing_result.dart';

/// Warning severities, ordered from least to most severe.
abstract final class WarningSeverity {
  static const info = 'info';
  static const warn = 'warn';
  static const error = 'error';
}

/// Numeric weight of each warning severity. This ordering is normative and is
/// shared verbatim by core-ts (`SEVERITY_ORDER`) and core-go
/// (`routing.SeverityWeight`): info = 0, warn = 1, error = 2.
const Map<String, int> severityOrder = {
  WarningSeverity.info: 0,
  WarningSeverity.warn: 1,
  WarningSeverity.error: 2,
};

/// Returns the numeric weight of [severity]. Unknown or `null` severities
/// weigh the same as `info` (0) so that an unrecognized value never hides
/// warnings.
int severityWeight(String? severity) =>
    severityOrder[severity] ?? severityOrder[WarningSeverity.info]!;

/// Keeps only warnings whose severity weight is >= the weight of
/// [minSeverity], preserving their original order.
List<RoutingWarning> filterBySeverity(
  List<RoutingWarning> warnings,
  String? minSeverity,
) {
  final threshold = severityWeight(minSeverity);
  return warnings.where((w) => severityWeight(w.severity) >= threshold).toList();
}
