import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

import '../widgets/result_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<StreamSubscription<Object?>> _subscriptions = [];
  String _latest = 'Waiting for an event.';

  @override
  void initState() {
    super.initState();
    final notifications = InfobipMobileMessagingHuawei.notifications;
    _subscriptions.addAll([
      notifications.onMessageReceived.listen(
        (message) => _show('Message received', _message(message)),
      ),
      // A notification tapped during cold start is replayed on this stream once.
      notifications.onNotificationTapped.listen(
        (message) => _show('Notification tapped', _message(message)),
      ),
      notifications.onNotificationActionTapped.listen(
        (event) => _show(
          'Notification action tapped',
          'Action ID: ${event.actionId ?? 'not provided'}\n${_message(event.message)}',
        ),
      ),
      notifications.onRegistrationUpdated.listen(
        (installation) => _show(
          'Registration updated',
          'Push registration enabled: '
              '${installation.isPushRegistrationEnabled ?? 'unknown'}',
        ),
      ),
      notifications.onInstallationUpdated.listen(
        (installation) => _show(
          'Installation updated',
          'Primary device: ${installation.isPrimaryDevice ?? 'unknown'}\n'
              'Push registration enabled: '
              '${installation.isPushRegistrationEnabled ?? 'unknown'}',
        ),
      ),
    ]);
  }

  String _message(Message message) => [
    'Message ID: ${message.messageId ?? 'not provided'}',
    'Title: ${message.title ?? 'not provided'}',
    'Body: ${message.body ?? 'not provided'}',
    'Deep link: ${message.deeplink ?? 'not provided'}',
    'Silent: ${message.silent ?? false}',
    'Custom payload: ${const JsonEncoder.withIndent('  ').convert(message.customPayload)}',
  ].join('\n');

  void _show(String type, String value) {
    if (mounted) setState(() => _latest = '$type\n$value');
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Send a notification to this external user from the Infobip Portal. '
            'Personalization lets the Portal target the configured test user. '
            'The app receives the portal push.\n\n'
            'This screen listens to all public notification streams. The tap '
            'stream also receives the SDK\'s one-time cold-start replay.',
          ),
          const SizedBox(height: 12),
          ResultCard(title: 'Latest event', message: _latest),
        ],
      ),
    ),
  );
}
