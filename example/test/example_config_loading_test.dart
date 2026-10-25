import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei_example/config/load_example_config.dart';

class ConfigBundle extends CachingAssetBundle {
  ConfigBundle(this.source);
  final String? source;
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        if (source != null)
          localConfigAsset: [
            {'asset': localConfigAsset},
          ],
      })!;
    }
    if (key == localConfigAsset && source != null) {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(source!)));
    }
    throw StateError('Missing asset');
  }
}

void main() {
  test('clean checkout loads safe defaults without private asset', () async {
    final config = await loadExampleConfig(bundle: ConfigBundle(null));
    expect(config.applicationCode, isEmpty);
    expect(config.rtcCallsConfigurationId, isEmpty);
    expect(config.jwtSecretKey, isEmpty);
  });
  test(
    'private values reach configuration including separate auth and RTC',
    () async {
      final config = await loadExampleConfig(
        bundle: ConfigBundle(
          jsonEncode({
            'infobipApplicationCode': 'synthetic-app',
            'jwtToken': 'synthetic-mm',
            'chatJwtToken': 'synthetic-chat',
            'chatAuthMode': 'jwt',
            'rtcCallsConfigurationId': 'custom-route',
            'rtcIdentity': 'synthetic-user',
            'jwtTtlSeconds': 45,
            'enableVideoTesting': false,
            'installationAttributes': {'test': true},
          }),
        ),
      );
      expect(config.applicationCode, 'synthetic-app');
      expect(config.jwtToken, 'synthetic-mm');
      expect(config.chatJwtToken, 'synthetic-chat');
      expect(config.chatAuth, 'jwt');
      expect(config.rtcCallsConfigurationId, 'custom-route');
      expect(config.rtcIdentity, 'synthetic-user');
      expect(config.jwtTtl.inSeconds, 45);
      expect(config.enableVideoTesting, false);
      expect(config.installationAttributes, {'test': true});
    },
  );
  test('invalid private data fails without exposing its contents', () async {
    for (final source in ['private-invalid-json', '[]', '{"jwtToken":123}']) {
      await expectLater(
        loadExampleConfig(bundle: ConfigBundle(source)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.toString(),
            'safe message',
            isNot(contains(source)),
          ),
        ),
      );
    }
  });
}
