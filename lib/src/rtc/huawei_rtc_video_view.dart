import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Camera source from an existing outgoing Huawei RTC video call.
enum HuaweiRtcVideoSource { local, remote }

/// Android-only camera rendering. Disposal releases the view, never the call.
///
/// Give this widget bounded space. Call/source changes create a fresh native view;
/// ordinary rebuilds reuse it. Remote selection pins the sole endpoint and blanks
/// when ambiguous or unavailable. Screen sharing is never selected.
class HuaweiRtcVideoView extends StatefulWidget {
  const HuaweiRtcVideoView({
    required this.callId,
    required this.source,
    super.key,
  });

  final String callId;
  final HuaweiRtcVideoSource source;

  @override
  State<HuaweiRtcVideoView> createState() => _HuaweiRtcVideoViewState();
}

class _HuaweiRtcVideoViewState extends State<HuaweiRtcVideoView>
    with WidgetsBindingObserver {
  int _generation = 0;
  bool _suspended = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      if (!_suspended && mounted) setState(() => _suspended = true);
    } else if (state == AppLifecycleState.resumed && _suspended && mounted) {
      setState(() {
        _suspended = false;
        _generation++;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final unavailable =
          kIsWeb ||
          defaultTargetPlatform != TargetPlatform.android ||
          widget.callId.trim().isEmpty ||
          _suspended ||
          !constraints.hasBoundedWidth ||
          !constraints.hasBoundedHeight;
      if (unavailable) {
        return const SizedBox(
          width: 160,
          height: 90,
          child: ColoredBox(
            color: Colors.black,
            child: Center(
              child: Text(
                'Video unavailable',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        );
      }
      return AndroidView(
        key: ValueKey((widget.callId, widget.source, _generation)),
        viewType: 'infobip_mobilemessaging_huawei/rtc_video',
        creationParams: {'callId': widget.callId, 'source': widget.source.name},
        creationParamsCodec: const StandardMessageCodec(),
      );
    },
  );
}
