import 'package:flutter/material.dart';
import 'app.dart';
import 'setup/example_controller.dart';
import 'config/test_config_mapper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ExampleApp(
      controller: ExampleController(config: configFromTestConstants()),
    ),
  );
}
