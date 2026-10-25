import 'dart:convert';
import 'package:flutter/services.dart';
import 'example_config.dart';

const localConfigAsset = 'config/example_config.local.json';

/// Missing private assets use safe defaults; invalid content never leaks values.
Future<ExampleConfig> loadExampleConfig({AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  final manifest = await AssetManifest.loadFromAssetBundle(assets);
  if (!manifest.listAssets().contains(localConfigAsset)) {
    return const ExampleConfig();
  }
  try {
    return parseExampleConfig(await assets.loadString(localConfigAsset));
  } catch (_) {
    throw const FormatException(
      'Invalid local configuration. Check JSON keys and value types.',
    );
  }
}

ExampleConfig parseExampleConfig(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected object');
  }
  const keys = <String>{
    'infobipApplicationCode',
    'jwtToken',
    'jwtKid',
    'jwtSecretKey',
    'jwtTtlSeconds',
    'chatAuthMode',
    'chatJwtToken',
    'chatWidgetId',
    'chatKeyId',
    'chatSecretKey',
    'chatJwtTtlSeconds',
    'chatMessage',
    'chatContextualData',
    'chatTheme',
    'externalUserId',
    'firstName',
    'lastName',
    'email',
    'phoneNumber',
    'inboxTopic',
    'inboxLimit',
    'invalidExternalUserId',
    'expectedNotificationTitle',
    'expectedNotificationBody',
    'expectedDeepLink',
    'rtcCallsConfigurationId',
    'rtcIdentity',
    'enableAudioTesting',
    'enableVideoTesting',
    'environmentName',
    'installationPrimary',
    'installationPushEnabled',
    'installationAttributes',
  };
  if (decoded.keys.any((key) => !keys.contains(key))) {
    throw const FormatException('Unknown configuration key');
  }
  const defaults = ExampleConfig();
  T value<T>(String key, T fallback) {
    if (!decoded.containsKey(key)) return fallback;
    final item = decoded[key];
    if (item is! T) {
      throw const FormatException('Invalid configuration value type');
    }
    return item;
  }

  return ExampleConfig(
    applicationCode: value<String>(
      'infobipApplicationCode',
      defaults.applicationCode,
    ),
    externalUserId: value<String>('externalUserId', defaults.externalUserId),
    jwtKid: value<String>('jwtKid', defaults.jwtKid),
    jwtSecretKey: value<String>('jwtSecretKey', defaults.jwtSecretKey),
    jwtTtl: Duration(
      seconds: value<int>('jwtTtlSeconds', defaults.jwtTtl.inSeconds),
    ),
    rtcCallsConfigurationId: value<String>(
      'rtcCallsConfigurationId',
      defaults.rtcCallsConfigurationId,
    ),
    rtcIdentity: value<String>('rtcIdentity', defaults.rtcIdentity),
    chatAuth: value<String>('chatAuthMode', defaults.chatAuth),
    chatWidgetId: value<String>('chatWidgetId', defaults.chatWidgetId),
    chatKeyId: value<String>('chatKeyId', defaults.chatKeyId),
    chatSecretKey: value<String>('chatSecretKey', defaults.chatSecretKey),
    chatJwtTtl: Duration(
      seconds: value<int>('chatJwtTtlSeconds', defaults.chatJwtTtl.inSeconds),
    ),
    jwtToken: value<String>('jwtToken', defaults.jwtToken),
    chatJwtToken: value<String>('chatJwtToken', defaults.chatJwtToken),
    firstName: value<String>('firstName', defaults.firstName),
    lastName: value<String>('lastName', defaults.lastName),
    email: value<String>('email', defaults.email),
    phoneNumber: value<String>('phoneNumber', defaults.phoneNumber),
    inboxTopic: value<String>('inboxTopic', defaults.inboxTopic),
    inboxLimit: value<int>('inboxLimit', defaults.inboxLimit),
    expectedNotificationTitle: value<String>(
      'expectedNotificationTitle',
      defaults.expectedNotificationTitle,
    ),
    expectedNotificationBody: value<String>(
      'expectedNotificationBody',
      defaults.expectedNotificationBody,
    ),
    expectedDeepLink: value<String>(
      'expectedDeepLink',
      defaults.expectedDeepLink,
    ),
    environmentName: value<String>('environmentName', defaults.environmentName),
    enableAudioTesting: value<bool>(
      'enableAudioTesting',
      defaults.enableAudioTesting,
    ),
    enableVideoTesting: value<bool>(
      'enableVideoTesting',
      defaults.enableVideoTesting,
    ),
    installationPrimary: value<bool>(
      'installationPrimary',
      defaults.installationPrimary,
    ),
    installationPushEnabled: value<bool>(
      'installationPushEnabled',
      defaults.installationPushEnabled,
    ),
    installationAttributes: value<Map<String, dynamic>>(
      'installationAttributes',
      defaults.installationAttributes,
    ),
    invalidExternalUserId: value<String>(
      'invalidExternalUserId',
      defaults.invalidExternalUserId,
    ),
    chatMessage: value<String>('chatMessage', defaults.chatMessage),
    chatContextualData: value<String>(
      'chatContextualData',
      defaults.chatContextualData,
    ),
    chatTheme: value<String>('chatTheme', defaults.chatTheme),
  );
}
