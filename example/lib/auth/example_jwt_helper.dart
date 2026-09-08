import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Local test signing only. No cache, logging, storage, or public plugin export.
abstract final class ExampleJwtHelper {
  static String generate({
    required String applicationCode,
    required String externalUserId,
    required String kid,
    required String secretKey,
    Duration ttl = const Duration(seconds: 15),
    DateTime? now,
  }) {
    requireValue(applicationCode, 'applicationCode');
    requireValue(externalUserId, 'externalUserId');
    requireValue(kid, 'kid');
    final key = decodeHexKey(secretKey);
    final issued = issuedSeconds(ttl, now);
    return signTestJwt(
      header: {'alg': 'HS256', 'typ': 'JWT', 'kid': kid.trim()},
      payload: {
        'typ': 'Bearer',
        'jti': uuidV4(),
        'sub': externalUserId.trim(),
        'iss': applicationCode.trim(),
        'iat': issued,
        'exp': issued + ttl.inSeconds,
        'infobip-api-key': applicationCode.trim(),
      },
      key: key,
    );
  }

  static List<int> decodeHexKey(String value) {
    // Validate before parsing so FormatException never retains a secret source.
    if (!RegExp(r'^[0-9a-fA-F]{64,}$').hasMatch(value) || value.length.isOdd) {
      throw const FormatException(
        'secretKey must be hex-encoded, at least 32 bytes.',
      );
    }
    return [
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16),
    ];
  }
}

void requireValue(String value, String field) {
  if (value.trim().isEmpty) throw FormatException('$field must not be blank.');
}

bool validTestTtl(Duration ttl, {int minimumSeconds = 1}) =>
    ttl.inSeconds >= minimumSeconds &&
    ttl.inSeconds <= 300 &&
    ttl.inMicroseconds == ttl.inSeconds * Duration.microsecondsPerSecond;

int issuedSeconds(Duration ttl, DateTime? now) {
  if (!validTestTtl(ttl)) {
    throw const FormatException(
      'Test TTL must be a whole number of seconds from 1 to 300.',
    );
  }
  return (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
}

String uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String signTestJwt({
  required Map<String, Object> header,
  required Map<String, Object> payload,
  required List<int> key,
}) {
  String encode(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
  final input =
      '${encode(utf8.encode(jsonEncode(header)))}.${encode(utf8.encode(jsonEncode(payload)))}';
  return '$input.${encode(Hmac(sha256, key).convert(utf8.encode(input)).bytes)}';
}
