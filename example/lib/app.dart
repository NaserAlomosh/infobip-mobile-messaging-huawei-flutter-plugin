import 'dart:async';
import 'package:flutter/material.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'screens/huawei_rtc_screen.dart';

import 'screens/test_center_screen.dart';
import 'setup/example_controller.dart';

class ExampleApp extends StatefulWidget {
  const ExampleApp({this.controller, super.key});
  final ExampleController? controller;
  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> with WidgetsBindingObserver {
  late final ExampleController _controller =
      widget.controller ?? ExampleController();
  final _navigator = GlobalKey<NavigatorState>();
  final _routes = _RtcRouteObserver();
  bool _returning = false;
  StreamSubscription<HuaweiRtcEvent>? _rtcEvents;

  Future<void> _returnToCall() async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    if (_returning) return;
    _returning = true;
    try {
      final call = await HuaweiRtc.takeNotificationCall();
      if (!mounted || call == null || _navigator.currentState == null) return;
      final existing = _routes.callRoute;
      if (existing != null) {
        _navigator.currentState!.popUntil((route) => route == existing);
      } else {
        unawaited(
          _navigator.currentState!.push<void>(
            MaterialPageRoute(
              settings: const RouteSettings(name: HuaweiRtcScreen.routeName),
              builder: (_) => HuaweiRtcScreen(
                controller: _controller,
                video: call.type == HuaweiRtcCallType.video,
              ),
            ),
          ),
        );
      }
    } catch (_) {
      // No native RTC implementation on unsupported platforms.
    } finally {
      _returning = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.startObserving();
    _rtcEvents = HuaweiRtc.events.listen((event) {
      if (event.type == HuaweiRtcEventType.returnToCall) {
        unawaited(_returnToCall());
      }
    }, onError: (Object _) {});
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_returnToCall()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.session.log(
      'SDK',
      'Application lifecycle',
      details: {'state': state.name},
    );
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.refresh());
      unawaited(_returnToCall());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_rtcEvents?.cancel());
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Huawei SDK Test Center',
    navigatorKey: _navigator,
    navigatorObservers: [_routes],
    theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
    home: TestCenterScreen(controller: _controller),
  );
}

class _RtcRouteObserver extends NavigatorObserver {
  final _stack = <Route<dynamic>>[];
  Route<dynamic>? get callRoute {
    for (final route in _stack.reversed) {
      if (route.settings.name == HuaweiRtcScreen.routeName) return route;
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.remove(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) _stack[index] = newRoute;
  }
}
