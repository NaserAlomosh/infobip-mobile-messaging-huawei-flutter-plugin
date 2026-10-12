import 'package:flutter/material.dart';
import 'app.dart';
import 'setup/example_controller.dart';
import 'config/example_config.dart';
import 'config/example_test_config.template.dart';

void main() => runApp(
  ExampleApp(
    controller: ExampleController(
      config: ExampleConfig(
        applicationCode: ExampleTestConfig.infobipApplicationCode,
        externalUserId: ExampleTestConfig.externalUserId,
        jwtKid: ExampleTestConfig.jwtKid,
        jwtSecretKey: ExampleTestConfig.jwtSecretKey,
        jwtTtl: Duration(seconds: ExampleTestConfig.jwtTtlSeconds),
        rtcCallsConfigurationId: ExampleTestConfig.rtcCallsConfigurationId,
        rtcIdentity: ExampleTestConfig.rtcIdentity,
        chatAuth: ExampleTestConfig.chatAuthMode,
        chatWidgetId: ExampleTestConfig.chatWidgetId,
        chatKeyId: ExampleTestConfig.chatKeyId,
        chatSecretKey: ExampleTestConfig.chatSecretKey,
        chatJwtTtl: Duration(seconds: ExampleTestConfig.chatJwtTtlSeconds),
        jwtToken: ExampleTestConfig.jwtToken,
        chatJwtToken: ExampleTestConfig.chatJwtToken,
        firstName: ExampleTestConfig.firstName,
        lastName: ExampleTestConfig.lastName,
        email: ExampleTestConfig.email,
        phoneNumber: ExampleTestConfig.phoneNumber,
        inboxTopic: ExampleTestConfig.inboxTopic,
        inboxLimit: ExampleTestConfig.inboxLimit,
        expectedNotificationTitle: ExampleTestConfig.expectedNotificationTitle,
        expectedNotificationBody: ExampleTestConfig.expectedNotificationBody,
        expectedDeepLink: ExampleTestConfig.expectedDeepLink,
        environmentName: ExampleTestConfig.environmentName,
        enableAudioTesting: ExampleTestConfig.enableAudioTesting,
        enableVideoTesting: ExampleTestConfig.enableVideoTesting,
        installationPrimary: ExampleTestConfig.installationPrimary,
        installationPushEnabled: ExampleTestConfig.installationPushEnabled,
        installationAttributes: ExampleTestConfig.installationAttributes,
        invalidExternalUserId: ExampleTestConfig.invalidExternalUserId,
        chatMessage: ExampleTestConfig.chatMessage,
        chatContextualData: ExampleTestConfig.chatContextualData,
        chatTheme: ExampleTestConfig.chatTheme,
      ),
    ),
  ),
);
