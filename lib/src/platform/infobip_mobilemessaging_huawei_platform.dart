import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_infobip_mobilemessaging_huawei.dart';
import '../user/user.dart';
import '../installation/installation.dart';
import '../inbox/inbox.dart';
import '../custom_event/custom_event.dart';
import '../chat/chat_customization.dart';

abstract class InfobipMobileMessagingHuaweiPlatform extends PlatformInterface {
  InfobipMobileMessagingHuaweiPlatform() : super(token: _token);

  static final Object _token = Object();

  static InfobipMobileMessagingHuaweiPlatform _instance =
      MethodChannelInfobipMobileMessagingHuawei();

  static InfobipMobileMessagingHuaweiPlatform get instance => _instance;

  static set instance(InfobipMobileMessagingHuaweiPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<Object?> get events;

  Future<void> initialize({required String applicationCode});

  Future<void> cleanup() => throw UnimplementedError();

  Future<void> registerForRemoteNotifications() => throw UnimplementedError();

  Future<int> getChatUnreadMessageCount() => throw UnimplementedError();

  Future<UserData> getUser() => throw UnimplementedError();

  Future<UserData> fetchUser() => throw UnimplementedError();

  Future<UserData> saveUser(UserData user) => throw UnimplementedError();

  Future<UserData> personalize(
    UserIdentity userIdentity,
    UserAttributes? userAttributes, {
    required bool forceDepersonalize,
  }) => throw UnimplementedError();

  Future<void> depersonalize() => throw UnimplementedError();

  Future<void> submitEvent(InfobipHuaweiCustomEvent event) =>
      throw UnimplementedError();

  Future<InfobipHuaweiCustomEvent> submitEventImmediately(
    InfobipHuaweiCustomEvent event,
  ) => throw UnimplementedError();

  Future<List<Installation>> depersonalizeInstallation(
    String pushRegistrationId,
  ) => throw UnimplementedError();

  Future<List<Installation>> setInstallationAsPrimary({
    required String pushRegistrationId,
    required bool isPrimary,
  }) => throw UnimplementedError();

  Future<void> setJwt(String? jwt) => throw UnimplementedError();

  Future<void> setChatJwtProvider() => throw UnimplementedError();

  Future<void> setChatExceptionHandler({required bool enabled}) =>
      throw UnimplementedError();

  Future<void> setChatCustomization(ChatCustomization customization) =>
      throw UnimplementedError();

  Future<void> resolveChatJwt(String jwt) => throw UnimplementedError();

  Future<void> rejectChatJwt(String error) => throw UnimplementedError();

  Future<Installation> getInstallation() => throw UnimplementedError();

  Future<Installation> fetchInstallation() => throw UnimplementedError();

  Future<Installation> saveInstallation(Installation installation) =>
      throw UnimplementedError();

  Future<Inbox> fetchInbox({
    required String externalUserId,
    String? jwt,
    FilterOptions? options,
  }) => throw UnimplementedError();

  Future<void> setInboxMessagesSeen({
    required String externalUserId,
    required List<String> messageIds,
  }) => throw UnimplementedError();
}
