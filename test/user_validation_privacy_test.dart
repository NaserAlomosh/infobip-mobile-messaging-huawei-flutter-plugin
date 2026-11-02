import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.infobip.mobilemessaging.huawei/methods');
  final platform = MethodChannelInfobipMobileMessagingHuawei();
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'save and patch forward email values unchanged to native validation',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return <String, Object?>{};
          });
      const emails = [
        'valid@example.invalid',
        ' spaced@example.invalid ',
        '用户@example.invalid',
        'malformed',
        '',
      ];
      await platform.saveUser(UserData(emails: emails));
      await platform.patchUser(
        const UserPatch(emails: FieldUpdate.set(emails)),
      );
      expect(calls.map((call) => call.method), ['saveUser', 'patchUser']);
      for (final call in calls) {
        expect(((call.arguments as Map)['user'] as Map)['emails'], emails);
      }
    },
  );

  test('native private length failure remains an error on both APIs', () async {
    final email = '${'x' * 256}@example.invalid';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(
            code: '-10',
            message: 'Each email must contain at most 255 UTF-16 code units',
          );
        });
    for (final operation in <Future<UserData> Function()>[
      () => platform.saveUser(UserData(emails: [email])),
      () => platform.patchUser(UserPatch(emails: FieldUpdate.set([email]))),
    ]) {
      await expectLater(
        operation(),
        throwsA(
          isA<PlatformException>()
              .having((error) => error.code, 'code', '-10')
              .having((error) => error.toString().contains(email), 'PII', false)
              .having((error) => error.details, 'details', isNull),
        ),
      );
    }
  });

  test(
    'personalize preserves identity attributes and force flag on the channel',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return <String, Object?>{};
          });
      const emails = [
        'valid@example.invalid',
        'other@example.invalid',
        ' spaced@example.invalid ',
        '用户@example.invalid',
        '',
      ];
      for (final force in [false, true]) {
        await platform.personalize(
          UserIdentity(
            externalUserId: 'synthetic-id',
            phones: ['synthetic-phone'],
            emails: emails,
          ),
          UserAttributes(firstName: 'Synthetic'),
          forceDepersonalize: force,
        );
        expect(calls.last.method, 'personalize');
        final payload = calls.last.arguments as Map;
        expect(payload['forceDepersonalize'], force);
        expect(payload['userIdentity'], {
          'externalUserId': 'synthetic-id',
          'phones': ['synthetic-phone'],
          'emails': emails,
        });
        expect((payload['userAttributes'] as Map)['firstName'], 'Synthetic');
      }
    },
  );

  test(
    'personalize forwards private native errors without treating them as success',
    () async {
      final email = 'x' * 256;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(
              code: '-10',
              message: 'Each email must contain at most 255 UTF-16 code units',
            );
          });
      await expectLater(
        platform.personalize(
          UserIdentity(emails: [email]),
          null,
          forceDepersonalize: true,
        ),
        throwsA(
          isA<PlatformException>()
              .having((error) => error.code, 'code', '-10')
              .having((error) => error.toString().contains(email), 'PII', false)
              .having((error) => error.details, 'details', isNull),
        ),
      );
    },
  );
}
