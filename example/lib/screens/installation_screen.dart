import 'package:flutter/material.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

import '../setup/safe_display.dart';
import '../widgets/result_card.dart';
import '../widgets/section_card.dart';

class InstallationScreen extends StatefulWidget {
  const InstallationScreen({super.key});

  @override
  State<InstallationScreen> createState() => _InstallationScreenState();
}

class _InstallationScreenState extends State<InstallationScreen> {
  Installation? _installation;
  bool _loading = false;
  bool? _isPrimaryDevice;
  String _result = 'No installation operation performed.';

  Future<void> _run(Future<void> Function() operation) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        setState(() => _result = safeFailure('Installation operation', error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(Installation installation, String operation) => setState(() {
    _installation = installation;
    _isPrimaryDevice = installation.isPrimaryDevice;
    _result = '$operation succeeded.';
  });

  @override
  Widget build(BuildContext context) {
    final installation = _installation;
    return Scaffold(
      appBar: AppBar(title: const Text('Installation')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Read installation',
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => _run(() async {
                              _show(
                                await InfobipMobileMessagingHuawei.getInstallation(),
                                'Cached installation read',
                              );
                            }),
                      child: const Text('Get cached'),
                    ),
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => _run(() async {
                              _show(
                                await InfobipMobileMessagingHuawei.fetchInstallation(),
                                'Server installation fetch',
                              );
                            }),
                      child: const Text('Fetch from server'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Push registration enabled (read-only): '
                  '${installation?.isPushRegistrationEnabled ?? 'unknown'}',
                ),
                Text(
                  'Notifications enabled (read-only): '
                  '${installation?.notificationsEnabled ?? 'unknown'}',
                ),
                Text(
                  'Device: ${installation?.deviceManufacturer ?? 'unknown'} '
                  '${installation?.deviceModel ?? ''}',
                ),
                Text('SDK version: ${installation?.sdkVersion ?? 'unknown'}'),
              ],
            ),
            SectionCard(
              title: 'Writable fields',
              description:
                  'Only primary-device status and custom attributes are '
                  'accepted by saveInstallation.',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Primary device'),
                  value: _isPrimaryDevice ?? false,
                  onChanged: installation == null || _loading
                      ? null
                      : (value) => setState(() => _isPrimaryDevice = value),
                ),
                FilledButton(
                  onPressed: installation == null || _loading
                      ? null
                      : () => _run(() async {
                          final saved =
                              await InfobipMobileMessagingHuawei.saveInstallation(
                                Installation(
                                  isPrimaryDevice: _isPrimaryDevice,
                                  customAttributes:
                                      installation.customAttributes,
                                ),
                              );
                          _show(saved, 'Installation save');
                        }),
                  child: const Text('Save installation'),
                ),
              ],
            ),
            if (_loading) const Center(child: CircularProgressIndicator()),
            ResultCard(title: 'Result', message: _result),
          ],
        ),
      ),
    );
  }
}
