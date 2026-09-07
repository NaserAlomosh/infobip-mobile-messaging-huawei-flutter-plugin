import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: InfobipHuaweiChatView(),
      ),
    );

    expect(find.text('Chat is available on Android only.'), findsOneWidget);
  });

  testWidgets('Chat view uses native input and Flutter toolbar defaults', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: InfobipHuaweiChatView(),
      ),
    );
    final view = tester.widget<AndroidView>(find.byType(AndroidView));
    expect(view.creationParams, <String, bool>{
      'withInput': true,
      'withToolbar': false,
    });
    expect(view.creationParamsCodec, isA<StandardMessageCodec>());
  });

  testWidgets('Chat view propagates native UI options', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: InfobipHuaweiChatView(withInput: false, withToolbar: true),
      ),
    );
    expect(
      tester.widget<AndroidView>(find.byType(AndroidView)).creationParams,
      <String, bool>{'withInput': false, 'withToolbar': true},
    );
  });

  group('embedded Chat errors', () {
    const viewId = 42;
    const channelName = 'com.infobip.mobilemessaging.huawei/chat_view/42';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    Future<void> mountView(
      WidgetTester tester, {
      InfobipHuaweiChatController? controller,
      void Function(InfobipHuaweiChatError)? onError,
    }) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: InfobipHuaweiChatView(
            controller: controller,
            onError: onError,
          ),
        ),
      );
      if (tester
              .widget<AndroidView>(find.byType(AndroidView))
              .onPlatformViewCreated !=
          null) {
        tester
            .widget<AndroidView>(find.byType(AndroidView))
            .onPlatformViewCreated!(viewId);
      }

      await tester.pump();
    }

    Future<void> emitError(Object? payload) async {
      final data = const StandardMethodCodec().encodeMethodCall(
        MethodCall('onError', payload),
      );
      await messenger.handlePlatformMessage(channelName, data, (_) {});
    }

    setUp(() {
      messenger.setMockMethodCallHandler(
        const MethodChannel(channelName),
        (call) async => call.method == 'navigateBackOrCloseChat' ? true : null,
      );
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(
        const MethodChannel(channelName),
        null,
      );
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
      testWidgets('decodes ${entry.key}', (tester) async {
        InfobipHuaweiChatError? received;
        await mountView(tester, onError: (error) => received = error);

        await emitError({'code': entry.key, 'message': 'Unavailable'});

        expect(received?.code, entry.value);
        expect(received?.message, 'Unavailable');
      });
    }

    testWidgets('malformed payload maps to unknown', (tester) async {
      InfobipHuaweiChatError? received;
      await mountView(tester, onError: (error) => received = error);

      await emitError('invalid');

      expect(received?.code, InfobipHuaweiChatErrorCode.unknown);
      expect(received?.message, isNull);
    });

    testWidgets('does not invoke callback after disposal', (tester) async {
      var calls = 0;
      await mountView(tester, onError: (_) => calls++);
      await tester.pumpWidget(const SizedBox());

      await emitError({'code': 'not_initialized'});

      expect(calls, 0);
    });

    testWidgets('controller shares the view bridge channel', (tester) async {
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      expect(controller.isAttached, isTrue);
      expect(await controller.navigateBackOrCloseChat(), isTrue);
    });

    testWidgets('draft message is forwarded unchanged', (tester) async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
        call,
      ) async {
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

    testWidgets('empty draft clears the native draft', (tester) async {
      MethodCall? draftCall;
      messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
        call,
      ) async {
        if (call.method == 'setChatDraftMessage') draftCall = call;
        return null;
      });
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await controller.setChatDraftMessage('');

      expect(draftCall?.arguments, <String, Object?>{'message': ''});
    });

    testWidgets('draft platform errors propagate', (tester) async {
      messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
        call,
      ) async {
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

    testWidgets('controller requests the thread list on its view channel', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
        call,
      ) async {
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

    testWidgets('thread list request forwards a native platform error', (
      tester,
    ) async {
      messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
        call,
      ) async {
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

    testWidgets('controller accepts a false navigation result', (tester) async {
      messenger.setMockMethodCallHandler(
        const MethodChannel(channelName),
        (call) async => call.method == 'navigateBackOrCloseChat' ? false : null,
      );
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      expect(await controller.navigateBackOrCloseChat(), isFalse);
    });

    for (final value in [true, false]) {
      testWidgets('controller returns $value for multithread state', (
        tester,
      ) async {
        messenger.setMockMethodCallHandler(
          const MethodChannel(channelName),
          (call) async => call.method == 'isMultithread' ? value : null,
        );
        final controller = InfobipHuaweiChatController();
        await mountView(tester, controller: controller);

        expect(await controller.isMultithread(), value);
      });
    }

    testWidgets('controller rejects malformed multithread state', (
      tester,
    ) async {
      messenger.setMockMethodCallHandler(
        const MethodChannel(channelName),
        (call) async => call.method == 'isMultithread' ? 1 : null,
      );
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await expectLater(controller.isMultithread(), throwsFormatException);
    });

    testWidgets('controller sends text on its view channel', (tester) async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
        call,
      ) async {
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

    testWidgets('controller sends contextual data on its view channel', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
        call,
      ) async {
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

    testWidgets('controller serializes every contextual data strategy', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
        call,
      ) async {
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

    testWidgets(
      'contextual data validation happens before channel invocation',
      (tester) async {
        var invocationCount = 0;
        messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
          _,
        ) async {
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

    testWidgets('contextual data native failures propagate unchanged', (
      tester,
    ) async {
      messenger.setMockMethodCallHandler(
        const MethodChannel(channelName),
        (call) async => throw PlatformException(
          code: 'native_error',
          message: 'Chat operation failed',
        ),
      );
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await expectLater(
        controller.sendContextualDataWithStrategy('{}'),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'native_error',
          ),
        ),
      );
    });

    testWidgets('controller sets and gets the component language', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
        call,
      ) async {
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

    testWidgets('controller sets and gets the widget theme', (tester) async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
        call,
      ) async {
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

    testWidgets('controller preserves an absent widget theme', (tester) async {
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      expect(await controller.getWidgetTheme(), isNull);
    });

    testWidgets('navigation rejects a missing native boolean', (tester) async {
      messenger.setMockMethodCallHandler(
        const MethodChannel(channelName),
        (_) async => null,
      );
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await expectLater(
        controller.navigateBackOrCloseChat(),
        throwsFormatException,
      );
    });

    testWidgets('controller validates language and theme values', (
      tester,
    ) async {
      final controller = InfobipHuaweiChatController();
      await mountView(tester, controller: controller);

      await expectLater(controller.setLanguage(' '), throwsArgumentError);
      await expectLater(controller.setLanguage(''), throwsArgumentError);
      await expectLater(controller.setWidgetTheme(' '), throwsArgumentError);
    });

    testWidgets('controller command forwards a native error', (tester) async {
      messenger.setMockMethodCallHandler(
        const MethodChannel(channelName),
        (call) async => throw PlatformException(code: 'native_error'),
      );
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

    testWidgets('disposed controller rejects commands', (tester) async {
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
