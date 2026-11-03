# Robolectric CI runtime resolution investigation

> **Historical engineering report.** This records the 2026-11-02 runtime-download investigation; its uncommitted status describes that snapshot, and the original CI root cause remains unconfirmed.
> Use the [current contributor validation procedure](../CONTRIBUTING.md#formatting-and-validation) for maintained guidance.
> Results, test counts and conclusions below belong to the recorded baseline;
> this notice adds no new validation or certification.

Date: 2026-11-02. Changes are intentionally uncommitted.

## Evidence and limits

Investigated [CI run 41408940475](https://github.com/NaserAlomosh/infobip-mobile-messaging-huawei-flutter-plugin/actions/runs/41408940475),
job `125157280566`, PR #92, head `17b2024aaebf4d946889a31020e392db6e7c388e`,
tested merge `c62dc76f89ab7157e6a1a8eeeb5eab5ac18447de`.
The Ubuntu 26.04 runner used Temurin 21 and restored the Gradle dependency cache.
Compilation and Gradle dependency resolution succeeded. Debug reported 194 test
entries, 24 failed; Release did not run. Failed entries were `classMethod`
initialization failures across 24 classes, rather than assertion failures in
24 individual test methods.

The complete available job log contains only this abbreviated exception chain:

```text
java.lang.AssertionError at MavenArtifactFetcher.java:129
    Caused by: java.util.concurrent.ExecutionException at AbstractFuture.java:292
        Caused by: java.io.IOException at HttpURLConnection.java:2034
```

The run has **zero retained artifacts**. The workflow did not upload XML or
HTML reports. The runner-local HTML report URL in the log is not downloadable
after job teardown. Thus the original full exception, HTTP status, exact requested
URL, and failing POM/JAR/checksum cannot be recovered from this run's retained
evidence. Claiming a specific 403, 429, timeout, DNS error, or corrupt cache would
be unsupported. The 170 remaining entries were not reported failed; exact CI
passed/skipped counts require XML and cannot be established from that summary.

## Resolution behavior

The project uses Robolectric 4.16. Its
[MavenRoboSettings](https://github.com/robolectric/robolectric/blob/robolectric-4.16/plugins/maven-dependency-resolver/src/main/java/org/robolectric/MavenRoboSettings.java)
defaults to `https://repo1.maven.org/maven2`.
Its [MavenDependencyResolver](https://github.com/robolectric/robolectric/blob/robolectric-4.16/plugins/maven-dependency-resolver/src/main/java/org/robolectric/internal/dependency/MavenDependencyResolver.java)
uses a separate local Maven repository (`maven.repo.local`, settings.xml, or
`~/.m2/repository`), independent of Gradle's `repositories` and dependency cache.
Its [MavenArtifactFetcher](https://github.com/robolectric/robolectric/blob/robolectric-4.16/plugins/maven-dependency-resolver/src/main/java/org/robolectric/internal/dependency/MavenArtifactFetcher.java)
downloads JAR, POM, and both SHA-512 files, verifies checksums, and wraps failed
fetches at line 129. That line alone cannot identify which download failed.

Local `~/.m2/repository` already contained all eight required runtime versions.
The CI Gradle cache restoration listed `.gradle` paths, not `.m2`. Installing
Android SDK platforms with sdkmanager does not populate Robolectric runtimes.
This explains why local cached success does not establish CI download success.

The [4.16 SDK mapping](https://github.com/robolectric/robolectric/blob/robolectric-4.16/robolectric/src/main/java/org/robolectric/plugins/DefaultSdkProvider.java)
and unchanged test annotations require these `org.robolectric:android-all-instrumented` versions:

| API | Version |
| --- | --- |
| 26 | `8.0.0_r4-robolectric-r1-i7` |
| 28 | `9-robolectric-4913185-2-i7` |
| 30 | `11-robolectric-6757853-i7` |
| 31 | `12-robolectric-7732740-i7` |
| 33 | `13-robolectric-9030017-i7` |
| 34 | `14-robolectric-10818077-i7` |
| 35 | `15-robolectric-13954326-i7` |
| 36 | `16-robolectric-13921718-i7` |

All affected classes use API 28 at class level, so the leading candidate is
`org.robolectric:android-all-instrumented:9-robolectric-4913185-2-i7`.
This is an inference, not an artifact name recovered from the CI exception.
Its default base URL is:

```text
https://repo1.maven.org/maven2/org/robolectric/android-all-instrumented/9-robolectric-4913185-2-i7/android-all-instrumented-9-robolectric-4913185-2-i7
```

Possible requested suffixes are `.pom`, `.jar`, `.pom.sha512`, `.jar.sha512`.
Both Maven Central endpoints returned HTTP 200 for this POM during local checks.
This does not establish their responses from the failed GitHub runner.

## Changes and safety

- `android/build.gradle.kts`: explicitly select
  `https://repo.maven.apache.org/maven2` in every native unit-test JVM, matching
  the endpoint used by Gradle's `mavenCentral()`. Enable full exception logging.
  This is a provisional endpoint mitigation, not proof of the original cause.
- `.github/workflows/ci.yml`: upload native XML and HTML reports with `always()`,
  including after test failure, retained for seven days. No other workflow changes.

The repository setting reaches the forked test JVM directly; setting a Gradle
daemon property alone would not guarantee this. Artifact coordinates, checksum
validation, SDK coverage, tests, assertions, tool versions, and production code
are unchanged. There are no retries, failure suppression, or cache prerequisites.
The selected endpoint is deterministic; external service availability is not.

## Local validation

JDK 21, existing Gradle/toolchain dependencies, separate initially absent
Robolectric Maven repositories. This was a clean **runtime artifact cache** test,
not a clean operating system or Gradle dependency cache test.

| Configuration | Passed | Failed/errors | Skipped |
| --- | ---: | ---: | ---: |
| Original endpoint, fresh runtime cache, Debug | 431 | 0 | 0 |
| Explicit endpoint, second fresh runtime cache, Debug | 431 | 0 | 0 |
| Explicit endpoint, same second cache, Release | 431 | 0 | 0 |

Counts were summed from all 56 `TEST-*.xml` suites per variant after completion.
Both test tasks executed (not UP-TO-DATE); compilation inputs were reused for the
second run. The original Debug invocation used `--rerun-tasks`. The configured
Debug/Release invocation used a temporary init script to force test execution:

```groovy
allprojects {
    tasks.withType(Test).configureEach {
        systemProperty 'maven.repo.local', '/private/tmp/robolectric-cold-fixed'
        outputs.upToDateWhen { false }
    }
}
```

The directory above did not exist before invocation. From `example/android`:

```sh
JAVA_HOME=/Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home \
  ./gradlew :infobip_mobilemessaging_huawei:testDebugUnitTest \
  :infobip_mobilemessaging_huawei:testReleaseUnitTest --console=plain \
  --init-script /private/tmp/robolectric-fixed-cold.gradle
```

The script above was saved at that init-script path. Baseline used a different
empty path, `/private/tmp/robolectric-cold-original`, before the build-file change.
Both runs downloaded all eight SDK JARs plus POMs and SHA-512 files.
Independent checksum recomputation matched all 16 JAR/POM files in each cache.
Local logs remain at `/private/tmp/robolectric-original.log` and
`/private/tmp/robolectric-fixed.log`; baseline XML was preserved at
`/private/tmp/robolectric-original-xml`. Configured-endpoint XML/HTML is under
`example/build/infobip_mobilemessaging_huawei/{test-results,reports/tests}`.

Workflow YAML syntax parsed successfully with Ruby YAML; `git diff --check`
passed. No production source, test source, assertions, or dependency versions changed.

## Required GitHub Actions verification

Run this change through the existing CI workflow. Confirm Debug and Release
complete, inspect uploaded XML for exact counts and zero initialization failures.
If failure recurs, inspect the complete nested exception and `system-err` in the
uploaded XML for the actual coordinate, URL, HTTP status, and checksum/network
message before choosing any further change. Do not infer these from line 129.

The original root cause remains unconfirmed because the required historical
exception evidence was not retained. No push, PR, or remote rerun was performed.

**Final verdict: NEEDS CHANGES** — the mitigation passes local validation, but the
requested evidence-based CI root-cause conclusion requires the full exception
from a reproducing run (or an independently saved copy of the original XML).
