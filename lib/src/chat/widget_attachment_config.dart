/// Attachment capabilities configured for a Live Chat widget.
final class WidgetAttachmentConfig {
  const WidgetAttachmentConfig({
    this.maxSize,
    this.isEnabled,
    this.allowedExtensions,
  });

  final int? maxSize;
  final bool? isEnabled;
  final List<String>? allowedExtensions;
}
