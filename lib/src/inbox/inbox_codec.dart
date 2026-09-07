import 'inbox.dart';
import '../platform/channel_contract.dart';
import '../notifications/message.dart';
import '../notifications/push_message_codec.dart';

abstract final class InboxCodec {
  static Map<String, Object?>? encodeOptions(InboxFilterOptions? options) {
    if (options == null) return null;
    if (options.fromDateTime != null &&
        options.toDateTime != null &&
        options.fromDateTime!.isAfter(options.toDateTime!)) {
      throw ArgumentError('from must not be after to');
    }
    if (options.topic != null && options.topic!.trim().isEmpty) {
      throw ArgumentError.value(options.topic, 'topic', 'Must not be empty');
    }
    if (options.topic != null && options.topics != null) {
      throw ArgumentError('topic and topics are mutually exclusive');
    }
    if (options.topics != null &&
        (options.topics!.isEmpty ||
            options.topics!.any((topic) => topic.trim().isEmpty))) {
      throw ArgumentError.value(
        options.topics,
        'topics',
        'Must contain non-empty values',
      );
    }
    if (options.limit != null && options.limit! <= 0) {
      throw ArgumentError.value(options.limit, 'limit', 'Must be positive');
    }
    return {
      ChannelContract.from: options.fromDateTime?.toUtc().toIso8601String(),
      ChannelContract.to: options.toDateTime?.toUtc().toIso8601String(),
      ChannelContract.topic: options.topic,
      ChannelContract.topics: options.topics,
      ChannelContract.limit: options.limit,
    };
  }

  static Inbox decode(Object? value) {
    if (value == null) return _emptyInbox();
    final map = _map(value, 'Inbox result');
    final messages = map[ChannelContract.messages];
    if (messages != null && messages is! List) {
      throw const FormatException('Invalid Inbox messages');
    }
    return Inbox(
      countTotal: _integer(map[ChannelContract.countTotal], 'countTotal'),
      countUnread: _integer(map[ChannelContract.countUnread], 'countUnread'),
      countTotalFiltered: _integer(
        map[ChannelContract.countTotalFiltered],
        'countTotalFiltered',
      ),
      countUnreadFiltered: _integer(
        map[ChannelContract.countUnreadFiltered],
        'countUnreadFiltered',
      ),
      messages: List.unmodifiable(
        (messages as List? ?? const []).map(_decodeMessage),
      ),
    );
  }

  static Inbox _emptyInbox() => const Inbox(
    countTotal: 0,
    countUnread: 0,
    countTotalFiltered: 0,
    countUnreadFiltered: 0,
    messages: [],
  );

  static Message _decodeMessage(Object? value) {
    final map = _map(value, 'Inbox message');
    final message = PushMessageCodec.decode(map);
    if (message.messageId == null ||
        message.messageId!.isEmpty ||
        message.seen == null) {
      throw const FormatException('Invalid Inbox message');
    }
    return message;
  }

  static Map<Object?, Object?> _map(Object? value, String name) {
    if (value is! Map) throw FormatException('$name must be a map');
    return value;
  }

  static int _integer(Object? value, String name) {
    if (value == null) return 0;
    if (value is! num || !value.isFinite) {
      throw FormatException('Invalid $name');
    }
    final result = value.toInt();
    if (result < 0) throw FormatException('Invalid $name');
    return result;
  }
}
