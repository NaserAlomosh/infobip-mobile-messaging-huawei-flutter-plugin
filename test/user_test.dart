import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ChannelContract.methodChannel);
  final calls = <MethodCall>[];
  late MethodChannelInfobipMobileMessagingHuawei platform;

  setUp(() {
    calls.clear();
    platform = MethodChannelInfobipMobileMessagingHuawei(
      methodChannel: channel,
      eventChannel: const EventChannel('user-test-events'),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == ChannelContract.depersonalize) return null;
          return <String, Object?>{
            ChannelContract.externalUserId: 'sample-id',
            ChannelContract.gender: 'female',
            ChannelContract.birthday: '1995-06-20',
            ChannelContract.phones: <String>['+12025550123'],
            ChannelContract.emails: <String>['sample@example.com'],
            ChannelContract.tags: <String>['customer'],
            ChannelContract.customAttributes: <String, Object?>{
              'active': true,
              'score': 4.5,
              'groups': <String>['a', 'b'],
            },
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('decodes channel-safe user values', () async {
    final user = await platform.getUser();
    expect(user.externalUserId, 'sample-id');
    expect(user.gender, Gender.Female);
    expect(user.birthday, '1995-06-20');
    expect(user.tags, ['customer']);
    expect(user.customAttributes?['active'], true);
  });

  test('decodes male gender', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => <String, Object?>{ChannelContract.gender: 'male'},
        );
    expect((await platform.getUser()).gender, Gender.Male);
  });

  test('delegates getUser and fetchUser independently', () async {
    await platform.getUser();
    await platform.fetchUser();
    expect(calls.map((call) => call.method), [
      ChannelContract.getUser,
      ChannelContract.fetchUser,
    ]);
  });

  test('encodes saveUser fields and date-only birthday', () async {
    await platform.saveUser(
      User(
        firstName: 'Sample',
        gender: Gender.Male,
        birthday: '1995-06-20',
        tags: const ['one', 'two'],
        customAttributes: const {'level': 2},
      ),
    );
    final arguments = calls.single.arguments as Map<Object?, Object?>;
    final user = arguments[ChannelContract.user] as Map<Object?, Object?>;
    expect(user[ChannelContract.birthday], '1995-06-20');
    expect(user[ChannelContract.gender], 'male');
    expect(user[ChannelContract.tags], ['one', 'two']);
  });

  test('encodes male and female genders', () async {
    await platform.saveUser(User(gender: Gender.Male));
    await platform.saveUser(User(gender: Gender.Female));

    expect(
      ((calls[0].arguments as Map)[ChannelContract.user]
          as Map)[ChannelContract.gender],
      'male',
    );
    expect(
      ((calls[1].arguments as Map)[ChannelContract.user]
          as Map)[ChannelContract.gender],
      'female',
    );
  });

  test(
    'encodes DateTime custom values with a date tag inside supported CustomList records',
    () async {
      final localInstant = DateTime.parse('2026-09-01T15:00:00+03:00');
      await platform.saveUser(
        User(
          customAttributes: {
            'created': localInstant,
            'history': [
              {'at': localInstant},
            ],
            'text': '2026-09-01T12:00:00Z',
          },
        ),
      );

      final arguments = calls.single.arguments as Map<Object?, Object?>;
      final user = arguments[ChannelContract.user] as Map<Object?, Object?>;
      final custom = user[ChannelContract.customAttributes] as Map;
      expect(custom['created'], {
        ChannelContract.customValueType: ChannelContract.customDateType,
        ChannelContract.customValue: '2026-09-01T12:00:00.000Z',
      });
      expect(
        ((custom['history'] as List).single as Map)['at'],
        custom['created'],
      );
      expect(custom['text'], '2026-09-01T12:00:00Z');
    },
  );

  test(
    'delegates personalization identity, attributes, and force option',
    () async {
      await platform.personalize(
        UserIdentity(externalUserId: 'sample-id'),
        UserAttributes(firstName: 'Sample'),
        forceDepersonalize: true,
      );
      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(arguments[ChannelContract.forceDepersonalize], true);
      expect(
        (arguments[ChannelContract.userIdentity]
            as Map)[ChannelContract.externalUserId],
        'sample-id',
      );
    },
  );

  test('delegates depersonalize', () async {
    await platform.depersonalize();
    expect(calls.single.method, ChannelContract.depersonalize);
  });

  test(
    'rejects unsupported custom attributes before invoking native code',
    () async {
      await expectLater(
        platform.saveUser(User(customAttributes: {'bad': Object()})),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'invalid_argument',
          ),
        ),
      );
      expect(calls, isEmpty);
    },
  );

  test('rejects malformed native user payloads', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => <String, Object?>{
            ChannelContract.phones: <Object?>['valid', 2],
          },
        );
    await expectLater(platform.fetchUser(), throwsFormatException);
  });

  test('decodes an unknown future native gender as null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => <String, Object?>{ChannelContract.gender: 'unspecified'},
        );
    expect((await platform.getUser()).gender, isNull);
  });

  test('decodes null gender as absent', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => <String, Object?>{ChannelContract.gender: null},
        );
    expect((await platform.getUser()).gender, isNull);
  });

  test('rejects a malformed non-string native gender', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => <String, Object?>{ChannelContract.gender: 1},
        );
    await expectLater(platform.getUser(), throwsFormatException);
  });

  test(
    'decodes tagged custom dates as UTC instants in CustomList record fields',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => <String, Object?>{
              ChannelContract.customAttributes: <String, Object?>{
                'created': <String, Object>{
                  ChannelContract.customValueType:
                      ChannelContract.customDateType,
                  ChannelContract.customValue: '2026-09-01T12:00:00Z',
                },
                'history': <Object?>[
                  {
                    'at': <String, Object>{
                      ChannelContract.customValueType:
                          ChannelContract.customDateType,
                      ChannelContract.customValue: '2026-09-01T12:00:00.000Z',
                    },
                  },
                ],
                'text': '2026-09-01T12:00:00Z',
              },
            },
          );

      final custom = (await platform.getUser()).customAttributes!;
      expect(custom['created'], DateTime.utc(2026, 9, 1, 12));
      expect(
        ((custom['history'] as List).single as Map)['at'],
        DateTime.utc(2026, 9, 1, 12),
      );
      expect(custom['text'], isA<String>());
    },
  );

  test('rejects malformed tagged custom dates', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => <String, Object?>{
            ChannelContract.customAttributes: <String, Object?>{
              'created': <String, Object>{
                ChannelContract.customValueType: ChannelContract.customDateType,
                ChannelContract.customValue: 'not-a-date',
              },
            },
          },
        );
    await expectLater(platform.getUser(), throwsFormatException);
  });
}
