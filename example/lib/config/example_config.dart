/// Controlled SDK testing only. Never ship signing secrets in a production app.
/// Values are loaded from an optional private JSON asset; defaults compile cleanly.
final class ExampleConfig {
  const ExampleConfig({
    this.applicationCode = '',
    this.externalUserId = '',
    this.jwtKid = '',
    this.jwtSecretKey = '',
    this.jwtTtl = const Duration(seconds: 60),
    this.rtcCallsConfigurationId = '',
    this.rtcIdentity = '',
    this.chatAuth = '',
    this.chatWidgetId = '',
    this.chatKeyId = '',
    this.chatSecretKey = '',
    this.chatJwtTtl = const Duration(seconds: 60),
    this.jwtToken = '',
    this.chatJwtToken = '',
    this.firstName = 'Test',
    this.lastName = 'User',
    this.email = '',
    this.phoneNumber = '',
    this.inboxTopic = '',
    this.inboxLimit = 20,
    this.expectedNotificationTitle = '',
    this.expectedNotificationBody = '',
    this.expectedDeepLink = '',
    this.environmentName = 'UAT',
    this.enableAudioTesting = true,
    this.enableVideoTesting = true,
    this.installationPrimary = false,
    this.installationPushEnabled = true,
    this.installationAttributes = const <String, dynamic>{},
    this.invalidExternalUserId = '',
    this.chatMessage = '',
    this.chatContextualData = '',
    this.chatTheme = '',
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

  final String jwtToken;

  final String chatJwtToken;

  final String firstName;

  final String lastName;

  final String email;

  final String phoneNumber;

  final String inboxTopic;

  final int inboxLimit;

  final String expectedNotificationTitle;

  final String expectedNotificationBody;

  final String expectedDeepLink;

  final String environmentName;

  final bool enableAudioTesting;

  final bool enableVideoTesting;

  final bool installationPrimary;

  final bool installationPushEnabled;

  final Map<String, dynamic> installationAttributes;

  final String invalidExternalUserId;

  final String chatMessage;

  final String chatContextualData;

  final String chatTheme;

  @override
  String toString() => 'ExampleConfig(values hidden)';
}
