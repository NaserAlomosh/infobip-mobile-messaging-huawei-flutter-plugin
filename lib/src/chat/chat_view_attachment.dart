/// An attachment whose native Chat preview was opened.
final class ChatViewAttachment {
  const ChatViewAttachment({this.url, this.type, this.caption});

  final String? url;
  final String? type;
  final String? caption;
}
