import 'dart:convert';

import 'example_jwt_helper.dart';

/// DIFFERENT CONTRACT: widget issuer, ski/stp claims and a Base64 widget key.
abstract final class ChatJwtHelper {
  static String generate({
    required String widgetId,
    required String externalUserId,
    required String keyId,
    required String secretKey,
    Duration ttl = const Duration(seconds: 60),
    DateTime? now,
  }) {
    requireValue(widgetId, 'chatWidgetId');
    requireValue(externalUserId, 'externalUserId');
    requireValue(keyId, 'chatKeyId');
    if (externalUserId.trim().length > 100) {
      throw const FormatException(
        'Chat external user ID must be at most 100 characters.',
      );
    }
    if (!validTestTtl(ttl, minimumSeconds: 15)) {
      throw const FormatException(
        'Chat test TTL must be 15 to 300 whole seconds.',
      );
    }
    final key = decodeKey(secretKey);
    final issued = issuedSeconds(ttl, now);
    return signTestJwt(
      header: {'alg': 'HS256', 'typ': 'JWT'},
      payload: {
        'iat': issued,
        'iss': widgetId.trim(),
        'jti': uuidV4(),
        'ski': keyId.trim(),
        'stp': 'externalPersonId',
        'sub': externalUserId.trim(),
        'exp': issued + ttl.inSeconds,
      },
      key: key,
    );
  }

  static List<int> decodeKey(String value) {
    try {
      final bytes = base64.decode(value);
      if (bytes.length < 32 || value.trim().isEmpty) {
        throw const FormatException();
      }
      return bytes;
    } catch (_) {
      // Never propagate the decoder's FormatException.source.
      throw const FormatException(
        'chatSecretKey must be Base64-encoded, at least 32 bytes.',
      );
    }
  }
}
