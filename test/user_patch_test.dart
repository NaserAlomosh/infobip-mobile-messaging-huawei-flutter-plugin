import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/user/user_codec.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('legacy encoder reproduces implicit null; patch preserves absence', () {
    expect(
      UserCodec.encode(UserData(firstName: 'Michael')).containsKey('lastName'),
      isTrue,
    );
    expect(
      UserCodec.encodePatch(
        const UserPatch(firstName: FieldUpdate.set('Michael')),
      ),
      {'firstName': 'Michael'},
    );
    expect(UserCodec.encodePatch(const UserPatch()), isEmpty);
  });
  test('clear, empty values and custom attribute deletion remain distinct', () {
    expect(
      UserCodec.encodePatch(
        const UserPatch(
          firstName: FieldUpdate.set(''),
          lastName: FieldUpdate.clear(),
          tags: FieldUpdate.set([]),
          customAttributes: FieldUpdate.set({'removed': null}),
        ),
      ),
      {
        'firstName': '',
        'lastName': null,
        'tags': [],
        'customAttributes': {'removed': null},
      },
    );
  });
  test('whole custom attribute clear is rejected', () {
    expect(
      () => UserCodec.encodePatch(
        const UserPatch(customAttributes: FieldUpdate.clear()),
      ),
      throwsA(isA<PlatformException>()),
    );
  });
  test('method channel preserves patch keys and null values', () async {
    const channel = MethodChannel('com.infobip.mobilemessaging.huawei/methods');
    final platform = MethodChannelInfobipMobileMessagingHuawei();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'patchUser');
          expect(call.arguments, {
            'user': {'lastName': null},
          });
          return <String, Object?>{};
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await platform.patchUser(const UserPatch(lastName: FieldUpdate.clear()));
  });
}
