import 'package:meta/meta.dart';
import '../muxed/decode.dart';
import '../exceptions.dart';
import 'codes.dart';
import 'detect.dart';

/// An immutable representation of a Stellar Address.
///
/// Use [StellarAddress.parse] when invalid input is exceptional; use
/// [detect] or `parse` when you want a non-throwing check.
///
/// ```dart
/// final address = StellarAddress.parse(
///   'MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACAAAAAAAAAAAAD672',
/// );
/// address.kind;    // AddressKind.m
/// address.baseG;   // 'GAYCUYT553C5…ADRSI'
/// address.muxedId; // BigInt.zero
/// ```
@immutable
class StellarAddress {
  /// The specific kind of address (g, m, or c).
  final AddressKind kind;

  /// The original, encoded string representation of the address.
  final String raw;

  /// The base G... address associated with this address.
  /// For G-addresses, it matches [raw]. For M-addresses, it is the underlying account.
  final String? baseG;

  /// The 64-bit unsigned integer ID. Only present for M-addresses (muxedId).
  final BigInt? muxedId;

  /// Private internal constructor to enforce immutability.
  const StellarAddress._({
    required this.kind,
    required this.raw,
    this.baseG,
    this.muxedId,
  });

  /// Factory constructor that parses a Stellar address string.
  ///
  /// Throws [StellarAddressException] for invalid input or length.
  factory StellarAddress.parse(String address) {
    if (address.isEmpty) {
      throw const StellarAddressException('Invalid address');
    }

    switch (address[0].toUpperCase()) {
      case 'G':
        return _parseStandard(address);
      case 'M':
        return _parseMuxed(address);
      case 'C':
        return _parseContract(address);
      default:
        throw const StellarAddressException('Invalid address');
    }
  }

  static StellarAddress _parseStandard(String address) {
    _expectKind(address, AddressKind.g);
    return StellarAddress._(
      kind: AddressKind.g,
      raw: address,
      baseG: address,
    );
  }

  static StellarAddress _parseMuxed(String address) {
    _expectKind(address, AddressKind.m);

    try {
      final decoded = MuxedDecoder.decodeMuxedString(address);
      return StellarAddress._(
        kind: AddressKind.m,
        raw: address,
        baseG: decoded.baseG,
        muxedId: decoded.id,
      );
    } catch (error) {
      throw StellarAddressException(
        'Invalid muxed address: ${error.toString()}',
      );
    }
  }

  static StellarAddress _parseContract(String address) {
    _expectKind(address, AddressKind.c);
    return StellarAddress._(kind: AddressKind.c, raw: address);
  }

  static void _expectKind(String address, AddressKind expectedKind) {
    if (detect(address) != expectedKind) {
      throw const StellarAddressException('Invalid address');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StellarAddress &&
          runtimeType == other.runtimeType &&
          raw == other.raw;

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() => raw;
}