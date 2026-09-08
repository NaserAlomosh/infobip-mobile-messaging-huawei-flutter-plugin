import 'package:flutter/material.dart';

import '../app.dart';
import '../widgets/result_card.dart';
import 'chat_screen.dart';
import 'inbox_screen.dart';
import 'huawei_rtc_screen.dart';
import 'installation_screen.dart';
import 'notifications_screen.dart';
import 'user_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.initializationState,
    required this.applicationCodeConfigured,
    required this.onInitialize,
    this.initializationFailure,
    super.key,
  });

  final InitializationState initializationState;
  final bool applicationCodeConfigured;
  final String? initializationFailure;
  final VoidCallback onInitialize;

  @override
  Widget build(BuildContext context) {
    final initialized = initializationState == InitializationState.initialized;
    final status = switch (initializationState) {
      InitializationState.notInitialized =>
        applicationCodeConfigured
            ? 'Not initialized. Select Initialize SDK to begin.'
            : 'Not initialized. Provide INFOBIP_APPLICATION_CODE with --dart-define.',
      InitializationState.initializing => 'Initializing…',
      InitializationState.initialized => 'Initialized',
      InitializationState.failed =>
        'Initialization failed: ${initializationFailure ?? 'Unknown error'}',
    };
    final destinations = <(String, IconData, Widget)>[
      (
        'Notifications',
        Icons.notifications_outlined,
        const NotificationsScreen(),
      ),
      ('User', Icons.person_outline, const UserScreen()),
      (
        'Installation',
        Icons.phone_android_outlined,
        const InstallationScreen(),
      ),
      ('Inbox', Icons.inbox_outlined, const InboxScreen()),
      ('Chat', Icons.chat_bubble_outline, const ChatScreen()),
      ('Huawei outgoing RTC', Icons.call_outlined, const HuaweiRtcScreen()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Infobip Huawei SDK Example')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ResultCard(title: 'SDK initialization', message: status),
            const SizedBox(height: 8),
            FilledButton(
              onPressed:
                  applicationCodeConfigured &&
                      initializationState != InitializationState.initializing &&
                      !initialized
                  ? onInitialize
                  : null,
              child: initializationState == InitializationState.initializing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Initialize SDK'),
            ),
            const SizedBox(height: 16),
            Text(
              'Feature examples',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...destinations.map(
              (item) => Card(
                child: ListTile(
                  leading: Icon(item.$2),
                  title: Text(item.$1),
                  subtitle: initialized
                      ? null
                      : const Text(
                          'Initialize the SDK before running operations.',
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(
                    context,
                  ).push<void>(MaterialPageRoute(builder: (_) => item.$3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
