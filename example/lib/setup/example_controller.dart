import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

import '../auth/chat_jwt_helper.dart';
import '../auth/example_jwt_helper.dart';
import '../config/example_config.dart';
import '../platform/example_permissions.dart';
import 'feature_readiness.dart';
import 'safe_display.dart';
import '../testing/test_session.dart';

class JwtTestMetadata {
  const JwtTestMetadata(this.subject, this.issued, this.expires);
  final String subject;
  final DateTime issued;
  final DateTime expires;
  Duration get ttl => expires.difference(issued);
  @override
  String toString() => 'JwtTestMetadata(token not retained)';
}

/// One example-scoped source of truth. No JWT is stored in this controller.
class ExampleController extends ChangeNotifier {
  ExampleController({this.config = const ExampleConfig()});
  final ExampleConfig config;
  final TestSession session = TestSession();
  bool _observing = false;

  void startObserving() {
    if (_observing) return;
    _observing = true;
    _listen();
    unawaited(session.restore());
  }

  bool _initialized = false;
  bool _busy = false;
  bool _disposed = false;
  Installation? _installation;
  UserData? _user;
  bool? _chatAvailable;
  ExamplePermissions _permissions = const ExamplePermissions();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  String? result;
  String? operationError;
  String? operationBlocker;
  JwtTestMetadata? jwtMetadata;
  InboxAuth _inboxAuth = InboxAuth.applicationCode;

  bool _chatPrepared = false;
  String get chatAuthLabel => ['installation', 'jwt'].contains(config.chatAuth)
      ? config.chatAuth
      : 'unconfigured';
  bool get initialized => _initialized;
  bool get busy => _busy;
  Installation? get installation => _installation;
  UserData? get user => _user;
  ExamplePermissions get permissions => _permissions;
  InboxAuth get inboxAuth => _inboxAuth;
  bool get applicationCodeConfigured =>
      config.applicationCode.trim().isNotEmpty;
  bool get externalUserIdConfigured => config.externalUserId.trim().isNotEmpty;
  bool get installationAvailable => _installation != null;
  bool get personalized =>
      externalUserIdConfigured &&
      _user?.externalUserId == config.externalUserId.trim();
  bool get pushEnabled => _installation?.isPushRegistrationEnabled == true;
  bool get registered =>
      _installation?.pushRegistrationId?.trim().isNotEmpty == true;
  bool get canLeaveApplicationSetup => initialized && !busy;
  // Let testers inspect individual missing prerequisites, including registration.
  bool get canOpenFeatures => initialized && !busy;

  List<FeatureRequirement> get jwtRequirements =>
      config.jwtToken.trim().isNotEmpty
      ? [
          FeatureRequirement('applicationCode', applicationCodeConfigured),
          FeatureRequirement('externalUserId', externalUserIdConfigured),
          FeatureRequirement(
            'Supplied JWT unexpired and matching subject',
            validSuppliedJwt(config.jwtToken),
          ),
        ]
      : [
          FeatureRequirement('applicationCode', applicationCodeConfigured),
          FeatureRequirement('externalUserId', externalUserIdConfigured),
          FeatureRequirement('kid', config.jwtKid.trim().isNotEmpty),
          FeatureRequirement(
            'secretKey (valid hex, at least 32 bytes)',
            _validMmKey,
          ),
          FeatureRequirement(
            'JWT TTL (1–300 whole seconds)',
            validTestTtl(config.jwtTtl),
          ),
        ];
  bool get _validMmKey {
    try {
      ExampleJwtHelper.decodeHexKey(config.jwtSecretKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool get jwtConfigReady => jwtRequirements.every((r) => r.satisfied);
  bool get _validChatKey {
    try {
      ChatJwtHelper.decodeKey(config.chatSecretKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  List<FeatureRequirement> get summary => [
    FeatureRequirement('SDK Initialized', initialized),
    FeatureRequirement('Installation available', installationAvailable),
    FeatureRequirement('Push registration enabled', pushEnabled),
    FeatureRequirement('External User ID configured', externalUserIdConfigured),
    FeatureRequirement('User personalized', personalized),
    FeatureRequirement('JWT signing config ready (optional)', jwtConfigReady),
  ];

  FeatureReadiness readiness(ExampleFeature feature, {InboxAuth? auth}) {
    final sdk = FeatureRequirement('SDK initialized', initialized);
    final install = FeatureRequirement(
      'Installation available',
      installationAvailable,
    );
    final identity = FeatureRequirement(
      'External User ID configured',
      externalUserIdConfigured,
    );
    final person = FeatureRequirement(
      'User personalized as configured external user',
      personalized,
    );
    final requirements = <FeatureRequirement>[sdk];
    switch (feature) {
      case ExampleFeature.push:
        requirements.addAll([
          install,
          FeatureRequirement('Push registration enabled', pushEnabled),
          FeatureRequirement('Push registration ID available', registered),
          FeatureRequirement(
            'HMS push token available',
            _installation?.pushServiceToken?.trim().isNotEmpty == true,
          ),
          FeatureRequirement(
            'Notifications enabled in Android',
            _installation?.notificationsEnabled == true &&
                _permissions.notifications == true,
          ),
          person,
          identity,
        ]);
      case ExampleFeature.inbox:
        requirements.add(identity);
        if ((auth ?? inboxAuth) == InboxAuth.jwt) {
          requirements.addAll(jwtRequirements);
        }
      case ExampleFeature.chat:
        requirements.addAll([
          FeatureRequirement('Native Chat available', _chatAvailable == true),
          install,
          FeatureRequirement('Push registration ID available', registered),
          FeatureRequirement(
            'Chat auth configured to match Portal (installation or jwt)',
            ['installation', 'jwt'].contains(config.chatAuth),
          ),
        ]);
        if (config.chatAuth == 'jwt') {
          requirements.addAll([
            FeatureRequirement(
              'Chat subject at most 100 characters',
              config.externalUserId.trim().length <= 100,
            ),
            identity,
            person,
            if (config.chatJwtToken.isEmpty) ...[
              FeatureRequirement(
                'Chat widget ID',
                config.chatWidgetId.trim().isNotEmpty,
              ),
              FeatureRequirement(
                'Chat key ID',
                config.chatKeyId.trim().isNotEmpty,
              ),
              FeatureRequirement(
                'Separate Chat secret (valid Base64, at least 32 bytes)',
                _validChatKey,
              ),
              FeatureRequirement(
                'Chat subject at most 100 characters',
                config.externalUserId.trim().length <= 100,
              ),
              FeatureRequirement(
                'Chat TTL (15–300 whole seconds)',
                validTestTtl(config.chatJwtTtl, minimumSeconds: 15),
              ),
            ] else
              FeatureRequirement(
                'Supplied Chat JWT unexpired and matching subject',
                validSuppliedJwt(config.chatJwtToken, chat: true),
              ),
          ]);
        }
      case ExampleFeature.rtcAudio:
      case ExampleFeature.rtcVideo:
        requirements.add(
          FeatureRequirement(
            'Testing enabled in local configuration',
            feature == ExampleFeature.rtcVideo
                ? config.enableVideoTesting
                : config.enableAudioTesting,
          ),
        );
        requirements.addAll([
          FeatureRequirement(
            'rtcCallsConfigurationId configured',
            config.rtcCallsConfigurationId.trim().isNotEmpty,
          ),
          FeatureRequirement(
            'RTC identity or registered installation ID',
            config.rtcIdentity.trim().isNotEmpty || registered,
          ),
          FeatureRequirement(
            'Microphone permission',
            _permissions.microphone == true,
          ),
          FeatureRequirement(
            'Nearby devices permission (Android 12+)',
            _permissions.nearbyDevices == true,
          ),
          if (feature == ExampleFeature.rtcVideo)
            FeatureRequirement(
              'Camera permission',
              _permissions.camera == true,
            ),
        ]);
      case ExampleFeature.user:
      case ExampleFeature.installation:
        break;
    }
    return FeatureReadiness(feature.title, requirements);
  }

  String? testBlocker(DeviceTest test) {
    if (test.action == 'initialize') {
      return applicationCodeConfigured
          ? null
          : 'Fill infobipApplicationCode in the local Dart configuration.';
    }
    if (!initialized) return 'Initialize SDK in Setup first.';
    if ((test.category == 'USER' || test.category == 'INBOX') &&
        !externalUserIdConfigured) {
      return 'Fill externalUserId in the local Dart configuration.';
    }
    if (test.category == 'SDK' && session.huaweiConfigured != true) {
      return 'Verify the real Huawei host App ID and agconnect-services.json.';
    }
    if (test.action == 'personalize' || test.action == 'saveUser') {
      if (!externalUserIdConfigured) {
        return 'Fill externalUserId in the local Dart configuration.';
      }
    }
    if (test.action == 'jwt') {
      return jwtConfigReady
          ? null
          : jwtRequirements
                .where((r) => !r.satisfied)
                .map((r) => r.title)
                .join('; ');
    }
    if (test.action == 'chat') {
      if (test.category == 'AUTH' && config.chatAuth != 'jwt') {
        return 'Set chatAuthMode=jwt for the Chat JWT authentication test; restart/rebuild.';
      }
      final missing = readiness(ExampleFeature.chat).missing;
      return missing.isEmpty ? null : missing.map((r) => r.title).join('; ');
    }
    if (test.category == 'PUSH' && test.action != 'register') {
      final missing = readiness(ExampleFeature.push).missing;
      return missing.isEmpty ? null : missing.map((r) => r.title).join('; ');
    }
    if (test.category == 'INBOX') {
      if (config.inboxLimit <= 0) {
        return 'Set inboxLimit to a positive integer.';
      }
      if (test.action == 'invalidInbox' &&
          config.invalidExternalUserId.trim().isEmpty) {
        return 'Fill invalidExternalUserId for this negative test.';
      }
      final missing = readiness(ExampleFeature.inbox).missing;
      return missing.isEmpty ? null : missing.map((r) => r.title).join('; ');
    }
    if (test.category == 'RTC') {
      final missing =
          readiness(
            test.action == 'rtcVideo'
                ? ExampleFeature.rtcVideo
                : ExampleFeature.rtcAudio,
          ).missing.where(
            (r) =>
                !(test.name == 'Permission denial' &&
                    r.title.toLowerCase().contains('permission')),
          );
      return missing.isEmpty ? null : missing.map((r) => r.title).join('; ');
    }
    return null;
  }

  void selectInboxAuth(InboxAuth value) {
    _inboxAuth = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> run(String operation, Future<void> Function() action) async {
    if (busy) return false;
    session.log('SDK', operation, status: 'RUNNING');
    _busy = true;
    result = null;
    operationError = null;
    operationBlocker = null;
    _notify();
    try {
      await action();
      result ??= '$operation completed; verify device/server evidence.';
      session.log('SDK', operation, status: 'REQUIRES_MANUAL_VERIFICATION');
      return true;
    } catch (error) {
      result = error is ExampleBlocked
          ? 'BLOCKED: ${error.message}'
          : safeFailure(operation, error);
      if (error is ExampleBlocked) {
        operationBlocker = error.message;
      } else {
        operationError = result;
      }
      session.log(
        'ERROR',
        operation,
        status: 'FAIL',
        details: {'error': result},
      );
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> initialize() async {
    if (initialized) return;
    await run('Initialize SDK', () async {
      if (!applicationCodeConfigured) {
        throw const ExampleBlocked(
          'Fill infobipApplicationCode in the local Dart configuration.',
        );
      }
      await InfobipMobileMessagingHuawei.initialize(
        applicationCode: config.applicationCode.trim(),
      );
      _initialized = true;
      startObserving();
    });
    if (initialized) await refresh();
  }

  void _listen() {
    final events = InfobipMobileMessagingHuawei.notifications;
    void installationChanged(Installation value) {
      session.log(
        'INSTALLATION',
        'Installation event',
        details: {
          'registered': value.pushRegistrationId?.isNotEmpty == true,
          'pushEnabled': value.isPushRegistrationEnabled,
        },
      );
      _installation = value;
      _notify();
    }

    void userChanged(UserData value) {
      session.log(
        'USER',
        'User event',
        details: {
          'matchesConfiguredIdentity':
              value.externalUserId == config.externalUserId.trim(),
        },
      );
      _user = value;
      _notify();
    }

    void failed(Object _) {
      session.log('ERROR', 'SDK event stream error', status: 'FAIL');
      result = 'SDK events • operation_failed\nRefresh setup state.';
      _notify();
    }

    _subscriptions.addAll([
      events.onMessageReceived.listen(
        (m) => recordPush('Message received', m),
        onError: failed,
      ),
      events.onNotificationTapped.listen(
        (m) => recordPush('Notification tapped', m),
        onError: failed,
      ),
      events.onNotificationActionTapped.listen(
        (e) => recordPush('Notification action tapped', e.message),
        onError: failed,
      ),
      InfobipMobileMessagingHuawei.chat.onUnreadMessageCounterUpdated.listen(
        (count) =>
            session.log('CHAT', 'Unread count', details: {'count': count}),
        onError: failed,
      ),
      HuaweiRtc.events.listen(
        (e) => session.log(
          'RTC',
          e.type.name,
          details: {
            'sequence': e.sequence,
            'callStatus': e.call?.status.name,
            'type': e.call?.type.name,
            'nativeErrorCode': e.nativeErrorCode,
          },
        ),
        onError: failed,
      ),
      events.onRegistrationUpdated.listen(installationChanged, onError: failed),
      events.onInstallationUpdated.listen(installationChanged, onError: failed),
      events.onUserUpdated.listen(userChanged, onError: failed),
      events.onPersonalized.listen(userChanged, onError: failed),
      events.onDepersonalized.listen((_) {
        _user = null;
        _notify();
      }, onError: failed),
    ]);
  }

  Future<void> _readInstallation() async {
    _installation = null;
    _installation = await InfobipMobileMessagingHuawei.getInstallation();
    _notify();
    _installation = await InfobipMobileMessagingHuawei.fetchInstallation();
  }

  Future<void> _readUser() async {
    _user = null;
    _user = await InfobipMobileMessagingHuawei.getUser();
    _notify();
    _user = await InfobipMobileMessagingHuawei.fetchUser();
  }

  Future<void> refresh() async {
    if (!initialized) return;
    await run('Refresh setup', () async {
      final failures = <String>[];
      for (final step in <(String, Future<void> Function())>[
        ('Refresh Installation', _readInstallation),
        ('Refresh User', _readUser),
        (
          'Check Chat availability',
          () async {
            _chatAvailable = null;
            _chatAvailable = await InfobipMobileMessagingHuawei.chat
                .isChatAvailable();
          },
        ),
        (
          'Check permissions',
          () async {
            _permissions = const ExamplePermissions();
            _permissions = await ExamplePermissions.read();
          },
        ),
      ]) {
        try {
          await step.$2();
        } catch (error) {
          failures.add(safeFailure(step.$1, error));
        }
      }
      if (failures.isNotEmpty) result = failures.join('\n');
    });
  }

  Future<void> refreshInstallation() async {
    await run('Refresh Installation', _readInstallation);
  }

  Future<void> refreshUser() async {
    await run('Refresh User', _readUser);
  }

  Future<bool> registerPush() async {
    if (!initialized) {
      operationBlocker = 'Initialize SDK before registering push.';
      return false;
    }
    return run('Register for remote notifications', () async {
      _permissions = await ExamplePermissions.read(request: 'push');
      await InfobipMobileMessagingHuawei.registerForRemoteNotifications();
      await _readInstallation();
      result =
          'Registration requested. Readiness uses the installation ID, HMS token and permission status; refresh while registration completes.';
    });
  }

  /// Identity changes must not silently invalidate an active RTC/Chat test.
  Future<void> ensureUserMutationAllowed({bool changesIdentity = true}) async {
    if (!initialized) {
      throw const ExampleBlocked(
        'Initialize SDK before changing the test user.',
      );
    }
    if (!externalUserIdConfigured) {
      throw const ExampleBlocked(
        'Fill externalUserId in the local Dart configuration.',
      );
    }
    if (changesIdentity &&
        (_chatPrepared ||
            session.tests.any(
              (t) => t.category == 'RTC' && t.status == TestStatus.RUNNING,
            ))) {
      throw const ExampleBlocked(
        'Finish RTC testing and restart after a prepared Chat session before changing user identity.',
      );
    }
    final active = await HuaweiRtc.getActiveCall();
    if (active != null && active.status != HuaweiRtcCallStatus.finished) {
      throw const ExampleBlocked(
        'Hang up and await finished before changing the test user.',
      );
    }
  }

  Future<UserData> saveConfiguredUser({
    UserData? previous,
    String? firstName,
    String? lastName,
  }) async {
    await ensureUserMutationAllowed(
      changesIdentity: _user?.externalUserId != config.externalUserId.trim(),
    );
    if (previous?.externalUserId != config.externalUserId.trim()) {
      previous = null;
    }
    await InfobipMobileMessagingHuawei.saveUser(
      UserData(
        externalUserId: config.externalUserId.trim(),
        firstName: firstName ?? config.firstName,
        lastName: lastName ?? config.lastName,
        middleName: previous?.middleName,
        gender: previous?.gender,
        birthday: previous?.birthday,
        tags: previous?.tags,
        customAttributes: previous?.customAttributes,
        emails: config.email.trim().isEmpty
            ? previous?.emails
            : [config.email.trim()],
        phones: config.phoneNumber.trim().isEmpty
            ? previous?.phones
            : [config.phoneNumber.trim()],
      ),
    );
    _user = await InfobipMobileMessagingHuawei.fetchUser();
    _notify();
    return _user!;
  }

  Future<bool> personalize({UserAttributes? attributes}) async {
    final succeeded = await run('Personalize User', () async {
      await ensureUserMutationAllowed();
      _user = await InfobipMobileMessagingHuawei.personalize(
        PersonalizeContext(
          userIdentity: UserIdentity(
            externalUserId: config.externalUserId.trim(),
          ),
          userAttributes: attributes,
        ),
      );
      // A callback is not proof of persisted server state.
      _user = await InfobipMobileMessagingHuawei.fetchUser();
    });
    if (succeeded) await refresh();
    return succeeded;
  }

  Future<UserData> depersonalizeUser() async {
    await ensureUserMutationAllowed();
    await InfobipMobileMessagingHuawei.depersonalize();
    _user = await InfobipMobileMessagingHuawei.fetchUser();
    _notify();
    return _user!;
  }

  String generateInboxJwt({DateTime? now}) {
    if (config.jwtToken.trim().isNotEmpty) {
      if (!validSuppliedJwt(config.jwtToken)) {
        throw const FormatException('Invalid supplied JWT');
      }
      return config.jwtToken.trim();
    }
    return ExampleJwtHelper.generate(
      applicationCode: config.applicationCode,
      externalUserId: config.externalUserId,
      kid: config.jwtKid,
      secretKey: config.jwtSecretKey,
      ttl: config.jwtTtl,
      now: now,
    );
  }

  Future<void> testJwt() async {
    await run('Generate/Test JWT', () async {
      // Only metadata survives this operation. The token is never kept in state.
      final token = generateInboxJwt();
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              )
              as Map<String, dynamic>;
      jwtMetadata = JwtTestMetadata(
        claims['sub'] as String,
        DateTime.fromMillisecondsSinceEpoch(
          (claims['iat'] as int) * 1000,
          isUtc: true,
        ),
        DateTime.fromMillisecondsSinceEpoch(
          (claims['exp'] as int) * 1000,
          isUtc: true,
        ),
      );
      result =
          'JWT structure checked locally; signature/backend authorization is tested by fetching Inbox.';
    });
  }

  Future<Inbox> fetchInbox({FilterOptions? options}) async {
    if (!readiness(ExampleFeature.inbox).isReady) {
      throw StateError('Inbox prerequisites missing');
    }
    // Capture the selection for this request. Never store a generated token.
    final auth = inboxAuth;
    if (auth == InboxAuth.applicationCode) {
      await InfobipMobileMessagingHuawei.setJwt(null);
      return InfobipMobileMessagingHuawei.fetchInbox(
        externalUserId: config.externalUserId.trim(),
        options: options,
      );
    }
    return InfobipMobileMessagingHuawei.fetchInbox(
      externalUserId: config.externalUserId.trim(),
      jwt: generateInboxJwt(),
      options: options,
    );
  }

  Future<bool> prepareChat() => run('Configure Chat', () async {
    if (!readiness(ExampleFeature.chat).isReady) {
      throw StateError('Chat prerequisites missing');
    }
    if (config.chatAuth == 'jwt') {
      await InfobipMobileMessagingHuawei.setChatJwtProvider(
        () async {
          if (!personalized) {
            throw StateError('Personalize the configured Chat user first');
          }
          session.log('AUTH', 'Chat JWT provider requested');
          if (config.chatJwtToken.trim().isNotEmpty) {
            if (!validSuppliedJwt(config.chatJwtToken, chat: true)) {
              throw const FormatException('Invalid supplied Chat JWT');
            }
            return config.chatJwtToken.trim();
          }
          return ChatJwtHelper.generate(
            widgetId: config.chatWidgetId,
            externalUserId: config.externalUserId,
            keyId: config.chatKeyId,
            secretKey: config.chatSecretKey,
            ttl: config.chatJwtTtl,
          );
        },
        (error) {
          result = safeFailure('Chat JWT provider', error);
          session.log(
            'ERROR',
            'Chat JWT provider failed',
            status: 'FAIL',
            details: {'error': result},
          );
          _notify();
        },
      );
    }
    await InfobipMobileMessagingHuawei.setChatCustomization(
      const ChatCustomization(
        chatBackgroundColor: '#FFFFFF',
        chatInputHintText: 'Type a message',
      ),
    );
    await InfobipMobileMessagingHuawei.setChatExceptionHandler((_) async {
      session.log('ERROR', 'Chat exception', status: 'FAIL');
      result =
          'Chat • chat_error\nCheck widget configuration and connectivity.';
      _notify();
    });
    _chatPrepared = true;
  });

  Future<void> requestRtcPermissions({required bool video}) async {
    await run('Request RTC permissions', () async {
      _permissions = await ExamplePermissions.read(
        request: video ? 'video' : 'audio',
      );
    });
  }

  Future<void> openSettings() async {
    await run('Open Android settings', ExamplePermissions.openSettings);
  }

  /// Structural/claim checks only; the backend verifies the supplied signature.
  /// MM and widget JWT contracts are deliberately validated separately.
  bool validSuppliedJwt(String token, {bool chat = false, DateTime? now}) {
    try {
      final parts = token.trim().split('.');
      if (parts.length != 3 ||
          parts.any((p) => !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(p))) {
        return false;
      }
      Map decode(String segment) =>
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(segment))),
              )
              as Map;
      final header = decode(parts[0]), claims = decode(parts[1]);
      if (header['alg'] != 'HS256' ||
          header['typ'] != 'JWT' ||
          base64Url.decode(base64Url.normalize(parts[2])).length != 32) {
        return false;
      }
      final seconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
      final issued = claims['iat'];
      // The widget contract defaults an omitted exp to iat + 15 seconds.
      final expires = chat && !claims.containsKey('exp') && issued is int
          ? issued + 15
          : claims['exp'];
      if (issued is! int ||
          expires is! int ||
          issued > seconds ||
          expires <= seconds ||
          expires <= issued ||
          !externalUserIdConfigured ||
          claims['sub'] != config.externalUserId.trim()) {
        return false;
      }
      bool nonblank(Object? value) =>
          value is String && value.trim().isNotEmpty;
      if (!nonblank(claims['jti']) || !nonblank(claims['iss'])) return false;
      if (chat) {
        return claims['stp'] == 'externalPersonId' &&
            config.externalUserId.trim().length <= 100 &&
            (claims['jti'] as String).length <= 50 &&
            nonblank(claims['ski']) &&
            (config.chatWidgetId.trim().isEmpty ||
                claims['iss'] == config.chatWidgetId.trim()) &&
            (config.chatKeyId.trim().isEmpty ||
                claims['ski'] == config.chatKeyId.trim());
      }
      return applicationCodeConfigured &&
          nonblank(header['kid']) &&
          (config.jwtKid.trim().isEmpty ||
              header['kid'] == config.jwtKid.trim()) &&
          claims['typ'] == 'Bearer' &&
          claims['iss'] == config.applicationCode.trim() &&
          claims['infobip-api-key'] == config.applicationCode.trim();
    } catch (_) {
      return false;
    }
  }

  void recordPush(String event, Message message) {
    session.log(
      'PUSH',
      event,
      details: {
        'titlePresent': message.title?.isNotEmpty == true,
        'bodyPresent': message.body?.isNotEmpty == true,
        'deepLinkPresent': message.deeplink?.isNotEmpty == true,
        'customPayloadPresent': message.customPayload != null,
        'titleMatches': config.expectedNotificationTitle.isEmpty
            ? null
            : message.title == config.expectedNotificationTitle,
        'bodyMatches': config.expectedNotificationBody.isEmpty
            ? null
            : message.body == config.expectedNotificationBody,
        'deepLinkMatches': config.expectedDeepLink.isEmpty
            ? null
            : message.deeplink == config.expectedDeepLink,
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    session.dispose();
    super.dispose();
  }
}
