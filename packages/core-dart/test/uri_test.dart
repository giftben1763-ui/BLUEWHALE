import 'package:bluewhale_core/bluewhale_core.dart';
import 'package:test/test.dart';

void main() {
  const baseG = 'GAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQADRSI';
  const muxedAddress =
      'MAYCUYT553C5LHVE2XPW5GMEJT4BXGM7AHMJWLAPZP53KJO7EIQACABAAAAAAAAAAEVIG';
  const cAddress = 'CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC';

  group('extractRoutingFromUriString — valid QR codes', () {
    test('destination only', () {
      final result =
          extractRoutingFromUriString('web+stellar:pay?destination=$baseG');

      expect(result.isSuccess, isTrue);
      expect(result.params!.destination, baseG);
      expect(result.params!.memo, isNull);
      expect(result.params!.memoType, isNull);
      expect(result.routing!.destinationBaseAccount, baseG);
      expect(result.routing!.source, RoutingSource.none);
      expect(result.routing!.id, isNull);
    });

    test('MEMO_ID routes via memo', () {
      final result = extractRoutingFromUriString(
        'web+stellar:pay?destination=$baseG&memo=123&memo_type=MEMO_ID',
      );

      expect(result.isSuccess, isTrue);
      expect(result.routing!.source, RoutingSource.memo);
      expect(result.routing!.idString, '123');
    });

    test('uint64-max MEMO_ID keeps full precision', () {
      final result = extractRoutingFromUriString(
        'web+stellar:pay?destination=$baseG'
        '&memo=18446744073709551615&memo_type=MEMO_ID',
      );

      expect(result.routing!.idString, '18446744073709551615');
    });

    test('memo_type is case-insensitive', () {
      final result = extractRoutingFromUriString(
        'web+stellar:pay?destination=$baseG&memo=42&memo_type=memo_id',
      );

      expect(result.routing!.idString, '42');
    });

    test('M-address expands to base G and muxed ID', () {
      final result = extractRoutingFromUriString(
        'web+stellar:pay?destination=$muxedAddress',
      );

      expect(result.isSuccess, isTrue);
      expect(result.routing!.destinationBaseAccount, baseG);
      expect(result.routing!.id, BigInt.parse('9007199254740993'));
      expect(result.routing!.source, RoutingSource.muxed);
    });

    test('all optional parameters are decoded', () {
      final result = extractRoutingFromUriString(
        'web+stellar:pay?destination=$baseG'
        '&amount=100.1234567'
        '&asset_code=USDC'
        '&asset_issuer=GAP5LETOV6YIE62YAM56STDANPRDO7ZFDBGSNHJQIYGGKSMOZAHOOS2S'
        '&memo=invoice%23123'
        '&memo_type=MEMO_TEXT'
        '&callback=url%3Ahttps%3A%2F%2Fexample.com%2Fcallback'
        '&msg=Pay%20me%20with%20lumens'
        '&network_passphrase=Test%20SDF%20Network%20%3B%20September%202015'
        '&origin_domain=example.com'
        '&signature=abc%2Bdef%3D',
      );

      expect(result.isSuccess, isTrue);
      final p = result.params!;
      expect(p.amount, '100.1234567');
      expect(p.assetCode, 'USDC');
      expect(p.assetIssuer,
          'GAP5LETOV6YIE62YAM56STDANPRDO7ZFDBGSNHJQIYGGKSMOZAHOOS2S');
      expect(p.memo, 'invoice#123');
      expect(p.memoType, 'MEMO_TEXT');
      expect(p.callback, 'url:https://example.com/callback');
      expect(p.msg, 'Pay me with lumens');
      expect(p.networkPassphrase, 'Test SDF Network ; September 2015');
      expect(p.originDomain, 'example.com');
      expect(p.signature, 'abc+def=');
    });

    test('accepts a pre-parsed Uri', () {
      final result = extractRoutingFromUri(
        Uri.parse('web+stellar:pay?destination=$baseG&memo=7&memo_type=MEMO_ID'),
      );

      expect(result.isSuccess, isTrue);
      expect(result.routing!.idString, '7');
    });

    test('first value wins when a parameter is repeated', () {
      final result = extractRoutingFromUriString(
        'web+stellar:pay?destination=$baseG&destination=$muxedAddress',
      );

      expect(result.params!.destination, baseG);
    });
  });

  group('extractRoutingFromUriString — encoded memos', () {
    test('percent-encoded numeric MEMO_TEXT routes via memo', () {
      final result = extractRoutingFromUriString(
        'web+stellar:pay?destination=$baseG&memo=%31%32%33&memo_type=MEMO_TEXT',
      );

      expect(result.params!.memo, '123');
      expect(result.routing!.source, RoutingSource.memo);
      expect(result.routing!.idString, '123');
    });

    test('percent-encoded non-numeric MEMO_TEXT is unroutable', () {
      final result = extractRoutingFromUriString(
        'web+stellar:pay?destination=$baseG&memo=hello%20world&memo_type=MEMO_TEXT',
      );

      expect(result.params!.memo, 'hello world');
      expect(result.routing!.id, isNull);
      expect(
        result.routing!.warnings.map((w) => w.code),
        contains(WarningCode.memoTextUnroutable),
      );
    });

    test('base64 MEMO_HASH is decoded and reported as unsupported', () {
      final result = extractRoutingFromUriString(
        'web+stellar:pay?destination=$baseG'
        '&memo=AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8%3D&memo_type=MEMO_HASH',
      );

      expect(result.params!.memo, 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=');
      expect(result.routing!.id, isNull);
      expect(
        result.routing!.warnings.map((w) => w.code),
        contains(WarningCode.unsupportedMemoType),
      );
    });
  });

  group('extractRoutingFromUriString — routing warnings', () {
    test('C destination yields INVALID_DESTINATION without throwing', () {
      final result =
          extractRoutingFromUriString('web+stellar:pay?destination=$cAddress');

      expect(result.isSuccess, isTrue);
      expect(result.routing!.source, RoutingSource.none);
      expect(result.routing!.warnings, [RoutingWarning.invalidDestination]);
    });

    test('minSeverityLevel is forwarded to routing', () {
      final result = extractRoutingFromUriString(
        'web+stellar:pay?destination=$muxedAddress&memo=abc&memo_type=MEMO_TEXT',
        minSeverityLevel: WarningSeverity.warn,
      );

      expect(
        result.routing!.warnings.map((w) => w.severity),
        everyElement(isNot('info')),
      );
    });

    test('invalid destination address returns destinationError', () {
      final result =
          extractRoutingFromUriString('web+stellar:pay?destination=NOTANADDRESS');

      expect(result.isSuccess, isTrue);
      expect(result.routing!.destinationError, isNotNull);
    });
  });

  group('extractRoutingFromUriString — malformed URIs', () {
    void expectFailure(String input, UriRoutingErrorCode code) {
      late UriRoutingResult result;
      expect(() => result = extractRoutingFromUriString(input), returnsNormally);
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, code);
      expect(result.routing, isNull);
      expect(result.params, isNull);
    }

    test('empty string', () {
      expectFailure('', UriRoutingErrorCode.invalidUri);
    });

    test('wrong scheme', () {
      expectFailure('https://example.com/pay?destination=$baseG',
          UriRoutingErrorCode.invalidUri);
    });

    test('plain address is not a URI', () {
      expectFailure(baseG, UriRoutingErrorCode.invalidUri);
    });

    test('tx operation is unsupported', () {
      expectFailure('web+stellar:tx?xdr=AAAA', UriRoutingErrorCode.unsupportedOperation);
    });

    test('missing operation is unsupported', () {
      expectFailure('web+stellar:?destination=$baseG',
          UriRoutingErrorCode.unsupportedOperation);
    });

    test('missing destination', () {
      expectFailure('web+stellar:pay?amount=100', UriRoutingErrorCode.missingDestination);
    });

    test('empty destination', () {
      expectFailure('web+stellar:pay?destination=', UriRoutingErrorCode.missingDestination);
    });

    test('whitespace destination', () {
      expectFailure('web+stellar:pay?destination=%20%20',
          UriRoutingErrorCode.missingDestination);
    });

    test('no query string', () {
      expectFailure('web+stellar:pay', UriRoutingErrorCode.missingDestination);
    });

    test('malformed percent-encoding', () {
      expectFailure('web+stellar:pay?destination=$baseG&memo=%zz',
          UriRoutingErrorCode.invalidEncoding);
    });

    test('error messages do not leak URI content', () {
      final result = extractRoutingFromUriString(
        'web+stellar:secret-op?signature=SECRETSIG&memo=PRIVATE',
      );

      expect(result.errorMessage, isNot(contains('SECRETSIG')));
      expect(result.errorMessage, isNot(contains('PRIVATE')));
      expect(result.errorMessage, isNot(contains('secret-op')));
    });
  });
}
