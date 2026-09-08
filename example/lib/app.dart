import 'dart:async';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Infobip Huawei SDK Example',
    theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
    home: HomeScreen(controller: _controller),
  );
}
