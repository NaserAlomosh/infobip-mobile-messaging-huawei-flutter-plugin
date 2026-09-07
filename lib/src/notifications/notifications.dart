import 'dart:async';

import '../platform/channel_contract.dart';
import '../platform/infobip_mobilemessaging_huawei_platform.dart';
import 'notification_events.dart';
import 'message.dart';
import 'push_message_codec.dart';
import '../installation/installation.dart';
import '../installation/installation_codec.dart';
import '../user/user.dart';
import '../user/user_codec.dart';

/// Notification and registration lifecycle events.
final class InfobipHuaweiNotifications {
  InfobipHuaweiNotifications._();

  static final InfobipHuaweiNotifications instance =
      InfobipHuaweiNotifications._();

  Stream<Object?> get _events =>
      InfobipMobileMessagingHuaweiPlatform.instance.events;

  Stream<Message> get onMessageReceived =>
      _typed(ChannelContract.messageReceived, _message);

  Stream<Message> get onNotificationTapped =>
      _typed(ChannelContract.notificationTapped, _message);

  Stream<NotificationActionEvent> get onNotificationActionTapped => _typed(
    ChannelContract.notificationActionTapped,
    (payload) => NotificationActionEvent(
      actionId: payload['actionId'] as String?,
      message: _message(payload),
    ),
  );

  /// Emits the complete installation when push registration changes.
  Stream<Installation> get onRegistrationUpdated =>
      _typed(ChannelContract.registrationUpdated, _installation);

  /// Emits when the native SDK updates the installation.
  Stream<Installation> get onInstallationUpdated =>
      _typed(ChannelContract.installationUpdated, _installation);

  /// Emits the user delivered by the Huawei `USER_UPDATED` broadcast.
  Stream<User> get onUserUpdated => _typed(ChannelContract.userUpdated, _user);

  /// Emits the user delivered by the Huawei `PERSONALIZED` broadcast.
  Stream<User> get onPersonalized =>
      _typed(ChannelContract.personalized, _user);

  /// Emits when the Huawei SDK reports that depersonalization completed.
  Stream<void> get onDepersonalized => _signal(ChannelContract.depersonalized);

  Stream<void> _signal(String type) => _events.transform(
    StreamTransformer<Object?, void>.fromHandlers(
      handleData: (event, sink) {
        if (event is Map &&
            event['version'] == ChannelContract.eventVersion &&
            event['type'] == type &&
            event['payload'] is Map) {
          sink.add(null);
        }
      },
    ),
  );

  Stream<T> _typed<T>(
    String type,
    T Function(Map<Object?, Object?> payload) decode,
  ) => _events.transform(
    StreamTransformer<Object?, T>.fromHandlers(
      handleData: (event, sink) {
        if (event is! Map ||
            event['version'] != ChannelContract.eventVersion ||
            event['type'] != type ||
            event['payload'] is! Map) {
          return;
        }
        try {
          sink.add(decode(event['payload'] as Map<Object?, Object?>));
        } on Object {
          // Malformed native events are ignored without terminating subscriptions.
        }
      },
    ),
  );

  static Message _message(Map<Object?, Object?> payload) {
    final message = payload['message'];
    if (message is! Map) throw const FormatException('Missing message');
    return PushMessageCodec.decode(message.cast<Object?, Object?>());
  }

  static Installation _installation(Map<Object?, Object?> payload) =>
      InstallationCodec.decode(payload[ChannelContract.installation]);

  static User _user(Map<Object?, Object?> payload) =>
      UserCodec.decode(payload[ChannelContract.user]);
}
