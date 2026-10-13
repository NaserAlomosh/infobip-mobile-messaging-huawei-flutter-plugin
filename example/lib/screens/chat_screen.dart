import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

import '../setup/example_controller.dart';
import '../setup/safe_display.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({this.controller, super.key});

  final ExampleController? controller;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final InfobipHuaweiChatController _chatController =
      InfobipHuaweiChatController();

  late final TextEditingController _message = TextEditingController(
    text: widget.controller?.config.chatMessage,
  );

  late final TextEditingController _contextualData = TextEditingController(
    text: widget.controller?.config.chatContextualData,
  );

  final TextEditingController _draft = TextEditingController();

  late final TextEditingController _theme = TextEditingController(
    text: widget.controller?.config.chatTheme,
  );

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
          if (!mounted) return;

          setState(() {
            _unreadCount = count;
          });
        });

    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await InfobipMobileMessagingHuawei.chat
          .getUnreadMessageCount();

      if (!mounted) return;

      setState(() {
        _unreadCount = count;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;

      setState(() {
        _result = _platformFailure(error);
      });
    }
  }

  Future<void> _run(Future<String> Function() operation) async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final result = await operation();

      widget.controller?.session.log(
        'CHAT',
        'Control operation completed',
        status: 'REQUIRES_MANUAL_VERIFICATION',
      );

      if (!mounted) return;

      setState(() {
        _result = result;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;

      setState(() {
        _result = _platformFailure(error);
      });
    } on ArgumentError catch (error) {
      if (!mounted) return;

      setState(() {
        _result = safeFailure('Chat operation', error);
      });
    } on FormatException catch (error) {
      if (!mounted) return;

      setState(() {
        _result = safeFailure('Chat operation', error);
      });
    } catch (error) {
      widget.controller?.session.log('ERROR', 'Chat control failed');

      if (!mounted) return;

      setState(() {
        _result = safeFailure('Chat operation', error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _platformFailure(PlatformException error) {
    return safeFailure('Chat operation', error);
  }

  Future<void> _navigateBack() async {
    if (_handlingBack) return;

    _handlingBack = true;

    try {
      final handled = await _chatController.navigateBackOrCloseChat();

      if (!handled && mounted) {
        Navigator.of(context).pop();
      }
    } on PlatformException catch (error) {
      if (!mounted) return;

      setState(() {
        _result = _platformFailure(error);
      });
    } on FormatException catch (error) {
      if (!mounted) return;

      setState(() {
        _result = safeFailure('Chat operation', error);
      });
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
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _navigateBack();
        }
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
              /// CHAT CONTROLS
              ///
              /// The ExpansionTile itself remains outside the scroll view.
              ///
              /// When expanded, its content gets a maximum height and becomes
              /// independently scrollable.
              ///
              /// This prevents RenderFlex overflow while keeping the native
              /// chat view constrained inside Expanded.
              ///
              ExpansionTile(
                title: const Text('Chat controls'),
                subtitle: Text(
                  _result,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                childrenPadding: EdgeInsets.zero,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.65,
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          /// Open native chat
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

                          const SizedBox(height: 12),

                          /// TEXT MESSAGE
                          TextField(
                            controller: _message,
                            decoration: const InputDecoration(
                              labelText: 'Programmatic text message',
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 8),

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

                          const SizedBox(height: 12),

                          /// DRAFT
                          TextField(
                            controller: _draft,
                            decoration: const InputDecoration(
                              labelText: 'Chat draft',
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _loading
                                    ? null
                                    : () => _run(() async {
                                        await _chatController
                                            .setChatDraftMessage(_draft.text);

                                        return 'Draft set for the active conversation.';
                                      }),
                                child: const Text('Set draft'),
                              ),
                              OutlinedButton(
                                onPressed: _loading
                                    ? null
                                    : () => _run(() async {
                                        await _chatController
                                            .setChatDraftMessage('');

                                        _draft.clear();

                                        return 'Draft cleared.';
                                      }),
                                child: const Text('Clear draft'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          /// CONTEXTUAL DATA
                          TextField(
                            controller: _contextualData,
                            decoration: const InputDecoration(
                              labelText: 'Contextual data (opaque String)',
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              onPressed: _loading
                                  ? null
                                  : () => _run(() async {
                                      await _chatController
                                          .sendContextualDataWithStrategy(
                                            _contextualData.text,
                                            ChatMultithreadStrategies.ACTIVE,
                                          );

                                      _contextualData.clear();

                                      return 'Contextual data sent.';
                                    }),
                              child: const Text('Send contextual data'),
                            ),
                          ),

                          const SizedBox(height: 12),

                          /// LANGUAGE
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _loading
                                    ? null
                                    : () => _run(() async {
                                        await _chatController.setLanguage(
                                          'en-US',
                                        );

                                        return 'Language set to en-US.';
                                      }),
                                child: const Text('English (en-US)'),
                              ),
                              OutlinedButton(
                                onPressed: _loading
                                    ? null
                                    : () => _run(() async {
                                        await _chatController.setLanguage(
                                          'ar-AE',
                                        );

                                        return 'Language set to ar-AE.';
                                      }),
                                child: const Text('Arabic (ar-AE)'),
                              ),
                              OutlinedButton(
                                onPressed: _loading
                                    ? null
                                    : () => _run(() async {
                                        final language = await _chatController
                                            .getLanguage();

                                        return 'Current language: $language';
                                      }),
                                child: const Text('Get language'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          /// THEME
                          TextField(
                            controller: _theme,
                            decoration: const InputDecoration(
                              labelText:
                                  'Configured widget theme name (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _loading
                                    ? null
                                    : () => _run(() async {
                                        await _chatController.setWidgetTheme(
                                          _theme.text,
                                        );

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

                                        if (theme == null) {
                                          return 'No explicit widget theme is active.';
                                        }

                                        return 'Current widget theme: $theme';
                                      }),
                                child: const Text('Get theme'),
                              ),
                            ],
                          ),

                          if (_loading) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              /// NATIVE CHAT VIEW
              Expanded(
                child: InfobipHuaweiChatView(
                  controller: _chatController,
                  onEvent: (event) {
                    widget.controller?.session.log(
                      'CHAT',
                      event.runtimeType.toString(),
                    );

                    if (!mounted) return;

                    switch (event) {
                      case InfobipHuaweiChatLoadedEvent(:final success):
                        setState(() {
                          _result = success
                              ? 'Chat loaded'
                              : 'Chat failed to load';
                        });

                      case InfobipHuaweiChatExitPressedEvent():
                        setState(() {
                          _result = 'Chat exit pressed';
                        });

                      case InfobipHuaweiChatRawMessageReceivedEvent():
                        setState(() {
                          _result = 'Chat message received';
                        });

                      default:
                        break;
                    }
                  },
                  onError: (error) {
                    widget.controller?.session.log(
                      'ERROR',
                      'Chat view error',
                      details: {'code': error.code.name},
                    );

                    if (!mounted) return;

                    setState(() {
                      _result =
                          'Chat view • ${error.code.name}\n'
                          'Check widget configuration and connectivity.';
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
