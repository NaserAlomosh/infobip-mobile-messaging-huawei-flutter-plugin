import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final class ChatExceptionPlatform extends InfobipMobileMessagingHuaweiPlatform
    with MockPlatformInterfaceMixin {
  final eventsController = StreamController<Object?>.broadcast(sync: true);
  final registrations = <bool>[];

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
  Future<void> setChatExceptionHandler({required bool enabled}) async {
    registrations.add(enabled);
  }

  void emit({Object? message = 'Connection failed', Object? name = 'Error'}) {
    eventsController.add({
      'version': ChannelContract.eventVersion,
      'type': ChannelContract.chatException,
      'payload': {'message': message, 'name': name},
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatExceptionPlatform platform;

  setUp(() {
    platform = ChatExceptionPlatform();
    InfobipMobileMessagingHuaweiPlatform.instance = platform;
  });

  tearDown(() async {
    await InfobipMobileMessagingHuawei.cleanup();
    await platform.eventsController.close();
  });

  test('decodes and delivers a native Chat exception exactly once', () async {
    final received = <ChatException>[];
    await InfobipMobileMessagingHuawei.setChatExceptionHandler((
      exception,
    ) async {
      received.add(exception);
    });

    platform.emit();
    await pumpEventQueue();

    expect(received, const [
      ChatException(message: 'Connection failed', name: 'Error'),
    ]);
    expect(platform.registrations, [true]);
  });

  test('replacement invokes only the newest handler', () async {
    var oldCalls = 0;
    var newCalls = 0;
    await InfobipMobileMessagingHuawei.setChatExceptionHandler(
      (_) async => oldCalls++,
    );
    await InfobipMobileMessagingHuawei.setChatExceptionHandler(
      (_) async => newCalls++,
    );

    platform.emit();
    await pumpEventQueue();

    expect(oldCalls, 0);
    expect(newCalls, 1);
  });

  test('null handler unregisters and prevents callbacks', () async {
    var calls = 0;
    await InfobipMobileMessagingHuawei.setChatExceptionHandler(
      (_) async => calls++,
    );
    await InfobipMobileMessagingHuawei.setChatExceptionHandler(null);
    platform.emit();
    await pumpEventQueue();

    expect(calls, 0);
    expect(platform.registrations, [true, false]);
  });

  test('cleanup clears handler state', () async {
    var calls = 0;
    await InfobipMobileMessagingHuawei.setChatExceptionHandler(
      (_) async => calls++,
    );
    await InfobipMobileMessagingHuawei.cleanup();
    platform.emit();
    await pumpEventQueue();

    expect(calls, 0);
  });

  test('asynchronous and synchronous failures call onError', () async {
    final errors = <Object>[];
    await InfobipMobileMessagingHuawei.setChatExceptionHandler(
      (_) => Future<void>.error(StateError('async')),
      errors.add,
    );
    platform.emit();
    await pumpEventQueue();

    await InfobipMobileMessagingHuawei.setChatExceptionHandler(
      (_) => throw ArgumentError('sync'),
      errors.add,
    );
    platform.emit();
    await pumpEventQueue();

    expect(errors, [isA<StateError>(), isA<ArgumentError>()]);
  });

  test('onError failure does not end exception delivery', () async {
    var calls = 0;
    await InfobipMobileMessagingHuawei.setChatExceptionHandler((_) async {
      calls++;
      throw StateError('handler');
    }, (_) => throw StateError('onError'));

    platform.emit();
    platform.emit();
    await pumpEventQueue();

    expect(calls, 2);
  });

  test('malformed payload is ignored without affecting later events', () async {
    final received = <ChatException>[];
    await InfobipMobileMessagingHuawei.setChatExceptionHandler((
      exception,
    ) async {
      received.add(exception);
    });

    platform.emit(message: 500);
    platform.eventsController.add({
      'version': ChannelContract.eventVersion,
      'type': ChannelContract.chatException,
      'payload': 'invalid',
    });
    platform.emit(message: null, name: null);
    await pumpEventQueue();

    expect(received, const [ChatException(message: null, name: null)]);
  });
}
