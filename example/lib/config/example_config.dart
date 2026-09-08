/// Controlled SDK testing only. Never ship signing secrets in a production app.
/// Load the ignored JSON file with --dart-define-from-file (see example/README).
final class ExampleConfig {
  const ExampleConfig({
    this.applicationCode = const String.fromEnvironment(
      'INFOBIP_APPLICATION_CODE',
    ),
    this.externalUserId = const String.fromEnvironment(
      'INFOBIP_EXTERNAL_USER_ID',
    ),
    this.jwtKid = const String.fromEnvironment('INFOBIP_JWT_KID'),
    this.jwtSecretKey = const String.fromEnvironment('INFOBIP_JWT_SECRET_KEY'),
    this.jwtTtl = const Duration(
      seconds: int.fromEnvironment('INFOBIP_JWT_TTL_SECONDS', defaultValue: 15),
    ),
    this.rtcCallsConfigurationId = const String.fromEnvironment(
      'INFOBIP_RTC_CALLS_CONFIGURATION_ID',
    ),
    this.rtcIdentity = const String.fromEnvironment('INFOBIP_RTC_IDENTITY'),
    this.chatAuth = const String.fromEnvironment('INFOBIP_CHAT_AUTH'),
    this.chatWidgetId = const String.fromEnvironment('INFOBIP_CHAT_WIDGET_ID'),
    this.chatKeyId = const String.fromEnvironment('INFOBIP_CHAT_KEY_ID'),
    this.chatSecretKey = const String.fromEnvironment(
      'INFOBIP_CHAT_SECRET_KEY',
    ),
    this.chatJwtTtl = const Duration(
      seconds: int.fromEnvironment(
        'INFOBIP_CHAT_JWT_TTL_SECONDS',
        defaultValue: 60,
      ),
    ),
  });

  final String applicationCode;
  final String externalUserId;
  final String jwtKid;

  /// Hex-encoded Mobile Messaging key, decoded before HMAC signing.
  final String jwtSecretKey;
  final Duration jwtTtl;
  final String rtcCallsConfigurationId;
  final String rtcIdentity;

  /// Explicitly choose 'installation' or 'jwt' to match the Portal widget.
  final String chatAuth;
  final String chatWidgetId;
  final String chatKeyId;

  /// Base64-encoded Live Chat widget key, separate from Mobile Messaging.
  final String chatSecretKey;
  final Duration chatJwtTtl;

  @override
  String toString() => 'ExampleConfig(values hidden)';
}
