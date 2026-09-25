# @redishfish/bluewhale-core (Dart)

The Dart/Flutter implementation of the Bluewhale for mobile and web wallet routing.

```yaml
dependencies:
  bluewhale_core: ^1.2.0
```

Part of a multi-language suite also available in **[TypeScript](https://github.com/REDISHFISH/BLUEWHALE/tree/main/packages/core-ts)** and **[Go](https://github.com/REDISHFISH/BLUEWHALE/tree/main/packages/core-go)**.

---

### 📖 Documentation & Guides
- [Flutter: Displaying Deposit Addresses](https://github.com/REDISHFISH/BLUEWHALE/blob/main/docs/guides/flutter-displaying-deposit-addresses.md)
- [Flutter: Web BigInt Considerations](https://github.com/REDISHFISH/BLUEWHALE/blob/main/docs/guides/flutter-web-bigint.md)
- [General: Compatibility Reference](https://github.com/REDISHFISH/BLUEWHALE/blob/main/docs/guides/compatibility-reference.md)

---

## Quick Start

```dart
import 'package:bluewhale_core/bluewhale_core.dart';

void main() {
  final address = 'GA7QYNF7SOWQ3GLR2B6RS22TBGZAOR6KLYH4PA5ZAM73A3H4K2HZZSQU';
  
  if (validate(address)) {
    final kind = detect(address);
    print('Address kind: $kind');
    
    final parsed = StellarAddress.parse(address);
    print('Base G address: ${parsed.baseG}');
  }
}
```

## Examples

### Simple Dart Example
A basic example can be found in the [example/](example/) folder.

### Full Flutter Demo
For a complete integration in a Flutter application, including UI components for displaying deposit addresses and handling incoming payments, check out the [flutter-demo](../../examples/flutter-demo) in the root repository.

## Documentation

For deep dives into Flutter implementation and web BigInt considerations, see our [comprehensive Guides](https://github.com/REDISHFISH/BLUEWHALE/tree/main/docs/guides).

## License

MIT
