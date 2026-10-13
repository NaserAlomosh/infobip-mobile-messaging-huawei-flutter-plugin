import 'package:flutter/services.dart';

import '../../infobip_mobilemessaging_huawei.dart' show Installation;
import '../platform/channel_contract.dart';
import '../installation/installation_codec.dart';
import 'user.dart';

abstract final class UserCodec {
  static Map<String, Object?>? encodeCustomAttributes(
    Map<String, Object?>? value,
  ) => _encodeCustomAttributes(value);

  static Map<String, Object?>? decodeCustomAttributes(Object? value) {
    if (value == null) return null;
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw const FormatException(
        'customAttributes must be a string-keyed map',
      );
    }
    return _decodeCustomAttributes(value);
  }

  static Map<String, Object?> encodeIdentity(UserIdentity identity) =>
      <String, Object?>{
        ChannelContract.externalUserId: identity.externalUserId,
        ChannelContract.phones: identity.phones,
        ChannelContract.emails: identity.emails,
      };

  static Map<String, Object?> encodeAttributes(UserAttributes attributes) =>
      <String, Object?>{
        ChannelContract.firstName: attributes.firstName,
        ChannelContract.lastName: attributes.lastName,
        ChannelContract.middleName: attributes.middleName,
        ChannelContract.gender: _encodeGender(attributes.gender),
        ChannelContract.birthday: _birthday(attributes.birthday),
        ChannelContract.tags: attributes.tags,
        ChannelContract.customAttributes: _encodeCustomAttributes(
          attributes.customAttributes,
        ),
      };

  static Map<String, Object?> encode(UserData user) => <String, Object?>{
    ChannelContract.externalUserId: user.externalUserId,
    ChannelContract.firstName: user.firstName,
    ChannelContract.lastName: user.lastName,
    ChannelContract.middleName: user.middleName,
    ChannelContract.gender: _encodeGender(user.gender),
    ChannelContract.birthday: _birthday(user.birthday),
    ChannelContract.phones: user.phones,
    ChannelContract.emails: user.emails,
    ChannelContract.tags: user.tags,
    ChannelContract.customAttributes: _encodeCustomAttributes(
      user.customAttributes,
    ),
  };

  static UserData decode(Object? value) {
    if (value is! Map) {
      throw const FormatException('User payload must be a map.');
    }
    final map = value.cast<Object?, Object?>();
    return UserData(
      externalUserId: _string(map, ChannelContract.externalUserId),
      firstName: _string(map, ChannelContract.firstName),
      lastName: _string(map, ChannelContract.lastName),
      middleName: _string(map, ChannelContract.middleName),
      gender: _gender(map[ChannelContract.gender]),
      birthday: _birthday(map[ChannelContract.birthday]),
      type: _type(map[ChannelContract.type]),
      phones: _strings(map, ChannelContract.phones),
      emails: _strings(map, ChannelContract.emails),
      tags: _strings(map, ChannelContract.tags),
      customAttributes: _decodeCustomAttributes(
        map[ChannelContract.customAttributes],
      ),
      installations: _installations(map[ChannelContract.installations]),
    );
  }

  static String? _string(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value == null || value is String) return value as String?;
    throw FormatException('$key must be a string.');
  }

  static List<String>? _strings(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! List || value.any((element) => element is! String)) {
      throw FormatException('$key must be a list of strings.');
    }
    return List<String>.unmodifiable(value.cast<String>());
  }

  static Gender? _gender(Object? value) => switch (value) {
    null => null,
    'male' => Gender.Male,
    'female' => Gender.Female,
    String() => null,
    _ => throw const FormatException('gender must be a string.'),
  };

  static String? _encodeGender(Gender? value) => switch (value) {
    null => null,
    Gender.Male => 'male',
    Gender.Female => 'female',
  };

  static Type? _type(Object? value) => switch (value) {
    null => null,
    'lead' => Type.LEAD,
    'LEAD' => Type.LEAD,
    'customer' => Type.CUSTOMER,
    'CUSTOMER' => Type.CUSTOMER,
    String() => null,
    _ => throw const FormatException('type must be a string.'),
  };

  static List<Installation>? _installations(Object? value) {
    if (value == null) return null;
    if (value is! List) {
      throw const FormatException('installations must be a list.');
    }
    return List.unmodifiable(value.map(InstallationCodec.decode));
  }

  static String? _birthday(Object? value) {
    if (value == null) return null;
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('birthday must use YYYY-MM-DD.');
    }
    final parts = value.split('-').map(int.parse).toList();
    final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
    if (_dateOnly(parsed) != value) {
      throw const FormatException('birthday is not a valid date.');
    }
    return value;
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static Map<String, Object?>? _encodeCustomAttributes(
    Map<String, Object?>? attributes,
  ) => attributes?.map(
    (key, value) => MapEntry(key, _encodeCustomValue(value, key)),
  );

  static Object? _encodeCustomValue(Object? value, String key) {
    if (value == null || value is String || value is bool || value is num) {
      return value;
    }
    if (value is DateTime) {
      return <String, Object>{
        ChannelContract.customValueType: ChannelContract.customDateType,
        ChannelContract.customValue: value.toUtc().toIso8601String(),
      };
    }
    if (value is List) {
      return value
          .map((item) => _customRecord(item, key, encode: true))
          .toList();
    }
    throw PlatformException(
      code: 'invalid_argument',
      message: 'Unsupported custom attribute value for "$key".',
    );
  }

  static Map<String, Object?>? _decodeCustomAttributes(Object? value) {
    if (value == null) return null;
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw const FormatException(
        'customAttributes must be a string-keyed map.',
      );
    }
    return Map<String, Object?>.unmodifiable(
      value.cast<String, Object?>().map(
        (key, item) => MapEntry(key, _decodeCustomValue(item)),
      ),
    );
  }

  static Object? _decodeCustomValue(Object? value) {
    if (value == null || value is String || value is bool || value is num) {
      return value;
    }
    if (value is List) {
      return List<Object?>.unmodifiable(
        value.map(
          (item) =>
              item is Map && !item.containsKey(ChannelContract.customValueType)
              ? _customRecord(item, 'CustomList', encode: false)
              : _decodeCustomValue(item),
        ),
      );
    }
    if (value is Map) return _decodeTaggedCustomValue(value);
    throw const FormatException('Unsupported custom attribute value.');
  }

  static Map<String, Object?> _customRecord(
    Object? value,
    String key, {
    required bool encode,
  }) {
    if (value is! Map ||
        value.isEmpty ||
        value.keys.any((key) => key is! String)) {
      throw const FormatException(
        'CustomList must contain non-empty records with string keys.',
      );
    }
    return Map<String, Object?>.unmodifiable(
      value.map((field, item) {
        if (item is List || (item is Map && encode)) {
          throw const FormatException(
            'CustomList fields must be scalar values or DateTime.',
          );
        }
        return MapEntry(
          field as String,
          encode ? _encodeCustomValue(item, key) : _decodeCustomValue(item),
        );
      }),
    );
  }

  static DateTime _decodeTaggedCustomValue(Map<Object?, Object?> value) {
    if (value.length != 2 ||
        value[ChannelContract.customValueType] !=
            ChannelContract.customDateType ||
        value[ChannelContract.customValue] is! String) {
      throw const FormatException('Malformed custom attribute date value.');
    }
    final encoded = value[ChannelContract.customValue] as String;
    final parsed = DateTime.tryParse(encoded);
    if (parsed == null || !parsed.isUtc) {
      throw const FormatException('Malformed custom attribute date value.');
    }
    return parsed.toUtc();
  }
}
