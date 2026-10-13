// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/channel_contract.dart';
import 'chat_error.dart';
import 'chat_event.dart';
import 'chat_message_payload.dart';
import 'chat_view_attachment.dart';
import 'widget_attachment_config.dart';
import 'widget_info.dart';

/// Determines which Chat threads receive contextual data.
enum ChatMultithreadStrategies {
  /// Applies contextual data to every existing thread.
  ALL,

  /// Applies contextual data to every existing thread and to new threads.
  ALL_PLUS_NEW,

  /// Applies contextual data to the active thread.
  ACTIVE,
}

typedef InfobipHuaweiChatErrorCallback =
    void Function(InfobipHuaweiChatError error);
typedef InfobipHuaweiChatEventCallback =
    void Function(InfobipHuaweiChatEvent event);

final class _ChatViewBridge {
  _ChatViewBridge(this.viewId, this._onError, this._onEvent)
    : channel = MethodChannel('${ChannelContract.chatViewChannel}$viewId') {
    channel.setMethodCallHandler(_handleMethodCall);
    unawaited(channel.invokeMethod<void>(ChannelContract.chatViewReady));
  }

  final int viewId;
  final MethodChannel channel;
  InfobipHuaweiChatErrorCallback? _onError;
  InfobipHuaweiChatEventCallback? _onEvent;

  void updateErrorCallback(InfobipHuaweiChatErrorCallback? callback) {
    _onError = callback;
  }

  void updateEventCallback(InfobipHuaweiChatEventCallback? callback) {
    _onEvent = callback;
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case ChannelContract.chatOnError:
        _onError?.call(_decodeError(call.arguments));
        return;
      case ChannelContract.chatOnRuntimeEvent:
        final event = decodeInfobipHuaweiChatEvent(call.arguments);
        if (event != null) _onEvent?.call(event);
        return;
    }
  }

  void dispose() {
    _onError = null;
    _onEvent = null;
    channel.setMethodCallHandler(null);
  }
}

@visibleForTesting
InfobipHuaweiChatEvent? decodeInfobipHuaweiChatEvent(Object? payload) {
  if (payload is! Map) return null;
  final value = payload[ChannelContract.value];
  switch (payload[ChannelContract.event]) {
    case ChannelContract.chatLoaded:
      if (value is! bool) return null;
      return InfobipHuaweiChatLoadedEvent(success: value);
    case ChannelContract.chatExitPressed:
      return const InfobipHuaweiChatExitPressedEvent();
    case ChannelContract.chatWidgetThemeChanged:
      if (value is! String) return null;
      return InfobipHuaweiChatWidgetThemeChangedEvent(theme: value);
    case ChannelContract.chatWidgetInfoUpdated:
      final widgetInfo = _decodeWidgetInfo(value);
      if (widgetInfo == null) return null;
      return InfobipHuaweiChatWidgetInfoUpdatedEvent(widgetInfo: widgetInfo);
    case ChannelContract.chatAttachmentPreviewOpened:
      final attachment = _decodeAttachment(value);
      if (attachment == null) return null;
      return InfobipHuaweiChatAttachmentPreviewOpenedEvent(
        attachment: attachment,
      );
    case ChannelContract.chatRawMessageReceived:
      if (value is! String) return null;
      return InfobipHuaweiChatRawMessageReceivedEvent(rawMessage: value);
    case ChannelContract.chatViewChanged:
      if (value is! String) return null;
      return InfobipHuaweiChatViewChangedEvent(
        state: switch (value) {
          'LOADING' => InfobipHuaweiChatViewState.loading,
          'THREAD_LIST' => InfobipHuaweiChatViewState.threadList,
          'LOADING_THREAD' => InfobipHuaweiChatViewState.loadingThread,
          'THREAD' => InfobipHuaweiChatViewState.thread,
          'CLOSED_THREAD' => InfobipHuaweiChatViewState.closedThread,
          'SINGLE_MODE_THREAD' => InfobipHuaweiChatViewState.singleModeThread,
          _ => InfobipHuaweiChatViewState.unknown,
        },
        rawValue: value,
      );
    case ChannelContract.chatConnectionChanged:
      if (value is! String) return null;
      return InfobipHuaweiChatConnectionChangedEvent(
        state: switch (value) {
          'CONNECTED' => InfobipHuaweiChatConnectionState.connected,
          'DISCONNECTED' => InfobipHuaweiChatConnectionState.disconnected,
          _ => InfobipHuaweiChatConnectionState.unknown,
        },
        rawValue: value,
      );
  }
  return null;
}

WidgetInfo? _decodeWidgetInfo(Object? value) {
  if (value is! Map) return null;
  final themeNames = value['themeNames'];
  if (themeNames != null &&
      (themeNames is! List || themeNames.any((name) => name is! String))) {
    return null;
  }
  final attachmentValue = value['attachmentConfig'];
  WidgetAttachmentConfig? attachmentConfig;
  if (attachmentValue != null) {
    if (attachmentValue is! Map) return null;
    final maxSize = attachmentValue['maxSize'];
    final enabled = attachmentValue['isEnabled'];
    final extensions = attachmentValue['allowedExtensions'];
    if ((maxSize != null && maxSize is! int) ||
        (enabled != null && enabled is! bool) ||
        (extensions != null &&
            (extensions is! List ||
                extensions.any((extension) => extension is! String)))) {
      return null;
    }
    attachmentConfig = WidgetAttachmentConfig(
      maxSize: maxSize as int?,
      isEnabled: enabled as bool?,
      allowedExtensions: (extensions as List?)?.cast<String>(),
    );
  }
  const stringFields = <String>[
    'id',
    'title',
    'primaryColor',
    'backgroundColor',
    'primaryTextColor',
  ];
  const boolFields = <String>[
    'multiThread',
    'multiChannelConversationEnabled',
    'callsEnabled',
  ];
  if (stringFields.any((key) => value[key] != null && value[key] is! String) ||
      boolFields.any((key) => value[key] != null && value[key] is! bool)) {
    return null;
  }
  return WidgetInfo(
    id: value['id'] as String?,
    title: value['title'] as String?,
    primaryColor: value['primaryColor'] as String?,
    backgroundColor: value['backgroundColor'] as String?,
    primaryTextColor: value['primaryTextColor'] as String?,
    multiThread: value['multiThread'] as bool?,
    multiChannelConversationEnabled:
        value['multiChannelConversationEnabled'] as bool?,
    callsEnabled: value['callsEnabled'] as bool?,
    themeNames: (themeNames as List?)?.cast<String>(),
    attachmentConfig: attachmentConfig,
  );
}

ChatViewAttachment? _decodeAttachment(Object? value) {
  if (value is! Map) return null;
  for (final key in const ['url', 'type', 'caption']) {
    if (value[key] != null && value[key] is! String) return null;
  }
  return ChatViewAttachment(
    url: value['url'] as String?,
    type: value['type'] as String?,
    caption: value['caption'] as String?,
  );
}

InfobipHuaweiChatError _decodeError(Object? payload) {
  if (payload is! Map) {
    return const InfobipHuaweiChatError(
      code: InfobipHuaweiChatErrorCode.unknown,
    );
  }
  final code = switch (payload[ChannelContract.code]) {
    'not_initialized' => InfobipHuaweiChatErrorCode.notInitialized,
    'activity_unavailable' => InfobipHuaweiChatErrorCode.activityUnavailable,
    'activity_fragment_unavailable' =>
      InfobipHuaweiChatErrorCode.activityFragmentUnavailable,
    'chat_unavailable' => InfobipHuaweiChatErrorCode.chatUnavailable,
    'native_error' => InfobipHuaweiChatErrorCode.nativeError,
    _ => InfobipHuaweiChatErrorCode.unknown,
  };
  final message = payload[ChannelContract.message];
  return InfobipHuaweiChatError(
    code: code,
    message: message is String ? message : null,
  );
}

/// Controls one [InfobipHuaweiChatView].
final class InfobipHuaweiChatController {
  _ChatViewBridge? _bridge;
  int? _viewId;

  /// Whether this controller is attached to a live native Chat view.
  bool get isAttached => _bridge != null;

  /// Sends a text message through this embedded Chat component.
  ///
  /// The native composer remains available and is the supported attachment
  /// workflow.
  Future<void> send(InfobipHuaweiChatMessagePayload payload) async {
    final bridge = _requireBridge();
    await bridge.channel.invokeMethod<void>(
      ChannelContract.chatSend,
      payload.toMap(),
    );
  }

  /// Sets the native composer draft for the active Chat conversation.
  ///
  /// Huawei SDK 8.14.0 has no composer draft setter. On an attached native
  /// view this retained API throws a PlatformException with code `not_available`.
  /// The controller must be attached to a live native Chat view.
  Future<void> setChatDraftMessage(String draftMessage) async {
    final bridge = _requireBridge();
    await bridge.channel.invokeMethod<void>(
      ChannelContract.chatSetDraftMessage,
      <String, Object>{ChannelContract.message: draftMessage},
    );
  }

  /// Sends opaque contextual data through this embedded Chat component.
  ///
  /// Contextual data is not displayed as a normal Chat message.
  Future<void> sendContextualData(String data) async {
    await sendContextualDataWithStrategy(data);
  }

  /// Sends opaque contextual data using [chatMultithreadStrategy].
  ///
  /// The controller must be attached to a live native Chat view. Huawei
  /// applies the selected strategy according to the widget's thread mode.
  Future<void> sendContextualDataWithStrategy(
    String data, [
    ChatMultithreadStrategies chatMultithreadStrategy =
        ChatMultithreadStrategies.ACTIVE,
  ]) async {
    if (data.trim().isEmpty) {
      throw ArgumentError.value(data, 'data', 'must not be empty');
    }
    final bridge = _requireBridge();
    await bridge.channel.invokeMethod<void>(
      ChannelContract.chatSendContextualData,
      <String, Object>{
        ChannelContract.data: data,
        ChannelContract.chatMultiThreadStrategy: chatMultithreadStrategy.name,
      },
    );
  }

  /// Sets the language used by this embedded Chat component.
  ///
  /// The value is a language identifier supported by the configured Infobip
  /// widget. It is forwarded to the native SDK and is not persisted by Dart.
  Future<void> setLanguage(String language) async {
    if (language.trim().isEmpty) {
      throw ArgumentError.value(language, 'language', 'must not be empty');
    }
    final bridge = _requireBridge();
    await bridge.channel.invokeMethod<void>(
      ChannelContract.chatSetLanguage,
      <String, Object>{ChannelContract.language: language},
    );
  }

  /// Returns the language currently reported by this Chat component.
  Future<String> getLanguage() async {
    final bridge = _requireBridge();
    final language = await bridge.channel.invokeMethod<String>(
      ChannelContract.chatGetLanguage,
    );
    if (language == null) {
      throw PlatformException(
        code: 'native_error',
        message: 'Chat language is unavailable',
      );
    }
    return language;
  }

  /// Sets the configured widget theme name for this Chat component.
  ///
  /// This is an Infobip widget theme identifier, not a Flutter [ThemeData]
  /// value or an Android resource identifier.
  Future<void> setWidgetTheme(String widgetTheme) async {
    if (widgetTheme.trim().isEmpty) {
      throw ArgumentError.value(
        widgetTheme,
        'widgetTheme',
        'must not be empty',
      );
    }
    final bridge = _requireBridge();
    await bridge.channel.invokeMethod<void>(
      ChannelContract.chatSetWidgetTheme,
      <String, Object>{ChannelContract.widgetTheme: widgetTheme},
    );
  }

  /// Returns the widget theme name currently reported by this component.
  Future<String?> getWidgetTheme() async {
    final bridge = _requireBridge();
    return bridge.channel.invokeMethod<String>(
      ChannelContract.chatGetWidgetTheme,
    );
  }

  /// Lets Chat consume its internal back navigation.
  ///
  /// Returns `false` when the controller is not attached. When it returns
  /// `false`, the Flutter route may be popped.
  Future<bool> navigateBackOrCloseChat() async {
    final bridge = _bridge;
    if (bridge == null) return false;
    final handled = await bridge.channel.invokeMethod<Object?>(
      ChannelContract.chatNavigateBack,
    );
    if (handled is! bool) {
      throw const FormatException('Invalid Chat navigation result');
    }
    return handled;
  }

  /// Shows the native conversation list for a multithread Chat widget.
  ///
  /// This controller must be attached to a live [InfobipHuaweiChatView].
  Future<void> showThreadsList() async {
    final bridge = _requireBridge();
    await bridge.channel.invokeMethod<void>(
      ChannelContract.chatShowThreadsList,
    );
  }

  /// Returns whether the attached native Chat fragment supports threads.
  Future<bool> isMultithread() async {
    final bridge = _requireBridge();
    final value = await bridge.channel.invokeMethod<Object?>(
      ChannelContract.chatIsMultithread,
    );
    if (value is! bool) {
      throw const FormatException('Invalid Chat multithread result');
    }
    return value;
  }

  _ChatViewBridge _requireBridge() {
    final bridge = _bridge;
    if (bridge == null) {
      throw PlatformException(
        code: 'chat_unavailable',
        message: 'Chat view is unavailable',
      );
    }
    return bridge;
  }

  void _attach(_ChatViewBridge bridge) {
    final viewId = bridge.viewId;
    if (_viewId != null && _viewId != viewId) {
      throw StateError('A Chat controller can only control one active view.');
    }
    _viewId = viewId;
    _bridge = bridge;
  }

  void _detach(int? viewId) {
    if (_viewId != viewId) return;
    _viewId = null;
    _bridge = null;
  }
}

/// Embeds the Infobip native Chat UI inside Flutter-provided bounds.
///
/// The native view owns the message composer and attachments. Put this widget
/// in a Flutter [Scaffold] body to retain Flutter navigation and app bars.
class InfobipHuaweiChatView extends StatefulWidget {
  const InfobipHuaweiChatView({
    super.key,
    this.controller,
    this.withInput = true,
    this.withToolbar = false,
    this.onError,
    this.onEvent,
  });

  final InfobipHuaweiChatController? controller;

  /// Whether the native Infobip message composer is displayed.
  final bool withInput;

  /// Whether the native Infobip toolbar is displayed.
  ///
  /// This defaults to `false` because Flutter applications commonly provide
  /// their own app bar and route navigation.
  final bool withToolbar;

  /// Called for lifecycle and availability failures affecting this view.
  ///
  /// Controller command failures continue to complete their returned Future
  /// with a [PlatformException].
  final InfobipHuaweiChatErrorCallback? onError;

  /// Receives ordered runtime events belonging only to this native Chat view.
  ///
  /// Native events that arrive while Flutter attaches are replayed from a
  /// bounded per-view buffer. No events are delivered after disposal.
  final InfobipHuaweiChatEventCallback? onEvent;

  @override
  State<InfobipHuaweiChatView> createState() => _InfobipHuaweiChatViewState();
}

class _InfobipHuaweiChatViewState extends State<InfobipHuaweiChatView> {
  int? _viewId;
  _ChatViewBridge? _bridge;

  @override
  void didUpdateWidget(InfobipHuaweiChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(_viewId);
      final viewId = _viewId;
      final bridge = _bridge;
      if (viewId != null && bridge != null) widget.controller?._attach(bridge);
    }
    _bridge?.updateErrorCallback(widget.onError);
    _bridge?.updateEventCallback(widget.onEvent);
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Center(child: Text('Chat is available on Android only.'));
    }
    return AndroidView(
      viewType: ChannelContract.chatView,
      creationParams: <String, bool>{
        'withInput': widget.withInput,
        'withToolbar': widget.withToolbar,
      },
      creationParamsCodec: const StandardMessageCodec(),

      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },

      onPlatformViewCreated: (viewId) {
        widget.controller?._detach(_viewId);
        _bridge?.dispose();

        _viewId = viewId;

        final bridge = _ChatViewBridge(viewId, widget.onError, widget.onEvent);

        _bridge = bridge;
        widget.controller?._attach(bridge);
      },
    );
  }

  @override
  void dispose() {
    widget.controller?._detach(_viewId);
    _bridge?.dispose();
    _bridge = null;
    super.dispose();
  }
}
