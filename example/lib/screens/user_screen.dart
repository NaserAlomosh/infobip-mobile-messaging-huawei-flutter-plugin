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
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

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
        setState(() => _result = safeFailure('User operation', error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setUser(UserData user, String operation) => setState(() {
    _user = user;
    _firstName.text = user.firstName ?? '';
    _lastName.text = user.lastName ?? '';
    _result = '$operation succeeded.\n${_describe(user)}';
  });

  String _describe(UserData user) => [
    'First name: ${user.firstName ?? 'not set'}',
    'Last name: ${user.lastName ?? 'not set'}',
    'Gender: ${user.gender?.name ?? 'not set'}',
    'Birthday: ${user.birthday ?? 'not set'}',
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
                        final saved =
                            await InfobipMobileMessagingHuawei.saveUser(
                              UserData(
                                externalUserId: _user?.externalUserId,
                                firstName: _firstName.text.trim(),
                                lastName: _lastName.text.trim(),
                                middleName: _user?.middleName,
                                gender: _user?.gender,
                                birthday: _user?.birthday,
                                phones: _user?.phones,
                                emails: _user?.emails,
                                tags: _user?.tags,
                                customAttributes: _user?.customAttributes,
                              ),
                            );
                        _setUser(saved, 'User save');
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
                            final user =
                                await InfobipMobileMessagingHuawei.personalize(
                                  PersonalizeContext(
                                    userIdentity: UserIdentity(
                                      externalUserId: widget
                                          .controller
                                          .config
                                          .externalUserId
                                          .trim(),
                                    ),
                                    userAttributes: UserAttributes(
                                      firstName: _firstName.text.trim().isEmpty
                                          ? null
                                          : _firstName.text.trim(),
                                      lastName: _lastName.text.trim().isEmpty
                                          ? null
                                          : _lastName.text.trim(),
                                    ),
                                  ),
                                );
                            _setUser(user, 'Personalization');
                          }),
                    child: const Text('Personalize'),
                  ),
                  OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _run(() async {
                            await InfobipMobileMessagingHuawei.depersonalize();
                            if (mounted) {
                              setState(() {
                                _user = null;
                                _result = 'Depersonalization succeeded.';
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
