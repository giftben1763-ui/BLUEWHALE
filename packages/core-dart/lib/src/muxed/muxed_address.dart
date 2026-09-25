import '../address/detect.dart';
import '../address/codes.dart';
import '../exceptions.dart';
import '../util/strkey.dart';
import 'decode.dart';
import 'decoded_muxed_address.dart';
import 'encode.dart';

/// Class for handling Stellar Muxed Addresses (M... addresses).
///
/// IMPORTANT: On web targets, Dart compiled to JavaScript uses JS `Number` for
/// integer values, which cannot safely represent all 64-bit values above
/// `2^53 - 1`. In this library, `MuxedAddress` uses Dart `BigInt` for the
/// muxed ID; web consumers should avoid converting the 64-bit `id` to a JS
/// `Number`, or explicitly keep it as `BigInt` to prevent precision loss.
///
/// If you need to serialize IDs for web usage, treat them as strings and
/// apply appropriate conversion logic to maintain full 64-bit range
/// correctness. The [SafeRoutingId] wrapper does exactly this: it parses,
/// validates, and serializes routing IDs as exact decimal strings (see also
/// `isWebJsRuntime` for the compile-time web probe).
///
/// For Flutter web guidance and BigInt caveats, see
/// [flutter-web-bigint.md](../../../../docs/guides/flutter-web-bigint.md).
class MuxedAddress {
  /// Encodes the classic account [baseG] and the uint64 [id] into an
  /// `M…` address.
  ///
  /// Throws [StellarAddressException] if [id] is outside `0..2^64 - 1` or
  /// [baseG] is not a valid `G…` address.
  ///
  /// ```dart
  /// final m = MuxedAddress.encode(
  ///   baseG: 'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI',
  ///   id: BigInt.parse('9007199254740993'),
  /// );
  /// ```
  static String encode({required String baseG, required BigInt id}) {
    final uint64Max = BigInt.parse('18446744073709551615');
    if (id < BigInt.zero || id > uint64Max) {
      throw const StellarAddressException('ID out of uint64 range');
    }

    if (detect(baseG) != AddressKind.g) {
      throw const StellarAddressException('Invalid base G address');
    }

    return MuxedEncoder.encodeMuxed(_decodeG(baseG), id);
  }

  /// Decodes an `M…` address into its base `G…` account and uint64 ID.
  ///
  /// Throws [StellarAddressException] if [mAddress] is not valid Base32 or
  /// does not have the muxed length and version byte. The CRC-16 checksum
  /// is **not** verified; use [StellarAddress.parse] (or check [detect]
  /// first) for untrusted input.
  ///
  /// ```dart
  /// final decoded = MuxedAddress.decode(m);
  /// decoded.baseG; // the underlying G address
  /// decoded.id;    // BigInt, exact on every platform
  /// ```
  static DecodedMuxedAddress decode(String mAddress) {
    try {
      return MuxedDecoder.decodeMuxedString(mAddress);
    } catch (e) {
      if (e is StellarAddressException) rethrow;
      throw StellarAddressException('Failed to decode M address: $e');
    }
  }

  static List<int> _decodeG(String g) {
    try {
      final decoded = StrKeyUtil.decodeBase32(g);
      return decoded.sublist(1, 33);
    } catch (e) {
      throw const StellarAddressException('Failed to decode G address');
    }
  }
}
