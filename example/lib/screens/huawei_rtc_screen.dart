import 'dart:async';

import 'package:flutter/material.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

import '../setup/example_controller.dart';
import '../setup/feature_readiness.dart';
import '../setup/safe_display.dart';

/// Deliberately small device-validation surface, not a call UI or video renderer.
class HuaweiRtcScreen extends StatefulWidget {
  const HuaweiRtcScreen({
    required this.controller,
    required this.video,
    super.key,
  });
  final ExampleController controller;
  final bool video;

  @override
  State<HuaweiRtcScreen> createState() => _HuaweiRtcScreenState();
}

class _HuaweiRtcScreenState extends State<HuaweiRtcScreen> {
  ExampleController get c => widget.controller;
  final _events = <String>[];
  StreamSubscription<HuaweiRtcEvent>? _subscription;
  bool _starting = false;
  bool _active = false;
  String _result = 'Start a call, then watch for an established event.';

  @override
  void initState() {
    super.initState();
    _subscription = HuaweiRtc.events.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _active =
              event.call != null &&
              event.call!.status != HuaweiRtcCallStatus.finished;
          _events.insert(
            0,
            '${event.sequence}: ${event.type.name} / '
            '${event.call?.status.name ?? 'idle'}'
            '${event.nativeErrorCode == null ? '' : ' / reason ${event.nativeErrorCode}'}',
          );
          if (_events.length > 30) _events.removeLast();
        });
      },
      onError: (Object _) {
        if (mounted) setState(() => _result = 'RTC event stream error.');
      },
    );
  }

  Future<void> _call(HuaweiRtcCallType type) async {
    await c.refresh();
    if (!mounted ||
        _starting ||
        _active ||
        !c
            .readiness(
              type == HuaweiRtcCallType.video
                  ? ExampleFeature.rtcVideo
                  : ExampleFeature.rtcAudio,
            )
            .isReady) {
      return;
    }
    setState(() => _starting = true);
    try {
      final call = await HuaweiRtc.callApplication(
        HuaweiRtcCallRequest(
          callsConfigurationId: c.config.rtcCallsConfigurationId.trim(),
          type: type,
          identity: c.config.rtcIdentity.trim().isEmpty
              ? null
              : c.config.rtcIdentity.trim(),
        ),
      );
      if (mounted) {
        setState(() {
          _active = call.status != HuaweiRtcCallStatus.finished;
          _result =
              'Native ${call.type.name} call created; watch events for establishment.';
        });
      }
    } on HuaweiRtcException catch (error) {
      if (mounted) {
        setState(() => _result = safeFailure('RTC operation', error));
      }
    } on ArgumentError {
      if (mounted) setState(() => _result = 'Enter a Calls configuration ID.');
    } catch (_) {
      if (mounted) setState(() => _result = 'RTC operation unavailable.');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _hangup() async {
    try {
      await HuaweiRtc.hangup();
      if (mounted) {
        setState(() => _result = 'Hangup requested; wait for finished.');
      }
    } on HuaweiRtcException catch (error) {
      if (mounted) {
        setState(() => _result = safeFailure('RTC operation', error));
      }
    } catch (_) {
      if (mounted) setState(() => _result = 'RTC operation unavailable.');
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(
          'Huawei outgoing RTC · ${widget.video ? 'Video' : 'Audio'}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Device test only. Grant Microphone, Camera (video), and Nearby devices '
            '(Android 12+) in Android App info → Permissions, then return here. '
            'Use a test account with Web and In-app Calls enabled. '
            'Keep the app in the foreground. Video is transmitted without a local '
            'preview or remote video renderer; confirm media at the receiving endpoint.',
          ),
          Text(
            'Calls configuration: ${masked(c.config.rtcCallsConfigurationId)}',
          ),
          Text(
            'Identity: ${c.config.rtcIdentity.trim().isEmpty ? 'registered installation' : masked(c.config.rtcIdentity)}',
          ),
          ...c
              .readiness(
                widget.video
                    ? ExampleFeature.rtcVideo
                    : ExampleFeature.rtcAudio,
              )
              .missing
              .map((r) => Text('Missing: ${r.title}')),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed:
                    _starting ||
                        _active ||
                        c.busy ||
                        !c
                            .readiness(
                              widget.video
                                  ? ExampleFeature.rtcVideo
                                  : ExampleFeature.rtcAudio,
                            )
                            .isReady
                    ? null
                    : () => _call(
                        widget.video
                            ? HuaweiRtcCallType.video
                            : HuaweiRtcCallType.audio,
                      ),
                child: Text(widget.video ? 'Video call' : 'Audio call'),
              ),
              OutlinedButton(
                onPressed: _active && !_starting ? _hangup : null,
                child: const Text('Hang up'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_result),
          const Text(
            'Leaving this screen does not hang up. Return here to end the call.',
          ),
          const Divider(),
          const Text('Recent events'),
          ..._events.map(Text.new),
        ],
      ),
    ),
  );
}
