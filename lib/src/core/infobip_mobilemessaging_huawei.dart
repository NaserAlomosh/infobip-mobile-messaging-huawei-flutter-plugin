import 'dart:async';

import '../notifications/notifications.dart';
import '../platform/channel_contract.dart';
import '../platform/infobip_mobilemessaging_huawei_platform.dart';
import '../user/user.dart';
import '../installation/installation.dart';
import '../inbox/inbox.dart';
import '../chat/chat.dart';
import '../chat/chat_exception.dart';
import '../chat/chat_customization.dart';
import '../custom_event/custom_event.dart';
import '../configuration/web_rtc_ui.dart';

/// Entry point for the Infobip Huawei Mobile Messaging plugin.
final class InfobipMobileMessagingHuawei {
  InfobipMobileMessagingHuawei._();

  /// Whether the SDK's SQLite-backed default message store is used by the
  /// next native initialization.
  ///
  /// Configure this before [initialize]. Changing it does not reconfigure an
  /// already initialized SDK; it takes effect after [cleanup] and a subsequent
  /// initialization.
  static bool defaultMessageStorage = true;

  /// Notification and registration lifecycle events.
  static InfobipHuaweiNotifications get notifications =>
      InfobipHuaweiNotifications.instance;

  /// Global Chat state and events.
  static InfobipHuaweiChat get chat => InfobipHuaweiChat.instance;

  /// Applies global customization to the native Chat interface.
  static Future<void> setChatCustomization(ChatCustomization customization) =>
      InfobipMobileMessagingHuaweiPlatform.instance.setChatCustomization(
        customization,
      );

  /// Sets the title override used by future Chat push notifications on Android.
  ///
  /// Passing `null` removes the override. Empty and whitespace-only strings are
  /// forwarded unchanged.
  static Future<void> setChatPushTitle(String? title) =>
      InfobipMobileMessagingHuaweiPlatform.instance.setChatPushTitle(title);

  /// Sets the body override used by future Chat push notifications on Android.
  ///
  /// Passing `null` removes the override. Empty and whitespace-only strings are
  /// forwarded unchanged.
  static Future<void> setChatPushBody(String? body) =>
      InfobipMobileMessagingHuaweiPlatform.instance.setChatPushBody(body);

  /// Presents the standard native Chat screen.
  ///
  /// [shouldBePresentedModallyIOS] is retained for compatibility with the
  /// official Flutter API and is ignored on Huawei Android.
  static Future<void> showChat({bool shouldBePresentedModallyIOS = true}) =>
      InfobipMobileMessagingHuaweiPlatform.instance.showChat(
        shouldBePresentedModallyIOS: shouldBePresentedModallyIOS,
      );

  static Future<String> Function()? _chatJwtProvider;
  static void Function(Object error)? _chatJwtProviderErrorHandler;
  static StreamSubscription<Object?>? _chatJwtSubscription;
  static Future<void> Function(ChatException exception)? _chatExceptionHandler;
  static void Function(Object error)? _chatExceptionErrorHandler;
  static StreamSubscription<Object?>? _chatExceptionSubscription;

  /// Initializes the native SDK with an Infobip application code.
  ///
  /// Equivalent calls are idempotent. A different application code is rejected
  /// once initialization has started.
  static Future<void> initialize({
    required String applicationCode,
    WebRTCUI? webRTCUI,
  }) {
    if (applicationCode.trim().isEmpty) {
      throw ArgumentError.value(
        applicationCode,
        'applicationCode',
        'Must not be empty or whitespace-only',
      );
    }
    return InfobipMobileMessagingHuaweiPlatform.instance.initialize(
      applicationCode: applicationCode,
      defaultMessageStorage: defaultMessageStorage,
      webRTCUI: webRTCUI,
    );
  }

  /// Removes local Mobile Messaging SDK data and state.
  ///
  /// Initialize the SDK again before further use. For signing a user out, use
  /// [depersonalize] instead.
  static Future<void> cleanup() async {
    try {
      await InfobipMobileMessagingHuaweiPlatform.instance.cleanup();
    } finally {
      _chatJwtProvider = null;
      _chatJwtProviderErrorHandler = null;
      await _chatJwtSubscription?.cancel();
      _chatJwtSubscription = null;
      _chatExceptionHandler = null;
      _chatExceptionErrorHandler = null;
      await _chatExceptionSubscription?.cancel();
      _chatExceptionSubscription = null;
    }
  }

  /// Enables incoming calls for [identity].
  static Future<void> enableCalls(String identity) =>
      InfobipMobileMessagingHuaweiPlatform.instance.enableCalls(identity);

  /// Enables calls initiated from the in-app Chat interface.
  static Future<void> enableChatCalls() =>
      InfobipMobileMessagingHuaweiPlatform.instance.enableChatCalls();

  /// Disables calls on the currently enabled WebRTC UI instance.
  static Future<void> disableCalls() =>
      InfobipMobileMessagingHuaweiPlatform.instance.disableCalls();

  /// Asks the Infobip SDK to register this installation for remote
  /// notifications.
  ///
  /// The host application must obtain Android notification permission first.
  static Future<void> registerForRemoteNotifications() =>
      InfobipMobileMessagingHuaweiPlatform.instance
          .registerForRemoteNotifications();

  /// Marks regular Mobile Messaging messages as seen.
  ///
  /// Completion means the command was accepted locally by the native SDK;
  /// seen-status reporting to the backend may happen asynchronously.
  static Future<void> markMessagesSeen(List<String> messageIds) =>
      InfobipMobileMessagingHuaweiPlatform.instance.markMessagesSeen(
        messageIds,
      );

  /// Returns the locally cached user without making a server request.
  static Future<UserData> getUser() =>
      InfobipMobileMessagingHuaweiPlatform.instance.getUser();

  /// Refreshes and returns the user from Infobip services.
  static Future<UserData> fetchUser() =>
      InfobipMobileMessagingHuaweiPlatform.instance.fetchUser();

  /// Saves the supplied profile and completes with the resulting user.
  static Future<UserData> saveUser(UserData user) =>
      InfobipMobileMessagingHuaweiPlatform.instance.saveUser(user);

  /// Associates this installation with the supplied user context.
  static Future<UserData> personalize(PersonalizeContext context) =>
      InfobipMobileMessagingHuaweiPlatform.instance.personalize(
        context.userIdentity,
        context.userAttributes,
        forceDepersonalize: context.forceDepersonalize,
      );

  /// Compatibility helper for the pre-v1 positional personalization API.
  @Deprecated('Use personalize(PersonalizeContext(...))')
  static Future<UserData> personalizeUser(
    UserIdentity userIdentity, [
    UserAttributes? userAttributes,
    bool forceDepersonalize = false,
  ]) => InfobipMobileMessagingHuaweiPlatform.instance.personalize(
    userIdentity,
    userAttributes,
    forceDepersonalize: forceDepersonalize,
  );

  /// Removes the current personalization on the Infobip service.
  static Future<void> depersonalize() =>
      InfobipMobileMessagingHuaweiPlatform.instance.depersonalize();

  /// Queues [event] for submission using the Huawei SDK.
  static Future<void> submitEvent(InfobipHuaweiCustomEvent event) =>
      InfobipMobileMessagingHuaweiPlatform.instance.submitEvent(event);

  /// Submits [event] and completes after the Huawei SDK callback succeeds.
  static Future<InfobipHuaweiCustomEvent> submitEventImmediately(
    InfobipHuaweiCustomEvent event,
  ) => InfobipMobileMessagingHuaweiPlatform.instance.submitEventImmediately(
    event,
  );

  /// Depersonalizes the installation identified by [pushRegistrationId].
  static Future<List<Installation>> depersonalizeInstallation(
    String pushRegistrationId,
  ) {
    final id = pushRegistrationId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(
        pushRegistrationId,
        'pushRegistrationId',
        'Must not be empty or whitespace-only',
      );
    }
    return InfobipMobileMessagingHuaweiPlatform.instance
        .depersonalizeInstallation(id);
  }

  /// Changes primary status for the installation identified by its push ID.
  static Future<List<Installation>> setInstallationAsPrimary({
    required String pushRegistrationId,
    required bool isPrimary,
  }) {
    final id = pushRegistrationId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(
        pushRegistrationId,
        'pushRegistrationId',
        'Must not be empty or whitespace-only',
      );
    }
    return InfobipMobileMessagingHuaweiPlatform.instance
        .setInstallationAsPrimary(pushRegistrationId: id, isPrimary: isPrimary);
  }

  /// Configures the memory-only Infobip JWT used by native SDK requests.
  ///
  /// Passing `null` or a whitespace-only value clears the current JWT.
  static Future<void> setJwt(String? jwt) =>
      InfobipMobileMessagingHuaweiPlatform.instance.setJwt(
        jwt?.trim().isEmpty == true ? null : jwt?.trim(),
      );

  /// Registers the asynchronous provider used for In-App Chat authentication.
  ///
  /// The native Chat SDK may invoke [jwtProvider] repeatedly, including after
  /// reconnection and lifecycle changes. Return a fresh, non-empty JWT for
  /// every invocation. This provider is separate from [setJwt], which
  /// configures Mobile Messaging and Inbox authorization.
  static Future<void> setChatJwtProvider(
    Future<String> Function() jwtProvider, [
    void Function(Object error)? onError,
  ]) async {
    _chatJwtProvider = jwtProvider;
    _chatJwtProviderErrorHandler = onError;
    await _chatJwtSubscription?.cancel();
    _chatJwtSubscription = InfobipMobileMessagingHuaweiPlatform.instance.events
        .where(_isChatJwtRequest)
        .listen((_) => _provideChatJwt());
    try {
      await InfobipMobileMessagingHuaweiPlatform.instance.setChatJwtProvider();
    } on Object {
      _chatJwtProvider = null;
      _chatJwtProviderErrorHandler = null;
      await _chatJwtSubscription?.cancel();
      _chatJwtSubscription = null;
      rethrow;
    }
  }

  /// Registers a handler for exceptions reported by the native Chat widget.
  ///
  /// Passing `null` removes the custom handler and restores the native SDK's
  /// default exception handling.
  static Future<void> setChatExceptionHandler(
    Future<void> Function(ChatException exception)? exceptionHandler, [
    void Function(Object error)? onError,
  ]) async {
    await _chatExceptionSubscription?.cancel();
    _chatExceptionSubscription = null;
    _chatExceptionHandler = exceptionHandler;
    _chatExceptionErrorHandler = exceptionHandler == null ? null : onError;

    if (exceptionHandler != null) {
      _chatExceptionSubscription = InfobipMobileMessagingHuaweiPlatform
          .instance
          .events
          .where(_isChatException)
          .listen(_handleChatException);
    }

    try {
      await InfobipMobileMessagingHuaweiPlatform.instance
          .setChatExceptionHandler(enabled: exceptionHandler != null);
    } on Object {
      _chatExceptionHandler = null;
      _chatExceptionErrorHandler = null;
      await _chatExceptionSubscription?.cancel();
      _chatExceptionSubscription = null;
      rethrow;
    }
  }

  static bool _isChatException(Object? event) =>
      event is Map &&
      event['version'] == ChannelContract.eventVersion &&
      event['type'] == ChannelContract.chatException &&
      event['payload'] is Map;

  static Future<void> _handleChatException(Object? event) async {
    final handler = _chatExceptionHandler;
    if (handler == null || event is! Map) return;
    final payload = event['payload'];
    if (payload is! Map) return;
    final message = payload[ChannelContract.message];
    final name = payload[ChannelContract.name];
    if ((message != null && message is! String) ||
        (name != null && name is! String)) {
      return;
    }
    final errorHandler = _chatExceptionErrorHandler;
    try {
      await handler(
        ChatException(message: message as String?, name: name as String?),
      );
    } on Object catch (error) {
      try {
        errorHandler?.call(error);
      } on Object {
        // Host callback failures must not terminate the native event stream.
      }
    }
  }

  static bool _isChatJwtRequest(Object? event) =>
      event is Map &&
      event['version'] == ChannelContract.eventVersion &&
      event['type'] == ChannelContract.chatJwtRequested &&
      event['payload'] is Map;

  static Future<void> _provideChatJwt() async {
    final platform = InfobipMobileMessagingHuaweiPlatform.instance;
    final provider = _chatJwtProvider;
    if (provider == null) {
      await _rejectChatJwt(platform, 'Chat JWT provider is not registered');
      return;
    }
    late final String jwt;
    try {
      jwt = (await provider()).trim();
      if (jwt.isEmpty) {
        throw const FormatException('Chat JWT must not be empty');
      }
    } on Object catch (error) {
      try {
        _chatJwtProviderErrorHandler?.call(error);
      } on Object {
        // A host error handler must not prevent the native callback completing.
      }
      await _rejectChatJwt(platform, 'Unable to provide Chat JWT');
      return;
    }
    try {
      await platform.resolveChatJwt(jwt);
    } on Object {
      // Native teardown may race an in-flight provider result.
    }
  }

  static Future<void> _rejectChatJwt(
    InfobipMobileMessagingHuaweiPlatform platform,
    String error,
  ) async {
    try {
      await platform.rejectChatJwt(error);
    } on Object {
      // Native teardown may race an in-flight provider failure.
    }
  }

  /// Returns the locally cached installation without network access.
  static Future<Installation> getInstallation() =>
      InfobipMobileMessagingHuaweiPlatform.instance.getInstallation();

  /// Refreshes and returns the installation from Infobip services.
  static Future<Installation> fetchInstallation() =>
      InfobipMobileMessagingHuaweiPlatform.instance.fetchInstallation();

  /// Saves writable installation properties and returns the resulting state.
  static Future<Installation> saveInstallation(Installation installation) =>
      InfobipMobileMessagingHuaweiPlatform.instance.saveInstallation(
        installation,
      );

  /// Fetches Inbox messages for [externalUserId].
  ///
  /// A non-empty [jwt] overrides the globally configured JWT. When [jwt] is
  /// absent or whitespace-only, the native SDK uses the global JWT, if set,
  /// and otherwise uses Application Code authorization.
  static Future<Inbox> fetchInbox({
    required String externalUserId,
    String? jwt,
    FilterOptions? options,
  }) {
    if (externalUserId.trim().isEmpty) {
      throw ArgumentError.value(
        externalUserId,
        'externalUserId',
        'Must not be empty or whitespace-only',
      );
    }
    return InfobipMobileMessagingHuaweiPlatform.instance.fetchInbox(
      externalUserId: externalUserId,
      jwt: jwt?.trim().isEmpty == true ? null : jwt?.trim(),
      options: options,
    );
  }

  /// Marks the Inbox messages identified by [messageIds] as seen.
  static Future<void> setInboxMessagesSeen({
    required String externalUserId,
    required List<String> messageIds,
  }) {
    if (externalUserId.trim().isEmpty) {
      throw ArgumentError.value(
        externalUserId,
        'externalUserId',
        'Must not be empty or whitespace-only',
      );
    }
    if (messageIds.isEmpty || messageIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError.value(messageIds, 'messageIds', 'Must not be empty');
    }
    return InfobipMobileMessagingHuaweiPlatform.instance.setInboxMessagesSeen(
      externalUserId: externalUserId,
      messageIds: List.unmodifiable(messageIds),
    );
  }
}
