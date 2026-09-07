import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/channel_contract.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/infobip_mobilemessaging_huawei_platform.dart';
import 'package:infobip_mobilemessaging_huawei/src/platform/method_channel_infobip_mobilemessaging_huawei.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ToolbarCustomization uses official JSON keys and preserves nulls', () {
    const toolbar = ToolbarCustomization(
      titleText: 'Support',
      titleCentered: true,
      subtitleText: 'Online',
      subtitleCentered: false,
      navigationIcon: 'assets/back.png',
    );

    expect(toolbar.toJson(), containsPair('titleText', 'Support'));
    expect(toolbar.toJson(), containsPair('titleTextColor', null));
    expect(toolbar.toJson(), containsPair('subtitleText', 'Online'));
    expect(toolbar.toJson(), containsPair('subtitleCentered', false));
  });

  test('ChatCustomization serializes nested toolbars as valid JSON maps', () {
    const customization = ChatCustomization(
      chatToolbar: ToolbarCustomization(titleText: 'Chat'),
      attachmentPreviewToolbar: ToolbarCustomization(subtitleText: 'Preview'),
      networkErrorIcon: 'assets/network.png',
      chatBannerErrorTextAppearance: 'ChatBannerText',
      chatInputSeparatorLineVisible: false,
      chatFullScreenErrorRefreshButtonVisible: true,
      shouldHandleKeyboardAppearance: true,
    );

    final encoded = jsonEncode(customization.toJson());
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    expect(decoded['chatToolbar'], isA<Map<String, dynamic>>());
    expect(decoded['chatToolbar']['titleText'], 'Chat');
    expect(decoded['attachmentPreviewToolbar']['subtitleText'], 'Preview');
    expect(decoded['networkErrorIcon'], 'assets/network.png');
    expect(decoded['chatBannerErrorTextAppearance'], 'ChatBannerText');
    expect(decoded['chatInputSeparatorLineVisible'], isFalse);
    expect(decoded['shouldHandleKeyboardAppearance'], isTrue);
  });

  test('global API sends JSON and propagates native PlatformException', () async {
    const channel = MethodChannel(ChannelContract.methodChannel);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    InfobipMobileMessagingHuaweiPlatform.instance =
        MethodChannelInfobipMobileMessagingHuawei();

    await InfobipMobileMessagingHuawei.setChatCustomization(
      const ChatCustomization(chatBackgroundColor: '#FFFFFF'),
    );

    expect(received?.method, ChannelContract.setChatCustomization);
    expect(
      jsonDecode(received!.arguments as String),
      containsPair('chatBackgroundColor', '#FFFFFF'),
    );

    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'native_error');
    });
    await expectLater(
      InfobipMobileMessagingHuawei.setChatCustomization(
        const ChatCustomization(),
      ),
      throwsA(isA<PlatformException>()),
    );
  });
}
