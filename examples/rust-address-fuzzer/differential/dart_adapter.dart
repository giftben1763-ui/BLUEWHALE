// core-dart side of the differential address harness
// (scripts/differential-fuzz.js).
//
// Reads newline-delimited JSON strings from stdin, runs `detect` and `parse`
// on each, and writes one JSON outcome per line to stdout in the shared
// adapter format. Run with core-dart's package config, e.g.:
//
//   dart --packages=packages/core-dart/.dart_tool/package_config.json \
//     examples/rust-address-fuzzer/differential/dart_adapter.dart
import 'dart:convert';
import 'dart:io';

import 'package:bluewhale_core/bluewhale_core.dart';

String? kindName(AddressKind? kind) => kind?.name.toUpperCase();

Map<String, Object?> run(String input) {
  String? detected;
  try {
    detected = kindName(detect(input));
  } catch (_) {
    detected = null;
  }

  final parseOutcome = <String, Object?>{
    'ok': false,
    'kind': null,
    'address': null,
    'baseG': null,
    'muxedId': null,
    'error': null,
  };

  try {
    final parsed = parse(input);
    if (parsed.kind == null) {
      parseOutcome['error'] = parsed.error?.code ?? 'UNKNOWN';
    } else {
      parseOutcome['ok'] = true;
      parseOutcome['kind'] = kindName(parsed.kind);
      parseOutcome['address'] = parsed.address;
      if (parsed.kind == AddressKind.m) {
        final decoded = MuxedDecoder.decodeMuxedString(parsed.address);
        parseOutcome['baseG'] = decoded.baseG;
        parseOutcome['muxedId'] = decoded.id.toString();
      }
    }
  } catch (e) {
    parseOutcome['ok'] = false;
    parseOutcome['kind'] = null;
    parseOutcome['address'] = null;
    parseOutcome['baseG'] = null;
    parseOutcome['muxedId'] = null;
    parseOutcome['error'] = 'EXCEPTION';
  }

  return {'detect': detected, 'parse': parseOutcome};
}

Future<void> main() async {
  final out = StringBuffer();
  await for (final line in stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    if (line.isEmpty) continue;
    final input = jsonDecode(line) as String;
    out.writeln(jsonEncode(run(input)));
  }
  stdout.write(out.toString());
  await stdout.flush();
}
