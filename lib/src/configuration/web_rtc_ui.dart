/// Optional configuration for the Infobip WebRTC user interface.
///
/// A configuration ID is not required during Mobile Messaging initialization.
/// It will be consumed by the WebRTC call APIs when those APIs are available.
final class WebRTCUI {
  const WebRTCUI({this.configurationId});

  final String? configurationId;
}
