# G-01 user update patch report

> **Historical engineering report.** This records the original G-01 implementation snapshot; its uncommitted/review status describes that delivery.
> Use the [current user-update guidance](messaging-chat.md#user) for maintained guidance.
> Results, test counts and conclusions below belong to the recorded baseline;
> this notice adds no new validation or certification.

## Repository baseline
Both GitHub repository names resolve through the connected GitHub API to repository ID 1353253833, canonical name NaserAlomosh/infobip-mobile-messaging-huawei-flutter-plugin. Origin remains unchanged. Branch: fix/user-update-patch-semantics. Starting and final HEAD: 7d2362659a7b1dcf62d2148792583004aef31104. Initially clean; final changes are uncommitted and limited to G-01.

Published annotated tag v2.0.0 object 4a42d7038d6783e0d1fa1b1b284ba16a168d81cf peels to ea8325e4b27932d9e7460514782fdcea0951ead1. Both match git ls-remote origin. HEAD has identical tree contents to that release commit.

## Root cause and evidence
UserCodec.encode(UserData) includes nullable fields unconditionally. UserData cannot distinguish an omitted constructor argument from an explicit null. MethodChannel saveUser forwards these keys. UserMapper.toUser unconditionally invokes native setters, losing presence even for incoming maps that omit keys. UserManager.saveUser delegates to MobileMessaging.saveUser.

Inspected cached Huawei SDK 9.3.0 bytecode: UserJson.resolveUser delegates to fromJSON (the artifact's actual method name), which checks JSONObject.has before setters. UserAttributes setters call setField; User setters do likewise, with phones/emails converted to backend lists. UserDataReporter.patch validates via UserDataValidator and consumes User.getMap. CustomAttributeHolder preserves per-key null deletion values. New Kotlin regression tests assert actual SDK maps and validate all supported null clears. Legacy tests reproduce the mismatch alongside the sparse-patch expectation. Tests were added after implementation; no pre-fix failing test execution is claimed.

No backend deletion was demonstrated.

## Implementation
Additive public APIs: FieldUpdate<T>.omitted/set/clear, UserPatch, InfobipMobileMessagingHuawei.patchUser. All mutable profile fields supported by existing encoding are available; type and installations remain excluded. UserCodec.encodePatch emits only included keys. New platform method and channel contract reach a separate native handler and UserManager.patchUser. UserMapper.toPatch checks presence before each setter and rejects unknown keys and whole-map customAttributes null. Custom attributes use existing value encoding, including null deletion markers, dates and lists.

Existing saveUser signatures, encoding, setters, callbacks and errors remain unchanged. No dependency, toolchain configuration, package version or remote changes. Empty strings and collections remain explicit values. A sparse firstName patch now yields only firstName in the native map; lastName clear yields a present null key.

Changed files: lib/src/user/user.dart and user_codec.dart; core facade; platform interface, channel implementation and contract; native plugin handler, contract, UserManager and UserMapper; Dart and Kotlin patch tests; README, CHANGELOG and this report.

## Validation
- Flutter 3.44.4 pub get --no-example: passed.
- flutter analyze --no-pub: passed after correcting formatting lints.
- flutter test --no-pub: 242 passed.
- Example Dart tests: 49 passed.
- Native Debug: 416 passed, zero failures/errors/skips.
- Native Release: 416 passed, zero failures/errors/skips.
- Debug APK: passed.
- Release APK: passed on sequential rerun (88.0 MB).
- Publish dry-run: executed, exit 1 due solely to the expected uncommitted-files warning; nothing published.
- git diff --check: passed.

Initial native run with Java 17 failed on an existing SDK-36 Robolectric test requiring Java 21. Installed Java 21 rerun passed without changing toolchain configuration. Concurrent Android checks initially collided on shared outputs; the final native run completed successfully and APK Release was rerun sequentially.

## Risks
SDK request maps and local validation establish bridge semantics, not backend acceptance or persisted deletion. Controlled synthetic backend testing is still required for server handling of clears and empty values. Existing saveUser nullable behavior remains for backward compatibility; callers must opt into patchUser. Whole-map custom attribute clearing is intentionally unsupported. No device instrumentation, signing or backend tests were performed.

## Final verdict
READY FOR REVIEW: additive bridge implementation and automated checks pass. Backend semantics remain unverified and the publication dry-run reports the expected dirty-tree warning. All changes remain uncommitted.
