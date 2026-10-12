# Phase 3.5.2 — release documentation and packaging

Date: 2026-10-12 (Asia/Amman). Assessment: **BLOCKED for publication**.
Documentation and package preparation are complete within the authorized scope;
this is not a release or security certification.

## Repository and initial state — VERIFIED

- Repository: `/Users/apple/Desktop/mobile-messaging-huawei-flutter-plugin`.
- Required/current branch: `release/rtc-production-certification`.
- HEAD: `c18351b3af457256bdd9761509deb0bc6be262e4`.
- Initial `git status --short` and `git status --porcelain=v1 -uall`: empty.
  There were no staged, unstaged or untracked user changes.
- Base branch named by task: `development`; no fetch, switch or mutation of it.
- Origin matches pubspec repository/issue tracker namespace:
  `https://github.com/NaserAlomosh/mobile-messaging-huawei-flutter-plugin`.
- No commits, pushes, tags, publication, reset, stash, clean or branch changes.

## Files changed — VERIFIED

| File | Release preparation |
| --- | --- |
| `README.md` | Full current integration guide: platforms/toolchain, HMS/Infobip setup, initialization, Push/events, user/Inbox, native/embedded Chat, JWT/counters, RTC/audio/video/renderers/controls/notifications, sharing, cleanup, troubleshooting/security and example |
| `CHANGELOG.md` | Expanded existing 1.0.0 entry with implemented features, performance/orientation improvements and CHAT-01/CHAT-02/API-01 hardening; no invented version/history or publication claim |
| `example/README.md` | Correct branch/static Dart config, host `app_id`/AGConnect reality, credential contracts, device run and Push/Chat/RTC/sharing checklists |
| `docs/screen-sharing.md` | New current feature guide: pipeline, permissions/consent, foreground notification, background/lifecycle, Stop, restoration, orientation/resize, resolution/readability and preview |
| `SECURITY.md` | Backend tokens, log/credential/privacy practices and unresolved upstream issue |
| `pubspec.yaml` | Description only: include current RTC/sharing features |
| `.pubignore` | Explicit package exclusions retaining root Git ignore safeguards, lockfile/local test-output exclusions; nested example Git ignores remain applicable |
| `API_COMPATIBILITY.md` | Correct current cleanup status and append current outgoing RTC/Chat reliability scope; preserve historical audit sections/results |
| `docs/huawei-rtc-outgoing.md` | Correct obsolete controls/rendering/sharing/foreground-notification scope and device setup; link current guides |
| `lib/src/rtc/huawei_rtc_screen_as_camera.dart` | Dart documentation comments only; remove stale experimental/POC support classification |
| `lib/src/rtc/huawei_rtc_video_view.dart` | Dart documentation comments only; clarify local camera substitution |
| `docs/release-packaging.md` | This report |

Dart executable content in both edited source files is identical to HEAD after
removing documentation-comment lines. No runtime, channel, manifest, Gradle,
dependency version or example UI changes were made. Historical capture POC,
performance, orientation, video-quality and Chat reliability records are
byte-for-byte unchanged. Existing runtime UI/channel labels containing
“Experimental” remain and are explicitly explained in current documentation.

## Source verification — VERIFIED

Reviewed public library exports, core API, Chat/controller/events, notifications,
RTC call/control/video/capture APIs, native channel dispatch, initialization,
Chat activation/JWT bridge, cleanup manager, HMS resource validation, RTC token
provider/services/capture/filter/renderer implementation, Gradle/manifest, example
configuration/launcher/host and relevant tests/docs.

Key source-confirmed integration details:

- Plugin supports Android only; Dart `^3.9.0`, Flutter `>=3.35.7`, minSdk 26,
  compileSdk 36; screen sharing API 29+. Example targetSdk 36, Java target 17,
  AGP 8.13.0/Kotlin 2.1.0/Gradle 8.13. Android 36 Robolectric needs Java 21.
- Huawei MM/Inbox/Chat remain 8.14.0 and RTC Core remains 2.5.28. Official incoming
  calls/RTC UI remain guarded. Core retains existing Firebase/GMS transitives.
- Initialization validates numeric, nonzero host `app_id`. The example parses AGC
  JSON for manifest metadata/`example_huawei_app_id`, but does not create `app_id`
  or apply AGConnect. The checked-in strings contain placeholders. Documentation
  now describes the explicit private host setup; no credentials were supplied.
- Chat activation failure retains initialized MM; same-code initialization retries
  activation after one-second cooldown (`chat_activation_busy` during cooldown).
- Chat JWT provider: 25-second Dart bound, independent 30-second native deadline,
  at most 32 pending requests per side, stale-result rejection; underlying provider
  Futures are not cancellable. MM/Inbox JWTs are separate.
- RTC backend tokens are acquired natively through initialized MM, not hardcoded
  or supplied through Dart. Default identity uses registered installation ID;
  explicit identity requires host/backend authorization. Calls routing is separate
  from RTC push configuration and is not a callee argument.
- Screen → MediaProjection → ImageReader → Bitmap → VideoFilter → RTC replaces
  camera publication; camera stays enabled, no separate screen track exists.
  Fresh consent and foreground capture service/notification Stop are required.
- Stop blocks frame submission; native 3-second deadline and Dart 5-second fallback
  report uncertain termination. Resource flags and camera-submission restoration
  are distinct from peer acknowledgment. Failed release is retryable.
- Capture can continue while backgrounded with attached Activity/OS permission;
  detach, call end or revocation stops it. Changed resize callbacks after the first
  valid report stop sharing; fresh consent is needed to restart.
- Pinned SDK camera path is 640×480, with fit-center black bars and reduced portrait
  text detail. Publication compensation and unmirrored local sharing preview are
  implemented. Conversion scratch/latest-frame/geometry optimizations exist; no
  physical performance improvement is quantified.
- Plugin cleanup clears Dart callbacks after native success, shares concurrent
  cleanup and guards conflicting lifecycle work. Rejection preserves Dart Chat
  registrations. Vendor-internal cleanup does not promise rollback of partial work.

## Security — VERIFIED issue disclosure; release security BLOCKED

Huawei Mobile Messaging 8.14.0 authorization-header logging in its dependency's
`AuthorizationUtils` remains unresolved, as supplied in the task and recorded in
existing SDK investigation evidence. RTC Core logging disablement does not fix it.
No binary patch, reflection bypass, stdout interception, dependency upgrade or
claim of a fix was added. Owner/vendor disposition remains required.

Current docs contain only placeholders and callable backend-provider examples.
Tracked-file checks found no private AGC JSON, signing files, local Dart config,
APK/AAB/AAR or build outputs. Credential-like literal screening identified only
synthetic example test signing fixtures (sequential test bytes). Pub's scanner
reported no sensitive-file warning. This is a scoped local check, not a complete
security audit of dependencies or ignored local credentials.

## Package metadata and LICENSE

**VERIFIED:** package name `infobip_mobilemessaging_huawei`, version **1.0.0**, SDK/
Flutter constraints, Android registration, dependencies, existing repository and
issue URLs and topics remain unchanged. Only the description changed. No
`publish_to` override exists; publishing would use pub's default hosted destination.
No new URL, publisher identity, license or version was invented.

**BLOCKED:** there is no root LICENSE. Dart publication requires one:
[official publishing requirements](https://dart.dev/tools/pub/publishing).
License selection and copyright ownership require code-owner authorization.
Recommendation for owner review: establish provenance/redistribution rights,
review third-party obligations, and authorize a specific license and copyright
statement before adding LICENSE. No license option is selected on the owner's
behalf; no placeholder or copied SDK license was added.

## Package dry-run — BLOCKED

Ran **`flutter pub publish --dry-run`** against a temporary tracked-file snapshot
with the final edited/new release files and ignore rules. Private ignored local
files were not copied. This permits package resolution without overwriting user
configuration, root lockfiles or checkout metadata. No upload/publication occurred.

Final snapshot archive: **1018 KB compressed** (approximately 1 MB).
Result: **exit 65**. One error and one potential issue:

- Error: “You must have a LICENSE file in the root directory.”
- Advisory: rename top-level `docs` to `doc` to follow pub layout conventions.

The existing `docs/` paths and historical records were retained to avoid a broad
rename/link migration. This advisory is disclosed, not hidden. The snapshot has no
Git metadata, so it does not exercise pub's dirty-checkout warning; the real
checkout intentionally retains this task's uncommitted edits.

The archive inventory includes public Dart/Android implementation, manifest/
resources/consumer rules, example source/host, tests and documentation. Git/pub
ignore rules omit credentials, ignored private example launch/config, Flutter/
Gradle output, binaries covered by ignore rules and lockfiles. The Gradle wrapper
JAR is legitimate example tooling, not an SDK binary. Historical text/source audit
evidence remains included so documentation links continue to resolve.

## Documentation and regression checks

Environment: Flutter **3.35.7**, Dart **3.9.2**. No dependency upgrade/fetch of Git
branches or source changes to repair warnings.

| Check | Result | Classification |
| --- | --- | --- |
| Root `flutter test --no-pub` | Exit 0; **229 passed** | VERIFIED |
| Example `flutter test --no-pub` | Exit 0; **42 passed** | VERIFIED |
| Root `flutter analyze --no-pub` | Exit 1; **21 pre-existing info-level deprecated-member notices**, no errors/warnings | VERIFIED baseline limitation |
| Example `flutter analyze --no-pub` | Exit 0; **no issues** | VERIFIED |
| Native `:infobip_mobilemessaging_huawei:testDebugUnitTest --offline`, Java 17 | Exit 1; 306 reported tests, 1 sandbox initialization failure: Android 36 requires Java 21 | VERIFIED environment failure |
| Same complete native task with installed Java 21 | Exit 0; **323 tests, 49 suites, zero failures/errors/skips** | VERIFIED |
| Extracted README/screen-guide Dart blocks | **13 snippet files**, no analyzer issues after suppressing harness-only unused imports/results | VERIFIED static signatures/types |
| Changed Markdown local links | All targets resolve in repository/snapshot | VERIFIED |
| `git diff --check` | Exit 0 | VERIFIED |
| Public source changes | Documentation comments only; non-comment Dart content matches HEAD | VERIFIED |
| Historical screen/Chat audit files | Byte-for-byte equal to HEAD | VERIFIED |
| Credentials/artifacts/package inventory | No private credential/build-file warning; synthetic fixture review only | VERIFIED scoped check |
| Live HMS delivery, Chat JWT acceptance, RTC token/routing/media, projection/notifications/OEM lifecycle | No credentials/hardware used by this task | NOT TESTED / UNVERIFIED |
| Physical screen readability/orientation, GL/JNI races, CPU/memory/frame-rate gains | No hardware measurements | NOT TESTED / UNVERIFIED |
| Release APK/AAB, signing, installation on Huawei, actual pub.dev upload/ownership | Outside this task's executed validation | NOT TESTED |

Initial sandbox test attempts could not write installed Flutter/Gradle caches;
permitted reruns used existing caches. Java 21 native compilation emitted three
existing test-source warnings (unchecked cast, deprecated `isServiceIntent`,
deprecated `addResolveInfoForIntent`) and standard JVM class-sharing warnings.
No test exclusions or SDK/source repairs were used. Unit tests are not device
acceptance evidence. Snippet analysis verifies compilation-level types/signatures,
not authentication or runtime permissions.

## Remaining gates and publication assessment

Publication documentation review, 2026-10-12: the results above remain the
historical packaging record; no builds, tests or dry-run were rerun for this
documentation update. Use the
[current acceptance checklist](final-production-certification.md#20-final-acceptance-checklist)
and [SEC-01 verification record](sec01-release-logging-mitigation.md).

1. **BLOCKED:** owner-authorized LICENSE and redistribution rights.
2. **BLOCKED / PARTIALLY MITIGATED:** upstream authorization-header logging and RTC
   signaling that may expose temporary TURN credentials. Optional host R8 rules
   remove matching print/println calls application-wide, require R8/optimization,
   and do not cover RTC printf or guarantee removal of all sensitive logs. Obtain
   vendor resolution or an evidence-backed owner security disposition. The
   [sanitized Infobip draft](sec01-infobip-responsible-disclosure.md) is prepared,
   not sent; vendor acknowledgment/fix status **UNVERIFIED**.
3. **UNVERIFIED:** physical Huawei/backend acceptance for Push, Chat,
   RTC/rendering/notifications/sharing and lifecycle restoration; use example and
   historical device checklists with sanitized evidence.
4. **VERIFIED advisory:** top-level `docs/` pub layout warning and 21 pre-existing
   analyzer infos remain; neither was hidden or fixed with unrelated runtime edits.
5. **BLOCKED / UNVERIFIED:** release verification. A later SEC-01 optimized example
   APK built successfully but was unsigned; exact signed/minified installation,
   startup, functional regression and sensitive-log verification remain UNVERIFIED.
6. **BLOCKED / UNVERIFIED:** 16 KB compatibility. The later native audit records
   passing LOAD/ZIP checks and nonzero RELRO-end remainders. Vendor/toolchain
   disposition and runtime validation on a real 16 KB environment remain
   UNVERIFIED; the observed Huawei device uses 4 KB pages.
7. **BLOCKED:** pub.dev dry-run readiness. Last recorded dry-run exited 65 for
   missing LICENSE. Final-candidate dry-run, archive inventory and publication
   account/package-name availability remain UNVERIFIED. Rerun after license and
   candidate documentation are finalized; do not publish as part of this task.

**Final assessment: documentation and packaging preparation complete; stable
publication is NO-GO until the license/security, signed-release, device acceptance,
16 KB compatibility and final dry-run gates have owner-reviewed evidence.**
Version/dependencies and runtime behavior are preserved.
