/// Customizes a native Chat toolbar.
final class ToolbarCustomization {
  const ToolbarCustomization({
    this.titleTextAppearance,
    this.titleTextColor,
    this.titleText,
    this.titleCentered,
    this.backgroundColor,
    this.navigationIcon,
    this.navigationIconTint,
    this.subtitleTextAppearance,
    this.subtitleTextColor,
    this.subtitleText,
    this.subtitleCentered,
  });

  final String? titleTextAppearance;
  final String? titleTextColor;
  final String? titleText;
  final bool? titleCentered;
  final String? backgroundColor;
  final String? navigationIcon;
  final String? navigationIconTint;

  /// Android-only subtitle text appearance resource name.
  final String? subtitleTextAppearance;
  final String? subtitleTextColor;
  final String? subtitleText;
  final bool? subtitleCentered;

  Map<String, Object?> toJson() => {
    'titleTextAppearance': titleTextAppearance,
    'titleTextColor': titleTextColor,
    'titleText': titleText,
    'titleCentered': titleCentered,
    'backgroundColor': backgroundColor,
    'navigationIcon': navigationIcon,
    'navigationIconTint': navigationIconTint,
    'subtitleTextAppearance': subtitleTextAppearance,
    'subtitleTextColor': subtitleTextColor,
    'subtitleText': subtitleText,
    'subtitleCentered': subtitleCentered,
  };
}

/// Customizes the native Infobip Chat interface.
final class ChatCustomization {
  const ChatCustomization({
    this.chatStatusBarBackgroundColor,
    this.chatStatusBarIconsColorMode,
    this.chatToolbar,
    this.attachmentPreviewToolbar,
    this.attachmentPreviewToolbarSaveMenuItemIcon,
    this.attachmentPreviewToolbarMenuItemsIconTint,
    this.networkErrorText,
    this.networkErrorTextColor,
    this.networkErrorTextAppearance,
    this.networkErrorLabelBackgroundColor,
    this.networkErrorIcon,
    this.networkErrorIconTint,
    this.chatBannerErrorTextColor,
    this.chatBannerErrorTextAppearance,
    this.chatBannerErrorBackgroundColor,
    this.chatBannerErrorIcon,
    this.chatBannerErrorIconTint,
    this.chatFullScreenErrorTitleText,
    this.chatFullScreenErrorTitleTextColor,
    this.chatFullScreenErrorTitleTextAppearance,
    this.chatFullScreenErrorDescriptionText,
    this.chatFullScreenErrorDescriptionTextColor,
    this.chatFullScreenErrorDescriptionTextAppearance,
    this.chatFullScreenErrorBackgroundColor,
    this.chatFullScreenErrorIcon,
    this.chatFullScreenErrorIconTint,
    this.chatFullScreenErrorRefreshButtonText,
    this.chatFullScreenErrorRefreshButtonTextColor,
    this.chatFullScreenErrorRefreshButtonVisible,
    this.chatBackgroundColor,
    this.chatProgressBarColor,
    this.chatInputTextAppearance,
    this.chatInputTextColor,
    this.chatInputBackgroundColor,
    this.chatInputHintText,
    this.chatInputHintTextColor,
    this.chatInputAttachmentIcon,
    this.chatInputAttachmentIconTint,
    this.chatInputAttachmentDisabledIconTint,
    this.chatInputAttachmentBackgroundDrawable,
    this.chatInputAttachmentBackgroundColor,
    this.chatInputSendIcon,
    this.chatInputSendIconTint,
    this.chatInputSendDisabledIconTint,
    this.chatInputSendBackgroundDrawable,
    this.chatInputSendBackgroundColor,
    this.chatInputSeparatorLineColor,
    this.chatInputSeparatorLineVisible,
    this.chatInputCursorColor,
    this.chatInputCharCounterTextAppearance,
    this.chatInputCharCounterDefaultColor,
    this.chatInputCharCounterAlertColor,
    this.shouldHandleKeyboardAppearance,
  });

  final String? chatStatusBarBackgroundColor;
  final String? chatStatusBarIconsColorMode;
  final ToolbarCustomization? chatToolbar;
  final ToolbarCustomization? attachmentPreviewToolbar;
  final String? attachmentPreviewToolbarSaveMenuItemIcon;
  final String? attachmentPreviewToolbarMenuItemsIconTint;
  final String? networkErrorText;
  final String? networkErrorTextColor;
  final String? networkErrorTextAppearance;
  final String? networkErrorLabelBackgroundColor;
  final String? networkErrorIcon;
  final String? networkErrorIconTint;
  final String? chatBannerErrorTextColor;
  final String? chatBannerErrorTextAppearance;
  final String? chatBannerErrorBackgroundColor;
  final String? chatBannerErrorIcon;
  final String? chatBannerErrorIconTint;
  final String? chatFullScreenErrorTitleText;
  final String? chatFullScreenErrorTitleTextColor;
  final String? chatFullScreenErrorTitleTextAppearance;
  final String? chatFullScreenErrorDescriptionText;
  final String? chatFullScreenErrorDescriptionTextColor;
  final String? chatFullScreenErrorDescriptionTextAppearance;
  final String? chatFullScreenErrorBackgroundColor;
  final String? chatFullScreenErrorIcon;
  final String? chatFullScreenErrorIconTint;
  final String? chatFullScreenErrorRefreshButtonText;
  final String? chatFullScreenErrorRefreshButtonTextColor;
  final bool? chatFullScreenErrorRefreshButtonVisible;
  final String? chatBackgroundColor;
  final String? chatProgressBarColor;
  final String? chatInputTextAppearance;
  final String? chatInputTextColor;
  final String? chatInputBackgroundColor;
  final String? chatInputHintText;
  final String? chatInputHintTextColor;
  final String? chatInputAttachmentIcon;
  final String? chatInputAttachmentIconTint;
  final String? chatInputAttachmentDisabledIconTint;
  final String? chatInputAttachmentBackgroundDrawable;
  final String? chatInputAttachmentBackgroundColor;
  final String? chatInputSendIcon;
  final String? chatInputSendIconTint;
  final String? chatInputSendDisabledIconTint;
  final String? chatInputSendBackgroundDrawable;
  final String? chatInputSendBackgroundColor;
  final String? chatInputSeparatorLineColor;
  final bool? chatInputSeparatorLineVisible;
  final String? chatInputCursorColor;
  final String? chatInputCharCounterTextAppearance;
  final String? chatInputCharCounterDefaultColor;
  final String? chatInputCharCounterAlertColor;

  /// iOS-only in the official API. Huawei Android ignores this value.
  final bool? shouldHandleKeyboardAppearance;

  Map<String, Object?> toJson() => {
    'chatStatusBarBackgroundColor': chatStatusBarBackgroundColor,
    'chatStatusBarIconsColorMode': chatStatusBarIconsColorMode,
    'chatToolbar': chatToolbar?.toJson(),
    'attachmentPreviewToolbar': attachmentPreviewToolbar?.toJson(),
    'attachmentPreviewToolbarSaveMenuItemIcon': attachmentPreviewToolbarSaveMenuItemIcon,
    'attachmentPreviewToolbarMenuItemsIconTint': attachmentPreviewToolbarMenuItemsIconTint,
    'networkErrorText': networkErrorText,
    'networkErrorTextColor': networkErrorTextColor,
    'networkErrorTextAppearance': networkErrorTextAppearance,
    'networkErrorLabelBackgroundColor': networkErrorLabelBackgroundColor,
    'networkErrorIcon': networkErrorIcon,
    'networkErrorIconTint': networkErrorIconTint,
    'chatBannerErrorTextColor': chatBannerErrorTextColor,
    'chatBannerErrorTextAppearance': chatBannerErrorTextAppearance,
    'chatBannerErrorBackgroundColor': chatBannerErrorBackgroundColor,
    'chatBannerErrorIcon': chatBannerErrorIcon,
    'chatBannerErrorIconTint': chatBannerErrorIconTint,
    'chatFullScreenErrorTitleText': chatFullScreenErrorTitleText,
    'chatFullScreenErrorTitleTextColor': chatFullScreenErrorTitleTextColor,
    'chatFullScreenErrorTitleTextAppearance': chatFullScreenErrorTitleTextAppearance,
    'chatFullScreenErrorDescriptionText': chatFullScreenErrorDescriptionText,
    'chatFullScreenErrorDescriptionTextColor': chatFullScreenErrorDescriptionTextColor,
    'chatFullScreenErrorDescriptionTextAppearance': chatFullScreenErrorDescriptionTextAppearance,
    'chatFullScreenErrorBackgroundColor': chatFullScreenErrorBackgroundColor,
    'chatFullScreenErrorIcon': chatFullScreenErrorIcon,
    'chatFullScreenErrorIconTint': chatFullScreenErrorIconTint,
    'chatFullScreenErrorRefreshButtonText': chatFullScreenErrorRefreshButtonText,
    'chatFullScreenErrorRefreshButtonTextColor': chatFullScreenErrorRefreshButtonTextColor,
    'chatFullScreenErrorRefreshButtonVisible': chatFullScreenErrorRefreshButtonVisible,
    'chatBackgroundColor': chatBackgroundColor,
    'chatProgressBarColor': chatProgressBarColor,
    'chatInputTextAppearance': chatInputTextAppearance,
    'chatInputTextColor': chatInputTextColor,
    'chatInputBackgroundColor': chatInputBackgroundColor,
    'chatInputHintText': chatInputHintText,
    'chatInputHintTextColor': chatInputHintTextColor,
    'chatInputAttachmentIcon': chatInputAttachmentIcon,
    'chatInputAttachmentIconTint': chatInputAttachmentIconTint,
    'chatInputAttachmentDisabledIconTint': chatInputAttachmentDisabledIconTint,
    'chatInputAttachmentBackgroundDrawable': chatInputAttachmentBackgroundDrawable,
    'chatInputAttachmentBackgroundColor': chatInputAttachmentBackgroundColor,
    'chatInputSendIcon': chatInputSendIcon,
    'chatInputSendIconTint': chatInputSendIconTint,
    'chatInputSendDisabledIconTint': chatInputSendDisabledIconTint,
    'chatInputSendBackgroundDrawable': chatInputSendBackgroundDrawable,
    'chatInputSendBackgroundColor': chatInputSendBackgroundColor,
    'chatInputSeparatorLineColor': chatInputSeparatorLineColor,
    'chatInputSeparatorLineVisible': chatInputSeparatorLineVisible,
    'chatInputCursorColor': chatInputCursorColor,
    'chatInputCharCounterTextAppearance': chatInputCharCounterTextAppearance,
    'chatInputCharCounterDefaultColor': chatInputCharCounterDefaultColor,
    'chatInputCharCounterAlertColor': chatInputCharCounterAlertColor,
    'shouldHandleKeyboardAppearance': shouldHandleKeyboardAppearance,
  };
}
