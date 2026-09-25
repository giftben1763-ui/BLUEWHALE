import '../address/codes.dart';
import 'safe_routing_id.dart';

/// The outcome of normalizing a memo value into a routing ID.
///
/// Returned by [normalizeMemoId] and [normalizeMemoTextId].
class NormalizeResult {
  /// The canonical decimal routing ID, or `null` if the memo cannot be used
  /// for routing.
  final String? normalized;

  /// Non-blocking warnings, e.g. `NON_CANONICAL_ROUTING_ID` when leading
  /// zeros were stripped.
  final List<Warning> warnings;

  /// Creates a normalization result.
  NormalizeResult({this.normalized, required this.warnings});
}

/// `2^64 - 1`. Internal; not exported. Use [SafeRoutingId.uint64Max].
final BigInt uint64Max = SafeRoutingId.uint64Max;

/// Matches one or more ASCII digits. Internal; not exported.
final RegExp digitsOnly = RegExp(r'^\d+$');

/// Strict normalizer for MEMO_ID type.
/// A MEMO_ID must be a non-empty string of digits parseable as a uint64.
/// Leading zeros are invalid (except the canonical "0").
/// Returns null if the value cannot be used as a routing ID.
///
/// ```dart
/// normalizeMemoId('42').normalized;                   // '42'
/// normalizeMemoId('007').normalized;                  // '7' (+ warning)
/// normalizeMemoId('18446744073709551616').normalized; // null (> uint64)
/// normalizeMemoId('abc').normalized;                  // null
/// ```
///
/// Web safety: range validation goes through [SafeRoutingId.tryParse],
/// which works on the decimal string directly (length- and
/// lexicographic-comparison based) and therefore never coerces the value
/// through `int`/JS `Number`. Large MEMO_IDs (>
/// `Number.MAX_SAFE_INTEGER`) are validated exactly in browser contexts.
NormalizeResult normalizeMemoId(String s) {
  final warnings = <Warning>[];

  // Reject blank or non-digit strings
  if (s.isEmpty || !digitsOnly.hasMatch(s)) {
    return NormalizeResult(normalized: null, warnings: warnings);
  }

  // Reject leading zeros (e.g. "007" is invalid for a strict MEMO_ID)
  if (s.length > 1 && s.startsWith('0')) {
    warnings.add(
      Warning(
        code: WarningCode.nonCanonicalRoutingId,
        severity: WarningSeverity.warn,
        message:
            'Memo routing ID had leading zeros. Normalized to canonical decimal.',
        normalization: Normalization(
          original: s,
          normalized: BigInt.parse(s).toString(),
        ),
      ),
    );
    // Strip zeros and re-normalize for the returned value
    final stripped = BigInt.parse(s).toString();
    if (SafeRoutingId.tryParseStrict(stripped) == null) {
      return NormalizeResult(normalized: null, warnings: warnings);
    }
    return NormalizeResult(normalized: stripped, warnings: warnings);
  }

  // Validate uint64 range (string-exact; safe on Flutter Web)
  if (SafeRoutingId.tryParseStrict(s) == null) {
    return NormalizeResult(normalized: null, warnings: warnings);
  }

  return NormalizeResult(normalized: s, warnings: warnings);
}

/// Normalizer for MEMO_TEXT type — tries to parse a numeric routing ID.
/// Leading zeros trigger a normalization warning; non-numeric values return null.
///
/// ```dart
/// normalizeMemoTextId('1234').normalized;     // '1234'
/// normalizeMemoTextId('0042').normalized;     // '42' (+ warning)
/// normalizeMemoTextId('invoice-7').normalized; // null
/// ```
NormalizeResult normalizeMemoTextId(String s) {
  final warnings = <Warning>[];

  // Step 1, 2, 3: Blank, non-digit
  if (s.isEmpty || !digitsOnly.hasMatch(s)) {
    return NormalizeResult(normalized: null, warnings: warnings);
  }

  // Step 4: Leading zeros — normalize and warn
  var normalized = s.replaceFirst(RegExp(r'^0+'), '');
  if (normalized.isEmpty) {
    normalized = '0';
  }

  if (normalized != s) {
    warnings.add(
      Warning(
        code: WarningCode.nonCanonicalRoutingId,
        severity: WarningSeverity.warn,
        message:
            'Memo routing ID had leading zeros. Normalized to canonical decimal.',
        normalization: Normalization(original: s, normalized: normalized),
      ),
    );
  }

  // Step 5: uint64 max — validated on the string itself, exactly, so IDs
  // above JS Number.MAX_SAFE_INTEGER are not truncated on Flutter Web.
  if (SafeRoutingId.tryParse(normalized) == null) {
    return NormalizeResult(normalized: null, warnings: warnings);
  }

  return NormalizeResult(normalized: normalized, warnings: warnings);
}
