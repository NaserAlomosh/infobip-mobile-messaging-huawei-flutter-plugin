import 'package:flutter/material.dart';
import '../setup/example_controller.dart';
import '../setup/feature_readiness.dart';
import '../setup/safe_display.dart';
import '../widgets/readiness_card.dart';
import '../widgets/result_card.dart';
import '../widgets/section_card.dart';
import 'chat_screen.dart';
import 'huawei_rtc_screen.dart';
import 'inbox_screen.dart';
import 'installation_screen.dart';
import 'notifications_screen.dart';
import 'user_screen.dart';

/// Exactly three primary stages; existing feature test screens are drill-downs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.controller, super.key});
  final ExampleController controller;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _page = 0;
  ExampleController get c => widget.controller;

  Future<void> _open(ExampleFeature feature) async {
    if (!c.readiness(feature).isReady || c.busy) return;
    if (feature == ExampleFeature.chat && !await c.prepareChat()) return;
    if (!mounted) return;
    final screen = switch (feature) {
      ExampleFeature.push => const NotificationsScreen(),
      ExampleFeature.inbox => InboxScreen(controller: c),
      ExampleFeature.chat => const ChatScreen(),
      ExampleFeature.rtcAudio => HuaweiRtcScreen(controller: c, video: false),
      ExampleFeature.rtcVideo => HuaweiRtcScreen(controller: c, video: true),
      ExampleFeature.user => UserScreen(controller: c),
      ExampleFeature.installation => const InstallationScreen(),
    };
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => screen));
    await c.refresh();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => PopScope<void>(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !c.busy) setState(() => _page--);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            [
              'Application Setup',
              'User & Installation Setup',
              'Features',
            ][_page],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      'Step ${_page + 1} of 3 · Application → User & Installation → Features',
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: (_page + 1) / 3),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: ValueKey(_page),
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...switch (_page) {
                      0 => _application(),
                      1 => _setup(),
                      _ => _features(),
                    },
                    if (c.busy) const LinearProgressIndicator(),
                    if (c.result != null)
                      ResultCard(title: 'Last operation', message: c.result!),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_page > 0)
                      OutlinedButton(
                        onPressed: c.busy
                            ? null
                            : () => setState(() => _page--),
                        child: const Text('Back'),
                      ),
                    const Spacer(),
                    if (_page < 2)
                      FilledButton(
                        key: const ValueKey('next'),
                        onPressed:
                            (_page == 0
                                ? c.canLeaveApplicationSetup
                                : c.canOpenFeatures)
                            ? () => setState(() => _page++)
                            : null,
                        child: const Text('Next'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _application() => [
    SectionCard(
      title: 'Application Code',
      children: [
        Text(
          c.applicationCodeConfigured
              ? 'Configured · ${masked(c.config.applicationCode)}'
              : 'Missing · provide INFOBIP_APPLICATION_CODE in your local configuration.',
        ),
        const Text(
          'The Application Code initializes the Mobile Messaging SDK for your test app profile.',
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: c.applicationCodeConfigured && !c.busy && !c.initialized
              ? c.initialize
              : null,
          child: const Text('Initialize SDK'),
        ),
        if (c.initialized) const Text('SDK Initialized ✅'),
      ],
    ),
    const SectionCard(
      title: 'Controlled SDK testing only',
      children: [
        Text(
          'Never embed signing secrets in a production mobile application. This local configuration is for controlled SDK testing only.',
        ),
        Text(
          'Configure example_config.local.json using the example README, then rebuild. No credentials are entered on these screens.',
        ),
      ],
    ),
  ];

  Widget _check(String title, bool ready) => Text('$title  ${status(ready)}');
  List<Widget> _setup() {
    final installation = c.installation;
    final metadata = c.jwtMetadata;
    return [
      SectionCard(
        title: 'A · Installation',
        children: [
          _check('Installation available', c.installationAvailable),
          Text(
            'Push registration enabled: ${status(installation?.isPushRegistrationEnabled)}',
          ),
          Text(
            'Notifications enabled: ${status(installation?.notificationsEnabled)}',
          ),
          Text(
            'Push registration ID: ${masked(installation?.pushRegistrationId)}',
          ),
          Text('Primary device: ${status(installation?.isPrimaryDevice)}'),
          Text('Device model: ${installation?.deviceModel ?? 'unknown'}'),
          OutlinedButton(
            onPressed: c.busy ? null : c.refreshInstallation,
            child: const Text('Refresh Installation'),
          ),
        ],
      ),
      SectionCard(
        title: 'B · Push Registration',
        description:
            'Android 13+ requires notification permission. Registration can complete asynchronously; an enabled flag alone does not prove delivery is ready.',
        children: [
          _check('Push registration enabled', c.pushEnabled),
          _check('Push registration ID available', c.registered),
          Text('Android notifications: ${status(c.permissions.notifications)}'),
          FilledButton(
            onPressed: c.busy ? null : c.registerPush,
            child: const Text('Register for Remote Notifications'),
          ),
          TextButton(
            onPressed: c.busy ? null : c.openSettings,
            child: const Text('Open Android permission settings'),
          ),
        ],
      ),
      SectionCard(
        title: 'C · User Personalization',
        description:
            'Personalization lets the Infobip Portal target this test user identity.',
        children: [
          Text(
            'External User ID: ${c.externalUserIdConfigured ? 'configured · ${masked(c.config.externalUserId)}' : 'missing'}',
          ),
          Text('Current user: ${masked(c.user?.externalUserId)}'),
          Text(
            c.personalized
                ? 'Personalized ✅'
                : 'Not personalized as the configured user',
          ),
          FilledButton(
            onPressed:
                c.busy ||
                    !c.externalUserIdConfigured ||
                    !c.installationAvailable
                ? null
                : c.personalize,
            child: const Text('Personalize User'),
          ),
          OutlinedButton(
            onPressed: c.busy ? null : c.refreshUser,
            child: const Text('Refresh User'),
          ),
        ],
      ),
      Card(
        child: ExpansionTile(
          title: const Text('D · Mobile Messaging JWT'),
          subtitle: Text(
            c.jwtConfigReady
                ? 'Generated on demand ✅'
                : 'Optional · signing configuration missing or invalid',
          ),
          childrenPadding: const EdgeInsets.all(16),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...c.jwtRequirements.map((r) => _check(r.title, r.satisfied)),
            FilledButton(
              onPressed: c.busy || !c.jwtConfigReady ? null : c.testJwt,
              child: const Text('Generate/Test JWT'),
            ),
            if (metadata != null)
              Text(
                'Generation verified ✅ (token discarded)\nSubject: ${masked(metadata.subject)}\nIssued: ${metadata.issued}\nExpiry: ${metadata.expires}\nTTL: ${metadata.ttl.inSeconds} seconds',
              ),
          ],
        ),
      ),
      const Card(
        child: ExpansionTile(
          title: Text('E · Authentication by feature'),
          childrenPadding: EdgeInsets.all(16),
          children: [
            Text(
              'Application Code: base SDK initialization and application auth context.\n\nMobile Messaging JWT: supported Mobile Messaging / Inbox requests. This example uses it explicitly for Inbox fetches.\n\nChat JWT: a separate widget provider and separate signing configuration. There is no global Application Code vs JWT mode.',
            ),
          ],
        ),
      ),
      SectionCard(
        title: 'Readiness summary',
        children: [
          ...c.summary.map((r) => _check(r.title, r.satisfied)),
          const Text(
            'Next requires SDK initialization. Each feature enforces its own remaining prerequisites; JWT signing is optional for other features.',
          ),
        ],
      ),
    ];
  }

  List<Widget> _features() => [
    const Text(
      'READY means local prerequisites are satisfied. Confirm service configuration and backend behavior on your Huawei test device.',
    ),
    OutlinedButton(
      onPressed: c.busy ? null : c.refresh,
      child: const Text('Refresh readiness'),
    ),
    ...ExampleFeature.values.map(
      (feature) => ReadinessCard(
        readiness: c.readiness(feature),
        onOpen: c.busy ? null : () => _open(feature),
        children: switch (feature) {
          ExampleFeature.push => [
            const Text(
              'Send a notification to this external user from the Infobip Portal. This screen receives notifications; the app does not send the portal push.',
            ),
          ],
          ExampleFeature.inbox => [
            DropdownButton<InboxAuth>(
              value: c.inboxAuth,
              isExpanded: true,
              items: InboxAuth.values
                  .map(
                    (auth) => DropdownMenuItem(
                      value: auth,
                      child: Text('Auth: ${auth.label}'),
                    ),
                  )
                  .toList(),
              onChanged: c.busy
                  ? null
                  : (value) {
                      if (value != null) c.selectInboxAuth(value);
                    },
            ),
            const Text(
              'Application Code requires a sandbox profile that allows it. JWT uses a fresh token for every fetch.',
            ),
          ],
          ExampleFeature.chat => [
            Text(
              'Chat auth: ${c.config.chatAuth.isEmpty ? 'requires separate configuration' : c.config.chatAuth}. Match the Portal widget security setting. Chat JWT uses a separate contract.',
            ),
          ],
          ExampleFeature.rtcAudio || ExampleFeature.rtcVideo => [
            const Text(
              'Use a Calls configuration ID with Web and In-app Calls enabled. Microphone and Nearby devices (Android 12+) are required; video also needs Camera.',
            ),
            OutlinedButton(
              onPressed: c.busy
                  ? null
                  : () => c.requestRtcPermissions(
                      video: feature == ExampleFeature.rtcVideo,
                    ),
              child: const Text('Grant call permissions'),
            ),
            TextButton(
              onPressed: c.busy ? null : c.openSettings,
              child: const Text('Android permission settings'),
            ),
          ],
          _ => [],
        },
      ),
    ),
  ];
}
