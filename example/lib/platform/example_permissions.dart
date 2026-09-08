import 'package:flutter/services.dart';

/// Actual Android grants. Null means not checked; never assumed ready.
class ExamplePermissions {
  const ExamplePermissions({
    this.microphone,
    this.camera,
    this.nearbyDevices,
    this.notifications,
  });
  final bool? microphone;
  final bool? camera;
  final bool? nearbyDevices;
  final bool? notifications;

  static const channel = MethodChannel('infobip_huawei_example/permissions');

  static Future<ExamplePermissions> read({String? request}) async {
    final result = await channel.invokeMapMethod<String, bool>(
      request == null ? 'status' : 'request',
      request == null ? null : {'group': request},
    );
    return ExamplePermissions(
      microphone: result?['microphone'],
      camera: result?['camera'],
      nearbyDevices: result?['nearbyDevices'],
      notifications: result?['notifications'],
    );
  }

  static Future<void> openSettings() =>
      channel.invokeMethod<void>('openSettings');
}
