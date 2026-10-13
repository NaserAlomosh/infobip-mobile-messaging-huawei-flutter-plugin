/// A custom event submitted to the Infobip event service.
final class InfobipHuaweiCustomEvent {
  const InfobipHuaweiCustomEvent({
    required this.definitionId,
    this.eventId,
    this.createdAt,
    this.properties,
  });

  /// Identifier of the event definition configured in Infobip.
  final String definitionId;

  /// Server-assigned event identifier, when returned by Infobip.
  final String? eventId;

  /// Server event creation time, when returned by Infobip.
  final DateTime? createdAt;

  /// Values defined by the corresponding event definition.
  final Map<String, Object?>? properties;
}
