import 'widget_attachment_config.dart';

/// Configuration reported by the Live Chat widget.
final class WidgetInfo {
  const WidgetInfo({
    this.id,
    this.title,
    this.primaryColor,
    this.backgroundColor,
    this.primaryTextColor,
    this.multiThread,
    this.multiChannelConversationEnabled,
    this.callsEnabled,
    this.themeNames,
    this.attachmentConfig,
  });

  final String? id;
  final String? title;
  final String? primaryColor;
  final String? backgroundColor;
  final String? primaryTextColor;
  final bool? multiThread;
  final bool? multiChannelConversationEnabled;
  final bool? callsEnabled;
  final List<String>? themeNames;
  final WidgetAttachmentConfig? attachmentConfig;
}
