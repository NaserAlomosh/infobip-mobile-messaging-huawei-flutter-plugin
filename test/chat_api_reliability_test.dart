import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class ReliabilityPlatform extends InfobipMobileMessagingHuaweiPlatform
    with MockPlatformInterfaceMixin {
  final controller = StreamController<Object?>.broadcast(sync: true);
  Completer<void>? pendingCleanup;
  Completer<void>? pendingInitialize;
  Completer<void>? pendingRegistration;
  Object? cleanupError;
  Object? initializationError;
  int cleanupCalls = 0;
  int initializeCalls = 0;
  int request = 0;
  final resolved = <String>[];
  final rejected = <String>[];
  @override
  Stream<Object?> get events => controller.stream;
  @override
  Future<void> cleanup() async {
    cleanupCalls++;
    if (cleanupError != null) throw cleanupError!;
    await pendingCleanup?.future;
  }

  @override
  Future<void> initialize({
    required String applicationCode,
    bool defaultMessageStorage = true,
    WebRTCUI? webRTCUI,
  }) async {
    initializeCalls++;
    if (initializationError != null) throw initializationError!;
    await pendingInitialize?.future;
  }

  @override
  Future<void> setChatJwtProvider() async {
    await pendingRegistration?.future;
  }

  @override
  Future<void> setChatExceptionHandler({required bool enabled}) async {}
  @override
  Future<void> resolveChatJwt(
    String jwt, {
    required String requestId,
    required int generation,
  }) async {
    resolved.add(requestId);
  }

  @override
  Future<void> rejectChatJwt(
    String error, {
    required String requestId,
    required int generation,
  }) async {
    rejected.add(requestId);
  }

  void jwt() => emit('chat_jwt_requested', {
    'requestId': 'request-${++request}',
    'generation': 1,
  });
  void emit(String type, Map<String, Object?> payload) =>
      controller.add({'version': 1, 'type': type, 'payload': payload});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReliabilityPlatform platform;
  setUp(() {
    platform = ReliabilityPlatform();
    InfobipMobileMessagingHuaweiPlatform.instance = platform;
  });
  tearDown(() async {
    platform.cleanupError = null;
    platform.pendingCleanup = null;
    platform.pendingInitialize = null;
    await InfobipMobileMessagingHuawei.cleanup();
    await platform.controller.close();
  });

  testWidgets(
    'never completing provider expires and late success cannot reach native state',
    (tester) async {
      final provider = Completer<String>();
      final errors = <Object>[];
      await InfobipMobileMessagingHuawei.setChatJwtProvider(
        () => provider.future,
        errors.add,
      );
      platform.jwt();
      await tester.pump();
      await tester.pump(const Duration(seconds: 24));
      expect(platform.rejected, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(platform.rejected, ['request-1']);
      expect(errors.single, isA<TimeoutException>());
      provider.complete('fixture-sensitive-value');
      await tester.pump();
      expect(platform.resolved, isEmpty);
      expect(platform.rejected.length, 1);
      await tester.runAsync(() async {
        await InfobipMobileMessagingHuawei.setChatJwtProvider(
          () async => 'fresh',
        );
        platform.jwt();
        await pumpEventQueue();
        expect(platform.resolved, ['request-2']);
        await InfobipMobileMessagingHuawei.cleanup();
      });
    },
  );

  testWidgets(
    'late exception after timeout is consumed without a second native response',
    (tester) async {
      final provider = Completer<String>();
      await InfobipMobileMessagingHuawei.setChatJwtProvider(
        () => provider.future,
      );
      platform.jwt();
      await tester.pump();
      await tester.pump(const Duration(seconds: 25));
      provider.completeError(StateError('fixture-sensitive-value'));
      await tester.pump();
      expect(platform.rejected, ['request-1']);
      expect(platform.resolved, isEmpty);
      await tester.runAsync(InfobipMobileMessagingHuawei.cleanup);
      await tester.pump();
    },
  );

  testWidgets(
    'successful cleanup invalidates pending JWT and cancels its timer',
    (tester) async {
      final provider = Completer<String>();
      final errors = <Object>[];
      await InfobipMobileMessagingHuawei.setChatJwtProvider(
        () => provider.future,
        errors.add,
      );
      platform.jwt();
      await tester.pump();
      await tester.runAsync(InfobipMobileMessagingHuawei.cleanup);
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      provider.complete('fixture-sensitive-value');
      await tester.pump();
      expect(errors, isEmpty);
      expect(platform.resolved, isEmpty);
      expect(platform.rejected, isEmpty);
    },
  );

  testWidgets('pending provider survives rejected cleanup and still resolves', (
    tester,
  ) async {
    final provider = Completer<String>();
    await InfobipMobileMessagingHuawei.setChatJwtProvider(
      () => provider.future,
    );
    platform.jwt();
    await tester.pump();
    platform.cleanupError = PlatformException(code: 'rtc_invalid_state');
    await tester.runAsync(() async {
      await expectLater(
        InfobipMobileMessagingHuawei.cleanup(),
        throwsA(isA<PlatformException>()),
      );
    });
    provider.complete('fixture');
    await tester.pump();
    expect(platform.resolved, ['request-1']);
    expect(platform.rejected, isEmpty);
    platform.cleanupError = null;
    await tester.runAsync(InfobipMobileMessagingHuawei.cleanup);
  });

  testWidgets(
    'pending Dart JWT capacity is bounded and cleanup cancels every timer',
    (tester) async {
      final provider = Completer<String>();
      await InfobipMobileMessagingHuawei.setChatJwtProvider(
        () => provider.future,
      );
      for (var i = 0; i < 33; i++) {
        platform.jwt();
      }
      await tester.pump();
      expect(platform.rejected, ['request-33']);
      await tester.runAsync(InfobipMobileMessagingHuawei.cleanup);
      await tester.pump(const Duration(seconds: 30));
      provider.complete('fixture');
      await tester.pump();
      expect(platform.resolved, isEmpty);
      expect(platform.rejected, ['request-33']);
    },
  );

  test(
    'cleanup cannot interleave with pending native provider registration',
    () async {
      platform.pendingRegistration = Completer<void>();
      final registration = InfobipMobileMessagingHuawei.setChatJwtProvider(
        () async => 'fixture',
      );
      await pumpEventQueue();
      await expectLater(
        InfobipMobileMessagingHuawei.cleanup(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'operation_in_progress',
          ),
        ),
      );
      expect(platform.cleanupCalls, 0);
      platform.pendingRegistration!.complete();
      await registration;
      await InfobipMobileMessagingHuawei.cleanup();
      expect(platform.cleanupCalls, 1);
    },
  );

  for (final code in ['rtc_invalid_state', 'native_error']) {
    test(
      'cleanup $code preserves JWT exceptions and unread subscriptions',
      () async {
        final exceptions = <ChatException>[];
        final unread = <int>[];
        await InfobipMobileMessagingHuawei.setChatJwtProvider(
          () async => 'fixture',
        );
        await InfobipMobileMessagingHuawei.setChatExceptionHandler((e) async {
          exceptions.add(e);
        });
        final subscription = InfobipMobileMessagingHuawei
            .chat
            .onUnreadMessageCounterUpdated
            .listen(unread.add);
        platform.cleanupError = PlatformException(
          code: code,
          message: 'Safe cleanup failure',
        );
        await expectLater(
          InfobipMobileMessagingHuawei.cleanup(),
          throwsA(isA<PlatformException>().having((e) => e.code, 'code', code)),
        );
        platform.jwt();
        platform.emit('chat_exception', {'message': 'safe', 'name': 'Error'});
        platform.emit('chat_unread_message_counter_updated', {'count': 4});
        await pumpEventQueue();
        expect(platform.resolved, ['request-1']);
        expect(exceptions.length, 1);
        expect(unread, [4]);
        platform.cleanupError = null;
        await InfobipMobileMessagingHuawei.cleanup();
        platform.jwt();
        platform.emit('chat_exception', {'message': 'late', 'name': 'Error'});
        await pumpEventQueue();
        expect(platform.resolved.length, 1);
        expect(exceptions.length, 1);
        await subscription.cancel();
      },
    );
  }

  test(
    'concurrent cleanup shares one native result and repeated cleanup is safe',
    () async {
      platform.pendingCleanup = Completer<void>();
      final first = InfobipMobileMessagingHuawei.cleanup();
      final second = InfobipMobileMessagingHuawei.cleanup();
      expect(identical(first, second), isTrue);
      expect(platform.cleanupCalls, 1);
      platform.pendingCleanup!.complete();
      await Future.wait([first, second]);
      platform.pendingCleanup = null;
      await InfobipMobileMessagingHuawei.cleanup();
      expect(platform.cleanupCalls, 2);
    },
  );

  test(
    'cleanup during initialization rejects without native cleanup',
    () async {
      platform.pendingInitialize = Completer<void>();
      final initialization = InfobipMobileMessagingHuawei.initialize(
        applicationCode: 'fixture',
      );
      await expectLater(
        InfobipMobileMessagingHuawei.cleanup(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'operation_in_progress',
          ),
        ),
      );
      expect(platform.cleanupCalls, 0);
      platform.pendingInitialize!.complete();
      await initialization;
      await InfobipMobileMessagingHuawei.cleanup();
      expect(platform.cleanupCalls, 1);
    },
  );

  test(
    'initialization and handler replacement during cleanup reject and do not mutate state',
    () async {
      platform.pendingCleanup = Completer<void>();
      final cleanup = InfobipMobileMessagingHuawei.cleanup();
      expect(
        () =>
            InfobipMobileMessagingHuawei.initialize(applicationCode: 'fixture'),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        InfobipMobileMessagingHuawei.setChatExceptionHandler((_) async {}),
        throwsA(isA<PlatformException>()),
      );
      expect(platform.initializeCalls, 0);
      platform.pendingCleanup!.complete();
      await cleanup;
    },
  );

  test(
    'Chat activation errors propagate and repeated initialization provides retry',
    () async {
      platform.initializationError = PlatformException(
        code: 'chat_unavailable',
        message: 'Chat activation failed',
      );
      await expectLater(
        InfobipMobileMessagingHuawei.initialize(applicationCode: 'fixture'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'chat_unavailable',
          ),
        ),
      );
      platform.initializationError = null;
      await InfobipMobileMessagingHuawei.initialize(applicationCode: 'fixture');
      expect(platform.initializeCalls, 2);
    },
  );
}
