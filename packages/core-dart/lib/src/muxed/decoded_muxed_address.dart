/// The two components of a decoded muxed (`M…`) address.
///
/// Returned by `MuxedAddress.decode`. [id] is a [BigInt] so the full uint64
/// range is exact on every platform, including Flutter Web.
///
/// ```dart
/// final decoded = MuxedAddress.decode(
///   'MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAD672',
/// );
/// decoded.baseG; // GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI
/// decoded.id;    // BigInt.zero
/// ```
class DecodedMuxedAddress {
  /// The underlying classic `G…` account the muxed address points at.
  final String baseG;

  /// The 64-bit unsigned muxed account ID.
  final BigInt id;

  /// Creates a decoded muxed address from its [baseG] account and [id].
  const DecodedMuxedAddress({required this.baseG, required this.id});

  @override
  bool operator ==(Object other) =>
      other is DecodedMuxedAddress && other.baseG == baseG && other.id == id;

  @override
  int get hashCode => Object.hash(baseG, id);

  @override
  String toString() => 'DecodedMuxedAddress(baseG: $baseG, id: $id)';
}
