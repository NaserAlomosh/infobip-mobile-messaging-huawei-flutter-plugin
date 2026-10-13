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
