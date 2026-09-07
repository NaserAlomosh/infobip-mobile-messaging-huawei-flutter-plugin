import 'chat_view_attachment.dart';
import 'widget_info.dart';

/// Runtime events emitted by one embedded Chat view.
sealed class InfobipHuaweiChatEvent {
  const InfobipHuaweiChatEvent();
}

/// The Live Chat widget finished its native loading sequence.
final class InfobipHuaweiChatLoadedEvent extends InfobipHuaweiChatEvent {
  const InfobipHuaweiChatLoadedEvent({required this.success});

  final bool success;
}

/// The user pressed the exit control in the native Chat view.
final class InfobipHuaweiChatExitPressedEvent extends InfobipHuaweiChatEvent {
  const InfobipHuaweiChatExitPressedEvent();
}

/// The Live Chat widget selected a different configured theme.
final class InfobipHuaweiChatWidgetThemeChangedEvent
    extends InfobipHuaweiChatEvent {
  const InfobipHuaweiChatWidgetThemeChangedEvent({required this.theme});

  final String theme;
}

/// The Live Chat widget configuration was updated.
final class InfobipHuaweiChatWidgetInfoUpdatedEvent
    extends InfobipHuaweiChatEvent {
  const InfobipHuaweiChatWidgetInfoUpdatedEvent({required this.widgetInfo});

  final WidgetInfo widgetInfo;
}

/// The native Chat attachment preview was opened.
final class InfobipHuaweiChatAttachmentPreviewOpenedEvent
    extends InfobipHuaweiChatEvent {
  const InfobipHuaweiChatAttachmentPreviewOpenedEvent({
    required this.attachment,
  });

  final ChatViewAttachment attachment;
}

/// An opaque raw message received from the Live Chat widget.
final class InfobipHuaweiChatRawMessageReceivedEvent
    extends InfobipHuaweiChatEvent {
  const InfobipHuaweiChatRawMessageReceivedEvent({required this.rawMessage});

  final String rawMessage;
}

/// A stable representation of the screen currently displayed by Chat.
enum InfobipHuaweiChatViewState {
  loading,
  threadList,
  loadingThread,
  thread,
  closedThread,
  singleModeThread,
  unknown,
}

/// Chat changed the screen displayed by this embedded view.
final class InfobipHuaweiChatViewChangedEvent extends InfobipHuaweiChatEvent {
  const InfobipHuaweiChatViewChangedEvent({
    required this.state,
    required this.rawValue,
  });

  final InfobipHuaweiChatViewState state;

  /// The Huawei SDK value, retained for forward compatibility.
  final String rawValue;
}

/// The connection state reported by the embedded Live Chat widget.
enum InfobipHuaweiChatConnectionState { connected, disconnected, unknown }

/// Chat resumed or paused its connection.
final class InfobipHuaweiChatConnectionChangedEvent
    extends InfobipHuaweiChatEvent {
  const InfobipHuaweiChatConnectionChangedEvent({
    required this.state,
    required this.rawValue,
  });

  final InfobipHuaweiChatConnectionState state;

  /// The native value, retained for forward compatibility.
  final String rawValue;
}
