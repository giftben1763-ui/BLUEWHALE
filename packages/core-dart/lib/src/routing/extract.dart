import '../address/codes.dart' as codes;
import '../address/parse.dart';
import '../muxed/decode.dart';
import 'routing_result.dart';
import 'memo.dart';
import 'safe_routing_id.dart';

/// Extracts deposit routing information from a Stellar payment input.
/// Following the standard priority policy, M-address identifiers take
/// precedence over any provided memo.
///
/// Zero-throw policy: this function never throws for any valid string input.
/// C-addresses, empty destinations, and unrecognized prefixes are returned as
/// a structured [RoutingResult] with either an `INVALID_DESTINATION` warning
/// or a [DestinationError], rather than raising an [ExtractRoutingException].
/// The only remaining exception case is when [RoutingInput.destination] is
/// truly invalid at the type level (which cannot happen in typed Dart code).
///
/// Web safety: routing IDs are resolved through [SafeRoutingId], which
/// parses the canonical decimal **string** exactly and never converts
/// through `int`/JS `Number`. Combined with the `BigInt`-backed
/// [RoutingResult.id], [RoutingResult.idString], and
/// [RoutingResult.safeId] accessors, MEMO_IDs and muxed IDs up to the
/// uint64 ceiling survive Flutter Web without truncation.
///
/// This is the synchronous variant for pure string parsing.
/// For future compatibility with async network checks (Federation, SEP-0029),
/// use [extractRouting] instead.
RoutingResult extractRoutingSync(RoutingInput input) {
  final trimmed = input.destination.trim();

  // Empty destination → return structured destinationError (zero-throw policy).
  if (trimmed.isEmpty) {
    return RoutingResult(
      source: RoutingSource.none,
      warnings: [],
      destinationError: DestinationError(
        code: codes.ErrorCode.unknownPrefix,
        message: 'Invalid input: destination must be a non-empty string.',
      ),
    );
  }

  final prefix = trimmed[0].toUpperCase();

  // Non-G/M prefix (C-address or unknown) → return structured result.
  // C-addresses get an INVALID_DESTINATION warning; unknown prefixes get
  // a destinationError. Both are consistent with Go and TypeScript behavior.
  if (prefix != 'G' && prefix != 'M') {
    // Attempt to parse to distinguish a valid C-address from a garbage prefix.
    try {
      final parsed = parse(input.destination);
      if (parsed.kind == codes.AddressKind.c) {
        return RoutingResult(
          source: RoutingSource.none,
          warnings: [
            const RoutingWarning(
              code: codes.WarningCode.invalidDestination,
              severity: 'error',
              message: 'C address is not a valid destination',
            ),
          ],
        );
      }
    } catch (_) {
      // Fall through to the destinationError path below.
    }
    return RoutingResult(
      source: RoutingSource.none,
      warnings: [],
      destinationError: DestinationError(
        code: codes.ErrorCode.unknownPrefix,
        message:
            'Invalid destination: expected a G or M address, got "${input.destination}".',
      ),
    );
  }

  if (input.sourceAccount != null && input.sourceAccount!.isNotEmpty) {
    try {
      final source = parse(input.sourceAccount!);
      if (source.kind == codes.AddressKind.c) {
        return RoutingResult(
          source: RoutingSource.none,
          warnings: [RoutingWarning.contractSender],
        );
      }
    } catch (_) {
      // Ignore source account parsing errors for routing extraction
    }
  }

  final parsed = parse(input.destination);

  if (parsed.kind == null) {
    return RoutingResult(
      source: RoutingSource.none,
      warnings: [],
      destinationError: parsed.error != null
          ? DestinationError(
              code: parsed.error!.code,
              message: parsed.error!.message,
            )
          : null,
    );
  }

  final warnings = <RoutingWarning>[];
  for (final w in parsed.warnings) {
    warnings.add(RoutingWarning(
      code: w.code,
      severity: w.severity,
      message: w.message,
    ));
  }

  if (parsed.kind == codes.AddressKind.m) {
    final decoded = MuxedDecoder.decodeMuxedString(parsed.address);
    final baseG = decoded.baseG;
    final muxedId = decoded.id;

    if (input.memoType == 'none') {
      return RoutingResult(
        destinationBaseAccount: baseG,
        id: muxedId,
        source: RoutingSource.muxed,
        warnings: warnings,
      );
    }

    BigInt? routingId;
    RoutingSource routingSource = RoutingSource.none;

    warnings.add(RoutingWarning.memoIgnored);

    if (input.memoType == 'id') {
      final norm = normalizeMemoId(input.memoValue ?? '');
      if (norm.normalized != null) {
        routingId = SafeRoutingId.tryParse(norm.normalized!)?.toBigInt;
        routingSource = RoutingSource.memo;
      } else {
        warnings.add(
          const RoutingWarning(
            code: codes.WarningCode.memoIdInvalidFormat,
            severity: 'warn',
            message: 'MEMO_ID was empty, non-numeric, or exceeded uint64 max.',
          ),
        );
      }
      for (final w in norm.warnings) {
        warnings.add(RoutingWarning(
          code: w.code,
          severity: w.severity,
          message: w.message,
        ));
      }
    } else if (input.memoType == 'text' && input.memoValue != null) {
      final norm = normalizeMemoTextId(input.memoValue!);
      if (norm.normalized != null) {
        routingId = SafeRoutingId.tryParse(norm.normalized!)?.toBigInt;
        routingSource = RoutingSource.memo;
      } else {
        warnings.add(
          const RoutingWarning(
            code: codes.WarningCode.memoTextUnroutable,
            severity: 'warn',
            message: 'MEMO_TEXT was not a valid numeric uint64.',
          ),
        );
      }
      for (final w in norm.warnings) {
        warnings.add(RoutingWarning(
          code: w.code,
          severity: w.severity,
          message: w.message,
        ));
      }
    } else if (input.memoType == 'hash' || input.memoType == 'return') {
      warnings.add(
        RoutingWarning(
          code: codes.WarningCode.unsupportedMemoType,
          severity: 'warn',
          message: 'Memo type ${input.memoType} is not supported for routing.',
        ),
      );
    } else {
      warnings.add(
        const RoutingWarning(
          code: codes.WarningCode.unsupportedMemoType,
          severity: 'warn',
          message: 'Unrecognized memo type: unknown',
        ),
      );
    }

    return RoutingResult(
      destinationBaseAccount: baseG,
      id: routingId,
      source: routingSource,
      warnings: warnings,
    );
  }

  BigInt? routingId;
  RoutingSource routingSource = RoutingSource.none;

  if (input.memoType == 'id') {
    final norm = normalizeMemoId(input.memoValue ?? '');
    if (norm.normalized != null) {
      routingId = SafeRoutingId.tryParse(norm.normalized!)?.toBigInt;
      routingSource = RoutingSource.memo;
    } else {
      warnings.add(
        const RoutingWarning(
          code: codes.WarningCode.memoIdInvalidFormat,
          severity: 'warn',
          message: 'MEMO_ID was empty, non-numeric, or exceeded uint64 max.',
        ),
      );
    }
    for (final w in norm.warnings) {
      warnings.add(RoutingWarning(
        code: w.code,
        severity: w.severity,
        message: w.message,
      ));
    }
  } else if (input.memoType == 'text' && input.memoValue != null) {
    final norm = normalizeMemoTextId(input.memoValue!);
    if (norm.normalized != null) {
      routingId = SafeRoutingId.tryParse(norm.normalized!)?.toBigInt;
      routingSource = RoutingSource.memo;
    } else {
      warnings.add(
        const RoutingWarning(
          code: codes.WarningCode.memoTextUnroutable,
          severity: 'warn',
          message: 'MEMO_TEXT was not a valid numeric uint64.',
        ),
      );
    }
    for (final w in norm.warnings) {
      warnings.add(RoutingWarning(
        code: w.code,
        severity: w.severity,
        message: w.message,
      ));
    }
  } else if (input.memoType == 'hash' || input.memoType == 'return') {
    warnings.add(
      RoutingWarning(
        code: codes.WarningCode.unsupportedMemoType,
        severity: 'warn',
        message: 'Memo type ${input.memoType} is not supported for routing.',
      ),
    );
  } else if (input.memoType != 'none') {
    warnings.add(
      const RoutingWarning(
        code: codes.WarningCode.unsupportedMemoType,
        severity: 'warn',
        message: 'Unrecognized memo type: unknown',
      ),
    );
  }

  return RoutingResult(
    destinationBaseAccount: parsed.address,
    id: routingId,
    source: routingSource,
    warnings: warnings,
  );
}

/// Extracts deposit routing information with support for future
/// async network checks (Federation, SEP-0029).
///
/// Currently delegates to [extractRoutingSync]; when async capabilities
/// are added this function will perform the additional checks.
typedef MemoRequirementFetcher = Future<bool> Function(String baseAccount);

/// Performs routing extraction and optionally checks a destination's SEP-0029
/// memo requirement. Fetch failures fail open to preserve parser behavior.
Future<RoutingResult> extractRouting(
  RoutingInput input, {
  MemoRequirementFetcher? fetchMemoRequirement,
}) async {
  final result = extractRoutingSync(input);
  if (fetchMemoRequirement == null ||
      result.destinationBaseAccount == null ||
      result.id != null ||
      result.destinationError != null) {
    return result;
  }

  try {
    if (await fetchMemoRequirement(result.destinationBaseAccount!)) {
      return RoutingResult(
        source: result.source,
        id: result.id,
        destinationBaseAccount: result.destinationBaseAccount,
        destinationError: result.destinationError,
        warnings: [...result.warnings, RoutingWarning.missingRequiredMemo],
      );
    }
  } catch (_) {
    // Network/configuration failures must not change the synchronous result.
  }
  return result;
}
