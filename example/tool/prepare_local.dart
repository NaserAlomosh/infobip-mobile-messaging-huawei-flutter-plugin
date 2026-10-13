import 'dart:io';

void main() {
  final local = File('lib/config/example_test_config.dart');
  if (!local.existsSync()) {
    File('lib/config/example_test_config.template.dart').copySync(local.path);
  }
  File('lib/main_local.dart').writeAsStringSync(
    File('lib/main.dart').readAsStringSync().replaceFirst(
      'config/example_test_config.template.dart',
      'config/example_test_config.dart',
    ),
  );
  stdout.writeln(
    'Edit lib/config/example_test_config.dart, then run flutter run -t lib/main_local.dart.',
  );
}
