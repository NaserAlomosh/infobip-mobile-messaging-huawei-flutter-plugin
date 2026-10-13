import 'message.dart';

/// A notification action selection and its related message.
final class NotificationActionEvent {
  const NotificationActionEvent({
    required this.actionId,
    required this.message,
  });

  final String? actionId;
  final Message message;
}
