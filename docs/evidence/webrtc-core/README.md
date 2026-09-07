# Reproducing the dependency research

These are inspection probes, not an RTC integration. They do not modify the app's
compile/runtime configurations, turn on `infobipWebRtcEnabled`, register an account,
or place a call. `CoreApiProbe.java` is outside Android source sets and is never
packaged. No vendor binaries are redistributed here.

From `example/android`, with the repository's normal Flutter/Android toolchain:

```sh
./gradlew -I ../../docs/evidence/webrtc-core/resolve.gradle \
  -PrtcResearchOutput=/private/tmp/huawei-rtc-core-research \
  :app:rtcCoreResearchDebug :app:rtcCoreResearchRelease --console=plain
```

The output contains four TSV inventories of actual external Maven artifacts:
baseline/candidate, debug/release. The candidate extends each host runtime graph
in its own resolvable configuration, adding only
`com.infobip:infobip-rtc:2.5.28@aar` with transitives enabled. Local project
artifacts are excluded from the artifact view, not from dependency traversal.
The six repeated artifact file references are deduplicated by resolved path in
the scan; they are not counted as six extra packaged libraries.

From the repository root:

```sh
python3 docs/evidence/webrtc-core/inspect_artifacts.py \
  /private/tmp/huawei-rtc-core-research
```

Use optional repeated `--aar /absolute/path/to/infobip-rtc-VERSION.aar` arguments
to record SHA-256 and verify that each Core archive has no Mobile Messaging class
definitions. The recorded run supplied the inspected 2.5.20, 2.5.28, and 2.5.41
AARs. The scanner fails on missing/unsafe expected dependencies or duplicate MM
classes. Run Python normally, without `-O`, so its assertions are enabled.

To reproduce a graph, use the same init script and run
`:app:dependencies --configuration releaseRuntimeClasspath` for baseline or
`:app:dependencies --configuration rtcCoreResearchRelease` for the candidate.
The checked-in text graphs start at that task's output; local configuration
chatter and machine paths were removed. Debug and release artifact inventories
were both checked; only the full release graphs are retained here.

`api-evidence.txt` records actual `javap -public` interfaces and `javap -c -p`
method excerpts from the AARs' `classes.jar`, plus Huawei token-service symbols
and Chat hook absence checks. `dependency-evidence.txt` records the executed scan
and artifact hashes. Neither output demonstrates backend or device behavior.

For the compile-only Java probe, extract `classes.jar` and embedded `libs/*.jar`
from the resolved candidate AARs into a temporary directory. Compile
`CoreApiProbe.java` using `javac -source 17 -target 17`, with those JARs, the
resolved external JARs and Android 36's `android.jar` on the classpath. The run
returned exit 0. The probe is never instantiated; its token and configuration
values are method parameters with no real values supplied.

The original ephemeral probe had two Gradle selection errors and one Java checked
exception error, as recorded in the main report. The committed Gradle/Python
probes and Java source contain the corrections. The committed Gradle probe and
Python assertions were rerun successfully before delivery.
