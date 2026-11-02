import '../installation/installation.dart';

// Names intentionally match the official Infobip Flutter API.
// ignore_for_file: constant_identifier_names

enum Gender {
  Male,
  Female;

  @Deprecated('Use Gender.Male')
  static const male = Male;
  @Deprecated('Use Gender.Female')
  static const female = Female;
}

enum Type {
  LEAD,
  CUSTOMER;

  @Deprecated('Use Type.LEAD')
  static const Lead = LEAD;
  @Deprecated('Use Type.CUSTOMER')
  static const Customer = CUSTOMER;
}

class UserIdentity {
  UserIdentity({this.externalUserId, this.phones, this.emails});
  String? externalUserId;
  List<String>? phones;
  List<String>? emails;
}

class UserAttributes {
  UserAttributes({
    this.firstName,
    this.lastName,
    this.middleName,
    this.gender,
    this.birthday,
    this.tags,
    this.customAttributes,
  });
  String? firstName;
  String? lastName;
  String? middleName;
  Gender? gender;
  String? birthday;
  List<String>? tags;
  Map<String, dynamic>? customAttributes;
}

/// A Mobile Messaging user profile.
class UserData {
  UserData({
    this.externalUserId,
    this.firstName,
    this.lastName,
    this.middleName,
    this.gender,
    this.birthday,
    this.type,
    this.phones,
    this.emails,
    this.tags,
    this.customAttributes,
    this.installations,
  });
  String? externalUserId;
  String? firstName;
  String? lastName;
  String? middleName;
  Gender? gender;
  String? birthday;
  Type? type;
  List<String>? phones;
  List<String>? emails;
  List<String>? tags;
  Map<String, dynamic>? customAttributes;
  List<Installation>? installations;
}

/// Backwards-compatible name for [UserData].
@Deprecated('Use UserData')
typedef User = UserData;

/// Values used to personalize an installation.
class PersonalizeContext {
  PersonalizeContext({
    this.forceDepersonalize = false,
    required this.userIdentity,
    this.userAttributes,
  });
  final bool forceDepersonalize;
  final UserIdentity userIdentity;
  final UserAttributes? userAttributes;
}

/// One explicit patch operation. Null is represented only by [FieldUpdate.clear].
class FieldUpdate<T extends Object> {
  const FieldUpdate.omitted() : included = false, value = null;
  const FieldUpdate.set(T this.value) : included = true;
  const FieldUpdate.clear() : included = true, value = null;
  final bool included;
  final T? value;
}

/// Partial user update. Unspecified fields remain unchanged.
/// Clear custom attributes individually with null map values.
class UserPatch {
  const UserPatch({
    this.externalUserId = const FieldUpdate.omitted(),
    this.firstName = const FieldUpdate.omitted(),
    this.lastName = const FieldUpdate.omitted(),
    this.middleName = const FieldUpdate.omitted(),
    this.gender = const FieldUpdate.omitted(),
    this.birthday = const FieldUpdate.omitted(),
    this.phones = const FieldUpdate.omitted(),
    this.emails = const FieldUpdate.omitted(),
    this.tags = const FieldUpdate.omitted(),
    this.customAttributes = const FieldUpdate.omitted(),
  });
  final FieldUpdate<String> externalUserId;
  final FieldUpdate<String> firstName;
  final FieldUpdate<String> lastName;
  final FieldUpdate<String> middleName;
  final FieldUpdate<Gender> gender;
  final FieldUpdate<String> birthday;
  final FieldUpdate<List<String>> phones;
  final FieldUpdate<List<String>> emails;
  final FieldUpdate<List<String>> tags;
  final FieldUpdate<Map<String, Object?>> customAttributes;
}
