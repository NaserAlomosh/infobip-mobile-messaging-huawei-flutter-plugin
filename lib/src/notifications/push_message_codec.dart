import 'message.dart';

abstract final class PushMessageCodec {
  static Message decode(Map<Object?, Object?> map) => Message(
    messageId: _string(map['messageId'], 'messageId'),
    title: _string(map['title'], 'title'),
    body: _string(map['body'], 'body'),
    sound: _string(map['sound'], 'sound'),
    vibrate: _bool(map['vibrate'], 'vibrate'),
    icon: _string(map['icon'], 'icon'),
    silent: _bool(map['silent'] ?? map['isSilent'], 'silent'),
    category: _string(map['category'], 'category'),
    customPayload: _map(map['customPayload'], 'customPayload'),
    internalData: _string(map['internalData'], 'internalData'),
    receivedTimestamp: _number(map['receivedTimestamp'], 'receivedTimestamp'),
    seenDate: _number(map['seenDate'], 'seenDate'),
    contentUrl: _string(map['contentUrl'], 'contentUrl'),
    seen: _bool(map['seen'], 'seen'),
    originalPayload: _map(map['originalPayload'], 'originalPayload'),
    browserUrl: _string(map['browserUrl'], 'browserUrl'),
    deeplink: _string(map['deeplink'] ?? map['deepLink'], 'deeplink'),
    webViewUrl: _string(map['webViewUrl'], 'webViewUrl'),
    inAppOpenTitle: _string(map['inAppOpenTitle'], 'inAppOpenTitle'),
    inAppDismissTitle: _string(map['inAppDismissTitle'], 'inAppDismissTitle'),
    chat: _bool(map['chat'], 'chat'),
    topic: _string(map['topic'], 'topic'),
  );

  static String? _string(Object? value, String name) {
    if (value == null || value is String) return value as String?;
    throw FormatException('$name must be a string');
  }

  static bool? _bool(Object? value, String name) {
    if (value == null || value is bool) return value as bool?;
    throw FormatException('$name must be a boolean');
  }

  static num? _number(Object? value, String name) {
    if (value == null || value is num) return value as num?;
    throw FormatException('$name must be numeric milliseconds');
  }

  static Map<String, dynamic>? _map(Object? value, String name) {
    if (value == null) return null;
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException('$name must be a string-keyed map');
    }
    return Map.unmodifiable(
      value.map((key, item) => MapEntry(key as String, _value(item))),
    );
  }

  static Object? _value(Object? value) => switch (value) {
    null || String() || bool() || int() || double() => value,
    List() => List.unmodifiable(value.map(_value)),
    Map() when value.keys.every((key) => key is String) => Map.unmodifiable(
      value.map((key, item) => MapEntry(key as String, _value(item))),
    ),
    _ => throw const FormatException('Payload contains an invalid value'),
  };
}
