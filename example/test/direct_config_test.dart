import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei_example/config/example_test_config.dart';
import 'package:infobip_mobilemessaging_huawei_example/config/test_config_mapper.dart';

void main() {
  test('direct configuration preserves authentication and RTC choices', () {
    final config = configFromTestConstants();
    // Compare booleans so a failure never prints private configuration values.
    expect(
      config.applicationCode == ExampleTestConfig.infobipApplicationCode,
      isTrue,
    );
    expect(config.jwtToken == ExampleTestConfig.jwtToken, isTrue);
    expect(config.chatAuth == ExampleTestConfig.chatAuthMode, isTrue);
    expect(config.chatJwtToken == ExampleTestConfig.chatJwtToken, isTrue);
    expect(config.jwtTtl.inSeconds == ExampleTestConfig.jwtTtlSeconds, isTrue);
    expect(
      config.chatJwtTtl.inSeconds == ExampleTestConfig.chatJwtTtlSeconds,
      isTrue,
    );
    expect(
      config.rtcCallsConfigurationId ==
          ExampleTestConfig.rtcCallsConfigurationId,
      isTrue,
    );
    expect(config.rtcIdentity == ExampleTestConfig.rtcIdentity, isTrue);
    expect(
      config.enableAudioTesting == ExampleTestConfig.enableAudioTesting,
      isTrue,
    );
    expect(
      config.enableVideoTesting == ExampleTestConfig.enableVideoTesting,
      isTrue,
    );
    expect(config.toString(), 'ExampleConfig(values hidden)');
  });
}
