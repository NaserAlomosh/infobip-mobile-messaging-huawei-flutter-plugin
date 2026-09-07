import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

import 'config/example_config.dart';
import 'screens/home_screen.dart';

enum InitializationState { notInitialized, initializing, initialized, failed }

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  var _state = InitializationState.notInitialized;
  String? _failure;

  Future<void> _initialize() async {
    if (_state == InitializationState.initializing ||
        _state == InitializationState.initialized) {
      return;
    }
    setState(() {
      _state = InitializationState.initializing;
      _failure = null;
    });
    try {
      await InfobipMobileMessagingHuawei.initialize(
        applicationCode: ExampleConfig.applicationCode,
      );
      await InfobipMobileMessagingHuawei.setChatCustomization(
        const ChatCustomization(
          chatBackgroundColor: '#FFFFFF',
          chatInputHintText: 'Type a message',
        ),
      );
      await InfobipMobileMessagingHuawei.setChatExceptionHandler((
        exception,
      ) async {
        debugPrint(
          'Chat exception: name=${exception.name}, message=${exception.message}',
        );
      }, (_) => debugPrint('Chat exception handler failed'));
      if (mounted) setState(() => _state = InitializationState.initialized);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _state = InitializationState.failed;
          _failure =
              '${error.code}: ${error.message ?? 'Initialization failed'}';
        });
      }
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() {
          _state = InitializationState.failed;
          _failure = error.message?.toString() ?? 'Invalid configuration';
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(InfobipMobileMessagingHuawei.setChatExceptionHandler(null));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Infobip Huawei SDK Example',
    theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
    home: HomeScreen(
      initializationState: _state,
      initializationFailure: _failure,
      applicationCodeConfigured: ExampleConfig.applicationCode.isNotEmpty,
      onInitialize: _initialize,
    ),
  );
}
