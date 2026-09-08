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
  bool _initialized = false;
  bool _busy = false;
  bool _disposed = false;
  Installation? _installation;
  UserData? _user;
  bool? _chatAvailable;
  ExamplePermissions _permissions = const ExamplePermissions();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  String? result;
  JwtTestMetadata? jwtMetadata;
  InboxAuth _inboxAuth = InboxAuth.applicationCode;

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

  List<FeatureRequirement> get jwtRequirements => [
    FeatureRequirement('applicationCode', applicationCodeConfigured),
    FeatureRequirement('externalUserId', externalUserIdConfigured),
    FeatureRequirement('kid', config.jwtKid.trim().isNotEmpty),
    FeatureRequirement('secretKey (valid hex, at least 32 bytes)', _validMmKey),
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
            identity,
            person,
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
          ]);
        }
      case ExampleFeature.rtcAudio:
      case ExampleFeature.rtcVideo:
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

  void selectInboxAuth(InboxAuth value) {
    _inboxAuth = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> run(String operation, Future<void> Function() action) async {
    if (busy) return false;
    _busy = true;
    result = null;
    _notify();
    try {
      await action();
      result ??= '$operation succeeded.';
      return true;
    } catch (error) {
      result = safeFailure(operation, error);
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> initialize() async {
    if (initialized) return;
    await run('Initialize SDK', () async {
      requireValue(config.applicationCode, 'applicationCode');
      await InfobipMobileMessagingHuawei.initialize(
        applicationCode: config.applicationCode.trim(),
      );
      _initialized = true;
      _listen();
    });
    if (initialized) await refresh();
  }

  void _listen() {
    final events = InfobipMobileMessagingHuawei.notifications;
    void installationChanged(Installation value) {
      _installation = value;
      _notify();
    }

    void userChanged(UserData value) {
      _user = value;
      _notify();
    }

    void failed(Object _) {
      result = 'SDK events • operation_failed\nRefresh setup state.';
      _notify();
    }

    _subscriptions.addAll([
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

  Future<void> registerPush() async {
    if (!initialized) return;
    await run('Register for remote notifications', () async {
      _permissions = await ExamplePermissions.read(request: 'push');
      await InfobipMobileMessagingHuawei.registerForRemoteNotifications();
      await _readInstallation();
      result =
          'Registration requested. Readiness uses the installation ID, HMS token and permission status; refresh while registration completes.';
    });
  }

  Future<void> personalize() async {
    if (!initialized || !externalUserIdConfigured) return;
    final succeeded = await run('Personalize User', () async {
      _user = await InfobipMobileMessagingHuawei.personalize(
        PersonalizeContext(
          userIdentity: UserIdentity(
            externalUserId: config.externalUserId.trim(),
          ),
        ),
      );
    });
    if (succeeded) await refresh();
  }

  String generateInboxJwt({DateTime? now}) => ExampleJwtHelper.generate(
    applicationCode: config.applicationCode,
    externalUserId: config.externalUserId,
    kid: config.jwtKid,
    secretKey: config.jwtSecretKey,
    ttl: config.jwtTtl,
    now: now,
  );

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
          'JWT generation verified locally. Backend authorization is tested by fetching Inbox.';
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
      await InfobipMobileMessagingHuawei.setChatJwtProvider(() async {
        if (!personalized)
          throw StateError('Personalize the configured Chat user first');
        return ChatJwtHelper.generate(
          widgetId: config.chatWidgetId,
          externalUserId: config.externalUserId,
          keyId: config.chatKeyId,
          secretKey: config.chatSecretKey,
          ttl: config.chatJwtTtl,
        );
      });
    }
    await InfobipMobileMessagingHuawei.setChatCustomization(
      const ChatCustomization(
        chatBackgroundColor: '#FFFFFF',
        chatInputHintText: 'Type a message',
      ),
    );
    await InfobipMobileMessagingHuawei.setChatExceptionHandler((_) async {
      result =
          'Chat • chat_error\nCheck widget configuration and connectivity.';
      _notify();
    });
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

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
