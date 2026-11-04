# FIN-HUAWEI-940 — SDK 9.4.0 compatibility audit

> Historical evidence: Pre-upgrade snapshot; dependency and version statements below describe its recorded baseline. See the [current guides](README.md).


Audit date: 2026-11-04. Research only; repository dependencies, production code and release metadata are unchanged. Target plugin release 2.2.0 is provisional.

## 1. Baseline and scope

- Branch: `feature/infobip-huawei-sdk-9.4.0-upgrade`.
- Initial working tree: clean. `git fetch origin` succeeded.
- HEAD, local `development`, and fetched `origin/development`: `8d195fa45d857ec972dc9bd634e51d85f40c4f7c` (merge PR #95).
- `pubspec.yaml`: 2.1.0; Dart ^3.12.2; Flutter >=3.44.4.
- `android/build.gradle.kts:74–78`: Core `9.3.0@aar`, transitive enabled; Inbox and Chat `9.3.0`. RTC remains `2.5.28`; RTC UI `15.1.0@aar` is inspection-only. Enabling `infobipWebRtcEnabled` still deliberately fails configuration.
- Runtime extras: constraintlayout 2.1.4, localbroadcastmanager 1.1.0, fragment-ktx 1.8.9. Tests: JUnit 4.13.2, Mockito 5.20.0, ASM 9.8, Robolectric 4.16.
- Repository declarations: `android/build.gradle.kts`, `android/settings.gradle.kts`, `example/android/settings.gradle.kts`, `example/android/app/build.gradle.kts`, `example/android/build.gradle.kts`; historical standalone resolution scripts under `doc/evidence/` are not app dependencies. No strict version constraints, resolution force, or Gradle dependency locks were found in these active declarations. Dart pubspec.lock files exist and are unrelated to native Maven version selection.
- Repositories: Google, Maven Central, Huawei; example additionally includes Flutter's artifact repository. Example AGP 9.1.1, Kotlin 2.2.10, Gradle 9.3.1, AGConnect 1.9.1.301; desugar_jdk_libs 2.1.5.
- Plugin/example compileSdk 37 and minSdk 26; Java/Kotlin target 17. Example targetSdk 36.

Public contract reviewed: `lib/src/core/infobip_mobilemessaging_huawei.dart`, `lib/src/platform/{infobip_mobilemessaging_huawei_platform,method_channel_infobip_mobilemessaging_huawei,channel_contract}.dart`, feature models under `lib/src/{user,chat,inbox,rtc}`, native `plugin/ChannelContract.kt`, and method dispatch in `InfobipMobileMessagingHuaweiPlugin.kt`. Existing method/event names and wire maps need no change merely to select 9.4.0. A new Flutter thread-routing API is a separate feature decision.

## 2. Official evidence and change inventory

Primary references:

- [Official release](https://github.com/infobip/mobile-messaging-sdk-huawei/releases/tag/9.4.0), published 2026-11-03 09:51:07 UTC. Release notes describe new African-language translations and notification-to-thread navigation; they are not an exhaustive compatibility statement.
- [Full tag comparison](https://github.com/infobip/mobile-messaging-sdk-huawei/compare/9.3.0...9.4.0).
- Tag 9.3.0: `12bdabeec686e4bf8b3218d343fbf65ccb387699`; tag 9.4.0: `1d96196d2f00225d42431a537f0555e7b675959e`. The source diff used these tags. The downloaded checkout HEAD `79e71c9735ef0b8a9046e93b72ae2c1c42b22113` differs from 9.4.0 only in README/gradle.properties; all inspected implementation and build files match the 9.4.0 tag.
- [9.4.0 build requirements](https://github.com/infobip/mobile-messaging-sdk-huawei/blob/9.4.0/build.gradle).
- [Notification interaction documentation](https://github.com/infobip/mobile-messaging-sdk-huawei/wiki/In%E2%80%90app-chat#handle-notification-interaction) is linked by the release; conclusions below use tagged implementation rather than assuming mutable wiki behavior.

| Classification | Change | Compatibility effect / evidence |
|---|---|---|
| ADDITIVE | `OpenLivechatAction.threadId: String` | Parses nonblank `customPayload.threadId` only for Chat messages; combines it with an existing openLiveChat action. Tagged Core `OpenLivechatAction.java`; confirmed in published javap output. |
| BEHAVIORAL | Default push interaction opens the specified native Chat thread | `InAppChat.java` documents routing; `InAppChatActivity.kt` calls `showThread(threadId)` in multithread mode and sends an optional keyword to that thread. Single-thread mode ignores thread ID. Missing action retains callback-activity fallback. |
| BEHAVIORAL | JavaScript arguments use JSON string serialization | `LivechatWidgetClientImpl.kt` escapes thread IDs and other string arguments instead of interpolating single-quoted strings. Null inputs become the literal string `"null"`, not JavaScript null. Exercise quotes, slashes, Unicode and nulls. No removed widget signatures. |
| ADDITIVE | KINYARWANDA, LUGANDA, SWAHILI_KENYA, SWAHILI_TANZANIA | `LivechatWidgetLanguage.kt`; codes rw-RW, lg-UG, sw-KE, sw-TZ. Native resources added for rw, lg, sw. |
| INTERNAL | MessagePayload adapter redundant return cleanup; demo controls; gitignore/readme/version metadata | No public payload schema removal evidenced. Upstream README still shows 9.3.0; tagged gradle.properties uses SNAPSHOT, so publication is verified separately. |
| INTERNAL / BEHAVIORAL | Tag diff expands Core/Chat ProGuard rules | Kotlin/Gson/reflection/JS boundaries retained more explicitly. **Published 9.3.0 and 9.4.0 AAR proguard.txt are already identical**, so do not describe this as a newly delivered binary fix. |
| BEHAVIORAL / UNKNOWN runtime | API Java and Android resources 16.3.0 → 16.5.0 | All three POMs carry this change as applicable. Downloaded API source trees are identical; resource/runtime integration still needs APK/device verification. |
| INTERNAL | Inbox implementation | No Inbox source change in tag diff; published classes.jar entries byte-identical. |
| BREAKING | None confirmed in inspected public binary signatures | Not a guarantee of unchanged navigation, backend contracts, or every transitive behavior. |

The complete tag diff has 20 files, 375 insertions and 86 deletions. No Huawei Core initialization, user synchronization, token-service, manifest, permission, or Inbox implementation change appears outside the inventory above. Both tags configure SDK Java/Kotlin compilation for Java 11 with Kotlin 2.2.10; the plugin targets Java 17. Published public API enumeration (`javap -public` over every class) found only the threadId field, language constants, and a Kotlin internal helper exposed in bytecode. No public method removal or new deprecation was identified. This is signature evidence, not a full binary compatibility proof for arbitrary consumers.

## 3. Maven and binary verification

All POM, AAR and Gradle `.module` files returned successfully from Maven Central:

| Artifact (group com.infobip, version 9.4.0) | AAR bytes | SHA-256 |
|---|---:|---|
| [infobip-mobile-messaging-huawei-sdk](https://repo.maven.apache.org/maven2/com/infobip/infobip-mobile-messaging-huawei-sdk/9.4.0/) | 477893 | `35bf4d03cee596d04fb96d75ed69e4450aed4e8b91dba74d452f0dbd26c46bbf` |
| [infobip-mobile-messaging-huawei-inbox-sdk](https://repo.maven.apache.org/maven2/com/infobip/infobip-mobile-messaging-huawei-inbox-sdk/9.4.0/) | 27944 | `2e581a4197a46f4e3d96e657c43e5d44d30a59975f7294d04047daed34b9c2ac` |
| [infobip-mobile-messaging-huawei-chat-sdk](https://repo.maven.apache.org/maven2/com/infobip/infobip-mobile-messaging-huawei-chat-sdk/9.4.0/) | 632616 | `8bfbb2a2acf8615334312e902c3bab177aec2b854be1a1a5b35a9f41b7cd4008` |

POM deltas are limited to Core 9.3→9.4 references and API/resources 16.3→16.5. Important unchanged dependencies include HMS Push 6.7.0.300, WorkManager 2.10.0, Gson 2.9.0, Kotlin 2.2.10, coroutines 1.11.0, core-ktx 1.16.0, lifecycle 2.9.3, appcompat 1.7.1, activity 1.11.0, recyclerview 1.4.0, exifinterface 1.4.1 and material 1.13.0. Chat publishes viewbinding 9.2.0; this already existed in 9.3.0 despite the host's AGP 9.1.1.

Isolated Gradle 9.3.1 resolution used Google/Maven Central/Huawei and all existing plugin runtime declarations, substituting only the three target versions. It succeeded, including RTC 2.5.28, google-webrtc 1.0.45036, API/resources 16.5.0, viewbinding 9.2.0 and constraintlayout **2.2.2** (Gradle conflict selection over direct 2.1.4). Core appears twice in resolved output due to explicit @aar versus normal dependency requests; inspect final packaging rather than treating this alone as duplicate classes.

All three published manifests and AAR metadata are byte-identical to their 9.3.0 counterparts. minCompileSdk=37, minAndroidGradlePluginVersion=1.0.0, library minSdk=21, no core-library-desugaring requirement in this metadata. Source build AGP 9.2.0 is not itself a requirement to upgrade the host AGP. No new permission, exported component, provider, or R8 consumer rule in the published delta. Existing plugin compileSdk/minSdk satisfy these declarations.

Binary entry comparison: only OpenLivechatAction changes in Core; no changed classes in Inbox; six changed Chat class entries (widget implementation/generated helpers, activity, language enum/companion). Core/Chat/Inbox rule SHA-256 respectively: `591ae851c12a01ce43841628a94a818d5d8e7670bf39a4d2eb10e10040201ab1`, `9a8dd401ff0a1211da7a1136ea8eb795074c8f894c2597ae54d989858ba14838`, `3bcdb1ad38ae87cec856ae6de3d9c6f154203d511001cd3f4a3860fddffc61dc`. These identify rules, not complete AARs.

## 4. Native contract matrix

Paths below are relative to `android/src/main/kotlin/com/infobip/mobilemessaging/huawei/`; upstream paths are under the corresponding tagged SDK module's `src/main/java/org/infobip/mobile/messaging/`.

| Surface | Plugin evidence / native contract | Assessment |
|---|---|---|
| Initialization | `core/MobileMessagingInitializer.kt`; `MobileMessaging.Builder(...).withApplicationCode(...).withSenderId(...).withFullFeaturedInApps().withDisplayNotification(...).build(InitListener)` | Signatures preserved; no required source adaptation found. Confirm HMS registration on device. |
| User fetch/save | `user/UserManager.kt`; `fetchUser(ResultListener<User>)`, `saveUser(User, ResultListener<User>)` | Preserved; listeners still use `Result<User,MobileMessagingError>`. |
| Partial patch | `user/UserMapper.kt::toPatch`, same saveUser call | No upstream mapper/User/Core class change in published Core. See G-01 caveats below. |
| Personalize | `personalize(UserIdentity, UserAttributes, boolean forceDepersonalize, boolean keepAsLead, boolean setDeviceAsPrimary, ResultListener<User>)` | Exact boolean order preserved. Existing overloads remain. |
| Depersonalize | `depersonalize(ResultListener<SuccessPending>)` | Preserved; asynchronous pending state remains meaningful. |
| Inbox | `inbox/InboxManager.kt`: fetch and setSeen with JWT state | Entire Inbox class content unchanged; backend/JWT expiry behavior needs integration tests. |
| Native/embedded Chat | `chat/ChatManager.kt`, `chat/ChatPlatformView.kt`, `chat/ChatLanguageMapper.kt` | Existing API calls preserved; notification destination changes; JS escaping changes. |
| Push/events/installations | notification dispatch in plugin; `installation/InstallationManager.kt` | Signatures/manifest unchanged. HMS token rotation, foreground/background/killed delivery unverified locally. |
| Errors | `user/UserManager.kt::userListener/execute` and feature error mappers | Stable native error/result classes; plugin fixed messages remain. No evidence all upstream log/error paths are sanitized. |
| RTC | `rtc/HuaweiRtcTokenProvider.kt`: `MobileApiRtc.getToken(TokenBody(subject,43200L))`; `rtc/HuaweiRtcManager.kt` | API source tree unchanged, RTC binary version unchanged. Real calls, permissions, audio/video, screen sharing and token renewal require external validation. No new background incoming-call support established. |

## 5. G-01 regression assessment

`lib/src/user/user.dart` defines UserPatch/FieldUpdate; `user_codec.dart::encodePatch` omits unchanged fields and sends explicit null for clears. Native `UserMapper.toPatch` only invokes setters for present keys, rejects unsupported fields, rejects clearing the entire custom-attribute map, and represents individual deletion values as native null. `saveUser` remains the separate legacy mapper behavior.

Upstream `UserMapper.plus` checks containsField OR nonnull values, preserving explicit-null intent; `UserMapper` null serializer is unchanged. `MobileMessagingCore.saveUser` first merges/stores unreported data and then invokes `userDataReporter().patch`. Consequently an empty patch still reaches the SDK and can synchronize existing pending data; it is **not guaranteed to be a no-op**. The same pipeline/classes are unchanged in published Core. This supports structural compatibility, not proof that backend deletion or omission persists correctly after retries, restart or upgrade. Test scalar/set/list/custom-attribute omission, set and clear; individual custom deletion; empty patch with/without pending data; offline retry, restart and subsequent fetch/backend readback.

## 6. G-02 regression assessment

`PersonalizeContext`, platform interface and method-channel implementation default both flags to false. Native plugin dispatch validates optional booleans and substitutes false when omitted. `UserManager` forwards forceDepersonalize, keepAsLead, setDeviceAsPrimary in that order. Deprecated Dart personalization entry points delegate with false defaults. SDK 9.4.0 retains the six-argument method and earlier overloads. No compatibility source edit required; preserve existing flag validation and all eight native boolean combinations. Device/backend tests must verify actual lead retention, installation primary status, force-depersonalization effects and legacy callers, including failure/retry behavior.

## 7. Email privacy and SEC-01

**SEC-01: PARTIALLY MITIGATED; unresolved.**

- `user/UserEmailPrivacy.kt` checks Kotlin String.length (>255 UTF-16 code units); `UserManager` invokes it before SDK saveUser, patchUser and personalize. Length 255 is accepted, 256 rejected, including surrogate-pair boundary cases. Native privacy exception maps to code `-10` and fixed value-free text. Existing pending/previously stored data is outside this new-input guard.
- Direct source **and 9.4.0 AAR bytecode** evidence: `util/AuthorizationUtils.java::getAuthorizationHeader` still concatenates the header into `System.out.println`. See [tagged source](https://github.com/infobip/mobile-messaging-sdk-huawei/blob/9.4.0/infobip-mobile-messaging-huawei-sdk/src/main/java/org/infobip/mobile/messaging/util/AuthorizationUtils.java). This class is byte-identical between published Core versions. This is not fixed upstream.
- Default Chat notification handler still logs message body through MobileMessagingLogger; OpenLivechatAction.toString now includes threadId. Review debug/diagnostic logs with synthetic data; do not equate absence of a new authorization defect with privacy clearance.
- Local `doc/sec01-release-logging-mitigation.md`, `SECURITY.md`, and `example/android/app/proguard-rules.pro` document host Release-only print/println suppression. The plugin does not export that opt-in; Debug and non-opted-in hosts remain exposed. Rules are application-wide and require effective R8 optimization.
- RTC remains 2.5.28. Existing documented `SocketHandler.logMessage` raw signaling/PrintStream.printf risk and possible TURN credentials remain unresolved; print/println rules do not cover printf. No new RTC transport or security fix is established by this upgrade. This audit did not perform an exhaustive RTC binary or shipping-APK log clearance.
- SDK-managed user serialization, pending storage, reporting and logging remain outside complete plugin control. Valid-length data may still enter SDK logs; the pre-SDK length guard is a narrow plugin mitigation, not a comprehensive privacy filter.

## 8. Capability adoption

| Capability | Automatic existing integration | Required work / validation |
|---|---|---|
| Chat push → thread | Default native handler can use Chat payload threadId and open InAppChatActivity automatically; plugin does not install a custom interaction handler | Host/backend must supply valid Chat messages and multithread configuration. Verify native activity theme/back navigation, cold/warm start, multiple notifications, malformed/missing IDs, keyword behavior and single-thread fallback on Huawei. |
| Flutter route / embedded view → particular thread | No new Flutter API appears automatically; channel exposes thread-list actions but no dedicated showThread(threadId) | If product requires Flutter navigation instead of default native activity, separately design Kotlin interaction handling plus Dart API/event contract. Not required merely to compile; do not add silently. |
| New languages | Existing ChatLanguageMapper.findLanguage(widgetCode) dynamically uses SDK enum | Existing string-based language route can accept new codes without Kotlin/Dart enumeration changes; verify backend/widget translations and native resources. |
| Improved JS escaping | SDK-internal widget implementation | No Flutter change; test special characters and null behavior with real widget. |
| ProGuard improvements | Already present in downloaded 9.3 and 9.4 AARs | No new broad keep/dontwarn rules justified. Inspect effective Release rules and runtime reflection/JS behavior. |
| Init/callbacks | No changed contract identified | Reuse existing integration, validate lifecycle and persisted installation on upgrade. |

## 9. Required implementation work and risks

No mandatory Dart/Kotlin production source change was identified for native API compatibility. A later implementation task should change **all three SDK declarations together**, retain Core transitivity, and inspect the selected graph/packaging. Do not automatically change AGP, Kotlin, compileSdk, RTC, pubspec or release number based on upstream source build versions.

Before shipping, resolve the notification-navigation acceptance decision, complete target native/build validation and device/backend matrix, and obtain an explicit SEC-01 release disposition with signed-artifact evidence. These are readiness gates, not claims of newly discovered source breakage. External uncertainties: real HMS/backend routing, Chat identity/thread ownership, pending-data persistence/deletion, personalized installation flags, RTC runtime, signed upgrade/rollback, and production logging. Automated checks cannot resolve them.

## 10. Local validation evidence and recommended matrix

Temporary source checkout: `/private/tmp/fin-huawei-940-upstream`; artifacts: `/private/tmp/fin-huawei-940-artifacts`; standalone graph: `/private/tmp/fin-huawei-940-resolve`; plugin copy: `/private/tmp/fin-huawei-940-plugin`. Temporary copy changes only target dependency selections and generated plugin path for validation. No upgrade was applied to the working repository. Logs are temporary and should be retained/exported by the implementation owner if needed.

| Check | Audit result / concrete acceptance criterion | Environment |
|---|---|---|
| Flutter analysis | PASS, no issues; `/tmp/fin-huawei-940-analyze.log` | Local, Flutter 3.44.4 |
| Plugin Dart tests | PASS, 253; `/tmp/fin-huawei-940-dart-tests.log` | Local; verifies Flutter contract, does not execute native SDK |
| Example Dart tests | PASS, 49; `/tmp/fin-huawei-940-example-tests.log` | Local |
| Android Debug/Release tests | PASS: 433 Debug + 433 Release tests, zero failures/errors/skips; includes existing G-01/G-02/email/RTC contracts | Local Java 21; existing API-36 Robolectric tests fail on Java 17 |
| Debug/Release APKs | PASS: both APKs assembled; Release minifyReleaseWithR8 and resource shrinking completed; Release APK is unsigned | Local; target dependency copy |
| R8/security | Inspect effective rules, missing-rules diagnostics, final dex for reflective APIs, header println and RTC printf; runtime log tests with synthetic secrets | Local artifact inspection plus signed physical-device tests; not established merely by assembleRelease |
| Push/token lifecycle | register, rotate/re-register, revoke, foreground/background/killed/locked notification delivery and taps | Physical HMS Huawei + Portal/backend |
| Chat/Inbox | single/multithread push routing, valid/missing/blank/foreign thread ID, keyword, warm/cold process, embedded/native views, attachments, language, unread counts, JWT expiry and seen readback | Physical Huawei + configured Chat/Inbox backend |
| G-01 | all omission/set/clear combinations; custom deletion, empty patch, pending queue, offline retry and restart; backend readback | Local mapping tests + backend/device |
| G-02 | all flag combinations, omitted/false defaults, invalid wire types, legacy API; backend lead/primary-installation readback | Local contracts + backend/device |
| Email | 255/256 UTF-16 units including surrogate pairs; value-free -10 errors, no SDK call on invalid input; old pending data and runtime logs | Local spies + physical device/log capture |
| RTC | outgoing audio/video, controls, camera switch, permission denial, screen capture, lifecycle, token failure/renewal, network interruption | Contract tests local; real Huawei + RTC backend/media required |
| Upgrade/rollback | signed 2.1→candidate installation retaining registration, user queue, Chat state; controlled rollback feasibility | Signed APKs + real device/backend; not performed |
| CI | rerun analysis, Dart tests, both native test variants, both APKs on exact future candidate SHA | Hosted CI; not run by this audit |

## 11. Proposed v2.2.0 phases

1. Review this audit; decide default native notification routing versus a separately scoped Flutter thread feature; define device/backend owners and SEC-01 acceptance criteria.
2. In an authorized implementation task, update only the three SDK coordinates first. Preserve G-01/G-02/privacy behavior and run the local/hosted matrix on the resulting exact SHA.
3. Add focused routing/escaping regression coverage and documentation for intentional behavior changes. Implement any Flutter thread API only under explicit feature scope.
4. Validate signed device upgrades, push/Chat/Inbox/backend semantics, RTC and shipping logs. Resolve or explicitly disposition SEC-01; do not infer closure from version bump or tests.
5. Decide 2.2.0 release metadata and release approval separately after evidence review. No commit, push, merge, tag or publication is part of this audit.

## 12. Final validation and verdict

**READY FOR SDK UPGRADE** — ready for a controlled implementation of the three dependency updates. No confirmed native signature blocker, missing artifact, or required Dart/Kotlin production adaptation was found. This is not release or production-security approval.

Final isolated run used Java 21 and canonical `/private/tmp` paths: `:infobip_mobilemessaging_huawei:testDebugUnitTest`, `:infobip_mobilemessaging_huawei:testReleaseUnitTest`, `:app:assembleDebug`, `:app:assembleRelease`. Result: BUILD SUCCESSFUL in 1m 34s; 433 tests per variant, zero failures/errors/skips. Full log: `/private/tmp/fin-huawei-940-target-validation.log`; XML: temporary copy `example/build/infobip_mobilemessaging_huawei/test-results/test{Debug,Release}UnitTest/`. Analysis and 302 Dart tests also passed, totaling 1,168 passing tests across Dart and native variants. The first exploratory attempts encountered inherited temporary build state, a /tmp canonical-path mismatch, and Java-17 incompatibility with an existing API-36 Robolectric test; clean canonical paths and Java 21 resolved these environmental failures. They are not attributed to SDK 9.4.0.

Remaining release gates: physical HMS/backend validation; acceptance of native Chat thread navigation; signed upgrade/persistence and runtime log checks; hosted CI on the future implementation SHA; explicit SEC-01 disposition. No hard blocker to starting the upgrade remains. Existing toolchain warnings include Flutter's future Kotlin >=2.2.20 recommendation, deprecated AGP Kotlin integration/Gradle APIs, and Android SDK XML tooling mismatch; they did not fail this run and do not justify silently expanding upgrade scope. If Flutter-only thread navigation is required, scope the native handler and Flutter API work before promising that behavior.

Only this audit report is added to the working tree, uncommitted. No production source, dependency declaration, pubspec, release version, commit, push, merge, tag or publication was changed.
