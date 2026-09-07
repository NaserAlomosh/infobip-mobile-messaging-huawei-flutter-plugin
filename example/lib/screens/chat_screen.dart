import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final InfobipHuaweiChatController _chatController =
      InfobipHuaweiChatController();
  final _message = TextEditingController();
  final _contextualData = TextEditingController();
  final _draft = TextEditingController();
  final _theme = TextEditingController();
  StreamSubscription<int>? _unreadSubscription;
  int? _unreadCount;
  bool _loading = false;
  bool _handlingBack = false;
  String _result =
      'The native Chat composer and attachments remain available below.';

  @override
  void initState() {
    super.initState();
    _unreadSubscription = InfobipMobileMessagingHuawei
        .chat
        .onUnreadMessageCounterUpdated
        .listen((count) {
          if (mounted) setState(() => _unreadCount = count);
        });
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await InfobipMobileMessagingHuawei.chat
          .getUnreadMessageCount();
      if (mounted) setState(() => _unreadCount = count);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _result = _platformFailure(error));
    }
  }

  Future<void> _run(Future<String> Function() operation) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await operation();
      if (mounted) setState(() => _result = result);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _result = _platformFailure(error));
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _result = error.message.toString());
    } on FormatException catch (error) {
      if (mounted) setState(() => _result = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _platformFailure(PlatformException error) =>
      '${error.code}: ${error.message ?? 'Chat operation failed'}';

  Future<void> _navigateBack() async {
    if (_handlingBack) return;
    _handlingBack = true;
    try {
      final handled = await _chatController.navigateBackOrCloseChat();
      if (!handled && mounted) Navigator.of(context).pop();
    } on PlatformException catch (error) {
      if (mounted) setState(() => _result = _platformFailure(error));
    } on FormatException catch (error) {
      if (mounted) setState(() => _result = error.message);
    } finally {
      _handlingBack = false;
    }
  }

  @override
  void dispose() {
    unawaited(_unreadSubscription?.cancel());
    _message.dispose();
    _contextualData.dispose();
    _draft.dispose();
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _navigateBack();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _navigateBack),
        title: const Text('Chat'),
        actions: [
          Center(child: Text('Unread: ${_unreadCount ?? '—'}')),
          IconButton(
            onPressed: _loading ? null : _loadUnreadCount,
            tooltip: 'Refresh unread count',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ExpansionTile(
              title: const Text('Chat controls'),
              subtitle: Text(
                _result,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _run(() async {
                            await InfobipMobileMessagingHuawei.showChat();
                            return 'Native Chat screen opened.';
                          }),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open native Chat'),
                  ),
                ),
                TextField(
                  controller: _message,
                  decoration: const InputDecoration(
                    labelText: 'Programmatic text message',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _loading
                        ? null
                        : () => _run(() async {
                            await _chatController.send(
                              InfobipHuaweiChatMessagePayload.text(
                                _message.text,
                              ),
                            );
                            _message.clear();
                            return 'Text message sent.';
                          }),
                    child: const Text('Send text'),
                  ),
                ),
                TextField(
                  controller: _draft,
                  decoration: const InputDecoration(
                    labelText: 'Chat draft',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => _run(() async {
                              await _chatController.setChatDraftMessage(
                                _draft.text,
                              );
                              return 'Draft set for the active conversation.';
                            }),
                      child: const Text('Set draft'),
                    ),
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => _run(() async {
                              await _chatController.setChatDraftMessage('');
                              _draft.clear();
                              return 'Draft cleared.';
                            }),
                      child: const Text('Clear draft'),
                    ),
                  ],
                ),
                TextField(
                  controller: _contextualData,
                  decoration: const InputDecoration(
                    labelText: 'Contextual data (opaque String)',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _run(() async {
                            await _chatController.sendContextualDataWithStrategy(
                              _contextualData.text,
                              ChatMultithreadStrategies.ACTIVE,
                            );
                            _contextualData.clear();
                            return 'Contextual data sent.';
                          }),
                    child: const Text('Send contextual data'),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => _run(() async {
                              await _chatController.setLanguage('en-US');
                              return 'Language set to en-US.';
                            }),
                      child: const Text('English (en-US)'),
                    ),
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => _run(() async {
                              await _chatController.setLanguage('ar-AE');
                              return 'Language set to ar-AE.';
                            }),
                      child: const Text('Arabic (ar-AE)'),
                    ),
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => _run(
                              () async =>
                                  'Current language: '
                                  '${await _chatController.getLanguage()}',
                            ),
                      child: const Text('Get language'),
                    ),
                  ],
                ),
                TextField(
                  controller: _theme,
                  decoration: const InputDecoration(
                    labelText: 'Configured widget theme name (optional)',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => _run(() async {
                              await _chatController.setWidgetTheme(_theme.text);
                              return 'Widget theme set.';
                            }),
                      child: const Text('Set theme'),
                    ),
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => _run(() async {
                              final theme = await _chatController
                                  .getWidgetTheme();
                              return theme == null
                                  ? 'No explicit widget theme is active.'
                                  : 'Current widget theme: $theme';
                            }),
                      child: const Text('Get theme'),
                    ),
                  ],
                ),
                if (_loading) const LinearProgressIndicator(),
              ],
            ),
            Expanded(
              child: InfobipHuaweiChatView(
                controller: _chatController,
                onEvent: (event) {
                  if (!mounted) return;
                  switch (event) {
                    case InfobipHuaweiChatLoadedEvent(:final success):
                      setState(() => _result =
                          success ? 'Chat loaded' : 'Chat failed to load');
                    case InfobipHuaweiChatExitPressedEvent():
                      setState(() => _result = 'Chat exit pressed');
                    case InfobipHuaweiChatRawMessageReceivedEvent():
                      setState(() => _result = 'Chat message received');
                    default:
                      break;
                  }
                },
                onError: (error) {
                  if (mounted) {
                    setState(
                      () => _result =
                          '${error.code.name}: '
                          '${error.message ?? 'Chat view unavailable'}',
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
