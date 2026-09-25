<p align="center">
  <img src="https://img.shields.io/badge/Bluewhale-3E1BDB?style=for-the-badge" alt="Bluewhale" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-1.2.0-blue?style=for-the-badge" alt="Version 1.2.0" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License MIT" />
  <img src="https://img.shields.io/badge/Documentation-Live-blue?style=for-the-badge&logo=gitbook&logoColor=white" alt="Docs" />
  <a href="https://codecov.io/gh/REDISHFISH/BLUEWHALE">
    <img src="https://codecov.io/gh/REDISHFISH/BLUEWHALE/graph/badge.svg" alt="Coverage" />
  </a>
</p>

**Bluewhale** is a specialized, multi-language library designed to solve the complexity of deposit routing on the Stellar network. It provides a unified, spec-compliant way to handle G-addresses (classic), M-addresses (muxed), and C-addresses (contracts) across TypeScript, Go, and Dart.

## Use Cases

- **Exchange Deposit Reconciliation**: Reliably identify incoming payments, correctly extracting the routing ID whether it arrives via a Muxed address or a standard Memo, while automatically flagging non-canonical formatting.
- **Wallet Address Input Forms**: Prevent users from making mistakes (like sending payments to a Contract address or entering a Memo alongside an M-address) with real-time UI warnings.
- **Compliance & Security Firewalls**: Automatically quarantine deposits from contract-senders or invalid destinations before they affect user balances.
- **Cross-Platform Parity**: Ensure identical deposit routing behavior whether your backend is written in Go, your frontend in TypeScript, or your mobile app in Flutter.

## Core Features

- **Spec-First Design**: Guaranteed identical behavior across all three languages via a shared test vector suite.
- **Precision Safety**: Built-in protection against 64-bit integer precision loss in JavaScript and Flutter Web.
- **Warning System**: Discriminated unions (TS) or structured objects (Go/Dart) to catch edge cases like numeric `MEMO_TEXT`.
- **Zero Dependencies**: Core logic is lightweight and has zero external dependencies beyond standard library features.

## Documentation

For full technical specifications, architecture deep-dives, and API references, visit our [Live Documentation](https://bluewhale.mintlify.app/docs/introduction).

- **[Quickstart](https://bluewhale.mintlify.app/docs/quickstart)**: Get running in under 60 seconds.
- **[Routing Logic](https://bluewhale.mintlify.app/docs/concepts/routing-logic)**: Complete reference of all routing scenarios.
- **[Common Mistakes](https://bluewhale.mintlify.app/docs/common-mistakes)**: Avoid the 6 most common integration pitfalls.
- **[Language Guides](https://bluewhale.mintlify.app/docs/guides/go-deposit-routing)**: Specialized guides for Go, TypeScript, and Flutter.
- **[React UI Guide](https://bluewhale.mintlify.app/docs/guides/react-address-input)**: Drop-in address input components for React apps.

## Packages

| Platform           | Package               | Install                                                              |
| ------------------ | --------------------- | -------------------------------------------------------------------- |
| **TypeScript**     | `@redishfish/bluewhale-core` | `npm install @redishfish/bluewhale-core`                                    |
| **React UI**       | `@redishfish/bluewhale` | `npm install @redishfish/bluewhale`                                  |
| **Go**             | `core-go`             | `go get github.com/REDISHFISH/BLUEWHALE/packages/core-go` |
| **Dart / Flutter** | `bluewhale_core` | `dart pub add bluewhale_core`                                   |
| **React (UI)**     | `@redishfish/bluewhale` | `npm install @redishfish/bluewhale`                                |

### UI Component Styling

The `@redishfish/bluewhale` React package exposes stable BEM class names (e.g. `bw-address-input`, `bw-type-badge`, `bw-warning-item`) so you can override styles with plain CSS, Tailwind, or any CSS-in-JS solution. Every component also accepts `className` and `style` props for direct overrides. See the [packages/bluewhale README](packages/bluewhale/README.md) for the full class reference and dark mode example.

## Quick Example

Extract canonical routing information from any address type (G, M, or C) with zero-throw safety.

```typescript
import { extractRouting } from "@redishfish/bluewhale-core";

// Handles M-addresses, G-addresses with memos, and C-addresses
const result = extractRouting({
  address:
    "MA7QYNF7SOWQ3GLR2BGMZEHXAVIRZA4KVWLT7AV7Y6S33Z6S3CHBAAAAAAAAAAAAABQD",
});

console.log(result.address); // "GA7Q..."
console.log(result.routingId); // "123"
```

## React UI Components

`@redishfish/bluewhale` ships ready-made React components for wallet and exchange address forms: an address input with a live G/M/C type badge, a memo field that only appears when a memo is meaningful, and inline warnings (e.g. for contract addresses).

```bash
npm install @redishfish/bluewhale react
```

```tsx
import { AddressInput } from "@redishfish/bluewhale";

export function WithdrawForm() {
  return (
    <form>
      <label>Destination</label>
      {/* Detects G/M/C addresses, shows a memo field for G-addresses,
          and warns when a contract (C) address is entered. */}
      <AddressInput />
    </form>
  );
}
```

The building blocks (`TypeBadge`, `MemoField`, `WarningList`) are also exported for custom layouts. See the [React UI Guide](https://bluewhale.mintlify.app/docs/guides/react-address-input) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
