import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  bool _incomingBusy = false;
  HuaweiRtcIncomingExperimentEvent? _incoming;
  StreamSubscription<HuaweiRtcIncomingExperimentEvent>? _incomingSubscription;
  String? _incomingError;
  final List<String> _incomingDiagnostics = [];
  int _lastDiagnosticSequence = 0;
  String? _lastIncomingReceipt;

  void _debugIncoming(String event, {int? timestampMillis}) {
    if (!kDebugMode) return;
    final time = timestampMillis == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(timestampMillis);
    _incomingDiagnostics.add('${time.toUtc().toIso8601String()} $event');
    if (_incomingDiagnostics.length > 100) _incomingDiagnostics.removeAt(0);
  }

  void _receiveIncoming(
    HuaweiRtcIncomingExperimentEvent event, {
    required bool fromStream,
  }) {
    if (kDebugMode) {
      for (final diagnostic in event.diagnostics) {
        if (diagnostic.sequence <= _lastDiagnosticSequence) continue;
        _lastDiagnosticSequence = diagnostic.sequence;
        _debugIncoming(
          'native #${diagnostic.sequence} ${diagnostic.event}'
          '${diagnostic.errorCode == null ? '' : ' code=${diagnostic.errorCode}'}',
          timestampMillis: diagnostic.timestampMillis,
        );
      }
      final receipt = '${event.state}:$_lastDiagnosticSequence';
      if (fromStream && receipt != _lastIncomingReceipt) {
        _lastIncomingReceipt = receipt;
        _debugIncoming(
          'flutter_event_received native_sequence=$_lastDiagnosticSequence',
        );
      }
      if (!fromStream) _debugIncoming('flutter_start_returned');
    }
    _incoming = event;
  }

  bool _starting = false;
  bool _useLiveChatIdentity = false;
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
    _incomingSubscription = HuaweiRtc.incomingExperimentEvents.listen(
      (event) {
        if (mounted) setState(() => _receiveIncoming(event, fromStream: true));
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            _debugIncoming('flutter_event_decode_or_channel_error');
            _incomingError = 'Incoming state unavailable.';
          });
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

  Future<void> _incomingAction(String action, {bool video = false}) async {
    if (_incomingBusy) return;
    setState(() {
      _incomingBusy = true;
      _incomingError = null;
    });
    try {
      if (action == 'start') {
        setState(() => _debugIncoming('flutter_start_requested'));
        await c.refresh();
        if (!c.personalized) {
          throw StateError('Personalization required');
        }
        final state = await HuaweiRtc.startForegroundIncomingExperiment(
          HuaweiRtcLiveChatIdentity(
            widgetId: c.config.chatWidgetId,
            expectedExternalUserId: c.config.externalUserId,
          ),
        );
        if (mounted) setState(() => _receiveIncoming(state, fromStream: false));
      } else {
        final handle = _incoming?.handle;
        if (handle == null) return;
        if (action == 'decline') {
          await HuaweiRtc.declineExperimentalIncomingCall(handle: handle);
        } else {
          final call = await HuaweiRtc.acceptExperimentalIncomingCall(
            handle: handle,
            video: video,
          );
          if (mounted) {
            setState(() {
              _activeCall = call;
              _active = call.status != HuaweiRtcCallStatus.finished;
            });
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _debugIncoming('flutter_operation_failed');
          _incomingError =
              'Incoming operation unavailable. Check personalization, permissions and invitation state. '
              'An invalidated experiment requires a fresh application process.';
        });
      }
    } finally {
      if (mounted) setState(() => _incomingBusy = false);
    }
  }

  Widget _incomingSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(),
      const Text('Incoming RTC — Experimental'),
      const Text(
        'EXPERIMENTAL — NOT PRODUCTION READY. Foreground only. '
        'One fixed personalized customer per process. No push delivery. '
        'Leaving this screen ends incoming experiment calls. '
        'Terminate the app process before testing another identity.',
      ),
      Text(switch (_incoming?.state) {
        'registrationRequested' =>
          'Registration requested / waiting for incoming signaling. Readiness unconfirmed.',
        'preparing' => 'Resolving identity / requesting access token.',
        'invitation' => 'Incoming application call invitation',
        'connecting' => 'Connecting',
        'connected' => 'Connected',
        'ended' => 'Ended — waiting for another invitation',
        'failed' => 'Failed — termination may still be pending',
        'invalidated' => 'Invalidated — terminate the app process to reset',
        'declining' => 'Decline requested — waiting for termination',
        'ending' => 'Ending — waiting for termination',
        'paused' => 'Presentation paused — signaling is not unregistered',
        'reconnecting' => 'Connection interrupted',
        _ => 'Not started',
      }),
      if (_incoming?.reason != null)
        Text('Incoming detail: ${_incoming!.reason}'),
      if (_incomingError != null) Text(_incomingError!),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: _incomingBusy || _active
                ? null
                : () => _incomingAction('start'),
            child: const Text('Start foreground incoming experiment'),
          ),
          if (_incoming?.handle != null) ...[
            OutlinedButton(
              onPressed: _incomingBusy ? null : () => _incomingAction('accept'),
              child: const Text('Accept Audio'),
            ),
            if (_incoming?.videoSupported == true)
              OutlinedButton(
                onPressed: _incomingBusy
                    ? null
                    : () => _incomingAction('accept', video: true),
                child: const Text('Accept Video'),
              ),
            OutlinedButton(
              onPressed: _incomingBusy
                  ? null
                  : () => _incomingAction('decline'),
              child: const Text('Decline'),
            ),
          ],
        ],
      ),
      const Divider(),
    ],
  );

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
      if (_useLiveChatIdentity && !c.personalized) {
        setState(
          () => _result = 'Personalize the configured user before calling.',
        );
        return;
      }
      final call = await HuaweiRtc.callApplication(
        HuaweiRtcCallRequest(
          callsConfigurationId: c.config.rtcCallsConfigurationId.trim(),
          type: type,
          identity: _useLiveChatIdentity || c.config.rtcIdentity.trim().isEmpty
              ? null
              : c.config.rtcIdentity.trim(),
          liveChatIdentity: _useLiveChatIdentity
              ? HuaweiRtcLiveChatIdentity(
                  widgetId: c.config.chatWidgetId,
                  expectedExternalUserId: c.config.externalUserId,
                )
              : null,
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
      if (mounted) {
        setState(
          () => _result =
              'Check the Calls configuration, Chat widget and expected user.',
        );
      }
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
    unawaited(_incomingSubscription?.cancel());
    unawaited(
      HuaweiRtc.closeForegroundIncomingExperimentScreen().catchError(
        (Object _) {},
      ),
    );
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
              'Default identity: ${c.config.rtcIdentity.trim().isEmpty ? 'registered installation' : masked(c.config.rtcIdentity)}',
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
            _incomingSection(),
            SwitchListTile(
              key: const ValueKey('rtc-live-chat-identity'),
              title: const Text('Use Live Chat customer identity'),
              subtitle: const Text(
                'Requires personalization and the configured Chat widget. '
                'Each outgoing call may create a new Conversation.',
              ),
              value: _useLiveChatIdentity,
              onChanged: _starting || _active
                  ? null
                  : (value) => setState(() => _useLiveChatIdentity = value),
            ),
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
              'Outgoing calls continue when leaving this screen. Incoming experiment calls are asked to end.',
            ),
            const Divider(),
            if (kDebugMode) ...[
              const Text('Incoming diagnostics — debug only'),
              const Text(
                'UTC timestamps. Registration return is not readiness. '
                'Idle connection/authentication and peer delivery are unobservable locally. '
                'Native channel writes are not Flutter receipt acknowledgments.',
              ),
              if (_incomingDiagnostics.isEmpty)
                const Text('No incoming diagnostics yet.'),
              ..._incomingDiagnostics.map((event) => Text(event)),
              const Divider(),
            ],
            const Text('Recent events'),
            ..._events.map(Text.new),
          ],
        ),
      ),
    ),
  );
}
