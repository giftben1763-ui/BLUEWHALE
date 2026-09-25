/// Thrown when a Stellar address or muxed ID is malformed or out of range.
///
/// Raised by `StellarAddress.parse`, `MuxedAddress.encode`, and
/// `MuxedAddress.decode`. The non-throwing `detect`, `validate`, and `parse`
/// functions never raise it.
///
/// ```dart
/// try {
///   StellarAddress.parse('not-an-address');
/// } on StellarAddressException catch (e) {
///   print(e.message); // Invalid address
/// }
/// ```
class StellarAddressException implements Exception {
  /// A human-readable description of what was wrong with the input.
  final String message;

  /// Creates an exception carrying [message].
  const StellarAddressException(this.message);

  @override
  String toString() => 'StellarAddressException: $message';
}
