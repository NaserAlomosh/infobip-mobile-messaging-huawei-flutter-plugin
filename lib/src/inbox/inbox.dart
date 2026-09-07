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
  final List<Message> messages;
}

@Deprecated('Use Message')
typedef InboxMessage = Message;
