// Address parsing throughput for G and M addresses.
//
// Run the same file on each runtime and compare the ops/s columns:
//
//   dart run benchmark/address_benchmark.dart                  # VM (JIT)
//   dart compile exe benchmark/address_benchmark.dart -o build/bench
//   ./build/bench                                              # VM (AOT)
//   dart compile js -O2 benchmark/address_benchmark.dart -o build/bench.js
//   node build/bench.js                                        # JavaScript
//
// See benchmark/README.md for recorded results.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:bluewhale_core/bluewhale_core.dart';
// Fixture generation only; not part of the measured code paths.
import 'package:bluewhale_core/src/util/strkey.dart';

/// Number of distinct addresses per fixture set. Cycling through a set
/// (rather than parsing one constant) keeps the JIT and dart2js from
/// specializing on a single input.
const _fixtureCount = 256;

/// Muxed IDs spanning the ranges that exercise different code paths:
/// small, around the JS-safe ceiling, and up to uint64 max.
final _idSamples = <BigInt>[
  BigInt.zero,
  BigInt.one,
  BigInt.from(123456789),
  BigInt.parse('9007199254740991'), // 2^53 - 1
  BigInt.parse('9007199254740993'), // 2^53 + 1
  BigInt.parse('9223372036854775807'), // 2^63 - 1
  BigInt.parse('18446744073709551615'), // 2^64 - 1
];

List<String> _gFixtures(Random random) => List.generate(_fixtureCount, (_) {
      final payload = Uint8List(33)..[0] = 0x30;
      for (var i = 1; i < payload.length; i++) {
        payload[i] = random.nextInt(256);
      }
      final crc = StrKeyUtil.calculateChecksum(payload);
      return StrKeyUtil.encodeBase32(
          Uint8List.fromList([...payload, crc & 0xFF, (crc >> 8) & 0xFF]));
    });

List<String> _mFixtures(List<String> gs) => List.generate(
      _fixtureCount,
      (i) => MuxedAddress.encode(
        baseG: gs[i],
        id: _idSamples[i % _idSamples.length],
      ),
    );

/// Parses every fixture once per [run]; the score is converted to ops/s by
/// dividing by [_fixtureCount].
class _AddressBenchmark extends BenchmarkBase {
  _AddressBenchmark(super.name, this.inputs, this.op);

  final List<String> inputs;
  final Object? Function(String) op;

  /// Keeps results observable so dart2js cannot drop the parse calls.
  int sink = 0;

  @override
  void run() {
    for (final input in inputs) {
      if (op(input) != null) sink++;
    }
  }

  @override
  void exercise() => run();

  double opsPerSecond() => inputs.length * 1e6 / measure();
}

String get _runtimeLabel {
  if (isWebJsRuntime) return 'JavaScript (dart2js)';
  const aot = bool.fromEnvironment('dart.vm.product');
  return aot ? 'Dart VM (AOT)' : 'Dart VM (JIT)';
}

void main() {
  final random = Random(42);
  final gs = _gFixtures(random);
  final ms = _mFixtures(gs);

  // Sanity-check the fixtures before timing anything.
  if (!gs.every((g) => detect(g) == AddressKind.g) ||
      !ms.every((m) => detect(m) == AddressKind.m)) {
    throw StateError('Benchmark fixtures failed to validate.');
  }

  final benchmarks = [
    _AddressBenchmark('detect(G)', gs, detect),
    _AddressBenchmark('detect(M)', ms, detect),
    _AddressBenchmark('StellarAddress.parse(G)', gs, StellarAddress.parse),
    _AddressBenchmark('StellarAddress.parse(M)', ms, StellarAddress.parse),
    _AddressBenchmark('MuxedAddress.decode(M)', ms, MuxedAddress.decode),
  ];

  print('Runtime: $_runtimeLabel');
  print('| Benchmark | ops/s | µs/op |');
  print('|---|---:|---:|');
  for (final b in benchmarks) {
    final ops = b.opsPerSecond();
    print('| ${b.name} | ${ops.round()} | ${(1e6 / ops).toStringAsFixed(2)} |');
  }
}
