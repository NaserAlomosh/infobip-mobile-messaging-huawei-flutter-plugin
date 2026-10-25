import 'dart:io';

/// Run once from example/. Never reads or overwrites an existing private file.
void main() {
  final target = File('lib/config/example_test_config.dart');
  if (target.existsSync()) {
    stdout.writeln('Existing private configuration preserved.');
    return;
  }
  File('lib/config/example_test_config.template.dart').copySync(target.path);
  stdout.writeln('Safe default configuration created.');
}
