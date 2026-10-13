/// An exception reported by the native In-App Chat widget.
final class ChatException {
  const ChatException({required this.message, required this.name});

  /// Human-readable exception description supplied by the Chat SDK.
  final String? message;

  /// Exception category supplied by the Chat SDK.
  final String? name;

  @override
  String toString() => 'ChatException(message: $message, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatException && other.message == message && other.name == name;

  @override
  int get hashCode => Object.hash(message, name);
}
