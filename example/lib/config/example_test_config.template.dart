/// Controlled real-device testing only. Never ship signing secrets in production.
/// Enter DECRYPTED test values manually; no decryption is performed.
abstract final class ExampleTestConfig {
  // ==========================================
  // 1. INFOBIP APPLICATION
  // ==========================================
  // Backend ApplicationCode -> INFOBIP_APPLICATION_CODE -> this SDK input.
  static const String infobipApplicationCode = '';
  // NOT USED: AppKey -> INFOBIP_APP_KEY, InfobipApplicationId ->
  // INFOBIP_APPLICATION_ID, InfobipBaseUrl -> INFOBIP_BASE_URL.
  // These have no corresponding initialize parameter here. AppKey is NOT a JWT key.

  // ==========================================
  // 2. MOBILE MESSAGING JWT
  // ==========================================
  // Supply an unexpired test JWT OR fill the hex signing-key fields.
  // A supplied JWT cannot be renewed locally; replace it when expired.
  static const String jwtToken = '';
  static const String jwtKid = '';
  static const String jwtSecretKey = '';
  static const int jwtTtlSeconds = 60;

  // ==========================================
  // 3. CHAT AUTHENTICATION (separate widget contract)
  // ==========================================
  static const String chatAuthMode = 'installation'; // installation or jwt
  static const String chatJwtToken = '';
  static const String chatWidgetId = '';
  static const String chatKeyId = '';
  static const String chatSecretKey = ''; // Base64 widget key, NOT MM hex key
  static const int chatJwtTtlSeconds = 60;
  static const String chatMessage = '';
  static const String chatContextualData = ''; // Test-only opaque string
  static const String chatTheme = ''; // Existing Portal widget theme

  // ==========================================
  // 4. TEST USER
  // ==========================================
  static const String externalUserId = '';
  static const String firstName = 'Test';
  static const String lastName = 'User';
  static const String email = '';
  static const String phoneNumber = '';

  // ==========================================
  // 5. INBOX
  // ==========================================
  static const String inboxTopic = '';
  static const int inboxLimit = 20;
  static const String invalidExternalUserId = ''; // Negative test only

  // ==========================================
  // 6. PUSH NOTIFICATIONS (match flags; payloads stay redacted)
  // ==========================================
  static const String expectedNotificationTitle = '';
  static const String expectedNotificationBody = '';
  static const String expectedDeepLink = '';

  // ==========================================
  // 7. OUTGOING HUAWEI RTC / WEBRTC
  // ==========================================
  static const String rtcCallsConfigurationId = ''; // NOT RTC push config ID
  static const String rtcIdentity = ''; // Empty uses registered installation ID
  static const bool enableAudioTesting = true;
  static const bool enableVideoTesting = true;
  // NOT USED: rtcTestCallee. The Calls configuration routes the application call.

  // ==========================================
  // 8. HUAWEI DEVICE TESTING / INSTALLATION
  // ==========================================
  static const String environmentName = 'UAT';
  static const bool installationPrimary = false;
  static const bool installationPushEnabled = true;
  static const Map<String, dynamic> installationAttributes =
      <String, dynamic>{};
  // Huawei AppGallery App ID is DIFFERENT from Infobip Application Code/ID.
  // Enter Huawei host values in android/app/agconnect-services.json, not here.
}
