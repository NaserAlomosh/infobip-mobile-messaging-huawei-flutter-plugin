# G-02 — Personalization native flags

## Baseline and scope

Implemented on `feature/personalization-flags` from development `35f1aed326ca9231f26e66f490e75051773612fc` (Privacy Fix PR #92). The fetched baseline includes email privacy commits `1f6fd82` and `0f59a88`, final report `17b2024`, and CI mitigation `db3b567` (Robolectric Maven Central endpoint and native-test report upload). The working tree was clean before implementation. The feature branch already existed at this baseline.

## API and defaults

```dart
await InfobipMobileMessagingHuawei.personalize(PersonalizeContext(
  userIdentity: UserIdentity(externalUserId: 'your-user-id'),
  forceDepersonalize: false,
  keepAsLead: false,
  setDeviceAsPrimary: true,
));
```

`PersonalizeContext.keepAsLead` and `PersonalizeContext.setDeviceAsPrimary` are optional booleans, each defaulting to **false**. `forceDepersonalize` retains its existing false default and behavior. Defaults are pinned by Dart and native dispatcher tests. Existing context construction and the legacy positional `personalizeUser(identity, attributes, forceDepersonalize)` API remain valid; the legacy API uses false for both new flags.

The platform interface and MethodChannel implementation accept the new optional named arguments. The channel sends `keepAsLead` and `setDeviceAsPrimary` as booleans. The Android dispatcher also defaults omitted/null optional values to false for older channel callers and rejects other types with `invalid_argument` before manager access. The existing required channel `forceDepersonalize` handling is preserved.

## Native SDK mapping

Huawei Core SDK 9.3.0 is invoked once using:

```text
personalize(identity, attributes, forceDepersonalize, keepAsLead, setDeviceAsPrimary, listener)
```

The existing identity and attribute mappers, listener, success result mapping, and safe error handling remain in place. Initialization checking and email privacy validation still run before native SDK invocation. An overlong identity email is rejected with code `-10` and a value-free message; neither personalization nor forced depersonalization can be triggered through this rejected request.

The flags request the native SDK's keep-as-lead and primary-device behavior. Passing them through is verified locally; resulting backend identity, lead lifecycle, primary-device selection, and persistence are not certified by mocked tests.

## Validation

Tests cover all four flag combinations with both force values, single SDK entry, exact positional argument ordering, success callbacks, SDK error propagation, omitted defaults, legacy personalization, accepted identity/attribute preservation, invalid channel flag types, and privacy rejection without SDK calls. Native tests use real SDK identity models and mocked SDK entry points under Robolectric.

Final validation used Flutter 3.44.4 and Java 21.0.11:

| Check | Pass | Fail | Skip |
| --- | ---: | ---: | ---: |
| Flutter analysis (`flutter analyze --no-pub`) | 1 (zero issues) | 0 | 0 |
| Plugin Dart (`flutter test --no-pub --reporter expanded`) | 253 | 0 | 0 |
| Example Dart (same command in `example`) | 49 | 0 | 0 |
| Android Debug (`:infobip_mobilemessaging_huawei:testDebugUnitTest`) | 433 | 0 | 0 |
| Android Release (`:infobip_mobilemessaging_huawei:testReleaseUnitTest`) | 433 | 0 | 0 |
| `git diff --check` | 1 | 0 | 0 |

Android counts come from the 57 JUnit XML suite reports per variant. Flag combinations are exercised inside test methods, not counted as separate JUnit tests. Both Android tasks ran together with `--console=plain` and completed successfully. Initial restricted-cache attempts could not start; an initial Java 17 Debug run reported 413 passes and one class setup failure because the existing SDK 36 Robolectric test requires Java 21 (Release did not run). The final Java 21 run supersedes that environment failure.

## Device and backend limitations

Physical Huawei device and backend testing remains required to establish lead retention/conversion, primary-device selection across multiple registered devices, force-depersonalization effects, backend responses, offline/retry behavior, persisted state, and upgrade behavior. Automated tests do not certify HMS delivery or Portal state. Previously pending emails and SDK-managed synchronization remain upstream privacy limitations described in [the privacy report](user-validation-privacy-report.md).

RTC, SEC-01, SDK versions, dependencies, and unrelated functionality are outside this change. No commit, push, or PR is created.

## Changed files

- `README.md`
- `doc/G-02_PERSONALIZATION_FLAGS.md`
- `lib/src/user/user.dart`
- `lib/src/core/infobip_mobilemessaging_huawei.dart`
- `lib/src/platform/channel_contract.dart`
- `lib/src/platform/infobip_mobilemessaging_huawei_platform.dart`
- `lib/src/platform/method_channel_infobip_mobilemessaging_huawei.dart`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/plugin/ChannelContract.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/InfobipMobileMessagingHuaweiPlugin.kt`
- `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/user/UserManager.kt`
- `test/personalization_flags_test.dart`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/user/PersonalizationFlagsTest.kt`
- `android/src/test/kotlin/com/infobip/mobilemessaging/huawei/user/UserPersonalizationPrivacyTest.kt`
