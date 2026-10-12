import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import '../setup/example_controller.dart';
import '../setup/feature_readiness.dart';
import '../setup/safe_display.dart';
import '../testing/test_session.dart';
import 'home_screen.dart';
import 'user_screen.dart';
import 'installation_screen.dart';
import 'inbox_screen.dart';
import 'chat_screen.dart';
import 'huawei_rtc_screen.dart';

class TestCenterScreen extends StatelessWidget {
  const TestCenterScreen({required this.controller, super.key});
  final ExampleController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, controller.session]),
    builder: (context, _) {
      final c = controller, s = c.session;
      return Scaffold(
        appBar: AppBar(title: const Text('Huawei SDK Test Center')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SDK: ${c.initialized ? 'Initialized' : 'Not initialized'}',
                    ),
                    Text(
                      'Huawei host resource: ${s.huaweiConfigured == null
                          ? 'Unknown'
                          : s.huaweiConfigured!
                          ? 'Present; device registration still required'
                          : 'Missing AGC resource'}',
                    ),
                    Text(
                      'Push: ${c.registered ? 'Registration ID present' : 'Waiting for registration'} · HMS token ${c.installation?.pushServiceToken?.isNotEmpty == true ? 'present' : 'missing'}',
                    ),
                    Text(
                      'Inbox authentication: ${c.inboxAuth.label} · Chat: ${c.chatAuthLabel}',
                    ),
                    Text('Test user: ${masked(c.config.externalUserId)}'),
                    Text(
                      'Device: ${s.deviceModel} · Android ${s.androidVersion}',
                    ),
                    Text(
                      'Passed ${s.count(TestStatus.PASS)} · Failed ${s.count(TestStatus.FAIL)} · Blocked ${s.count(TestStatus.BLOCKED)}',
                    ),
                  ],
                ),
              ),
            ),
            const Text(
              'Follow sections in order. Run collects real SDK evidence; confirm Pass only after checking the expected result. Local results survive app restart. Export before uninstalling or clearing app data.',
            ),
            for (final section in <(String, String)>[
              ('Setup', 'SDK'),
              ('Authentication', 'AUTH'),
              ('Push Notifications', 'PUSH'),
              ('User Management', 'USER'),
              ('Installation Management', 'INSTALLATION'),
              ('Mobile Inbox', 'INBOX'),
              ('In-App Chat', 'CHAT'),
              ('Huawei RTC', 'RTC'),
            ])
              Card(
                child: ListTile(
                  title: Text(section.$1),
                  subtitle: Text(
                    '${s.tests.where((t) => t.category == section.$2).length} guided tests',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TestSectionScreen(
                        controller: c,
                        category: section.$2,
                        title: section.$1,
                      ),
                    ),
                  ),
                ),
              ),
            Card(
              child: ListTile(
                title: const Text('Event Logs'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SessionOutputScreen(session: s, report: false),
                  ),
                ),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Test Report'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SessionOutputScreen(session: s, report: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class TestSectionScreen extends StatefulWidget {
  const TestSectionScreen({
    required this.controller,
    required this.category,
    required this.title,
    super.key,
  });
  final ExampleController controller;
  final String category, title;
  @override
  State<TestSectionScreen> createState() => _TestSectionScreenState();
}

class _TestSectionScreenState extends State<TestSectionScreen> {
  ExampleController get c => widget.controller;
  bool _running = false;
  Future<void> _open(Widget screen) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: screen is HuaweiRtcScreen
          ? const RouteSettings(name: HuaweiRtcScreen.routeName)
          : null,
      builder: (_) => screen,
    ),
  );
  Future<void> _controls() async {
    switch (widget.category) {
      case 'SDK':
      case 'AUTH':
        await _open(HomeScreen(controller: c));
      case 'USER':
        await _open(UserScreen(controller: c));
      case 'INSTALLATION':
        await _open(const InstallationScreen());
      case 'INBOX':
        await _open(InboxScreen(controller: c));
      case 'CHAT':
        if (await c.prepareChat() && mounted) {
          await _open(ChatScreen(controller: c));
        }
      case 'RTC':
        await _open(HuaweiRtcScreen(controller: c, video: false));
      default:
        await _open(
          SessionOutputScreen(
            session: c.session,
            report: false,
            initialCategory: 'PUSH',
          ),
        );
    }
  }

  Future<void> _run(DeviceTest t) async {
    if (_running) return;
    c.operationError = null;
    c.operationBlocker = null;
    if (t.category == 'INBOX') {
      c.selectInboxAuth(
        t.name.startsWith('JWT') ? InboxAuth.jwt : InboxAuth.applicationCode,
      );
    }
    if (t.action == 'jwt') c.selectInboxAuth(InboxAuth.jwt);
    if (t.action == 'clearJwt') c.selectInboxAuth(InboxAuth.applicationCode);
    c.session.begin(t, 'Inbox: ${c.inboxAuth.label}; Chat: ${c.chatAuthLabel}');
    final blocker = c.testBlocker(t);
    if (blocker != null) {
      c.session.complete(t, TestStatus.BLOCKED, blocker);
      return;
    }
    setState(() => _running = true);
    try {
      String actual =
          'Controls opened. Perform the steps, then confirm with device/Portal evidence.';
      final config = c.config;
      switch (t.action) {
        case 'initialize':
          await c.initialize();
          if (!c.initialized) {
            c.session.complete(
              t,
              c.operationBlocker != null ? TestStatus.BLOCKED : TestStatus.FAIL,
              c.result ?? 'Initialization failed.',
              error: c.operationError,
            );
            return;
          }
          actual = c.result ?? 'SDK initialized; verify installation.';
        case 'clearJwt':
          await InfobipMobileMessagingHuawei.setJwt(null);
          c.selectInboxAuth(InboxAuth.applicationCode);
          actual =
              'Mobile Messaging JWT cleared. Test supported operations next.';
        case 'jwt':
          if (!c.jwtConfigReady) {
            c.session.complete(
              t,
              TestStatus.BLOCKED,
              'Configure a valid supplied JWT or signing fields.',
            );
            return;
          }
          c.selectInboxAuth(InboxAuth.jwt);
          c.generateInboxJwt();
          actual =
              'Token structurally validated/generated; backend acceptance requires Inbox fetch.';
        case 'register':
          if (!await c.registerPush()) {
            if (c.operationBlocker != null) {
              throw ExampleBlocked(c.operationBlocker!);
            }
            c.session.complete(
              t,
              TestStatus.FAIL,
              'Registration operation failed.',
              error: c.operationError,
            );
            return;
          }
          actual = c.result ?? 'Registration requested.';
        case 'getUser':
        case 'fetchUser':
          final u = t.action == 'getUser'
              ? await InfobipMobileMessagingHuawei.getUser()
              : await InfobipMobileMessagingHuawei.fetchUser();
          actual =
              'User returned. Identity matches: ${u.externalUserId == config.externalUserId.trim()}; first/last name present: ${u.firstName != null}/${u.lastName != null}.';
        case 'saveUser':
          final u = await c.saveConfiguredUser();
          actual =
              'Server matches: identity ${u.externalUserId == config.externalUserId.trim()}; first name ${u.firstName == config.firstName}; last name ${u.lastName == config.lastName}; email ${config.email.isEmpty ? 'not tested' : u.emails?.contains(config.email.trim())}; phone ${config.phoneNumber.isEmpty ? 'not tested' : u.phones?.contains(config.phoneNumber.trim())}.';
        case 'personalize':
          if (!await c.personalize()) {
            if (c.operationBlocker != null) {
              throw ExampleBlocked(c.operationBlocker!);
            }
            c.session.complete(
              t,
              TestStatus.FAIL,
              'Personalization operation failed.',
              error: c.operationError,
            );
            return;
          }
          actual = c.result ?? 'Personalization requested; verify identity.';
        case 'depersonalize':
          final u = await c.depersonalizeUser();
          actual =
              'Server external identity empty: ${u.externalUserId?.isEmpty != false}.';
        case 'saveInstallation':
          await InfobipMobileMessagingHuawei.saveInstallation(
            Installation(
              isPrimaryDevice: config.installationPrimary,
              isPushRegistrationEnabled: config.installationPushEnabled,
              customAttributes: config.installationAttributes,
            ),
          );
          final i = await InfobipMobileMessagingHuawei.fetchInstallation();
          actual =
              'Server primary matches: ${i.isPrimaryDevice == config.installationPrimary}; push enabled matches: ${i.isPushRegistrationEnabled == config.installationPushEnabled}; configured attributes match: ${config.installationAttributes.entries.every((e) => i.customAttributes?[e.key] == e.value)}.';
        case 'getInstallation':
        case 'fetchInstallation':
          final i = t.action == 'getInstallation'
              ? await InfobipMobileMessagingHuawei.getInstallation()
              : await InfobipMobileMessagingHuawei.fetchInstallation();
          actual =
              'Installation returned. Registration ID present: ${i.pushRegistrationId?.isNotEmpty == true}; HMS token present: ${i.pushServiceToken?.isNotEmpty == true}; primary: ${i.isPrimaryDevice}; push enabled: ${i.isPushRegistrationEnabled}; notifications: ${i.notificationsEnabled}.';
        case 'inbox':
        case 'invalidInbox':
          c.selectInboxAuth(
            t.name.startsWith('JWT')
                ? InboxAuth.jwt
                : InboxAuth.applicationCode,
          );
          if (config.inboxLimit <= 0 ||
              !c.readiness(ExampleFeature.inbox).isReady ||
              (t.action == 'invalidInbox' &&
                  config.invalidExternalUserId.isEmpty)) {
            c.session.complete(
              t,
              TestStatus.BLOCKED,
              'Configure identity, positive inboxLimit and selected authentication fields. Invalid-identity tests need invalidExternalUserId.',
            );
            return;
          }
          final options = FilterOptions(
            limit: config.inboxLimit,
            topic: config.inboxTopic.isEmpty ? null : config.inboxTopic,
          );
          Inbox inbox;
          if (t.action == 'invalidInbox') {
            if (c.inboxAuth == InboxAuth.applicationCode) {
              await InfobipMobileMessagingHuawei.setJwt(null);
            }
            inbox = await InfobipMobileMessagingHuawei.fetchInbox(
              externalUserId: config.invalidExternalUserId.trim(),
              jwt: c.inboxAuth == InboxAuth.jwt ? c.generateInboxJwt() : null,
              options: options,
            );
          } else {
            inbox = await c.fetchInbox(options: options);
          }
          actual =
              'Inbox response: total ${inbox.countTotal}, unread ${inbox.countUnread}, filtered ${inbox.countTotalFiltered}, filtered unread ${inbox.countUnreadFiltered}, returned ${inbox.messages.length}. Verify the test-specific expectation.';
        case 'inboxControls':
          c.selectInboxAuth(
            t.name.startsWith('JWT')
                ? InboxAuth.jwt
                : InboxAuth.applicationCode,
          );
          if (mounted) await _open(InboxScreen(controller: c));
        case 'chat':
          if (!c.readiness(ExampleFeature.chat).isReady) {
            c.session.complete(
              t,
              TestStatus.BLOCKED,
              'Chat prerequisites missing; inspect Setup readiness.',
            );
            return;
          }
          if (!await c.prepareChat()) {
            throw StateError('Chat preparation failed');
          }
          if (mounted) await _open(ChatScreen(controller: c));
        case 'rtcAudio':
        case 'rtcVideo':
          if (mounted) {
            await _open(
              HuaweiRtcScreen(controller: c, video: t.action == 'rtcVideo'),
            );
          }
        default:
          actual =
              'Manual observation started. Follow steps; inspect device and Event Logs. No device outcome inferred.';
      }
      c.session.log(
        t.category,
        '${t.id} operation completed',
        details: {'summary': actual},
      );
      c.session.complete(
        t,
        TestStatus.REQUIRES_MANUAL_VERIFICATION,
        actual,
        error: c.operationError,
      );
    } on ExampleBlocked catch (error) {
      c.session.complete(t, TestStatus.BLOCKED, error.message);
    } catch (error) {
      c.session.complete(
        t,
        t.expectsRejection
            ? TestStatus.REQUIRES_MANUAL_VERIFICATION
            : TestStatus.FAIL,
        t.expectsRejection
            ? 'Negative test returned an error; confirm Pass only if this is the expected rejection.'
            : 'Operation failed unexpectedly. Correct the error and re-run before confirming Pass.',
        error: safeFailure('Test operation', error),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c.session,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton(
            onPressed: _running ? null : _controls,
            child: const Text('Open controls / readiness'),
          ),
          if (widget.category == 'RTC')
            OutlinedButton(
              onPressed: () =>
                  _open(HuaweiRtcScreen(controller: c, video: true)),
              child: const Text('Open video controls'),
            ),
          for (final t in c.session.tests.where(
            (t) => t.category == widget.category,
          ))
            Card(
              child: ExpansionTile(
                title: Text('${t.id} · ${t.name}'),
                subtitle: Text(t.status.name),
                childrenPadding: const EdgeInsets.all(16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WHAT IS BEING TESTED?\n${t.name}'),
                  Text(
                    'WHAT IS REQUIRED?\n${t.requirements}\nPermissions: ${t.permissions}\nAuthentication: ${t.authentication}',
                  ),
                  Text(
                    'WHAT BUTTON SHOULD I PRESS?\nRun / Begin observation, then the controls described below.\n${t.steps}',
                  ),
                  Text(
                    'WHAT SHOULD HAPPEN? / HOW DO I CONFIRM SUCCESS?\n${t.expected}',
                  ),
                  Text('Actual result: ${t.actual}'),
                  if (t.error != null) Text(t.error!),
                  Text(
                    'Executed: ${t.timestamp?.toLocal() ?? 'not run'} · Duration: ${t.durationMs ?? 0} ms',
                  ),
                  if (t.status != TestStatus.UNSUPPORTED)
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: _running ? null : () => _run(t),
                          child: Text(
                            t.action == 'manual' ? 'Begin observation' : 'Run',
                          ),
                        ),
                        if (!_running && t.canConfirm) ...[
                          OutlinedButton(
                            onPressed: () => c.session.complete(
                              t,
                              TestStatus.PASS,
                              '${t.actual}\nTester explicitly confirmed expected device/Portal behavior.',
                            ),
                            child: const Text('Confirm Pass'),
                          ),
                          OutlinedButton(
                            onPressed: () => c.session.complete(
                              t,
                              TestStatus.FAIL,
                              '${t.actual}\nTester explicitly confirmed unexpected behavior.',
                              error: t.error,
                            ),
                            child: const Text('Confirm Fail'),
                          ),
                        ],
                        OutlinedButton(
                          onPressed: _running
                              ? null
                              : () => c.session.complete(
                                  t,
                                  TestStatus.BLOCKED,
                                  'Tester reported missing device, Portal, configuration or permission prerequisite.',
                                ),
                          child: const Text('Blocked'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class SessionOutputScreen extends StatefulWidget {
  const SessionOutputScreen({
    required this.session,
    required this.report,
    this.initialCategory,
    super.key,
  });
  final TestSession session;
  final bool report;
  final String? initialCategory;
  @override
  State<SessionOutputScreen> createState() => _SessionOutputScreenState();
}

class _SessionOutputScreenState extends State<SessionOutputScreen> {
  late String? filter = widget.initialCategory;
  Future<void> _export() async {
    await Clipboard.setData(
      ClipboardData(
        text: widget.report
            ? widget.session.report()
            : widget.session.exportLogs(),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sanitized JSON copied. Paste into a local .json file to export.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.report ? 'Test Report' : 'Event Logs'),
          actions: [
            IconButton(
              onPressed: _export,
              tooltip: 'Copy / export sanitized JSON',
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton(
              onPressed: _export,
              child: const Text('Copy / Export sanitized JSON'),
            ),
            if (widget.report) ...[
              Text('Total tests: ${s.tests.length}'),
              for (final status in TestStatus.values)
                Text('${status.name}: ${s.count(status)}'),
              const Text(
                'Device results are tester confirmations. Automated validation never establishes Huawei device success.',
              ),
              for (final t in s.tests)
                ListTile(
                  title: Text('${t.id} ${t.name}'),
                  subtitle: Text('${t.status.name}\n${t.actual}'),
                ),
            ] else ...[
              DropdownButton<String>(
                value: filter ?? 'ALL',
                isExpanded: true,
                items:
                    [
                          'ALL',
                          'SDK',
                          'AUTH',
                          'PUSH',
                          'USER',
                          'INSTALLATION',
                          'INBOX',
                          'CHAT',
                          'RTC',
                          'ERROR',
                        ]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (v) =>
                    setState(() => filter = v == 'ALL' ? null : v),
              ),
              OutlinedButton(
                onPressed: () {
                  s.logs.clear();
                  s.changed();
                },
                child: const Text('Clear logs'),
              ),
              const Text(
                'Application-scoped subscriptions capture events while the app runs. Logs are bounded to 500 entries; no event capture is claimed while the process is terminated. Raw payloads are omitted.',
              ),
              for (final log in s.logs.where(
                (l) => filter == null || l['category'] == filter,
              ))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      '${log['timestamp']} · ${log['category']}\n${log['event']} · ${log['status']}\n${log['details']}',
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}
