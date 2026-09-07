/// Push transport used by an Infobip installation.
// ignore_for_file: constant_identifier_names
enum PushServiceType {
  GCM,
  Firebase,
  APNS,
  HMS;

  @Deprecated('Use PushServiceType.Firebase')
  static const FCM = Firebase;
}

/// An Infobip installation associated with this application instance.
///
/// Huawei accepts changes to [isPrimaryDevice],
/// [isPushRegistrationEnabled], and [customAttributes]. Other properties are
/// native-managed snapshots.
class Installation {
  Installation({
    this.installationId,
    this.pushRegistrationId,
    this.pushServiceToken,
    this.pushServiceType,
    this.isPrimaryDevice,
    bool? isPushRegistrationEnabled,
    this.notificationsEnabled,
    this.sdkVersion,
    String? appVersion,
    String? os,
    String? osVersion,
    this.deviceManufacturer,
    this.deviceModel,
    this.deviceSecure,
    this.language,
    String? deviceTimezoneOffset,
    String? applicationUserId,
    this.deviceName,
    this.customAttributes,
    bool? pushRegistrationEnabled,
    String? applicationVersion,
    String? operatingSystem,
    String? operatingSystemVersion,
    String? deviceTimezoneId,
    String? appUserId,
  }) : isPushRegistrationEnabled =
           isPushRegistrationEnabled ?? pushRegistrationEnabled,
       appVersion = appVersion ?? applicationVersion,
       os = os ?? operatingSystem,
       osVersion = osVersion ?? operatingSystemVersion,
       deviceTimezoneOffset = deviceTimezoneOffset ?? deviceTimezoneId,
       applicationUserId = applicationUserId ?? appUserId;

  final String? installationId;
  final String? pushRegistrationId;
  final String? pushServiceToken;
  final PushServiceType? pushServiceType;
  bool? isPrimaryDevice;
  bool? isPushRegistrationEnabled;
  final bool? notificationsEnabled;
  final String? sdkVersion;
  final String? appVersion;
  final String? os;
  final String? osVersion;
  final String? deviceManufacturer;
  final String? deviceModel;
  final bool? deviceSecure;
  final String? language;
  final String? deviceTimezoneOffset;
  final String? applicationUserId;
  final String? deviceName;
  Map<String, dynamic>? customAttributes;

  @Deprecated('Use isPushRegistrationEnabled')
  bool? get pushRegistrationEnabled => isPushRegistrationEnabled;
  @Deprecated('Use isPushRegistrationEnabled')
  set pushRegistrationEnabled(bool? value) => isPushRegistrationEnabled = value;
  @Deprecated('Use appVersion')
  String? get applicationVersion => appVersion;
  @Deprecated('Use os')
  String? get operatingSystem => os;
  @Deprecated('Use osVersion')
  String? get operatingSystemVersion => osVersion;
  @Deprecated('Use deviceTimezoneOffset')
  String? get deviceTimezoneId => deviceTimezoneOffset;
  @Deprecated('Use applicationUserId')
  String? get appUserId => applicationUserId;
}
