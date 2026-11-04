# 2.2.0 local release preparation — 2026-11-04

The original preparation evidence below is a historical snapshot. The final section
records the subsequent native-default compatibility fix and its validation.

## Decision

**CONDITIONAL GO for local release preparation and owner review.** Publication is
not approved or performed. Automated checks pass except the literal full-tree
format check, which finds existing ignored files. Physical Huawei notification
navigation, visual Chat readiness, backend behavior, signed upgrade/rollback and
shipping-artifact logging acceptance remain outstanding. SEC-01 remains
PARTIALLY MITIGATED and unresolved. No device testing was performed in this task.

## Version summary and baseline

- Branch: `feature/infobip-huawei-sdk-9.4.0-upgrade`.
- Starting and final HEAD: `15a1466db4bec90805c9ed41d3f77e725657aabf`.
- Starting tracked/untracked working tree: clean (ignored local configuration and
  generated artifacts already existed).
- Previous configured/documented version: 2.1.0. Latest published version: 2.1.0,
  verified through the [pub.dev package API](https://pub.dev/api/packages/infobip_mobilemessaging_huawei)
  during this task. The initial restricted lookup failed; the subsequent read-only
  lookup succeeded. No remote Git operation was used.
- Prepared version: **2.2.0**, because Chat notification navigation adds public
  APIs. SDK and composition changes also warrant a minor release over 2.1.0.
  The entry remains marked unreleased until publication.
- Core / Inbox / Chat: **9.4.0**; RTC Core: **2.5.28**; WebRTC: **1.0.45036**.
- Dart ^3.12.2; Flutter >=3.44.4; minSdk 26; compileSdk 37; example targetSdk 36.
- Java/Kotlin bytecode 17; native tests Java 21; example AGP 9.1.1,
  Kotlin 2.2.10, Gradle 9.3.1. Existing AGP transition/namespace flags retained.
- Updated package version, example path dependency lockfile and current README
  installation/publication examples. Example dependency remains `path: ../`;
  the example's own 1.0.0+1 app version is independent of the plugin.
- Android module's internal Gradle version 1.0.0 is not the pub.dev package version
  and remains unchanged. Native SDK/toolchain selections were already committed;
  no production functionality or workflow was changed by this preparation.

## Documentation cleanup

Reviewed the 43 existing Markdown files for current-versus-historical scope,
version references, duplicate content, local links and headings. No exact duplicate
Markdown files were found. **No Markdown files were deleted**: older investigations,
plans and security reports preserve distinct evidence or uncompleted device checks.
The existing documentation index already separates maintained guides from history.

Updated README, API compatibility, contributor guidance, security guidance, example
guide, messaging guide, identity guide and documentation index. Added explicit
historical notices to the 9.4.0 pre-upgrade audit, upgrade-only validation snapshot
and 9.3.0 email privacy report. Their original versions/counts remain evidence.
Historical 2.1.0 and older changelog/release entries remain unchanged.

Consolidated the consumer notification ownership contract in the shipped
`messaging-chat.md` guide. Retained the detailed regression report as engineering
and physical-test evidence. Replaced its README relative link (the report is
excluded from pub.dev) with a pinned repository URL; added a shipped-guide link.
The index now includes SDK 9.4.0, notification routing and both release reports.
All local file links and heading anchors were checked; external URL availability
was not comprehensively checked.

README retains initialization, HMS/Infobip setup, Push, native/embedded Chat,
notification configuration, outgoing audio/video, experimental foreground incoming,
screen sharing and limitations. It now explains hybrid composition/loading timeout.
No new RTC capability is claimed. Embedded notification mode requires each host's
own app-level route handler; the example supplies one. Pending requests are not a
durable journal across further process death. Actual push/thread/visual acceptance
is still unverified.

## Repository and package hygiene

Added explicit root ignore rules for private example constants, local result files,
report directories, FVM and Kotlin caches. Added FVM/Kotlin exclusions to pubignore;
existing private config, HMS JSON, signing material, environment, build and cache
exclusions remain. Verified representative private/HMS/env/report/cache paths with
`git check-ignore`. No Gitleaks exclusions, tooling or workflows were added.
The four previously reported historical Gitleaks findings were not rescanned or
reclassified in this task; dry-run success is not a full security audit.

The dry-run used an isolated copy of current tracked file contents and the safe
example configuration template, never the local private constants. Its package
listing excludes `agconnect-services.json`, private `example_test_config.dart`,
lockfiles, local reports, build outputs and caches; the safe template is included.
No unexpected generated file remains visible in final Git status. Build products
remain ignored. No credential values were printed or copied into this report.

## Prepared release notes

## 2.2.0 (unreleased)

### Added

- Public Chat notification presentation modes and pending-navigation query,
  event and acknowledgement APIs for host-owned Flutter navigation.
- Example app startup/resume recovery, ordered request handling, duplicate
  suppression and reuse of the embedded Chat route.

### Changed

- Upgrade Infobip Huawei Core, Inbox and Chat from 9.3.0 to 9.4.0.
  RTC Core remains 2.5.28; Flutter/Android build requirements are unchanged.
- Native SDK-owned notification presentation remains the default when no mode
  is saved. Embedded routing requires explicit opt-in and a host navigation handler;
  previously saved native or embedded choices remain unchanged.
  Pending navigation survives engine recreation, but is not persisted across
  another process death after interception.

### Fixed

- Use hybrid composition and container-based fragment attachment for embedded
  Chat; report a 30-second loading timeout and detach callbacks during disposal.
- Preserve SDK-parsed thread targets until route acknowledgement, including
  threadless notification requests and delayed Flutter startup.

### Security

- Preserve pre-SDK email validation and existing logging mitigations. SEC-01
  remains PARTIALLY MITIGATED; SDK 9.4.0 does not resolve upstream sensitive logging.

### Documentation

- Align current SDK/version references and document native versus embedded
  notification ownership, lifecycle limitations and release validation evidence.

No public API removals or new host build requirements. Physical Huawei push,
visual Chat readiness, backend behavior and signed upgrade/rollback remain
unverified by automated checks.


## Validation results

Logs are local under `/private/tmp/huawei-release-2.2.0/` (not packaged).
Flutter checks used the installed **3.44.4** SDK explicitly; the shell default was
older and unsuitable. JDK 21 was selected explicitly for Android tests/builds.

| Check | Result | Evidence / limitations |
| --- | --- | --- |
| `flutter pub get` | PASS | Package/example dependencies resolved; example lockfile changes only plugin 2.1.0 → 2.2.0. Initial restricted attempt could not write Flutter cache; rerun with permitted cache access succeeded. |
| `flutter analyze` | PASS | No issues found. |
| `dart format --output=none --set-exit-if-changed .` in working checkout | FAIL | 127 files examined; 21 would change: 20 pre-existing ignored build/docs snippets and the private example config. No files rewritten. |
| Maintained-source scoped format check | FAIL | Only the private ignored example config would change. Preserved untouched. |
| Same full format command in isolated clean source | PASS | 98 files, 0 changed, safe default example config. |
| `flutter test --no-pub` | PASS | 259 plugin tests. |
| Example `flutter test --no-pub` | PASS | 57 tests. |
| Existing Gradle Debug unit-test task | PASS | 453 tests, 0 failures/errors in 60 XML suites. |
| Existing Gradle Release unit-test task | PASS | 453 tests, 0 failures/errors in 60 XML suites. Both tasks: BUILD SUCCESSFUL. |
| Example Debug APK build | PASS | Existing Flutter build command, 9.0s; no install performed. |
| Example Release APK build | PASS | Existing Flutter build command, 31.2s; APK 88.2 MB; no signed distribution/device acceptance claimed. Existing legacy KGP migration warnings remain. |
| `flutter pub publish --dry-run` | PASS | Isolated current tracked source + safe defaults; 1008 KB compressed archive; 0 warnings; no publication. |
| Public API example analysis | PASS | 18 complete import-bearing snippets from README, messaging and identity guides; no issues. Initial temporary harness had filename lints and an import-only block; corrected harness then passed. Contextual fragments are not standalone examples. |
| Local Markdown files/headings | PASS | No missing local target files or heading anchors after adding this report; no exact duplicate Markdown content. |
| Version / metadata / API review | PASS | Additive Chat APIs verified against Dart/channel/native code; existing requirements retained; behavior migration explained. No production code changed. |
| `git diff --check` | PASS | No whitespace errors. |
| Physical Huawei / backend / signed upgrade / rollback | BLOCKED | No device/backend acceptance performed; use the retained routing and SDK-upgrade checklists before release acceptance. |
| SEC-01 release acceptance | BLOCKED | Upstream authorization-header and RTC signaling logging risks remain; owner disposition and shipping-artifact assessment required. |

1,222 automated test executions passed across plugin, example and both native
variants. Debug/Release native suites are the same scenarios on different variants.
This does not establish hosted CI, HMS delivery, backend state, OEM lifecycle,
16 KB runtime behavior or safe production logs.

## Final verification and file inventory

No commits, pushes, PRs, merges, tags, history rewrites, GitHub Actions edits or
publication were performed. HEAD is unchanged. All modifications remain local and
uncommitted. No production source was modified. No files were deleted.

Final `git status --short` (this report is the sole created file):

```text
 M .gitignore
 M .pubignore
 M API_COMPATIBILITY.md
 M CHANGELOG.md
 M CONTRIBUTING.md
 M README.md
 M SECURITY.md
 M doc/README.md
 M doc/SDK_9_4_0_COMPATIBILITY_AUDIT.md
 M doc/SDK_9_4_0_UPGRADE_VALIDATION.md
 M doc/huawei-rtc-customer-identity.md
 M doc/messaging-chat.md
 M doc/user-validation-privacy-report.md
 M example/README.md
 M example/pubspec.lock
 M pubspec.yaml
?? doc/release-2.2.0-preparation.md
```


## Native-default compatibility fix — 2026-11-04

The notification handler now reads a missing saved presentation preference as
`native`, preserving SDK-owned routing for both fresh installations and upgrades
without a saved mode. Explicit `embedded` and `native` selections are preserved;
no preference migration or reset is performed. Embedded routing remains available
through `setNotificationPresentationMode(ChatNotificationPresentationMode.embedded)`.
A pre-release installation that explicitly saved embedded mode retains that choice.

Only the preference fallback changes in executable production code. Pending queues,
thread selection, duplicate suppression, lifecycle handling and explicit `showChat()`
are unchanged. The public API comment and current routing guidance are corrected.
Native mode retains the SDK's payload-dependent destinations and informational tap
events; it does not enqueue or emit an embedded Flutter navigation request.

Regression coverage now explicitly selects embedded mode and exercises fresh and
existing installations without preferences, explicit native selection, handler/provider
recreation and saved embedded selection after simulated transient process-state loss.
Pending requests survive handler recreation but remain process-local. These are unit
simulations, not a real process-kill or physical Huawei acceptance test.

Validation used Flutter 3.44.4 / Dart 3.12.2 and JDK 21. Logs are under
`/private/tmp/huawei-native-default/` and are not packaged.

| Check | Result |
| --- | --- |
| Flutter analysis (including example) | PASS; no issues |
| Plugin Flutter tests | PASS; 259 tests |
| Example Flutter tests | PASS; 57 tests, including navigation/lifecycle coverage |
| Android Debug unit tests | PASS; 456 tests, zero failures/errors/skips |
| Android Release unit tests | PASS; 456 tests, zero failures/errors/skips |
| Publication dry run in working checkout | Exit 65; 1010 KB; one warning for seven modified packaged Git files; no other package warnings |

All 1,228 test executions passed with no skipped tests. Existing AGP/Kotlin and
Android API deprecation warnings remain. The dry-run dirty-tree warning is expected
while changes remain local for review; no commit or publication was performed.
Version 2.2.0 and all dependencies are unchanged.

The default-routing compatibility blocker is addressed. Physical Huawei/backend,
visual Chat, signed upgrade/rollback and shipping-artifact logging acceptance remain
outstanding. SEC-01 remains PARTIALLY MITIGATED and unresolved. This fix does not
constitute release approval. Earlier preparation counts and Git-status excerpts
above describe their original snapshot, not this follow-up working tree.
