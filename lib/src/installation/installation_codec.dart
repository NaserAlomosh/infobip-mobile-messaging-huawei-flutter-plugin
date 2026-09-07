import '../platform/channel_contract.dart';
import '../user/user_codec.dart';
import 'installation.dart';

abstract final class InstallationCodec {
  static Installation decode(Object? value) {
    if (value is! Map)
      throw const FormatException('Invalid installation payload');
    return Installation(
      installationId: _string(value, ChannelContract.installationId),
      pushRegistrationId: _string(value, ChannelContract.pushRegistrationId),
      pushServiceToken: _string(value, ChannelContract.pushServiceToken),
      pushServiceType: _serviceType(value[ChannelContract.pushServiceType]),
      isPushRegistrationEnabled: _bool(
        value,
        ChannelContract.isPushRegistrationEnabled,
        fallback: ChannelContract.pushRegistrationEnabled,
      ),
      isPrimaryDevice: _bool(value, ChannelContract.isPrimaryDevice),
      notificationsEnabled: _bool(value, ChannelContract.notificationsEnabled),
      sdkVersion: _string(value, ChannelContract.sdkVersion),
      appVersion: _string(
        value,
        ChannelContract.appVersion,
        fallback: ChannelContract.applicationVersion,
      ),
      os: _string(
        value,
        ChannelContract.os,
        fallback: ChannelContract.operatingSystem,
      ),
      osVersion: _string(
        value,
        ChannelContract.osVersion,
        fallback: ChannelContract.operatingSystemVersion,
      ),
      deviceManufacturer: _string(value, ChannelContract.deviceManufacturer),
      deviceModel: _string(value, ChannelContract.deviceModel),
      deviceSecure: _bool(value, ChannelContract.deviceSecure),
      language: _string(value, ChannelContract.language),
      deviceTimezoneOffset: _string(
        value,
        ChannelContract.deviceTimezoneOffset,
        fallback: ChannelContract.deviceTimezoneId,
      ),
      applicationUserId: _string(
        value,
        ChannelContract.applicationUserId,
        fallback: ChannelContract.appUserId,
      ),
      deviceName: _string(value, ChannelContract.deviceName),
      customAttributes: UserCodec.decodeCustomAttributes(
        value[ChannelContract.customAttributes],
      ),
    );
  }

  static Map<String, Object?> encodeWritable(Installation value) => {
    ChannelContract.isPrimaryDevice: value.isPrimaryDevice,
    ChannelContract.isPushRegistrationEnabled: value.isPushRegistrationEnabled,
    ChannelContract.customAttributes: UserCodec.encodeCustomAttributes(
      value.customAttributes,
    ),
  };

  static String? _string(Map value, String key, {String? fallback}) {
    final item = value[key] ?? (fallback == null ? null : value[fallback]);
    if (item == null || item is String) return item as String?;
    throw FormatException('$key must be a string');
  }

  static bool? _bool(Map value, String key, {String? fallback}) {
    final item = value[key] ?? (fallback == null ? null : value[fallback]);
    if (item == null || item is bool) return item as bool?;
    throw FormatException('$key must be a boolean');
  }

  static PushServiceType? _serviceType(Object? value) {
    if (value == null) return null;
    if (value is! String)
      throw const FormatException('pushServiceType must be a string');
    return switch (value.toUpperCase()) {
      'APNS' => PushServiceType.APNS,
      'GCM' => PushServiceType.GCM,
      'FIREBASE' => PushServiceType.Firebase,
      'FCM' => PushServiceType.Firebase,
      'HMS' => PushServiceType.HMS,
      _ => throw FormatException('Unknown pushServiceType: $value'),
    };
  }
}
