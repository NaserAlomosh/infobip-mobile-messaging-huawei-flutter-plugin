# v2.2.1 maintenance release preparation — 2026-11-04

## Decision and baseline

**READY for the local release preparation commit.** Final release date: 2026-11-04.
All required automated checks pass, including a warning-free package dry-run in an
isolated tracked-source copy. A clean-checkout dry-run is also required after the
local commit. Publication, remote changes and device/security acceptance are separate.
SEC-01 remains partially mitigated and unresolved.

- Branch: `release/2.2.1`, created with explicit owner authorization from
  `release/2.2.0-finalization`, carrying only the reviewed release edits.
- Starting HEAD: `4b91c1a0c3366387c526147488f1eec3f49530f1`.
- Verified remote main: `ff14070eaa001cd8794dceb200e4d4f390e7d89f`.
  Starting HEAD is three commits behind main with no unique commits; tracked trees
  match. Release preparation preserves this owner-approved baseline.
- Remote annotated `v2.2.0` tag object: `d1909244fe339295ac52eab8cab249d2a45f382d`,
  pointing to the verified main commit.
- [Pub.dev version metadata](https://pub.dev/api/packages/infobip_mobilemessaging_huawei/versions/2.2.0)
  confirms 2.2.0 publication on 2026-11-04 at 16:55:24 UTC.
- Target: 2.2.1. Authorized local commit message: `chore(release): prepare v2.2.1`.
  Tag name for later owner action: `v2.2.1`. No push, PR creation, merge, tag,
  history rewrite, pub.dev publication or GitHub Release publication is performed.

## Changes and consistency

- `pubspec.yaml`: 2.2.0 → 2.2.1; dependency resolution updates only the plugin
  version in the example path-dependency lockfile. Example app remains 1.0.0+1.
- `CHANGELOG.md`: adds 2.2.1 - 2026-11-04 and dates published 2.2.0 as 2026-11-04;
  preserves all historical release contents.
- `README.md`: documents the final 2.2.1 version and installation constraint,
  with publication instructions that do not claim publication has occurred.
- `API_COMPATIBILITY.md`: explicitly records unchanged APIs/runtime/requirements.
- `SECURITY.md`: updates the 9.4.0 version context and identifies the earlier
  disclosure decision as historical; does not claim vendor acknowledgment or a fix.
- `doc/README.md`: links this preparation report.
- `doc/release-2.2.0-preparation.md`: adds publication context above historical evidence.
- This report includes the complete final release notes below.

No production source, public API, Android build file, Flutter/Dart constraint,
SDK dependency, test or workflow changed. Core/Inbox/Chat remain 9.4.0, RTC 2.5.28,
and WebRTC 1.0.45036. Native Chat notification routing remains the default;
embedded routing remains explicit opt-in with a host navigation handler.

## Validation

Executed with Flutter 3.44.4 / Dart 3.12.2 and JDK 21. Local logs and package
listing: `/private/tmp/huawei-release-2.2.1-final/` (excluded from the repository/package).

| Check | Result |
| --- | --- |
| `flutter pub get` | PASS; example path dependency resolved to 2.2.1 |
| `flutter analyze` | PASS; no issues |
| `flutter analyze example` | PASS; no issues |
| `flutter test` | PASS; 259 tests |
| Example `flutter test` | PASS; 57 tests |
| Native `testDebugUnitTest` with `--rerun-tasks` | PASS; 456 tests, 0 failures/errors/skips |
| Native `testReleaseUnitTest` with `--rerun-tasks` | PASS; 456 tests, 0 failures/errors/skips |
| `flutter pub publish --dry-run` | PASS in isolated tracked-source copy; exit 0, 1009 KB compressed, 0 warnings |
| Relative Markdown links and heading anchors | PASS across tracked Markdown and this report |
| `git diff --check` | PASS |

All 1,228 test executions passed; no failed or skipped tests. Native variants repeat
scenarios against different builds. Native Gradle build succeeded; existing
AGP/Kotlin migration, deprecated Android API and JVM class-sharing warnings remain.
Dependency resolution reports newer incompatible package versions; none upgraded.
No APK build/install, physical Huawei/backend checks, signed upgrade/rollback,
shipping-artifact logging assessment or hosted CI run was performed for this patch.

The earlier preparation dry-run returned exit 65 solely for uncommitted files.
That historical result is superseded by the isolated final-source dry-run above;
no warning was suppressed.

## Package and security review

The dry-run inventory contains package metadata, public docs, Dart/native source,
tests, example source and safe configuration template, plus the six allowlisted
consumer guides. Internal reports, lockfiles, local private example configuration,
HMS JSON, signing keys, environment files, caches and build outputs are excluded.
Tracked configuration filenames and the dry-run listing were reviewed; no credential
or private configuration file was added or listed for packaging. This is a scoped
release hygiene check, not a new repository-history secret audit.

SEC-01 remains **PARTIALLY MITIGATED**, not resolved. Existing evidence documents
Huawei authorization-header stdout logging and RTC signaling `printf` risks.
The optional example Release R8 workaround is artifact-specific and does not cover
RTC `printf`. Automated tests do not establish safe production logs. The supplied
advisory screenshot shows triage and no patched version; it is not evidence of a
vendor fix. Private advisory details are not copied into public release notes.

## Final GitHub Release notes

# v2.2.1 — Maintenance Release

This maintenance patch corrects release metadata and documentation. Runtime behavior,
public APIs and functionality are unchanged from v2.2.0.

### Fixed

- Corrected v2.2.0's changelog status to its publication date, November 4, 2026.
- Clarified the historical status of earlier release-preparation evidence.

### Documentation and metadata

- Updated package metadata and the example path-dependency lockfile to 2.2.1.
- Updated installation documentation for v2.2.1.
- Documented patch compatibility and retained security limitations.

### Compatibility

- Infobip Huawei Core, Inbox and Chat: **9.4.0**.
- RTC Core: **2.5.28**; WebRTC: **1.0.45036**.
- Unchanged requirements: Dart **^3.12.2**, Flutter **>=3.44.4**, Android minSdk
  **26**, compileSdk **37**, with the existing Android toolchain/host flags.
- Native Chat notification routing remains the default. Embedded routing remains
  opt-in and requires the host's Flutter navigation handler.
- No new features, runtime fixes, API changes or dependency upgrades.

### Known security limitations

SEC-01 remains **PARTIALLY MITIGATED and unresolved**. Upstream Huawei authorization
logging and RTC signaling logging risks remain. Existing optional Release logging
mitigations do not guarantee safe logs and do not cover RTC `printf`. Consumers
must assess their own shipping artifacts; this patch is not a security fix.

### Validation

- Plugin and example analysis: no issues.
- 259 plugin, 57 example, 456 Android Debug and 456 Android Release unit tests
  passed: **1,228 test executions**, zero failures or skips.
- Dependency resolution and whitespace checks passed; local Markdown links checked.
- Publication dry-run in an isolated tracked-source copy: **1009 KB**, exit 0,
  **zero warnings**.
- Physical Huawei/backend behavior, signed upgrade/rollback, production logging and
  hosted CI were not verified by this local maintenance preparation.

[Full Changelog](https://github.com/NaserAlomosh/infobip-mobile-messaging-huawei-flutter-plugin/compare/v2.2.0...v2.2.1)

[Sponsor](https://github.com/sponsors/NaserAlomosh)
