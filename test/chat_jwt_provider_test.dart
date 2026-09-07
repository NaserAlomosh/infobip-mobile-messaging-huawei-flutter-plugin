import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class ChatJwtPlatform extends InfobipMobileMessagingHuaweiPlatform
    with MockPlatformInterfaceMixin {
  final eventsController = StreamController<Object?>.broadcast(sync: true);
  var registrations = 0;
  final resolved = <String>[];
  final responseIds = <String>[];
  final responseGenerations = <int>[];
  var nextRequest = 0;
  final rejected = <String>[];
  final globalJwts = <String?>[];

  @override
  Stream<Object?> get events => eventsController.stream;

  @override
  Future<void> initialize({
    required String applicationCode,
    bool defaultMessageStorage = true,
    WebRTCUI? webRTCUI,
  }) async {}

  @override
  Future<void> cleanup() async {}

  @override
  Future<void> setChatJwtProvider() async => registrations++;

  @override
  Future<void> resolveChatJwt(
    String jwt, {
    required String requestId,
    required int generation,
  }) async {
    resolved.add(jwt);
    responseIds.add(requestId);
    responseGenerations.add(generation);
  }

  @override
  Future<void> rejectChatJwt(
    String error, {
    required String requestId,
    required int generation,
  }) async {
    rejected.add(error);
    responseIds.add(requestId);
    responseGenerations.add(generation);
  }

  @override
  Future<void> setJwt(String? jwt) async => globalJwts.add(jwt);

  void requestJwt() => eventsController.add({
    'version': ChannelContract.eventVersion,
    'type': ChannelContract.chatJwtRequested,
    'timestamp': 1,
    'payload': <String, Object?>{
      'requestId': 'request-${++nextRequest}',
      'generation': registrations,
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatJwtPlatform platform;

  setUp(() {
    platform = ChatJwtPlatform();
    InfobipMobileMessagingHuaweiPlatform.instance = platform;
  });

  tearDown(() async {
    await InfobipMobileMessagingHuawei.cleanup();
    await platform.eventsController.close();
  });

  test('registers the native Chat JWT provider', () async {
    await InfobipMobileMessagingHuawei.setChatJwtProvider(() async => 'jwt');

    expect(platform.registrations, 1);
  });

  test('resolves every request with a freshly generated JWT', () async {
    var callCount = 0;
    await InfobipMobileMessagingHuawei.setChatJwtProvider(
      () async => 'token-${++callCount}',
    );

    platform.requestJwt();
    await pumpEventQueue();
    platform.requestJwt();
    await pumpEventQueue();

    expect(callCount, 2);
    expect(platform.resolved, ['token-1', 'token-2']);
    expect(platform.rejected, isEmpty);
  });

  test(
    'provider failure rejects native request without ending events',
    () async {
      final errors = <Object>[];
      var shouldThrow = true;
      await InfobipMobileMessagingHuawei.setChatJwtProvider(() async {
        if (shouldThrow) throw StateError('generation failed');
        return 'recovered-token';
      }, errors.add);

      platform.requestJwt();
      await pumpEventQueue();
      shouldThrow = false;
      platform.requestJwt();
      await pumpEventQueue();

      expect(errors.single, isA<StateError>());
      expect(platform.rejected, ['Unable to provide Chat JWT']);
      expect(platform.resolved, ['recovered-token']);
    },
  );

  for (final jwt in ['', '   ']) {
    test('rejects ${jwt.isEmpty ? 'empty' : 'whitespace-only'} JWT', () async {
      final errors = <Object>[];
      await InfobipMobileMessagingHuawei.setChatJwtProvider(
        () async => jwt,
        errors.add,
      );

      platform.requestJwt();
      await pumpEventQueue();

      expect(errors.single, isA<FormatException>());
      expect(platform.resolved, isEmpty);
      expect(platform.rejected, ['Unable to provide Chat JWT']);
    });
  }

  test('concurrent responses carry exact request correlation', () async {
    final futures = [Completer<String>(), Completer<String>()];
    var index = 0;
    await InfobipMobileMessagingHuawei.setChatJwtProvider(
      () => futures[index++].future,
    );
    platform.requestJwt();
    platform.requestJwt();
    futures[1].complete('second');
    await pumpEventQueue();
    futures[0].complete('first');
    await pumpEventQueue();
    expect(platform.responseIds, ['request-2', 'request-1']);
    expect(platform.responseGenerations, [1, 1]);
    expect(platform.resolved, ['second', 'first']);
  });

  for (final cleanup in [true, false]) {
    for (final fail in [true, false]) {
      test(
        'stale completion cleanup=$cleanup failure=$fail cannot reach new session',
        () async {
          final old = Completer<String>();
          final current = Completer<String>();
          final errors = <Object>[];
          await InfobipMobileMessagingHuawei.setChatJwtProvider(
            () => old.future,
            errors.add,
          );
          platform.requestJwt();
          if (cleanup) await InfobipMobileMessagingHuawei.cleanup();
          await InfobipMobileMessagingHuawei.setChatJwtProvider(
            () => current.future,
          );
          platform.requestJwt();
          if (fail) {
            old.completeError(StateError('old-secret'));
          } else {
            old.complete('old-secret');
          }
          await pumpEventQueue();
          expect(platform.resolved, isEmpty);
          expect(platform.rejected, isEmpty);
          expect(errors, isEmpty);
          current.complete('new-token');
          await pumpEventQueue();
          expect(platform.resolved, ['new-token']);
          expect(platform.responseIds, ['request-2']);
          expect(platform.responseGenerations, [2]);
        },
      );
    }
  }

  test('global setJwt remains independent from Chat authentication', () async {
    await InfobipMobileMessagingHuawei.setChatJwtProvider(
      () async => 'chat-token',
    );
    await InfobipMobileMessagingHuawei.setJwt(' inbox-token ');

    expect(platform.globalJwts, ['inbox-token']);
    expect(platform.resolved, isEmpty);
  });

  test('ignores unrelated events', () async {
    var providerCalls = 0;
    await InfobipMobileMessagingHuawei.setChatJwtProvider(() async {
      providerCalls++;
      return 'chat-token';
    });

    platform.eventsController.add({
      'version': ChannelContract.eventVersion,
      'type': ChannelContract.registrationUpdated,
      'payload': <String, Object?>{},
    });
    await pumpEventQueue();

    expect(providerCalls, 0);
    expect(platform.resolved, isEmpty);
  });
}
