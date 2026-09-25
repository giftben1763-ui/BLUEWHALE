/// Routing result types with web-safe routing ID accessors.
///
/// Exposes the [SafeRoutingId] wrapper so browser contexts (Flutter Web)
/// never have to push 64-bit routing IDs through a JS `Number`.
library;

import '../address/codes.dart' show WarningSeverity;
import 'safe_routing_id.dart';

/// Identifies the mechanism used to resolve a routing ID.
enum RoutingSource {
  /// The routing ID was extracted directly from a Muxed address (M-address).
  muxed,

  /// The routing ID was extracted from the transaction's MEMO field (ID or TEXT).
  memo,

  /// No routing ID could be resolved.
  none;

  /// Returns a human-friendly description of the routing source.
  String toDisplayString() {
    switch (this) {
      case RoutingSource.muxed:
        return 'Routed via muxed address (M-address)';
      case RoutingSource.memo:
        return 'Routed via memo ID';
      case RoutingSource.none:
        return 'No routing source detected';
    }
  }
}

/// Severity levels for routing warnings, ordered from least to most severe.
///
/// Used with [RoutingInput.minSeverityLevel] to filter warnings by importance.
enum WarningSeverity {
  /// Informational notice; no action required.
  info,

  /// Potential problem that may need attention.
  warn,

  /// Serious problem; the payment should not be credited automatically.
  error;

  /// Parses a wire severity string (`info`, `warn`, `error`).
  ///
  /// Returns `null` for unrecognized values.
  static WarningSeverity? tryParse(String value) {
    for (final s in WarningSeverity.values) {
      if (s.name == value) return s;
    }
    return null;
  }
}

/// Represents a non-blocking notification emitted during routing resolution.
class RoutingWarning {
  /// The unique code identifying the warning type.
  final String code;

  /// The severity of the warning (info, warn, error).
  final String severity;

  /// A descriptive message explaining the warning.
  final String message;

  /// Creates a warning. See [WarningSeverity] for valid [severity] values.
  const RoutingWarning({
    required this.code,
    required this.severity,
    required this.message,
  });

  /// Emitted when a memo is present but ignored because the destination is a muxed address.
  static const memoIgnored = RoutingWarning(
    code: 'memo-ignored',
    severity: WarningSeverity.info,
    message: 'Memo ignored for muxed address',
  );

  /// Emitted when the transaction sender is detected as a smart contract.
  static const contractSender = RoutingWarning(
    code: 'CONTRACT_SENDER_DETECTED',
    severity: 'info',
    message: 'Contract source detected. Routing state cleared.',
  );

  /// Emitted when SEP-0029 requires a memo but no routing ID was supplied.
  static const missingRequiredMemo = RoutingWarning(
    code: 'MISSING_REQUIRED_MEMO',
    severity: WarningSeverity.error,
    message: 'Destination account requires a memo, but no routing ID was provided.',
  );

  /// Emitted when the destination is a contract (C) address, which cannot
  /// receive classic payments.
  static const invalidDestination = RoutingWarning(
    code: 'INVALID_DESTINATION',
    severity: 'error',
    message: 'C address is not a valid destination',
  );

  /// The parsed [WarningSeverity] of this warning, or `null` if [severity]
  /// is not a recognized level.
  WarningSeverity? get severityLevel => WarningSeverity.tryParse(severity);

  @override
  String toString() => '[$severity] $code: $message';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutingWarning &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          severity == other.severity &&
          message == other.message;

  @override
  int get hashCode => Object.hash(code, severity, message);
}

/// Details of a terminal error encountered during destination account parsing.
class DestinationError {
  /// The `ErrorCode` identifying the failure reason.
  final String code;

  /// A human-readable error message.
  final String message;

  /// Creates a destination error.
  DestinationError({required this.code, required this.message});
}

/// Exception thrown when the routing input is fundamentally malformed.
///
/// `extractRoutingSync` and `extractRouting` throw this for an empty
/// destination or one whose prefix is not `G` or `M`. Structurally invalid
/// `G`/`M` addresses do **not** throw; they are reported through
/// [RoutingResult.destinationError].
///
/// ```dart
/// try {
///   extractRoutingSync(RoutingInput(destination: '', memoType: 'none'));
/// } on ExtractRoutingException catch (e) {
///   print(e.message);
/// }
/// ```
class ExtractRoutingException implements Exception {
  /// A human-readable description of what was wrong with the input.
  final String message;

  /// Creates an exception carrying [message].
  const ExtractRoutingException(this.message);

  @override
  String toString() => 'ExtractRoutingException: $message';
}

/// The set of parameters required to resolve a deposit route.
class RoutingInput {
  /// The destination address (G, M, or C) from the payment operation.
  final String destination;

  /// The type of memo attached to the transaction (none, id, text, hash, return).
  final String memoType;

  /// The raw value of the memo field, if any.
  final String? memoValue;

  /// The source account address of the transaction.
  final String? sourceAccount;

  /// Minimum severity (`info`, `warn` or `error`) of warnings to include in
  /// the result. Defaults to `info` (all warnings are returned).
  final String? minSeverityLevel;

  RoutingInput({
    required this.destination,
    required this.memoType,
    this.memoValue,
    this.sourceAccount,
    this.minSeverityLevel,
  });
}

/// Immutable result object returned from routing resolution.
///
/// Holds the [source] tag indicating how the route was resolved,
/// an optional numeric [id] extracted from the address or memo,
/// and any [warnings] emitted during resolution.
///
/// ## Flutter Web precision safety
///
/// [id] is a [BigInt], which is exact on every Dart target — including
/// Flutter Web, where plain `int` values compile to JS `Number`s and lose
/// precision above `2^53 - 1`. In browser contexts, serialize the routing
/// ID via [idString] or the [safeId] wrapper instead of ever converting it
/// to `int`/`num`.
final class RoutingResult {
  /// The mechanism that successfully resolved the routing ID.
  final RoutingSource source;

  /// The numeric routing identifier (e.g., User ID), or null if none was found.
  final BigInt? id;

  /// A list of non-blocking warnings encountered during resolution.
  final List<RoutingWarning> warnings;

  /// The classic 'G' address of the destination, even if an 'M' address was provided.
  final String? destinationBaseAccount;

  /// Details of the error if the destination address was unparseable.
  final DestinationError? destinationError;

  /// Creates a routing result. [warnings] is copied into an unmodifiable
  /// list.
  RoutingResult({
    required this.source,
    this.id,
    List<RoutingWarning>? warnings,
    this.destinationBaseAccount,
    this.destinationError,
  }) : warnings = List.unmodifiable(warnings ?? const []);

  /// Serializes this result to a JSON-compatible map.
  ///
  /// JSON key names are harmonized with the Go and TypeScript implementations:
  /// - [source]                → `"routingSource"`
  /// - [id]                   → `"routingId"` (decimal string, or null)
  /// - [destinationBaseAccount] → `"destinationBaseAccount"`
  /// - [warnings]             → `"warnings"`
  /// - [destinationError]     → `"destinationError"` (or absent when null)
  ///
  /// The routing ID is always serialized as a **decimal string** — never as a
  /// JS `Number` — so the exact uint64 value survives across isolate boundaries
  /// and platform channels on Flutter Web.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'destinationBaseAccount': destinationBaseAccount,
      'routingId': id?.toString(),
      'routingSource': source.name,
      'warnings': warnings
          .map((w) => <String, dynamic>{
                'code': w.code,
                'severity': w.severity,
                'message': w.message,
              })
          .toList(),
      if (destinationError != null)
        'destinationError': <String, dynamic>{
          'code': destinationError!.code,
          'message': destinationError!.message,
        },
    };
  }

  /// Deserializes a [RoutingResult] from a JSON-compatible map.
  ///
  /// Expects the canonical cross-language JSON keys produced by [toJson]:
  /// `routingSource`, `routingId`, `destinationBaseAccount`, `warnings`,
  /// and optionally `destinationError`.
  ///
  /// The routing ID is parsed from a **decimal string** using [SafeRoutingId]
  /// to guarantee bit-exact values on Flutter Web.
  factory RoutingResult.fromJson(Map<String, dynamic> json) {
    // Parse routingSource enum
    final sourceName = json['routingSource'] as String? ?? 'none';
    final source = RoutingSource.values.firstWhere(
      (e) => e.name == sourceName,
      orElse: () => RoutingSource.none,
    );

    // Parse routingId as a decimal string to avoid JS Number precision loss
    BigInt? id;
    final rawId = json['routingId'];
    if (rawId != null) {
      final idStr = rawId.toString();
      final safe = SafeRoutingId.tryParse(idStr);
      id = safe?.toBigInt;
    }

    // Parse warnings
    final rawWarnings = json['warnings'];
    final warnings = <RoutingWarning>[];
    if (rawWarnings is List) {
      for (final w in rawWarnings) {
        if (w is Map<String, dynamic>) {
          warnings.add(RoutingWarning(
            code: w['code'] as String? ?? '',
            severity: w['severity'] as String? ?? 'info',
            message: w['message'] as String? ?? '',
          ));
        }
      }
    }

    // Parse optional destinationError
    DestinationError? destinationError;
    final rawError = json['destinationError'];
    if (rawError is Map<String, dynamic>) {
      destinationError = DestinationError(
        code: rawError['code'] as String? ?? '',
        message: rawError['message'] as String? ?? '',
      );
    }

    return RoutingResult(
      source: source,
      id: id,
      destinationBaseAccount: json['destinationBaseAccount'] as String?,
      warnings: warnings,
      destinationError: destinationError,
    );
  }

  /// The routing ID as an exact, canonical decimal string, or `null` when
  /// no ID was resolved.
  ///
  /// This is the **web-safe** way to consume [id]: strings never pass
  /// through a JS `Number`, so routing IDs above
  /// `Number.MAX_SAFE_INTEGER` (`9007199254740991`) — up to the uint64
  /// ceiling `18446744073709551615` — keep full precision when running in
  /// a browser context (Flutter Web). Prefer this over `id.toInt()`-style
  /// conversions, which silently truncate there.
  String? get idString => id?.toString();

  /// The routing ID wrapped in a [SafeRoutingId], or `null` when no ID was
  /// resolved.
  ///
  /// [SafeRoutingId] is the BigInt-backed wrapper that guarantees the exact
  /// value survives parsing, comparison, and JSON serialization on all
  /// platforms, including Flutter Web.
  SafeRoutingId? get safeId => id == null ? null : SafeRoutingId.fromBigInt(id!);

  /// Returns a one-line human-readable summary of the result, such as
  /// `Muxed routing: ID 42 -> GA…`.
  String toDisplayString() {
    switch (source) {
      case RoutingSource.muxed:
        final idStr = id?.toString() ?? 'unknown';
        final base = destinationBaseAccount ?? 'unknown';
        return 'Muxed routing: ID $idStr -> $base';
      case RoutingSource.memo:
        final idStr = id?.toString() ?? 'unknown';
        return 'Memo routing: ID $idStr';
      case RoutingSource.none:
        return 'No routing detected';
    }
  }

  @override
  String toString() =>
      'RoutingResult(source: $source, id: $id, warnings: $warnings, destinationBaseAccount: $destinationBaseAccount, destinationError: $destinationError)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutingResult &&
          source == other.source &&
          id == other.id &&
          destinationBaseAccount == other.destinationBaseAccount &&
          destinationError?.code == other.destinationError?.code &&
          _listEquals(warnings, other.warnings);

  @override
  int get hashCode => Object.hash(source, id, destinationBaseAccount,
      destinationError?.code, Object.hashAll(warnings));

  static bool _listEquals(List<RoutingWarning> a, List<RoutingWarning> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
