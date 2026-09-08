import 'dart:async';

import 'package:flutter/material.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

/// Deliberately small device-validation surface, not a call UI or video renderer.
class HuaweiRtcScreen extends StatefulWidget {
  const HuaweiRtcScreen({super.key});

  @override
  State<HuaweiRtcScreen> createState() => _HuaweiRtcScreenState();
}

class _HuaweiRtcScreenState extends State<HuaweiRtcScreen> {
  final _configuration = TextEditingController();
  final _identity = TextEditingController();
  final _events = <String>[];
  StreamSubscription<HuaweiRtcEvent>? _subscription;
  bool _starting = false;
  bool _active = false;
  String _result = 'Initialize Mobile Messaging before placing a call.';

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
    setState(() => _starting = true);
    try {
      final call = await HuaweiRtc.callApplication(
        HuaweiRtcCallRequest(
          callsConfigurationId: _configuration.text.trim(),
          type: type,
          identity: _identity.text.trim().isEmpty
              ? null
              : _identity.text.trim(),
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
      if (mounted) setState(() => _result = '${error.code}: ${error.message}');
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
      if (mounted) setState(() => _result = '${error.code}: ${error.message}');
    } catch (_) {
      if (mounted) setState(() => _result = 'RTC operation unavailable.');
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _configuration.dispose();
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Huawei outgoing RTC')),
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
        TextField(
          controller: _configuration,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Calls configuration ID (not push configuration ID)',
          ),
        ),
        TextField(
          controller: _identity,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Test identity (optional; defaults to installation)',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _starting || _active
                  ? null
                  : () => _call(HuaweiRtcCallType.audio),
              child: const Text('Audio call'),
            ),
            FilledButton(
              onPressed: _starting || _active
                  ? null
                  : () => _call(HuaweiRtcCallType.video),
              child: const Text('Video call'),
            ),
            OutlinedButton(onPressed: _hangup, child: const Text('Hang up')),
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
  );
}
