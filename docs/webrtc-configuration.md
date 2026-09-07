# WebRTC calls

WebRTC configuration is optional and independent from Huawei Mobile Messaging.
The RTC implementation is supplied by the separate
`com.infobip:infobip-rtc-ui` Android artifact; it is not part of the Huawei
Mobile Messaging SDK.

Applications that do not use WebRTC initialize as before:

```dart
await InfobipMobileMessagingHuawei.initialize(
  applicationCode: 'YOUR_APPLICATION_CODE',
);
```

An application can provide initialization-time configuration and then enable
calls:

```dart
await InfobipMobileMessagingHuawei.initialize(
  applicationCode: 'YOUR_APPLICATION_CODE',
  webRTCUI: const WebRTCUI(
    configurationId: 'YOUR_WEBRTC_CONFIGURATION_ID',
  ),
);

await InfobipMobileMessagingHuawei.enableCalls('identity');
await InfobipMobileMessagingHuawei.enableChatCalls();
await InfobipMobileMessagingHuawei.disableCalls();
```

Both `webRTCUI` and `WebRTCUI.configurationId` may be null. Empty and whitespace
configuration IDs are retained without normalization. Validation required to
start a call is deliberately deferred to the call APIs.

## Initialization lifecycle

The configuration from the native initialization attempt is retained only when
that attempt succeeds. Repeating initialization with the same application code
remains idempotent and does not replace either Mobile Messaging or WebRTC
configuration. Cleanup clears the retained configuration, allowing a later
initialization to provide a new value.

## Optional Android dependency

The official Flutter plugin at commit
`8b630d0f736d400635317131d549c345349bd54d` establishes two relevant facts: RTC
UI is a conditional dependency and its Maven coordinate is
`com.infobip:infobip-rtc-ui`. The Huawei SDK source at commit
`5822d18b6a8686f3ce0db3ecbbcb0ad5439b0824` does not provide WebRTC and therefore
does not establish an RTC UI version corresponding to Huawei SDK 8.14.0.

Because an exact compatible RTC UI version cannot be proven from those source
commits, this plugin does not guess one or couple it to the Huawei SDK version.
The dependency is disabled by default. A host build can opt in only after
selecting and verifying a compatible published RTC UI version:

```text
-PinfobipWebRtcEnabled=true -PinfobipRtcUiVersion=<verified-version>
```

RTC classes are loaded through reflection only when a WebRTC API is called. If
the optional artifact is absent, the call completes with a controlled platform
error without affecting plugin registration or other Mobile Messaging APIs.
