# pub.dev publication readiness — v1.0.0

Reviewed 2026-10-12 (Asia/Amman) on `release/rtc-production-certification`.
Candidate HEAD before documentation edits: `68e96ee0850124b1d5f88dcfe18e1acd94ef6515`.
Initial working tree was clean; preserve all subsequent changes. This review
changes documentation only. No runtime changes, dependency upgrades, commit,
push, publication or vendor report were performed.

## Owner decision and unresolved security risk

The owner does not want to submit a security report to Infobip before publication.
Vendor disclosure, acknowledgment or remediation is not a package publication
gate. The sanitized draft remains optional and unsent. Vendor response/fix status
is **UNVERIFIED**; no approval or upstream fix is inferred.

**SEC-01 remains PARTIALLY MITIGATED, not fixed. This package is not
security-certified.** Huawei MM 8.14.0 contains authorization-header println
logging; RTC 2.5.28 contains signaling printf logging that may expose temporary
TURN usernames/credentials. Logger OFF does not govern direct stdout.

The optional host Release R8 print/println rule requires enabled R8 and effective
optimization. It affects matching PrintStream output application-wide, including
stderr and functional stream/file output; it does not remove RTC printf or
guarantee removal of all sensitive logs. It remains outside plugin consumer rules.
Prior unsigned-example disassembly is evidence only for the known MM println;
exact signed-device exposure and sensitive-log absence remain **UNVERIFIED**.
See [security guidance](../SECURITY.md) and
[artifact evidence](sec01-release-logging-mitigation.md).

## Metadata review

- Name `infobip_mobilemessaging_huawei`, version `1.0.0` already correct.
- Description covers implemented Huawei messaging, Chat, outgoing RTC and sharing;
  the README explains Screen-as-Camera limitations and Android-only support.
- Android plugin package/class registration present; Dart `^3.9.0` and Flutter
  `>=3.35.7` constraints retained.
- Dependencies are Flutter SDK / hosted packages, with no path or Git dependency
  in the root pubspec. All declared constraints and lockfiles are preserved.
- Repository and issue tracker URLs match the configured GitHub origin; four
  topics present. No `publish_to` override, so default destination is pub.dev.
- Root README and CHANGELOG present. No publisher identity or license invented.
- Publishing account permission, live package-name/version availability and remote
  repository accessibility are **UNVERIFIED** by local checks.

## License authorization — publication blocker

No root LICENSE exists. The owner must authorize the exact license text and
copyright holder/attribution after confirming code provenance, contributor rights
and redistribution permissions for everything in the archive. No selection,
approval or permission has been supplied; this task does not create a license.

Review the example Gradle wrapper JAR and SDK-derived evidence (including
`docs/evidence/sec01/release-authorization-method.smali` and dependency/API reports)
for applicable notices and redistribution obligations. Declaring a license for
plugin-owned code does not grant rights to third-party material. Referenced Maven
SDKs are not bundled as AARs, but their integration terms and required notices must
also be reviewed by the authorized owner. Third-party legal clearance is
**UNVERIFIED**; no legal approval is claimed.

Official requirements: [Dart publishing guide](https://dart.dev/tools/pub/publishing)
requires a LICENSE and rights to redistribute uploaded content.

## Requested validation

Executed in the actual working checkout with Flutter 3.35.7 / Dart 3.9.2:

| Requested command | Exit | Current result |
| --- | --- | --- |
| `flutter analyze` | 1 | 21 info-level deprecation notices in retained compatibility APIs/tests; no errors or warnings. Not a clean pass. |
| `flutter test` | 0 | 229 tests passed. |
| `flutter pub publish --dry-run` | 65 | Missing root LICENSE; two potential issues: modified documentation files and top-level `docs/` naming. No upload. |

The initial sandbox attempt could not write the installed Flutter cache; the
executed checks used approved cache access. Standard dependency resolution ran;
no dependency constraints or tracked lockfiles changed. Newer-version notices
are advisories, not upgrades. The previous production report's test/build results
remain historical evidence.

## Final proposed package contents

The dry-run's full file tree was reviewed from the actual checkout, including the
new publication report: **294 files**, approximately **1 MB compressed** / **2.45 MB
uncompressed**. Includes public Dart and Android sources/resources, narrow existing
consumer rules, tests, example sources/host/tooling, and documentation/evidence.
The only JAR is the example Gradle wrapper; no SDK AAR is bundled.

No listed files matched private AGConnect config, local properties/config/launcher,
signing files, APK/AAB/AAR, lockfiles, build/cache/IDE outputs or local test reports.
Example configuration templates have empty credential values. Scoped private-key /
JWT-literal screening found no matches; pub reported no sensitive-file warning.
This is not a complete security audit or legal clearance. Third-party wrapper and
SDK-derived evidence permissions remain owner-review items; documentation links
and legitimate security warnings are retained.

Runtime/source, Gradle/manifest/consumer rules, pubspecs and tracked lockfiles are
unchanged. `git diff --check` passes; this task performed no staging, branch
switch, commit or push. The publication report appeared staged during final
verification; that staging is preserved. The final dry-run must be repeated after adding the approved
LICENSE because the publication candidate will then change.

Native builds, signed Huawei/backend acceptance and real 16 KB runtime checks are
**UNVERIFIED** in this review. They remain production integration checks, separate
from source-package publication readiness.

## Publication acceptance and next steps

**NO-GO** until an owner-authorized root LICENSE / redistribution clearance is
provided and the final-candidate dry-run succeeds. Confirm account authorization
and package/version availability before uploading. Baseline analyzer deprecation
infos and the docs-directory layout advisory must be disclosed; they are not
hidden or repaired through unrelated runtime changes. Vendor reporting is not a
gate. Package publication would not grant production security certification.

After adding the explicitly approved LICENSE and completing the rights review,
run from this branch using the same Flutter installation:

```sh
cd /Users/apple/Desktop/mobile-messaging-huawei-flutter-plugin
git branch --show-current
git status --short
flutter analyze
flutter test
flutter pub publish --dry-run
```

Inspect every result and the proposed archive. `flutter analyze` currently has
baseline info-level deprecation diagnostics; do not describe a nonzero exit as a
clean pass. No new analyzer errors/warnings or test failures should be accepted.
Review any changed lockfiles; do not upgrade dependencies for this release.
The uncommitted-documentation and `docs/` advisories are nonblocking if reviewed;
no commit is required by this task.

Only when publication blockers are resolved, sign in with the intended authorized
pub.dev Google account when prompted, and run the interactive upload command:

```sh
cd /Users/apple/Desktop/mobile-messaging-huawei-flutter-plugin
flutter pub publish
```

Do not use `--force` or `--skip-validation`. The version comes from the root
pubspec (`1.0.0`); there is no version argument. This command is for the owner to
execute later and has not been run by this task. If `1.0.0` already exists, stop
and resolve that conflict; no version change is authorized here.
