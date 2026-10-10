import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Names are the report contract used by manual testers.
// ignore_for_file: constant_identifier_names
enum TestStatus {
  NOT_RUN,
  RUNNING,
  PASS,
  FAIL,
  BLOCKED,
  UNSUPPORTED,
  REQUIRES_MANUAL_VERIFICATION,
}

class DeviceTest {
  DeviceTest(
    this.id,
    this.name,
    this.category,
    this.steps,
    this.expected, {
    this.requirements = 'Initialized SDK and controlled Infobip test profile.',
    this.permissions = 'No additional permission.',
    this.authentication = 'Application Code initialization context.',
    this.action = 'manual',
    bool unsupported = false,
  }) : status = unsupported ? TestStatus.UNSUPPORTED : TestStatus.NOT_RUN;
  final String id,
      name,
      category,
      steps,
      expected,
      requirements,
      permissions,
      authentication,
      action;
  bool get expectsRejection =>
      action == 'invalidInbox' ||
      name.contains('Authentication errors') ||
      name == 'Network failure' ||
      name == 'Permission denial' ||
      name == 'Call already active' ||
      name == 'Network interruption';
  bool get canConfirm =>
      status == TestStatus.REQUIRES_MANUAL_VERIFICATION ||
      status == TestStatus.PASS ||
      (status == TestStatus.FAIL && (error == null || expectsRejection));
  TestStatus status;
  String actual = 'No evidence recorded.';
  String? error;
  DateTime? timestamp;
  DateTime? started;
  int? durationMs;
  String? authMode;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'status': status.name,
    'timestamp': timestamp?.toUtc().toIso8601String(),
    'durationMs': durationMs,
    'authenticationMode': authMode,
    'actualResult': actual,
    'error': error,
  };
}

/// Only application-owned summaries enter this store. No raw SDK objects,
/// exception messages, user notes, configuration values or payloads are accepted.
class TestSession extends ChangeNotifier {
  final tests = createTests();
  final List<Map<String, Object?>> logs = [];
  static const host = MethodChannel('infobip_huawei_example/permissions');
  String deviceModel = 'unknown', androidVersion = 'unknown';
  bool? huaweiConfigured;
  bool _disposed = false;
  Future<void>? _restoration;
  int count(TestStatus status) => tests.where((t) => t.status == status).length;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  void log(
    String category,
    String event, {
    String status = 'OBSERVED',
    Map<String, Object?> details = const {},
  }) {
    logs.insert(0, {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'category': category,
      'event': event,
      'status': status,
      'details': details,
    });
    if (logs.length > 500) logs.removeLast();
    changed();
  }

  void begin(DeviceTest test, String auth) {
    if (test.status == TestStatus.UNSUPPORTED) return;
    test.durationMs = null;
    test.started = DateTime.now();
    test.timestamp = test.started;
    test.authMode = auth;
    test.error = null;
    test.actual = 'Follow the steps and collect real device evidence.';
    test.status = TestStatus.RUNNING;
    changed();
    persist();
  }

  void complete(
    DeviceTest test,
    TestStatus status,
    String actual, {
    String? error,
  }) {
    if (test.status == TestStatus.UNSUPPORTED) return;
    if (status == TestStatus.PASS && !test.canConfirm) return;
    test.status = status;
    test.actual = actual;
    test.error = error;
    test.timestamp = DateTime.now();
    test.durationMs = test.started == null
        ? null
        : test.timestamp!.difference(test.started!).inMilliseconds;
    log(test.category, test.id, status: status.name);
    persist();
  }

  String report() => const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'deviceModel': deviceModel,
    'androidVersion': androidVersion,
    'counts': {for (final s in TestStatus.values) s.name: count(s)},
    'tests': tests.map((t) => t.toJson()).toList(),
  });
  String exportLogs() => const JsonEncoder.withIndent('  ').convert(logs);
  Future<void> persist() async {
    try {
      // Wait for the startup read before writing, so a quick test start cannot
      // erase earlier rows. Rows modified this session win over the snapshot.
      await _restoration;
      await host.invokeMethod<void>('saveTestReport', {'report': report()});
    } catch (_) {
      log('ERROR', 'Report persistence unavailable');
    }
  }

  Future<void> restore() => _restoration ??= _restore();

  Future<void> _restore() async {
    try {
      final info = await host.invokeMapMethod<String, dynamic>('deviceInfo');
      deviceModel = info?['model'] as String? ?? 'unknown';
      androidVersion = info?['androidVersion'] as String? ?? 'unknown';
      huaweiConfigured = info?['huaweiConfigured'] as bool?;
      final saved = await host.invokeMethod<String>('readTestReport');
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        for (final row in data['tests'] as List) {
          final matches = tests.where((t) => t.id == row['id']);
          if (matches.isEmpty) continue;
          final t = matches.first;
          if (t.status == TestStatus.UNSUPPORTED || t.timestamp != null) {
            continue;
          }
          t.status = TestStatus.values.byName(row['status'] as String);
          if (t.status == TestStatus.RUNNING) {
            t.status = TestStatus.REQUIRES_MANUAL_VERIFICATION;
          }
          // This private host store contains the app's own sanitized summaries.
          t.actual =
              row['actualResult'] as String? ??
              'Restored prior local result; re-run to collect fresh evidence.';
          t.error = row['error'] as String?;
          t.timestamp = DateTime.tryParse(row['timestamp'] as String? ?? '');
          t.durationMs = row['durationMs'] as int?;
          final auth = row['authenticationMode'];
          t.authMode =
              auth is String &&
                  RegExp(
                    r'^Inbox: (Application Code|JWT); Chat: (installation|jwt|unconfigured)$',
                  ).hasMatch(auth)
              ? auth
              : null;
        }
      }
    } catch (_) {
      log('ERROR', 'Local device/report information unavailable');
    }
    changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

List<DeviceTest> createTests() {
  final result = <DeviceTest>[];
  void add(
    String category,
    String name,
    String steps,
    String expected, {
    String action = 'manual',
    String? requirements,
    String? permissions,
    String? auth,
    bool unsupported = false,
  }) {
    result.add(
      DeviceTest(
        '$category-${(result.where((t) => t.category == category).length + 1).toString().padLeft(3, '0')}',
        name,
        category,
        steps,
        expected,
        action: action,
        requirements:
            requirements ??
            'Initialized SDK; test App Profile and local Dart configuration.',
        permissions: permissions ?? 'No additional permission.',
        authentication: auth ?? 'Application Code initialization context.',
        unsupported: unsupported,
      ),
    );
  }

  add(
    'SDK',
    'Initialize SDK',
    'Fill infobipApplicationCode. Press Run. Inspect setup state and installation.',
    'Native initialization completes; then verify installation belongs to your test application.',
    action: 'initialize',
    requirements: 'infobipApplicationCode; matching Android/Huawei host setup.',
  );
  add(
    'SDK',
    'Huawei host configuration',
    'Check the host status, AppGallery package, signing SHA-256, Push Kit and HMS Core. Register push next.',
    'Host resource is present AND actual HMS registration succeeds; resource presence alone is insufficient.',
  );
  add(
    'AUTH',
    'Application Code scenario',
    'Press Run to clear optional Mobile Messaging JWT. Use Inbox Application Code mode and User tests.',
    'JWT clear succeeds; actual supported operations succeed or show their real authorization errors.',
    action: 'clearJwt',
  );
  add(
    'AUTH',
    'Mobile Messaging JWT scenario',
    'Select JWT mode. Press Run, then fetch Inbox before the token expires.',
    'Local token is structurally valid; only a real Inbox response proves backend acceptance.',
    action: 'jwt',
    requirements:
        'jwtToken OR jwtKid + hex jwtSecretKey + jwtTtlSeconds; externalUserId.',
    auth: 'Mobile Messaging JWT; Application Code still initializes SDK.',
  );
  add(
    'AUTH',
    'Chat JWT authentication',
    'Set chatAuthMode=jwt and separate widget credentials or chatJwtToken. Personalize, then open Chat.',
    'Widget loads for the matching identity; reconnect requests another provider token.',
    action: 'chat',
    auth: 'Separate Chat JWT; matching personalized externalUserId.',
  );
  add(
    'PUSH',
    'Register remote notifications',
    'Press Run, grant notification permission, then fetch installation. Wait for asynchronous registration.',
    'HMS token and registration ID present; push enabled and notifications enabled.',
    action: 'register',
    permissions: 'Notifications on Android 13+.',
  );
  for (final name in [
    'Foreground notification',
    'Background notification',
    'Swipe-away / process termination notification',
    'Force-stop diagnostic',
    'Notification tapped',
    'Notification action tapped',
    'Custom payload',
    'Deep links',
    'Repeated registration',
    'Network failure',
  ]) {
    add(
      'PUSH',
      name,
      'Initialize, register and personalize. In Infobip Portal select your test App Profile and external user. Send a test notification. For $name reproduce that state; reopen the app and inspect Event Logs. For force-stop, explicitly relaunch before retrying. Compare configured title/body/deep-link match flags.',
      'Record visible device behavior and actual receipt/tap/action events. Background, swipe-away, OS termination and force-stop have different delivery rules; no event is fabricated.',
      action: name == 'Repeated registration' ? 'register' : 'manual',
      permissions: 'Notifications; Android channel enabled.',
      auth: 'Application Code; personalized test identity.',
    );
  }
  for (final entry in [
    ('Get cached user', 'getUser'),
    ('Fetch user', 'fetchUser'),
    ('Save user', 'saveUser'),
    ('Personalize', 'personalize'),
    ('Depersonalize', 'depersonalize'),
  ]) {
    add(
      'USER',
      entry.$1,
      'Press Run. Compare masked identity and field match flags. For writes, fetch again and verify the test user in Portal. Depersonalize only after hanging up RTC.',
      'Returned SDK data matches intended test state; writes persist on server.',
      action: entry.$2,
      requirements:
          'externalUserId; firstName, lastName, optional email/phoneNumber for save.',
    );
  }
  for (final entry in [
    ('Get cached installation', 'getInstallation'),
    ('Fetch installation', 'fetchInstallation'),
    ('Save installation', 'saveInstallation'),
    ('Primary device state', 'saveInstallation'),
    ('Registration state', 'fetchInstallation'),
    ('Custom attributes', 'saveInstallation'),
  ]) {
    add(
      'INSTALLATION',
      entry.$1,
      'Press Run. Compare flags. For save, set installationPrimary, installationPushEnabled and installationAttributes in local config. Fetch from server again.',
      'Server-backed flags/attributes match configuration; native-owned token fields remain masked.',
      action: entry.$2,
    );
  }
  for (final mode in ['Application Code', 'JWT']) {
    for (final name in [
      'Fetch Inbox',
      'Topic filters',
      'Result limits',
      'Unread counters',
      'Mark message seen / re-fetch',
      'Empty Inbox',
      'Invalid identity',
      'Authentication errors',
    ]) {
      add(
        'INBOX',
        '$mode: $name',
        'Select $mode in Inbox. ${name == 'Invalid identity'
            ? 'Configure invalidExternalUserId and press Run.'
            : name == 'Authentication errors'
            ? 'Use an intentionally invalid test token/profile, rebuild, then fetch.'
            : 'Press Run or Open controls. For seen updates select a real message, then re-fetch.'} Compare counts and Portal evidence; empty Inbox requires an actually empty identity.',
        'Actual service result or expected controlled error; seen status and unread counters verified after re-fetch.',
        action: name == 'Invalid identity'
            ? 'invalidInbox'
            : name.contains('seen')
            ? 'inboxControls'
            : 'inbox',
        requirements:
            'externalUserId; optional inboxTopic; positive inboxLimit. JWT requires supplied token or signing fields.',
        auth: mode,
      );
    }
  }
  for (final name in [
    'Embedded Chat',
    'Global showChat()',
    'Chat JWT provider',
    'Send message',
    'Receive message',
    'Native attachments',
    'Unread count / stream',
    'Contextual data',
    'Language',
    'Theme',
    'Chat events / errors',
    'Back navigation',
    'Reopening Chat',
    'Draft set / clear',
  ]) {
    add(
      'CHAT',
      name,
      'Press Open controls. ${name == 'Global showChat()' ? 'Press Open native Chat.' : 'Expand Chat controls and use the matching button or native composer.'} Send/reply using a real Portal agent. Verify the result at both endpoints; back out and reopen when required.',
      'Actual widget behavior and SDK event/count observed; message, attachment or contextual data confirmed by the agent.',
      action: 'chat',
      requirements:
          'Portal Chat widget; chatAuthMode matches widget. JWT mode needs separate credentials and personalization.',
      auth: 'Installation or separate Chat JWT as configured.',
    );
  }
  for (final name in [
    'RTC token acquisition',
    'Outgoing audio call',
    'Outgoing video call',
    'Call established event',
    'Hangup',
    'Repeated calls',
    'Call already active',
    'Permission denial',
    'Network interruption',
    'Activity recreation',
    'RTC cleanup',
    'Active call status',
  ]) {
    add(
      'RTC',
      name,
      'Grant call permissions in Setup. Open audio/video controls and start a real application call. ${name == 'Call already active'
          ? 'Use Attempt second call while active.'
          : name == 'Permission denial'
          ? 'Revoke permission in Settings, return, then use Probe denied permission.'
          : name == 'Activity recreation'
          ? 'Enable Android Developer options / Don’t keep activities, background and return during a call.'
          : name == 'RTC cleanup'
          ? 'Hang up, await finished, verify microphone/camera release and peer termination; then place another call.'
          : name == 'Network interruption'
          ? 'Disconnect network during establishment and during media; watch real error/reconnect events.'
          : 'Use Hang up / Refresh active call as needed.'} Peer must confirm two-way audio and outgoing camera frames for video.',
      'Real token delegation, call events and peer media/termination confirmed. Token stays native; creating a call is not proof of media.',
      action: name.contains('video') ? 'rtcVideo' : 'rtcAudio',
      permissions: 'Microphone, Nearby devices Android 12+; Camera for video.',
      requirements:
          'rtcCallsConfigurationId; rtcIdentity or registered installation. Backend Calls routing and peer.',
      auth: 'Native Mobile Messaging RTC token acquisition.',
    );
  }
  add(
    'RTC',
    'Incoming HMS calls',
    'No runnable incoming test.',
    'Incoming HMS signaling is not implemented; existing enableCalls/enableChatCalls safeguards remain.',
    unsupported: true,
  );
  add(
    'RTC',
    'Video preview / remote renderer',
    'No runnable renderer test.',
    'No local preview or remote video renderer is implemented in this branch.',
    unsupported: true,
  );
  return result;
}
