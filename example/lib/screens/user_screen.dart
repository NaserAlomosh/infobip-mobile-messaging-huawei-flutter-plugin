import 'package:flutter/material.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

import '../setup/example_controller.dart';
import '../setup/safe_display.dart';
import '../widgets/result_card.dart';
import '../widgets/section_card.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({required this.controller, super.key});
  final ExampleController controller;

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  late final _firstName = TextEditingController(
    text: widget.controller.config.firstName,
  );
  late final _lastName = TextEditingController(
    text: widget.controller.config.lastName,
  );

  bool _loading = false;
  String _result = 'No user operation performed.';
  UserData? _user;

  Future<void> _run(Future<void> Function() operation) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await operation();
      await widget.controller.refresh();
    } catch (error) {
      if (mounted) {
        setState(
          () => _result = error is ExampleBlocked
              ? 'BLOCKED: ${error.message}'
              : safeFailure('User operation', error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setUser(UserData user, String operation) => setState(() {
    _user = user;
    _result =
        '$operation returned SDK data; confirm intended server state.\n${_describe(user)}';
  });

  String _describe(UserData user) => [
    'First name: ${masked(user.firstName)}',
    'Last name: ${masked(user.lastName)}',
    'Gender: ${user.gender?.name ?? 'not set'}',
    'Birthday: ${masked(user.birthday)}',
    'Tags: ${user.tags?.length ?? 0}',
  ].join('\n');

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('User')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          SectionCard(
            title: 'Read user',
            children: [
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _run(
                            () async => _setUser(
                              await InfobipMobileMessagingHuawei.getUser(),
                              'Cached user read',
                            ),
                          ),
                    child: const Text('Get cached user'),
                  ),
                  OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _run(
                            () async => _setUser(
                              await InfobipMobileMessagingHuawei.fetchUser(),
                              'Server user fetch',
                            ),
                          ),
                    child: const Text('Fetch from server'),
                  ),
                ],
              ),
            ],
          ),
          SectionCard(
            title: 'Save profile fields',
            children: [
              TextField(
                controller: _firstName,
                decoration: const InputDecoration(labelText: 'First name'),
              ),
              TextField(
                controller: _lastName,
                decoration: const InputDecoration(labelText: 'Last name'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _loading
                    ? null
                    : () => _run(() async {
                        final saved = await widget.controller
                            .saveConfiguredUser(
                              previous: _user,
                              firstName: _firstName.text.trim(),
                              lastName: _lastName.text.trim(),
                            );
                        _setUser(saved, 'Server user verification after save');
                      }),
                child: const Text('Save user'),
              ),
            ],
          ),
          SectionCard(
            title: 'Personalization',
            description:
                'Use a test identity with a non-production Infobip application. '
                'The SDK persists user and installation state.',
            children: [
              Text(
                'Configured external user ID: ${masked(widget.controller.config.externalUserId)}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed:
                        _loading || !widget.controller.externalUserIdConfigured
                        ? null
                        : () => _run(() async {
                            final ok = await widget.controller.personalize(
                              attributes: UserAttributes(
                                firstName: _firstName.text.trim().isEmpty
                                    ? null
                                    : _firstName.text.trim(),
                                lastName: _lastName.text.trim().isEmpty
                                    ? null
                                    : _lastName.text.trim(),
                              ),
                            );
                            if (!mounted) return;
                            if (!ok) {
                              setState(
                                () => _result =
                                    widget.controller.result ??
                                    'Personalization failed.',
                              );
                              return;
                            }
                            final user = widget.controller.user!;
                            _setUser(user, 'Personalization');
                          }),
                    child: const Text('Personalize'),
                  ),
                  OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _run(() async {
                            await widget.controller.depersonalizeUser();
                            if (mounted) {
                              setState(() {
                                _user = null;
                                _result =
                                    'Depersonalization completed; verify empty server identity and Portal state.';
                              });
                            }
                          }),
                    child: const Text('Depersonalize'),
                  ),
                ],
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
