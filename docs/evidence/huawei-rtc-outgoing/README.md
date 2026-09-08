# Outgoing implementation evidence

These probes inspect **actual** example app runtime configurations after adding
RTC Core, unlike the earlier isolated candidate research probe. They never add,
exclude or substitute a dependency. No vendor binaries, local artifact paths,
application credentials, tokens or APKs are committed.

From `example/android`:

```sh
./gradlew -I ../../docs/evidence/huawei-rtc-outgoing/resolve.gradle \
  -PrtcEvidenceOutput=/private/tmp/huawei-rtc-outgoing \
  :app:rtcRuntimeDebug :app:rtcRuntimeRelease \
  :app:dependencies --configuration debugRuntimeClasspath --console=plain
./gradlew :app:dependencies --configuration releaseRuntimeClasspath --console=plain
```

From the repository root:

```sh
python3 docs/evidence/huawei-rtc-outgoing/inspect_artifacts.py \
  /private/tmp/huawei-rtc-outgoing
```

The Gradle inventory captures external Maven artifacts and the actual compiled
plugin runtime JAR for each variant. The Python scanner deduplicates identical
artifact paths and opens `classes.jar`, embedded `libs/*.jar`, external JARs and
the plugin JAR. Run Python without `-O` so its dependency/class assertions execute.
Local TSVs stay in the temporary directory because they include absolute paths.

The committed dependency trees are the `:app:dependencies` portions of the
successful output, with configuration chatter and local paths omitted. The
committed scan output contains resolved coordinates, counts and the Core AAR hash.
An additional scan after the final build confirmed the same graph/class findings.

`api-evidence.txt` contains fresh `javap -public -classpath <classes.jar> <classes>`
output from the **resolved** Core 2.5.28 AAR, Huawei 8.14.0 AAR and shared API 15.1.0
JAR. The named classes cover the singleton, request, options/builder, application
call, event listener/status/reasons and Huawei token service/body/response/provider.
Extract `classes.jar` from each AAR into a temporary directory to reproduce it.
No classes are instantiated by this probe. The earlier research already contains
the relevant Core bytecode; implementation-time bytecode checks additionally
confirmed permission validation, Core call assignment before signaling, public
listener replacement, hangup and terminal cleanup behavior.

Unit tests mock native/network boundaries. Actual native callback wiring and
outgoing media still require Huawei device/backend validation. Full executed
commands, test counts, limitations and status labels are in
[the verification report](../../huawei-rtc-outgoing-verification.md).
