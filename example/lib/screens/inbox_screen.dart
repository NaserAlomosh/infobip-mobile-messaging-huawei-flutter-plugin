import 'package:flutter/material.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

import '../setup/example_controller.dart';
import '../setup/feature_readiness.dart';
import '../setup/safe_display.dart';
import '../widgets/result_card.dart';
import '../widgets/section_card.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({required this.controller, super.key});
  final ExampleController controller;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  ExampleController get c => widget.controller;
  final _topic = TextEditingController();
  final _limit = TextEditingController(text: '20');
  Inbox? _inbox;
  bool _loading = false;
  String _result = 'Fetch Inbox for the configured test user.';

  Future<void> _fetch() async {
    if (_loading || !c.readiness(ExampleFeature.inbox).isReady) return;
    final limit = int.tryParse(_limit.text.trim());
    if (limit == null || limit <= 0) {
      setState(() => _result = 'Limit must be a positive integer.');
      return;
    }
    setState(() => _loading = true);
    try {
      final inbox = await c.fetchInbox(
        options: FilterOptions(
          limit: limit,
          topic: _topic.text.trim().isEmpty ? null : _topic.text.trim(),
        ),
      );
      if (mounted) {
        setState(() {
          _inbox = inbox;
          _result = 'Inbox fetch succeeded.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _result = safeFailure('Fetch Inbox', error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markSeen(InboxMessage message) async {
    if (_loading || !c.readiness(ExampleFeature.inbox).isReady) return;
    setState(() => _loading = true);
    try {
      await InfobipMobileMessagingHuawei.setInboxMessagesSeen(
        externalUserId: c.config.externalUserId.trim(),
        messageIds: [message.messageId],
      );
      if (mounted) {
        setState(
          () => _result = 'Seen request accepted; checking Inbox again.',
        );
      }
      await _fetchAfterUpdate();
    } catch (error) {
      if (mounted)
        setState(
          () => _result = safeFailure('Mark seen / refresh Inbox', error),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchAfterUpdate() async {
    final inbox = await c.fetchInbox(
      options: FilterOptions(
        limit: int.tryParse(_limit.text.trim()),
        topic: _topic.text.trim().isEmpty ? null : _topic.text.trim(),
      ),
    );
    if (mounted) setState(() => _inbox = inbox);
  }

  @override
  void dispose() {
    _topic.dispose();
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inbox = _inbox;
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            SectionCard(
              title: 'Fetch Inbox',
              description:
                  'Fetch messages for an external user ID using typed filters.',
              children: [
                Text('External User ID: ${masked(c.config.externalUserId)}'),
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
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              c.selectInboxAuth(value);
                              _inbox = null;
                              _result =
                                  'Auth: ${value.label}. Fetch to test this path.';
                            });
                          }
                        },
                ),
                const Text(
                  'Application Code: sandbox profiles only. JWT: generated immediately before each fetch. Seen updates use the existing installation context.',
                ),
                ...c
                    .readiness(ExampleFeature.inbox)
                    .missing
                    .map((r) => Text('Missing: ${r.title}')),
                TextField(
                  controller: _topic,
                  decoration: const InputDecoration(
                    labelText: 'Topic filter (optional)',
                  ),
                ),
                TextField(
                  controller: _limit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Limit'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed:
                      _loading || !c.readiness(ExampleFeature.inbox).isReady
                      ? null
                      : _fetch,
                  child: const Text('Fetch Inbox'),
                ),
              ],
            ),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (inbox != null) ...[
              ResultCard(
                title: 'Counters',
                message:
                    'Total: ${inbox.countTotal}\n'
                    'Unread: ${inbox.countUnread}\n'
                    'Filtered: ${inbox.countTotalFiltered}\n'
                    'Filtered unread: ${inbox.countUnreadFiltered}',
              ),
              ...inbox.messages.map(
                (message) => Card(
                  child: ListTile(
                    title: Text(message.title ?? 'Untitled message'),
                    subtitle: Text(
                      [
                        if (message.body != null) message.body!,
                        'Topic: ${message.topic}',
                        'Received: ${message.receivedTimestamp ?? 'unknown'}',
                      ].join('\n'),
                    ),
                    trailing: message.seen == true
                        ? const Icon(
                            Icons.drafts_outlined,
                            semanticLabel: 'Seen',
                          )
                        : TextButton(
                            onPressed:
                                _loading ||
                                    !c.readiness(ExampleFeature.inbox).isReady
                                ? null
                                : () => _markSeen(message),
                            child: const Text('Mark seen'),
                          ),
                  ),
                ),
              ),
            ],
            ResultCard(title: 'Result', message: _result),
          ],
        ),
      ),
    );
  }
}
