import '../notifications/message.dart';

/// Server-side options used when fetching Inbox messages.
class FilterOptions {
  const FilterOptions({
    DateTime? fromDateTime,
    DateTime? toDateTime,
    this.topic,
    this.topics,
    this.limit,
    DateTime? from,
    DateTime? to,
  }) : fromDateTime = fromDateTime ?? from,
       toDateTime = toDateTime ?? to;

  final DateTime? fromDateTime;
  final DateTime? toDateTime;
  final String? topic;
  final List<String>? topics;
  final int? limit;

  @Deprecated('Use fromDateTime')
  DateTime? get from => fromDateTime;
  @Deprecated('Use toDateTime')
  DateTime? get to => toDateTime;
}

@Deprecated('Use FilterOptions')
typedef InboxFilterOptions = FilterOptions;

class Inbox {
  const Inbox({
    required this.countTotal,
    required this.countUnread,
    required this.countTotalFiltered,
    required this.countUnreadFiltered,
    required this.messages,
  });
  final int countTotal;
  final int countUnread;
  final int countTotalFiltered;
  final int countUnreadFiltered;
  final List<InboxMessage> messages;
}

/// A Mobile Inbox message. Its sent time is independent of push receipt time.
class InboxMessage extends Message {
  const InboxMessage({
    required String messageId,
    required String topic,
    required bool seen,
    super.title,
    super.body,
    super.sound,
    super.vibrate,
    super.silent,
    super.category,
    super.customPayload,
    super.internalData,
    super.contentUrl,
    super.originalPayload,
    super.browserUrl,
    super.deeplink,
    super.webViewUrl,
    super.inAppOpenTitle,
    super.inAppDismissTitle,
    super.receivedTimestamp,
    this.sentTimestamp,
  }) : super(messageId: messageId, topic: topic, seen: seen);

  @override
  String get messageId => super.messageId!;
  @override
  String get topic => super.topic!;
  @override
  bool get seen => super.seen!;

  /// Milliseconds since epoch supplied by Huawei's sentTimestamp field.
  final num? sentTimestamp;
}
