import 'package:flutter/services.dart';

import '../platform/channel_contract.dart';
import '../user/user_codec.dart';
import 'custom_event.dart';

abstract final class CustomEventCodec {
  static Map<String, Object?> encode(InfobipHuaweiCustomEvent event) {
    final definitionId = event.definitionId.trim();
    if (definitionId.isEmpty) {
      throw ArgumentError.value(
        event.definitionId,
        'event.definitionId',
        'Must not be empty or whitespace-only',
      );
    }
    if (event.eventId != null || event.createdAt != null) {
      throw PlatformException(
        code: 'invalid_argument',
        message: 'eventId and createdAt are read-only',
      );
    }
    return <String, Object?>{
      ChannelContract.definitionId: definitionId,
      ChannelContract.properties: UserCodec.encodeCustomAttributes(
        event.properties,
      ),
    };
  }

  static InfobipHuaweiCustomEvent decode(Object? value) {
    if (value is! Map) {
      throw const FormatException('Custom event payload must be a map.');
    }

    final map = value.cast<Object?, Object?>();

    final rawDefinitionId = map[ChannelContract.definitionId];
    final rawEventId = map[ChannelContract.eventId];
    final rawCreatedAt = map[ChannelContract.createdAt];

    if (rawDefinitionId is! String || rawDefinitionId.trim().isEmpty) {
      throw const FormatException('definitionId must be a non-empty string.');
    }

    if (rawEventId != null && rawEventId is! String) {
      throw const FormatException('eventId must be a string.');
    }

    if (rawCreatedAt != null && rawCreatedAt is! String) {
      throw const FormatException('createdAt must be a string.');
    }

    final definitionId = rawDefinitionId;
    final eventId = rawEventId as String?;
    final createdAt = rawCreatedAt as String?;

    final parsedCreatedAt = createdAt == null
        ? null
        : DateTime.tryParse(createdAt);

    if (createdAt != null && parsedCreatedAt == null) {
      throw const FormatException('createdAt must be an ISO-8601 timestamp.');
    }

    return InfobipHuaweiCustomEvent(
      definitionId: definitionId,
      eventId: eventId,
      createdAt: parsedCreatedAt?.toUtc(),
      properties: UserCodec.decodeCustomAttributes(
        map[ChannelContract.properties],
      ),
    );
  }
}
