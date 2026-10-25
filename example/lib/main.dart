import 'package:flutter/material.dart';
import 'app.dart';
import 'setup/example_controller.dart';
import 'config/load_example_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = await loadExampleConfig();
    runApp(ExampleApp(controller: ExampleController(config: config)));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Unable to load example configuration. Check config/example_config.local.json '
              'against example_config.example.json, then stop and rebuild the app.',
            ),
          ),
        ),
      ),
    );
  }
}
