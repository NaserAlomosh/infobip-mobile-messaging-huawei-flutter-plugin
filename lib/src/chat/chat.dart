import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform/channel_contract.dart';
import '../platform/infobip_mobilemessaging_huawei_platform.dart';

/// Presentation used when a Chat notification is tapped on Android.
enum ChatNotificationPresentationMode { embedded, native }

/// An embedded Chat route request retained natively until acknowledged.
final class ChatNotificationNavigationRequest {
  const ChatNotificationNavigationRequest({
    required this.correlationId,
    this.threadId,
  });
  final String correlationId;
  final String? threadId;

  static ChatNotificationNavigationRequest? decode(Object? value) {
    if (value is! Map ||
        value['correlationId'] is! String ||
        (value['correlationId'] as String).isEmpty) {
      return null;
    }
    if (value['threadId'] != null && value['threadId'] is! String) return null;
    return ChatNotificationNavigationRequest(
      correlationId: value['correlationId'] as String,
      threadId: value['threadId'] as String?,
    );
  }
}

/// Global APIs for the Infobip Chat session.
final class InfobipHuaweiChat {
  InfobipHuaweiChat._();

  static final InfobipHuaweiChat instance = InfobipHuaweiChat._();

  /// Persists notification presentation across process restarts.
  ///
  /// Native is the default. When opting into embedded routing, handle
  /// [onNotificationNavigationRequested] at app level,
  /// query pending requests on startup/resume, then acknowledge after route opening.
  /// Native mode delegates navigation to the SDK; generic tap events remain informational.
  Future<void> setNotificationPresentationMode(
    ChatNotificationPresentationMode mode,
  ) => InfobipMobileMessagingHuaweiPlatform.instance
      .setChatNotificationPresentationMode(mode.name);

  /// Wakes the app's single route handler. Delivery does not consume the request.
  /// Query [getPendingNotificationNavigation] after subscription and on resume too.
  Stream<ChatNotificationNavigationRequest>
  get onNotificationNavigationRequested =>
      InfobipMobileMessagingHuaweiPlatform.instance.events.transform(
        StreamTransformer<
          Object?,
          ChatNotificationNavigationRequest
        >.fromHandlers(
          handleData: (event, sink) {
            if (event is! Map ||
                event['version'] != ChannelContract.eventVersion ||
                event['type'] !=
                    ChannelContract.chatNotificationNavigationRequested) {
              return;
            }
            final request = ChatNotificationNavigationRequest.decode(
              event['payload'],
            );
            if (request != null) {
              if (kDebugMode) {
                debugPrint(
                  'CHAT_EVENT_RECEIVED_BY_FLUTTER correlationId=${request.correlationId}',
                );
              }
              sink.add(request);
            }
          },
        ),
      );

  /// Returns the oldest request without removing it. Works without an EventChannel listener.
  Future<ChatNotificationNavigationRequest?>
  getPendingNotificationNavigation() async {
    final request = ChatNotificationNavigationRequest.decode(
      await InfobipMobileMessagingHuaweiPlatform.instance
          .getPendingChatNotificationNavigation(),
    );
    if (kDebugMode && request != null) {
      debugPrint(
        'CHAT_EVENT_RECEIVED_BY_FLUTTER correlationId=${request.correlationId}',
      );
    }
    return request;
  }

  /// Call only after the Navigator opens or reuses the embedded Chat route.
  /// This also hands the preserved thread target to the loaded native fragment.
  Future<bool> acknowledgeNotificationNavigation(String correlationId) =>
      InfobipMobileMessagingHuaweiPlatform.instance
          .acknowledgeChatNotificationNavigation(correlationId);

  /// Returns the current number of unread Chat messages.
  Future<int> getUnreadMessageCount() =>
      InfobipMobileMessagingHuaweiPlatform.instance.getChatUnreadMessageCount();

  /// Returns whether Live Chat is available for the current installation.
  Future<bool> isChatAvailable() =>
      InfobipMobileMessagingHuaweiPlatform.instance.isChatAvailable();

  /// Returns the current number of unread Chat messages.
  ///
  /// [getUnreadMessageCount] remains available as a backward-compatible alias.
  Future<int> getMessageCounter() =>
      InfobipMobileMessagingHuaweiPlatform.instance.getChatUnreadMessageCount();

  /// Resets the SDK-managed unread Chat message counter.
  Future<void> resetMessageCounter() =>
      InfobipMobileMessagingHuaweiPlatform.instance.resetChatMessageCounter();

  /// Emits future native unread-counter updates without replaying a value.
  Stream<int> get onUnreadMessageCounterUpdated =>
      InfobipMobileMessagingHuaweiPlatform.instance.events.transform(
        StreamTransformer<Object?, int>.fromHandlers(
          handleData: (event, sink) {
            if (event is! Map ||
                event['version'] != ChannelContract.eventVersion ||
                event['type'] !=
                    ChannelContract.chatUnreadMessageCounterUpdated ||
                event['payload'] is! Map) {
              return;
            }
            final count = (event['payload'] as Map)['count'];
            if (count is int && count >= 0) sink.add(count);
          },
        ),
      );
}
