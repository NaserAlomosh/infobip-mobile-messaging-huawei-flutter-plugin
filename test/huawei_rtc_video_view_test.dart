import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

void main() {
  testWidgets('unsupported platform and invalid id show unavailable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 300,
          height: 200,
          child: HuaweiRtcVideoView(
            callId: 'call',
            source: HuaweiRtcVideoSource.remote,
          ),
        ),
      ),
    );
    expect(find.text('Video unavailable'), findsOneWidget);
    expect(find.byType(AndroidView), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('ordinary rebuild reuses view and changing call recreates it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final nativeCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        nativeCalls.add(call);
        if (call.method == 'create') return 1;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
    Widget page(String call) => MaterialApp(
      home: SizedBox(
        width: 300,
        height: 200,
        child: HuaweiRtcVideoView(
          callId: call,
          source: HuaweiRtcVideoSource.remote,
        ),
      ),
    );
    await tester.pumpWidget(page('first'));
    await tester.pump();
    final element = tester.element(find.byType(AndroidView));
    final view = tester.widget<AndroidView>(find.byType(AndroidView));
    expect(view.creationParams, {'callId': 'first', 'source': 'remote'});
    await tester.pumpWidget(page('first'));
    expect(tester.element(find.byType(AndroidView)), same(element));
    await tester.pumpWidget(page('second'));
    await tester.pump();
    expect(tester.element(find.byType(AndroidView)), isNot(same(element)));
    expect(nativeCalls.where((c) => c.method == 'create').length, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(nativeCalls.where((c) => c.method == 'dispose').length, 2);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'unbounded layout avoids a native surface and does not overflow',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        MaterialApp(
          home: ListView(
            children: [
              HuaweiRtcVideoView(
                callId: 'call',
                source: HuaweiRtcVideoSource.local,
              ),
            ],
          ),
        ),
      );
      expect(find.byType(AndroidView), findsNothing);
      expect(find.text('Video unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'inactive view is disposed and resume creates a fresh renderer view',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (call) async {
          calls.add(call);
          return call.method == 'create' ? 1 : null;
        },
      );
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: SizedBox(
              width: 300,
              height: 200,
              child: HuaweiRtcVideoView(
                callId: 'call',
                source: HuaweiRtcVideoSource.local,
              ),
            ),
          ),
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(find.byType(AndroidView), findsNothing);
        expect(find.text('Video unavailable'), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(AndroidView), findsOneWidget);
        expect(calls.where((c) => c.method == 'create').length, 2);
        expect(calls.where((c) => c.method == 'dispose').length, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        );
      }
    },
  );

  testWidgets('empty call id never creates a native view', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 300,
            height: 200,
            child: HuaweiRtcVideoView(
              callId: '',
              source: HuaweiRtcVideoSource.local,
            ),
          ),
        ),
      );
      expect(find.byType(AndroidView), findsNothing);
      expect(find.text('Video unavailable'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
