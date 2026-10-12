import 'dart:async';

import 'package:flutter/material.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

import '../setup/example_controller.dart';
import '../setup/feature_readiness.dart';
import '../setup/safe_display.dart';

/// Device-validation surface for the existing outgoing call and camera views.
class HuaweiRtcScreen extends StatefulWidget {
  static const routeName = '/huawei-rtc';
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
  ScreenAsCameraState? _capture;
  StreamSubscription<ScreenAsCameraState>? _captureSubscription;
  bool _captureStarting = false;
  String? _captureError;
  bool get _cameraLocked => _captureStarting || _capture?.busy == true;
  bool _captureActionBusy = false;
  bool _starting = false;
  bool _controlBusy = false;
  bool _polling = false;
  int _revision = 0;
  HuaweiRtcControls? _controls;
  Timer? _timer;
  bool _active = false;
  HuaweiRtcCall? _activeCall;
  String _result = 'Start a call, then watch for an established event.';

  @override
  void initState() {
    super.initState();
    _captureSubscription = HuaweiRtcScreenAsCamera.states.listen(
      (state) {
        if (mounted && state.callId == _activeCall?.id) {
          setState(() => _capture = state);
        }
      },
      onError: (Object _) {
        if (mounted) {
          setState(() => _captureError = 'Capture state stream unavailable.');
        }
      },
    );
    unawaited(_refreshActive());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_active && !_controlBusy && !_polling) unawaited(_refreshControls());
    });
    _subscription = HuaweiRtc.events.listen(
      (event) {
        if (!mounted) return;
        _revision++;
        setState(() {
          if (_activeCall?.id != event.call?.id ||
              event.call?.status == HuaweiRtcCallStatus.finished) {
            _controls = null;
          }
          _activeCall = event.call;
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
        if (_active && !_controlBusy) unawaited(_refreshControls());
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
          _activeCall = call;
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

  Future<void> _probe({bool deniedPermission = false}) async {
    try {
      if (deniedPermission) {
        await c.refresh();
        final permissions = c.permissions;
        if (permissions.microphone == true &&
            permissions.nearbyDevices == true &&
            (!widget.video || permissions.camera == true)) {
          setState(
            () => _result =
                'Revoke a required permission in Android settings first.',
          );
          return;
        }
      } else if (!_active) {
        setState(
          () => _result =
              'Start and keep a call active before testing a second call.',
        );
        return;
      }
      final call = await HuaweiRtc.callApplication(
        HuaweiRtcCallRequest(
          callsConfigurationId: c.config.rtcCallsConfigurationId,
          identity: c.config.rtcIdentity.isEmpty ? null : c.config.rtcIdentity,
          type: widget.video
              ? HuaweiRtcCallType.video
              : HuaweiRtcCallType.audio,
        ),
      );
      if (mounted) {
        setState(
          () => _result =
              'Unexpected native call returned: ${call.status.name}. Verify and hang up.',
        );
      }
    } catch (error) {
      final summary = safeFailure('RTC rejection probe', error);
      c.session.log('RTC', 'Rejection probe', details: {'summary': summary});
      if (mounted) setState(() => _result = summary);
    }
  }

  Future<void> _refreshActive() async {
    final revision = _revision;
    try {
      final call = await HuaweiRtc.getActiveCall();
      c.session.log(
        'RTC',
        'Active call snapshot',
        details: {'status': call?.status.name, 'type': call?.type.name},
      );
      if (mounted && revision == _revision) {
        setState(() {
          if (_activeCall?.id != call?.id) _controls = null;
          _activeCall = call;
          _active = call != null && call.status != HuaweiRtcCallStatus.finished;
          _result = 'Active call: ${call?.status.name ?? 'none'}';
        });
        if (_active) await _refreshControls();
      }
    } catch (error) {
      if (mounted) setState(() => _result = safeFailure('RTC snapshot', error));
    }
  }

  Future<void> _refreshControls() async {
    final id = _activeCall?.id;
    if (id == null || !_active || _polling || _controlBusy) return;
    _polling = true;
    final revision = _revision;
    try {
      final controls = await HuaweiRtc.getCallControls(callId: id);
      final call = await HuaweiRtc.getActiveCall();
      final capture = call?.id == id
          ? await HuaweiRtcScreenAsCamera.getScreenAsCameraState(callId: id)
          : null;
      if (mounted && revision == _revision && _activeCall?.id == id) {
        setState(() {
          _capture = capture;
          _controls = call?.id == id ? controls : null;
          _activeCall = call;
          _active = call != null && call.status != HuaweiRtcCallStatus.finished;
        });
      }
    } catch (_) {
      if (mounted && revision == _revision && _activeCall?.id == id) {
        setState(() => _controls = null);
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _control(
    Future<HuaweiRtcControls> Function(String) operation,
  ) async {
    final id = _activeCall?.id;
    if (id == null || _controlBusy) return;
    _revision++; // Invalidates readbacks started before this operation.
    setState(() => _controlBusy = true);
    try {
      final controls = await operation(id);
      if (mounted && _active && _activeCall?.id == id) {
        setState(() => _controls = controls);
      }
    } catch (error) {
      if (mounted && _activeCall?.id == id) {
        setState(() {
          _controls = null;
          _result = safeFailure('RTC control', error);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _controlBusy = false);
        unawaited(_refreshControls());
      }
    }
  }

  Widget _callControls() {
    final controls = _controls;
    final enabled =
        _active &&
        !_starting &&
        !_controlBusy &&
        _activeCall?.status == HuaweiRtcCallStatus.established &&
        controls != null;
    final video = _activeCall?.type == HuaweiRtcCallType.video;
    final seconds = _activeCall?.duration.inSeconds ?? 0;
    final duration =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Call duration: $duration'),
        Text(
          'Microphone: ${controls == null
              ? 'unknown'
              : controls.microphoneMuted
              ? 'muted'
              : 'on'} · '
          'Camera: ${controls == null
              ? 'unknown'
              : controls.cameraEnabled
              ? 'on'
              : 'off'} · '
          'Facing: ${controls?.cameraOrientation?.name ?? 'unknown'} · '
          'Audio: ${controls?.audioOutput?.name ?? 'unknown'}',
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: enabled
                  ? () => _control(
                      (id) => HuaweiRtc.setMicrophoneMuted(
                        !controls.microphoneMuted,
                        callId: id,
                      ),
                    )
                  : null,
              child: Text(
                controls?.microphoneMuted == true
                    ? 'Unmute microphone'
                    : 'Mute microphone',
              ),
            ),
            OutlinedButton(
              onPressed:
                  enabled &&
                      controls.availableAudioOutputs.contains(
                        controls.speakerEnabled
                            ? HuaweiRtcAudioOutput.earpiece
                            : HuaweiRtcAudioOutput.speaker,
                      )
                  ? () => _control(
                      (id) => HuaweiRtc.setSpeakerEnabled(
                        !controls.speakerEnabled,
                        callId: id,
                      ),
                    )
                  : null,
              child: Text(
                controls?.speakerEnabled == true ? 'Speaker off' : 'Speaker on',
              ),
            ),
            OutlinedButton(
              onPressed:
                  enabled &&
                      video &&
                      !_cameraLocked &&
                      controls.cameraEnabled &&
                      controls.cameraOrientation != null
                  ? () => _control((id) => HuaweiRtc.switchCamera(callId: id))
                  : null,
              child: const Text('Switch camera'),
            ),
            OutlinedButton(
              onPressed: enabled && video && !_cameraLocked
                  ? () => _control(
                      (id) => HuaweiRtc.setCameraEnabled(
                        !controls.cameraEnabled,
                        callId: id,
                      ),
                    )
                  : null,
              child: Text(
                controls?.cameraEnabled == true ? 'Camera off' : 'Camera on',
              ),
            ),
            DropdownButton<HuaweiRtcAudioOutput>(
              hint: const Text('Audio output'),
              value:
                  controls?.availableAudioOutputs.contains(
                        controls.audioOutput,
                      ) ==
                      true
                  ? controls?.audioOutput
                  : null,
              items: (controls?.availableAudioOutputs ?? [])
                  .map(
                    (output) => DropdownMenuItem(
                      value: output,
                      child: Text(output.name),
                    ),
                  )
                  .toList(),
              onChanged: enabled
                  ? (output) {
                      if (output != null) {
                        unawaited(
                          _control(
                            (id) =>
                                HuaweiRtc.selectAudioOutput(output, callId: id),
                          ),
                        );
                      }
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _captureAction(bool start) async {
    final id = _activeCall?.id;
    if (id == null || _captureActionBusy && start) return;
    setState(() {
      _captureActionBusy = true;
      _captureStarting = start;
      _captureError = null;
    });
    try {
      final state = start
          ? await HuaweiRtcScreenAsCamera.startScreenAsCamera(callId: id)
          : await HuaweiRtcScreenAsCamera.stopScreenAsCamera(callId: id);
      if (mounted && _activeCall?.id == id) setState(() => _capture = state);
    } on ScreenAsCameraException catch (error) {
      if (mounted) {
        setState(
          () => _captureError = switch (error.code) {
            'screen_permission_cancelled' =>
              'Screen capture permission was cancelled or denied.',
            'screen_unsupported' =>
              'Screen as Camera requires Android 10 or newer.',
            'screen_stop_uncertain' =>
              'Capture shutdown is unconfirmed. Check Android capture controls.',
            'screen_cancelled' => 'Capture start was cancelled.',
            _ => error.code,
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _captureError = 'Capture operation unavailable.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _captureStarting = false;
          _captureActionBusy = false;
        });
      }
    }
  }

  Widget _captureControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Experimental: Screen as Camera (Android 10+)'),
      const Text(
        'The agent sees screen content in the camera stream, not a separate '
        'screen-share track. Camera remains enabled underneath; flip and on/off are '
        'locked during capture. Rotation/recreation may stop capture; start again with fresh consent.',
      ),
      Text(
        'Capture: ${_capture?.phase.name ?? "idle"} '
        '· projection ended: ${_capture?.projectionTerminated ?? true} '
        '· camera frame restored: ${_capture?.cameraOutputRestored ?? false}',
      ),
      if (_captureError != null || _capture?.error != null)
        Text('Capture detail: ${_captureError ?? _capture?.error}'),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed:
                !_cameraLocked &&
                    !_captureActionBusy &&
                    _activeCall?.status == HuaweiRtcCallStatus.established &&
                    _controls?.cameraEnabled == true
                ? () => _captureAction(true)
                : null,
            child: const Text('Start Screen as Camera'),
          ),
          OutlinedButton(
            onPressed: _cameraLocked ? () => _captureAction(false) : null,
            child: const Text('Stop Screen as Camera'),
          ),
        ],
      ),
    ],
  );

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
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_captureSubscription?.cancel());
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Device test only. Grant Microphone, Camera (video), and Nearby devices '
              '(Android 12+) in Android App info → Permissions, then return here. '
              'Use a test account with Web and In-app Calls enabled. '
              'Start in the foreground; an ongoing notification supports background calls. '
              'Allow Notifications to see it in the drawer. Remote camera video appears when the agent publishes it.',
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
                  onPressed: _starting ? null : _refreshActive,
                  child: const Text('Refresh active call'),
                ),
                OutlinedButton(
                  onPressed: _active && !_starting ? () => _probe() : null,
                  child: const Text('Attempt second call'),
                ),
                OutlinedButton(
                  onPressed: _starting
                      ? null
                      : () => _probe(deniedPermission: true),
                  child: const Text('Probe denied permission'),
                ),
                OutlinedButton(
                  onPressed: _active && !_starting ? _hangup : null,
                  child: const Text('Hang up'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_active && _activeCall?.type == HuaweiRtcCallType.video)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: HuaweiRtcVideoView(
                        callId: _activeCall!.id,
                        source: HuaweiRtcVideoSource.remote,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      width: 100,
                      height: 140,
                      child: HuaweiRtcVideoView(
                        callId: _activeCall!.id,
                        source: HuaweiRtcVideoSource.local,
                      ),
                    ),
                  ],
                ),
              ),
            _callControls(),
            if (_active && _activeCall?.type == HuaweiRtcCallType.video)
              _captureControls(),
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
    ),
  );
}
