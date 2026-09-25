/// SEP-0007 payment URI parsing.
///
/// Parses `web+stellar:pay?...` URIs (from QR code scanners or deeplinks)
/// and delegates to [extractRoutingSync] to produce canonical routing
/// information.
///
/// See https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0007.md
library;

import 'extract.dart';
import 'routing_result.dart';

const _scheme = 'web+stellar';

/// Reasons a SEP-0007 URI could not be turned into a routing result.
enum UriRoutingErrorCode {
  /// The input is not a parseable URI, or does not use the `web+stellar:` scheme.
  invalidUri,

  /// The URI uses an operation other than `pay` (for example `tx`).
  unsupportedOperation,

  /// The `destination` query parameter is absent or empty.
  missingDestination,

  /// The query string contains malformed percent-encoding.
  invalidEncoding,
}

/// Decoded parameters of a SEP-0007 `pay` URI.
class Sep7PayParams {
  final String destination;
  final String? amount;
  final String? assetCode;
  final String? assetIssuer;
  final String? memo;
  final String? memoType;
  final String? callback;
  final String? msg;
  final String? networkPassphrase;
  final String? originDomain;
  final String? signature;

  const Sep7PayParams({
    required this.destination,
    this.amount,
    this.assetCode,
    this.assetIssuer,
    this.memo,
    this.memoType,
    this.callback,
    this.msg,
    this.networkPassphrase,
    this.originDomain,
    this.signature,
  });
}

/// The outcome of parsing a SEP-0007 URI.
///
/// On success, [routing] and [params] are non-null. On failure, [errorCode]
/// and [errorMessage] are non-null. Error messages never include URI
/// content, so they are safe to log even when the URI carries memos or
/// signatures.
final class UriRoutingResult {
  final RoutingResult? routing;
  final Sep7PayParams? params;
  final UriRoutingErrorCode? errorCode;
  final String? errorMessage;

  const UriRoutingResult._success(RoutingResult this.routing, Sep7PayParams this.params)
      : errorCode = null,
        errorMessage = null;

  const UriRoutingResult._failure(UriRoutingErrorCode this.errorCode, String this.errorMessage)
      : routing = null,
        params = null;

  bool get isSuccess => errorCode == null;

  @override
  String toString() => isSuccess
      ? 'UriRoutingResult(routing: $routing)'
      : 'UriRoutingResult(errorCode: ${errorCode!.name}, errorMessage: $errorMessage)';
}

/// Parses a SEP-0007 URI string and extracts canonical routing information.
///
/// Never throws: malformed input yields a failed [UriRoutingResult].
///
/// ```dart
/// final result = extractRoutingFromUriString(
///   'web+stellar:pay?destination=GAYC...DRSI&memo=123&memo_type=MEMO_ID',
/// );
/// if (result.isSuccess) {
///   print(result.routing!.idString); // "123"
/// }
/// ```
UriRoutingResult extractRoutingFromUriString(
  String uriString, {
  WarningSeverity? minSeverityLevel,
}) {
  final trimmed = uriString.trim();
  final Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } on FormatException {
    if (trimmed.toLowerCase().startsWith('$_scheme:')) {
      return const UriRoutingResult._failure(
        UriRoutingErrorCode.invalidEncoding,
        'Failed to decode URI query parameters.',
      );
    }
    return const UriRoutingResult._failure(
      UriRoutingErrorCode.invalidUri,
      'Input is not a valid URI.',
    );
  }
  return extractRoutingFromUri(uri, minSeverityLevel: minSeverityLevel);
}

/// Parses a SEP-0007 [Uri] and extracts canonical routing information.
///
/// Only the `pay` operation is supported. `memo_type` values `MEMO_ID`,
/// `MEMO_TEXT`, `MEMO_HASH`, and `MEMO_RETURN` map to the corresponding
/// routing memo types; a missing or unrecognized `memo_type` is treated as
/// no memo. When a parameter is repeated, the first value is used.
///
/// Never throws: malformed input yields a failed [UriRoutingResult].
UriRoutingResult extractRoutingFromUri(
  Uri uri, {
  WarningSeverity? minSeverityLevel,
}) {
  if (uri.scheme.toLowerCase() != _scheme) {
    return const UriRoutingResult._failure(
      UriRoutingErrorCode.invalidUri,
      "URI must use the 'web+stellar:' scheme.",
    );
  }

  if (uri.path != 'pay') {
    return const UriRoutingResult._failure(
      UriRoutingErrorCode.unsupportedOperation,
      "Unsupported operation. Only 'pay' is supported for routing extraction.",
    );
  }

  final Map<String, List<String>> query;
  try {
    query = uri.queryParametersAll;
  } catch (_) {
    return const UriRoutingResult._failure(
      UriRoutingErrorCode.invalidEncoding,
      'Failed to decode URI query parameters.',
    );
  }

  String? param(String key) {
    final values = query[key];
    if (values == null || values.isEmpty || values.first.isEmpty) return null;
    return values.first;
  }

  final destination = param('destination')?.trim();
  if (destination == null || destination.isEmpty) {
    return const UriRoutingResult._failure(
      UriRoutingErrorCode.missingDestination,
      "Missing required 'destination' parameter.",
    );
  }

  final params = Sep7PayParams(
    destination: destination,
    amount: param('amount'),
    assetCode: param('asset_code'),
    assetIssuer: param('asset_issuer'),
    memo: param('memo'),
    memoType: param('memo_type'),
    callback: param('callback'),
    msg: param('msg'),
    networkPassphrase: param('network_passphrase'),
    originDomain: param('origin_domain'),
    signature: param('signature'),
  );

  final routing = extractRoutingSync(
    RoutingInput(
      destination: params.destination,
      memoType: _mapMemoType(params.memoType),
      memoValue: params.memo,
      minSeverityLevel: minSeverityLevel,
    ),
  );

  return UriRoutingResult._success(routing, params);
}

String _mapMemoType(String? sep7MemoType) {
  switch (sep7MemoType?.trim().toUpperCase()) {
    case 'MEMO_ID':
      return 'id';
    case 'MEMO_TEXT':
      return 'text';
    case 'MEMO_HASH':
      return 'hash';
    case 'MEMO_RETURN':
      return 'return';
    default:
      return 'none';
  }
}
