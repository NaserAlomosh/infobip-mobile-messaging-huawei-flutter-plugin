import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

Future<T> withTargetPlatform<T>(
  TargetPlatform platform,
  Future<T> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    return await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platformCalls = <MethodCall>[];
  Future<Object?> Function(MethodCall)? chatHandler;
  var channelName = '';
  void setChatHandler(Future<Object?> Function(MethodCall)? handler) {
    chatHandler = handler;
    if (channelName.isNotEmpty) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channelName), handler);
    }
  }

  setUp(() {
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          platformCalls.add(call);
          if (call.method == 'create') {
            channelName =
                'com.infobip.mobilemessaging.huawei/chat_view/${(call.arguments as Map)['id']}';
            setChatHandler(chatHandler ?? (_) async => null);
          }
          return null;
        });
  });

  Future<AndroidViewController> createView(WidgetTester tester) async {
    await tester.pump();
    final controller = tester
        .widget<AndroidViewSurface>(find.byType(AndroidViewSurface))
        .controller;

    return controller;
  }

  test('controller is safe before attachment', () async {
    final controller = InfobipHuaweiChatController();

    expect(controller.isAttached, isFalse);
    expect(await controller.navigateBackOrCloseChat(), isFalse);
    await expectLater(
      controller.send(const InfobipHuaweiChatMessagePayload.text('Hello')),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'chat_unavailable',
        ),
      ),
    );
    await expectLater(
      controller.sendContextualData('{"source":"support"}'),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      controller.setChatDraftMessage('Draft'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'chat_unavailable',
        ),
      ),
    );
    await expectLater(
      controller.getLanguage(),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      controller.getWidgetTheme(),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      controller.isMultithread(),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      controller.showThreadsList(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'chat_unavailable',
        ),
      ),
    );
  });

  test('text payload rejects empty text', () {
    expect(
      () => const InfobipHuaweiChatMessagePayload.text('  ').toMap(),
      throwsArgumentError,
    );
  });

  testWidgets('unsupported platforms render a deterministic placeholder', (
    tester,
  ) async {
    await withTargetPlatform(TargetPlatform.iOS, () async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: InfobipHuaweiChatView(),
        ),
      );

      expect(find.text('Chat is available on Android only.'), findsOneWidget);
    });
  });

  testWidgets('Chat view uses native input and Flutter toolbar defaults', (
    tester,
  ) async {
    await withTargetPlatform(TargetPlatform.android, () async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: InfobipHuaweiChatView(),
        ),
      );
      final controller = await createView(tester);
      expect(controller, isA<ExpensiveAndroidViewController>());
      final creation =
          platformCalls.lastWhere((call) => call.method == 'create').arguments
              as Map;
      expect(creation['hybrid'], true);
      expect(
        const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(creation['params'] as Uint8List),
        ),
        <String, bool>{'withInput': true, 'withToolbar': false},
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('Chat view propagates native UI options', (tester) async {
    await withTargetPlatform(TargetPlatform.android, () async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: InfobipHuaweiChatView(withInput: false, withToolbar: true),
        ),
      );
      await createView(tester);
      final creation =
          platformCalls.lastWhere((call) => call.method == 'create').arguments
              as Map;
      expect(
        const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(creation['params'] as Uint8List),
        ),
        <String, bool>{'withInput': false, 'withToolbar': true},
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('embedded Chat errors', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    void androidTest(String description, WidgetTesterCallback callback) {
      testWidgets(description, (tester) async {
        await withTargetPlatform(
          TargetPlatform.android,
          () => callback(tester),
        );
      });
    }

    Future<void> mountView(
      WidgetTester tester, {
      InfobipHuaweiChatController? controller,
      void Function(InfobipHuaweiChatError)? onError,
      void Function(InfobipHuaweiChatEvent)? onEvent,
    }) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: InfobipHuaweiChatView(
            controller: controller,
            onError: onError,
            onEvent: onEvent,
          ),
        ),
      );
      await createView(tester);

      await tester.pump();
    }

    Future<void> emitError(Object? payload) async {
      final data = const StandardMethodCodec().encodeMethodCall(
        MethodCall('onError', payload),
      );
      await messenger.handlePlatformMessage(channelName, data, (_) {});
    }

    setUp(() {
      setChatHandler(
        (call) async => call.method == 'navigateBackOrCloseChat' ? true : null,
      );
    });

    tearDown(() {
      setChatHandler(null);
    });

    for (final entry in <String, InfobipHuaweiChatErrorCode>{
      'not_initialized': InfobipHuaweiChatErrorCode.notInitialized,
      'activity_unavailable': InfobipHuaweiChatErrorCode.activityUnavailable,
      'activity_fragment_unavailable':
          InfobipHuaweiChatErrorCode.activityFragmentUnavailable,
      'chat_unavailable': InfobipHuaweiChatErrorCode.chatUnavailable,
      'native_error': InfobipHuaweiChatErrorCode.nativeError,
      'future_error': InfobipHuaweiChatErrorCode.unknown,
    }.entries) {
      androidTest('decodes ${entry.key}', (tester) async {
        InfobipHuaweiChatError? received;
        await mountView(tester, onError: (error) => received = error);

        await emitError({'code': entry.key, 'message': 'Unavailable'});

        expect(received?.code, entry.value);
        expect(received?.message, 'Unavailable');
      });
    }

    androidTest('loading results and repeated reopen use independent bridges', (
      tester,
    ) async {
      final events = <InfobipHuaweiChatEvent>[];
      final controller = InfobipHuaweiChatController();
      final ids = <int>{};
      for (var cycle = 0; cycle < 10; cycle++) {
        await mountView(tester, controller: controller, onEvent: events.add);
        final surface = tester.widget<AndroidViewSurface>(
          find.byType(AndroidViewSurface),
        );
        expect(ids.add(surface.controller.viewId), isTrue);
        final data = const StandardMethodCodec().encodeMethodCall(
          MethodCall('onRuntimeEvent', {
            'event': 'loaded',
            'value': cycle.isEven,
          }),
        );
        await messenger.handlePlatformMessage(channelName, data, (_) {});
        expect(
          (events.last as InfobipHuaweiChatLoadedEvent).success,
          cycle.isEven,
        );
        await tester.pumpWidget(const SizedBox());
        expect(controller.isAttached, isFalse);
        await messenger.handlePlatformMessage(channelName, data, (_) {});
        expect(events.length, cycle + 1);
      }
      expect(
        platformCalls.where((call) => call.method == 'dispose'),
        hasLength(10),
      );
    });

    androidTest('malformed payload maps to unknown', (tester) async {
      InfobipHuaweiChatError? received;
      await mountView(tester, onError: (error) => received = error);

      await emitError('invalid');

      expect(received?.code, InfobipHuaweiChatErrorCode.unknown);
      expect(received?.message, isNull);
    });

    androidTest('does not invoke callback after disposal', (tester) async {
      var calls = 0;
      await mountView(tester, onError: (_) => calls++);
      await tester.pumpWidget(const SizedBox());

      await emitError({'code': 'not_initialized'});

      expect(calls, 0);
    });

    androidTest('controller shares the view bridge channel', (tester) async {
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      expect(controller.isAttached, isTrue);
      expect(await controller.navigateBackOrCloseChat(), isTrue);
    });

    androidTest('draft message is forwarded unchanged', (tester) async {
      final calls = <MethodCall>[];
      setChatHandler((call) async {
        calls.add(call);
        return null;
      });
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await controller.setChatDraftMessage('  hello  ');

      final call = calls.singleWhere(
        (call) => call.method == 'setChatDraftMessage',
      );
      expect(call.arguments, <String, Object?>{'message': '  hello  '});
    });

    androidTest('empty draft clears the native draft', (tester) async {
      MethodCall? draftCall;
      setChatHandler((call) async {
        if (call.method == 'setChatDraftMessage') draftCall = call;
        return null;
      });
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await controller.setChatDraftMessage('');

      expect(draftCall?.arguments, <String, Object?>{'message': ''});
    });

    androidTest('draft platform errors propagate', (tester) async {
      setChatHandler((call) async {
        if (call.method == 'setChatDraftMessage') {
          throw PlatformException(code: 'native_error');
        }
        return null;
      });
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await expectLater(
        controller.setChatDraftMessage('Draft'),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'native_error',
          ),
        ),
      );
    });

    androidTest('controller requests the thread list on its view channel', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      setChatHandler((call) async {
        calls.add(call);
        return null;
      });
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await controller.showThreadsList();

      expect(
        calls.where((call) => call.method == 'showThreadsList'),
        hasLength(1),
      );
      expect(calls.last.arguments, isNull);
    });

    androidTest('thread list request forwards a native platform error', (
      tester,
    ) async {
      setChatHandler((call) async {
        if (call.method == 'showThreadsList') {
          throw PlatformException(
            code: 'native_error',
            message: 'Chat operation failed',
          );
        }
        return null;
      });
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await expectLater(
        controller.showThreadsList(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'native_error',
          ),
        ),
      );
    });

    androidTest('controller accepts a false navigation result', (tester) async {
      setChatHandler(
        (call) async => call.method == 'navigateBackOrCloseChat' ? false : null,
      );
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      expect(await controller.navigateBackOrCloseChat(), isFalse);
    });

    for (final value in [true, false]) {
      androidTest('controller returns $value for multithread state', (
        tester,
      ) async {
        setChatHandler(
          (call) async => call.method == 'isMultithread' ? value : null,
        );
        final controller = InfobipHuaweiChatController();
        await mountView(tester, controller: controller);

        expect(await controller.isMultithread(), value);
      });
    }

    androidTest('controller rejects malformed multithread state', (
      tester,
    ) async {
      setChatHandler((call) async => call.method == 'isMultithread' ? 1 : null);
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await expectLater(controller.isMultithread(), throwsFormatException);
    });

    androidTest('controller sends text on its view channel', (tester) async {
      final calls = <MethodCall>[];
      setChatHandler((call) async {
        calls.add(call);
        return null;
      });
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await controller.send(
        const InfobipHuaweiChatMessagePayload.text('Hello'),
      );

      expect(calls.last.method, 'send');
      expect(calls.last.arguments, <String, Object>{'text': 'Hello'});
    });

    androidTest('controller sends contextual data on its view channel', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      setChatHandler((call) async {
        calls.add(call);
        return null;
      });
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await controller.sendContextualData('{"source":"support"}');

      expect(calls.last.method, 'sendContextualData');
      expect(calls.last.arguments, <String, Object>{
        'data': '{"source":"support"}',
        'chatMultiThreadStrategy': 'ACTIVE',
      });
    });

    androidTest('controller serializes every contextual data strategy', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      setChatHandler((call) async {
        calls.add(call);
        return null;
      });
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      for (final strategy in ChatMultithreadStrategies.values) {
        const data = ' {"source":"support"}\n';
        await controller.sendContextualDataWithStrategy(data, strategy);

        expect(calls.last.method, 'sendContextualData');
        expect(calls.last.arguments, <String, Object>{
          'data': data,
          'chatMultiThreadStrategy': strategy.name,
        });
      }
    });

    androidTest(
      'contextual data validation happens before channel invocation',
      (tester) async {
        var invocationCount = 0;
        setChatHandler((_) async {
          invocationCount++;
          return null;
        });
        final controller = InfobipHuaweiChatController();
        await mountView(tester, controller: controller);
        final attachmentInvocationCount = invocationCount;

        await expectLater(
          controller.sendContextualDataWithStrategy('  '),
          throwsArgumentError,
        );
        expect(invocationCount, attachmentInvocationCount);
      },
    );

    androidTest('contextual data native failures propagate unchanged', (
      tester,
    ) async {
      setChatHandler((call) async {
        if (call.method == 'sendContextualData') {
          throw PlatformException(
            code: 'native_error',
            message: 'Chat operation failed',
          );
        }

        return call.method == 'navigateBackOrCloseChat' ? true : null;
      });
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await expectLater(
        controller.sendContextualDataWithStrategy('{}'),
        throwsA(
          isA<PlatformException>()
              .having((error) => error.code, 'code', 'native_error')
              .having(
                (error) => error.message,
                'message',
                'Chat operation failed',
              ),
        ),
      );
    });

    androidTest('controller sets and gets the component language', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      setChatHandler((call) async {
        calls.add(call);
        return call.method == 'getLanguage' ? 'en-US' : null;
      });
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await controller.setLanguage('en-US');

      expect(calls.last.method, 'setLanguage');
      expect(calls.last.arguments, <String, Object>{'language': 'en-US'});
      expect(await controller.getLanguage(), 'en-US');
    });

    androidTest('controller sets and gets the widget theme', (tester) async {
      final calls = <MethodCall>[];
      setChatHandler((call) async {
        calls.add(call);
        return call.method == 'getWidgetTheme' ? 'support' : null;
      });
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await controller.setWidgetTheme('support');

      expect(calls.last.method, 'setWidgetTheme');
      expect(calls.last.arguments, <String, Object>{'widgetTheme': 'support'});
      expect(await controller.getWidgetTheme(), 'support');
    });

    androidTest('controller preserves an absent widget theme', (tester) async {
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      expect(await controller.getWidgetTheme(), isNull);
    });

    androidTest('navigation rejects a missing native boolean', (tester) async {
      setChatHandler((_) async => null);
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await expectLater(
        controller.navigateBackOrCloseChat(),
        throwsFormatException,
      );
    });

    androidTest('controller validates language and theme values', (
      tester,
    ) async {
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await expectLater(controller.setLanguage(' '), throwsArgumentError);
      await expectLater(controller.setLanguage(''), throwsArgumentError);
      await expectLater(controller.setWidgetTheme(' '), throwsArgumentError);
    });

    androidTest('controller command forwards a native error', (tester) async {
      setChatHandler((call) async {
        if (call.method == 'send') {
          throw PlatformException(code: 'native_error');
        }

        return call.method == 'navigateBackOrCloseChat' ? true : null;
      });
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await expectLater(
        controller.send(const InfobipHuaweiChatMessagePayload.text('Hello')),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'native_error',
          ),
        ),
      );
    });

    androidTest('disposed controller rejects commands', (tester) async {
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);
      await tester.pumpWidget(const SizedBox());

      await expectLater(
        controller.sendContextualData('{}'),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
