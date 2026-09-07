import 'dart:convert';

import 'package:flutter/services.dart';

import 'channel_contract.dart';
import 'infobip_mobilemessaging_huawei_platform.dart';
import '../user/user.dart';
import '../user/user_codec.dart';
import '../installation/installation.dart';
import '../installation/installation_codec.dart';
import '../inbox/inbox.dart';
import '../inbox/inbox_codec.dart';
import '../custom_event/custom_event.dart';
import '../custom_event/custom_event_codec.dart';
import '../chat/chat_customization.dart';
import '../configuration/web_rtc_ui.dart';

final class MethodChannelInfobipMobileMessagingHuawei
    extends InfobipMobileMessagingHuaweiPlatform {
  MethodChannelInfobipMobileMessagingHuawei({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : methodChannel =
           methodChannel ?? const MethodChannel(ChannelContract.methodChannel),
       eventChannel =
           eventChannel ?? const EventChannel(ChannelContract.eventChannel) {
    _events = this.eventChannel.receiveBroadcastStream();
  }

  final MethodChannel methodChannel;
  final EventChannel eventChannel;
  late final Stream<Object?> _events;

  @override
  Stream<Object?> get events => _events;

  @override
  Future<int> getChatUnreadMessageCount() async {
    final result = await methodChannel.invokeMethod<Object?>(
      ChannelContract.getChatUnreadMessageCount,
    );
    if (result is! int || result < 0) {
      throw const FormatException('Invalid Chat unread message count');
    }
    return result;
  }

  @override
  Future<bool> isChatAvailable() async {
    final result = await methodChannel.invokeMethod<Object?>(
      ChannelContract.isChatAvailable,
    );
    if (result is! bool) {
      throw const FormatException('Invalid Chat availability result');
    }
    return result;
  }

  @override
  Future<void> resetChatMessageCounter() => methodChannel.invokeMethod<void>(
    ChannelContract.resetChatMessageCounter,
  );

  @override
  Future<void> initialize({
    required String applicationCode,
    bool defaultMessageStorage = true,
    WebRTCUI? webRTCUI,
  }) async {
    final arguments = <String, Object?>{
      ChannelContract.applicationCode: applicationCode,
      ChannelContract.defaultMessageStorage: defaultMessageStorage,
    };
    if (webRTCUI != null) {
      arguments[ChannelContract.webRTCUI] = <String, Object?>{
        ChannelContract.configurationId: webRTCUI.configurationId,
      };
    }
    await methodChannel.invokeMethod<void>(
      ChannelContract.initialize,
      arguments,
    );
  }

  @override
  Future<void> cleanup() =>
      methodChannel.invokeMethod<void>(ChannelContract.cleanup);

  @override
  Future<void> enableCalls(String identity) =>
      methodChannel.invokeMethod<void>(ChannelContract.enableCalls, identity);

  @override
  Future<void> enableChatCalls() =>
      methodChannel.invokeMethod<void>(ChannelContract.enableChatCalls);

  @override
  Future<void> disableCalls() =>
      methodChannel.invokeMethod<void>(ChannelContract.disableCalls);

  @override
  Future<void> registerForRemoteNotifications() => methodChannel
      .invokeMethod<void>(ChannelContract.registerForRemoteNotifications);

  @override
  Future<void> markMessagesSeen(List<String> messageIds) => methodChannel
      .invokeMethod<void>(ChannelContract.markMessagesSeen, messageIds);

  @override
  Future<UserData> getUser() async => UserCodec.decode(
    await methodChannel.invokeMethod<Object?>(ChannelContract.getUser),
  );

  @override
  Future<UserData> fetchUser() async => UserCodec.decode(
    await methodChannel.invokeMethod<Object?>(ChannelContract.fetchUser),
  );

  @override
  Future<UserData> saveUser(UserData user) async => UserCodec.decode(
    await methodChannel.invokeMethod<Object?>(ChannelContract.saveUser, {
      ChannelContract.user: UserCodec.encode(user),
    }),
  );

  @override
  Future<UserData> personalize(
    UserIdentity userIdentity,
    UserAttributes? userAttributes, {
    required bool forceDepersonalize,
  }) async => UserCodec.decode(
    await methodChannel.invokeMethod<Object?>(ChannelContract.personalize, {
      ChannelContract.userIdentity: UserCodec.encodeIdentity(userIdentity),
      ChannelContract.userAttributes: userAttributes == null
          ? null
          : UserCodec.encodeAttributes(userAttributes),
      ChannelContract.forceDepersonalize: forceDepersonalize,
    }),
  );

  @override
  Future<void> depersonalize() =>
      methodChannel.invokeMethod<void>(ChannelContract.depersonalize);

  @override
  Future<void> submitEvent(InfobipHuaweiCustomEvent event) => methodChannel
      .invokeMethod<void>(ChannelContract.submitEvent, {
        ChannelContract.customEvent: CustomEventCodec.encode(event),
      });

  @override
  Future<InfobipHuaweiCustomEvent> submitEventImmediately(
    InfobipHuaweiCustomEvent event,
  ) async => CustomEventCodec.decode(
    await methodChannel.invokeMethod<Object?>(
      ChannelContract.submitEventImmediately,
      {ChannelContract.customEvent: CustomEventCodec.encode(event)},
    ),
  );

  @override
  Future<List<Installation>> depersonalizeInstallation(
    String pushRegistrationId,
  ) async => _installationList(
    await methodChannel.invokeMethod<Object?>(
      ChannelContract.depersonalizeInstallation,
      {ChannelContract.pushRegistrationId: pushRegistrationId},
    ),
  );

  @override
  Future<List<Installation>> setInstallationAsPrimary({
    required String pushRegistrationId,
    required bool isPrimary,
  }) async => _installationList(
    await methodChannel.invokeMethod<Object?>(
      ChannelContract.setInstallationAsPrimary,
      {
        ChannelContract.pushRegistrationId: pushRegistrationId,
        ChannelContract.isPrimary: isPrimary,
      },
    ),
  );

  static List<Installation> _installationList(Object? value) {
    if (value is! List) {
      throw const FormatException('Installations payload must be a list.');
    }
    return List<Installation>.unmodifiable(value.map(InstallationCodec.decode));
  }

  @override
  Future<void> setJwt(String? jwt) => methodChannel.invokeMethod<void>(
    ChannelContract.setJwt,
    {ChannelContract.jwt: jwt?.trim().isEmpty == true ? null : jwt?.trim()},
  );

  @override
  Future<void> setChatJwtProvider() => methodChannel.invokeMethod<void>(
    ChannelContract.setChatJwtProvider,
  );

  @override
  Future<void> setChatExceptionHandler({required bool enabled}) => methodChannel
      .invokeMethod<void>(ChannelContract.setChatExceptionHandler, {
        ChannelContract.enabled: enabled,
      });

  @override
  Future<void> setChatCustomization(ChatCustomization customization) =>
      methodChannel.invokeMethod<void>(
        ChannelContract.setChatCustomization,
        jsonEncode(customization.toJson()),
      );

  @override
  Future<void> setChatPushTitle(String? title) =>
      methodChannel.invokeMethod<void>(ChannelContract.setChatPushTitle, title);

  @override
  Future<void> setChatPushBody(String? body) =>
      methodChannel.invokeMethod<void>(ChannelContract.setChatPushBody, body);

  @override
  Future<void> showChat({required bool shouldBePresentedModallyIOS}) =>
      methodChannel.invokeMethod<void>(
        ChannelContract.showChat,
        shouldBePresentedModallyIOS,
      );

  @override
  Future<void> resolveChatJwt(String jwt) => methodChannel.invokeMethod<void>(
    ChannelContract.resolveChatJwt,
    {ChannelContract.jwt: jwt},
  );

  @override
  Future<void> rejectChatJwt(String error) => methodChannel.invokeMethod<void>(
    ChannelContract.rejectChatJwt,
    {ChannelContract.error: error},
  );

  @override
  Future<Installation> getInstallation() async => InstallationCodec.decode(
    await methodChannel.invokeMethod<Object?>(ChannelContract.getInstallation),
  );

  @override
  Future<Installation> fetchInstallation() async => InstallationCodec.decode(
    await methodChannel.invokeMethod<Object?>(
      ChannelContract.fetchInstallation,
    ),
  );

  @override
  Future<Installation> saveInstallation(Installation installation) async =>
      InstallationCodec.decode(
        await methodChannel
            .invokeMethod<Object?>(ChannelContract.saveInstallation, {
              ChannelContract.installation: InstallationCodec.encodeWritable(
                installation,
              ),
            }),
      );

  @override
  Future<Inbox> fetchInbox({
    required String externalUserId,
    String? jwt,
    FilterOptions? options,
  }) async => InboxCodec.decode(
    await methodChannel.invokeMethod<Object?>(ChannelContract.fetchInbox, {
      ChannelContract.externalUserId: externalUserId,
      ChannelContract.jwt: jwt?.trim().isEmpty == true ? null : jwt?.trim(),
      ChannelContract.options: InboxCodec.encodeOptions(options),
    }),
  );

  @override
  Future<void> setInboxMessagesSeen({
    required String externalUserId,
    required List<String> messageIds,
  }) => methodChannel.invokeMethod<void>(ChannelContract.setInboxMessagesSeen, {
    ChannelContract.externalUserId: externalUserId,
    ChannelContract.messageIds: messageIds,
  });
}
