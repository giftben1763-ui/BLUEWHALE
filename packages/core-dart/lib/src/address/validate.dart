import 'detect.dart';

/// Returns `true` when [address] is a structurally valid G, M, or C address.
///
/// Validation is non-throwing and case-insensitive by default, matching
/// [detect]. Pass `strict: true` to additionally require the canonical
/// uppercase form.
///
/// ```dart
/// const g = 'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';
/// validate(g);                               // true
/// validate(g.toLowerCase());                 // true
/// validate(g.toLowerCase(), strict: true);   // false
/// validate('not-an-address');                // false
/// ```
bool validate(String address, {bool strict = false}) {
  final kind = detect(address);
  if (kind == null) return false;
  if (strict && address != address.toUpperCase()) return false;
  return true;
}
