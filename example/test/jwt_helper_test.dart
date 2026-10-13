import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei_example/auth/example_jwt_helper.dart';
import 'package:infobip_mobilemessaging_huawei_example/auth/chat_jwt_helper.dart';
import 'package:infobip_mobilemessaging_huawei_example/setup/safe_display.dart';
import 'support/fake_sdk.dart';

Map<String, dynamic> decodePart(String token, int part) =>
    jsonDecode(
          utf8.decode(
            base64Url.decode(base64Url.normalize(token.split('.')[part])),
          ),
        )
        as Map<String, dynamic>;

void main() {
  final time = DateTime.fromMillisecondsSinceEpoch(1700000000123, isUtc: true);
  String generate({
    String? app,
    String? sub,
    String? kid,
    String? key,
    Duration ttl = const Duration(seconds: 15),
    DateTime? now,
  }) => ExampleJwtHelper.generate(
    applicationCode: app ?? testConfig.applicationCode,
    externalUserId: sub ?? testConfig.externalUserId,
    kid: kid ?? testConfig.jwtKid,
    secretKey: key ?? testConfig.jwtSecretKey,
    ttl: ttl,
    now: now ?? time,
  );

  test('HS256 signature, exact claims/header and UUID v4 JTI', () {
    final token = generate();
    final parts = token.split('.');
    expect(parts, hasLength(3));
    expect(parts.any((p) => p.contains('=')), isFalse);
    expect(decodePart(token, 0), {
      'alg': 'HS256',
      'typ': 'JWT',
      'kid': 'test-kid',
    });
    final payload = decodePart(token, 1);
    expect(payload.keys.toSet(), {
      'typ',
      'jti',
      'sub',
      'iss',
      'iat',
      'exp',
      'infobip-api-key',
    });
    expect(payload['typ'], 'Bearer');
    expect(payload['sub'], testConfig.externalUserId);
    expect(payload['iss'], testConfig.applicationCode);
    expect(payload['infobip-api-key'], testConfig.applicationCode);
    expect(payload['iat'], 1700000000);
    expect(payload['exp'], 1700000015);
    expect(
      payload['jti'],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    // Independently known fixture bytes catch accidental UTF-8 signing of hex.
    expect(
      base64Url.decode(base64Url.normalize(parts[2])),
      Hmac(
        sha256,
        List<int>.generate(32, (i) => i),
      ).convert(utf8.encode('${parts[0]}.${parts[1]}')).bytes,
    );
  });
  test('rejects every required blank value without echoing secrets', () {
    for (final blank in ['', '   ', '\n']) {
      for (final operation in [
        () => generate(app: blank),
        () => generate(sub: blank),
        () => generate(kid: blank),
        () => generate(key: blank),
      ]) {
        expect(operation, throwsFormatException);
      }
    }
    for (final key in ['secret-value-not-hex', 'a' * 63, 'a' * 65, '00']) {
      try {
        generate(key: key);
        fail('Expected validation failure');
      } on FormatException catch (error) {
        expect(error.source, isNull);
        expect(error.toString(), isNot(contains(key)));
      }
    }
    expect(testConfig.toString(), isNot(contains(testConfig.jwtSecretKey)));
    expect(testConfig.toString(), isNot(contains(testConfig.chatSecretKey)));
  });
  test('TTL validation and configurable whole-second lifetime', () {
    for (final ttl in [
      Duration.zero,
      const Duration(seconds: -1),
      const Duration(milliseconds: 1500),
      const Duration(seconds: 301),
    ]) {
      expect(() => generate(ttl: ttl), throwsFormatException);
    }
    final claims = decodePart(generate(ttl: const Duration(seconds: 42)), 1);
    expect(claims['exp'] - claims['iat'], 42);
  });
  test(
    'new generation has a new JTI even in same second; expired token not reused',
    () {
      final first = decodePart(generate(), 1);
      expect(decodePart(generate(), 1)['jti'], isNot(first['jti']));
      final later = decodePart(
        generate(now: time.add(const Duration(seconds: 30))),
        1,
      );
      expect(later['iat'], greaterThan(first['exp'] as int));
      expect(later['jti'], isNot(first['jti']));
    },
  );
  test('Chat uses distinct contract and decodes Base64 key', () {
    final token = ChatJwtHelper.generate(
      widgetId: testConfig.chatWidgetId,
      externalUserId: testConfig.externalUserId,
      keyId: testConfig.chatKeyId,
      secretKey: testConfig.chatSecretKey,
      now: time,
    );
    expect(decodePart(token, 0), {'alg': 'HS256', 'typ': 'JWT'});
    final payload = decodePart(token, 1);
    expect(payload.keys.toSet(), {
      'iat',
      'iss',
      'jti',
      'ski',
      'stp',
      'sub',
      'exp',
    });
    expect(payload['iss'], 'test-widget');
    expect(payload['ski'], 'test-chat-key');
    expect(payload['stp'], 'externalPersonId');
    expect(payload['sub'], 'test-user');
    expect(payload['exp'] - payload['iat'], 60);
    final parts = token.split('.');
    expect(
      base64Url.decode(base64Url.normalize(parts[2])),
      Hmac(
        sha256,
        List<int>.generate(32, (i) => i),
      ).convert(utf8.encode('${parts[0]}.${parts[1]}')).bytes,
    );
    try {
      ChatJwtHelper.decodeKey('private-secret-invalid-base64');
      fail('Expected error');
    } on FormatException catch (error) {
      expect(error.source, isNull);
      expect(
        error.toString(),
        isNot(contains('private-secret-invalid-base64')),
      );
    }
  });
  test(
    'safe error display preserves stable code and discards backend text',
    () {
      final token = generate();
      final message = safeFailure(
        'Fetch Inbox',
        PlatformException(
          code: 'inbox_fetch_failed',
          message: 'Authorization: Bearer $token',
          details: testConfig.jwtSecretKey,
        ),
      );
      expect(message, contains('Fetch Inbox • inbox_fetch_failed'));
      expect(message, isNot(contains(token)));
      expect(message, isNot(contains(testConfig.jwtSecretKey)));
      expect(message, isNot(contains('Authorization')));
      expect(
        safeFailure('Fetch', PlatformException(code: token)),
        isNot(contains(token)),
      );
    },
  );
}
