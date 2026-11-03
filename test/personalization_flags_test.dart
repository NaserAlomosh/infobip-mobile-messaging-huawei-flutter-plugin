import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.infobip.mobilemessaging.huawei/methods');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return {'externalUserId': 'synthetic-id'};
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  for (final keep in [false, true]) {
    for (final primary in [false, true]) {
      test('facade forwards keep=$keep primary=$primary once', () async {
        for (final force in [false, true]) {
          calls.clear();
          final user = await InfobipMobileMessagingHuawei.personalize(
            PersonalizeContext(
              userIdentity: UserIdentity(externalUserId: 'synthetic-id'),
              userAttributes: UserAttributes(firstName: 'Synthetic'),
              forceDepersonalize: force,
              keepAsLead: keep,
              setDeviceAsPrimary: primary,
            ),
          );
          expect(user.externalUserId, 'synthetic-id');
          expect(calls.single.method, 'personalize');
          final payload = calls.single.arguments as Map;
          expect(payload['keepAsLead'], keep);
          expect(payload['setDeviceAsPrimary'], primary);
          expect(payload['forceDepersonalize'], force);
          expect((payload['userAttributes'] as Map)['firstName'], 'Synthetic');
        }
      });
    }
  }
  test(
    'omitted context flags and legacy positional API default false',
    () async {
      final identity = UserIdentity(externalUserId: 'synthetic-id');
      await InfobipMobileMessagingHuawei.personalize(
        PersonalizeContext(userIdentity: identity),
      );
      // ignore: deprecated_member_use_from_same_package
      await InfobipMobileMessagingHuawei.personalizeUser(identity);
      // ignore: deprecated_member_use_from_same_package
      await InfobipMobileMessagingHuawei.personalizeUser(identity, null, true);
      expect(calls.length, 3);
      for (final call in calls) {
        final payload = call.arguments as Map;
        expect(payload['keepAsLead'], false);
        expect(payload['setDeviceAsPrimary'], false);
      }
      expect((calls.last.arguments as Map)['forceDepersonalize'], true);
    },
  );
}
