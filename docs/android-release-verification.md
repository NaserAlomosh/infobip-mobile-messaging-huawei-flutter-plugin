# Huawei 8.14 release dependency assessment

This assessment fixes GRADLE-04 from audit commit `c13833fcf6adcda61a504cf01ecb856ec54e4a86`.
It applies to the pinned Huawei 8.14.0 dependency graph, not arbitrary future SDK versions.

The baseline `:app:assembleRelease` reproduced 16 missing-class diagnostics and an absent
`app/proguard-rules.pro`. The library now exports exact class rules through
`android/consumer-rules.pro`; the example supplies the expected application rules file.
No blanket warning suppression, new analytics dependency, crypto provider, or standard
Mobile Messaging Android core was added.

## Missing-class classification

The evidence is the published Huawei AAR bytecode (`javap -p -c`), including exception tables,
class-presence checks, and fallback branches. Every suppressed class is listed below.

| Missing class | Classification | Native evidence and consequence |
| --- | --- | --- |
| `com.huawei.android.os.BuildEx$VERSION` | C: optional OEM platform API | `EmuiUtil.isUpPVersion` checks both BuildEx classes via `ReflectionUtils.checkCompatible` and catches `Throwable`; returns false when absent. |
| `com.huawei.android.telephony.ServiceStateEx` | B: guarded OEM API | `NetworkUtil.getHwNetworkType` checks EMUI presence/version and catches `NoClassDefFoundError`, returning the standard fallback result. |
| `com.huawei.libcore.io.ExternalStorageFile` | C: optional OEM platform API | `CreateFileUtil.newFile` checks EMUI and class presence; falls back to `java.io.File`. |
| `com.huawei.libcore.io.ExternalStorageFileInputStream` | C: optional OEM platform API | `newFileInputStream` checks presence before construction; falls back to Java input stream. |
| `com.huawei.libcore.io.ExternalStorageFileOutputStream` | C: optional OEM platform API | `newFileOutputStream` checks presence before construction; falls back to Java output stream. |
| `com.huawei.libcore.io.ExternalStorageRandomAccessFile` | C: optional OEM platform API | `newRandomAccessFile` checks presence before construction; falls back to Java random-access file. |
| `com.huawei.hianalytics.process.HiAnalyticsConfig` | B: optional full analytics | `HMSBIInitializer` selects bundled `hatool` through `com.huawei.hms.stats.c.a()`; full analytics construction is in the other branch. |
| `com.huawei.hianalytics.process.HiAnalyticsConfig$Builder` | B: optional full analytics | Same guarded construction branch. |
| `com.huawei.hianalytics.process.HiAnalyticsInstance` | B: optional full analytics | `stats.c.a()` probes with `Class.forName`. `HianalyticsHelper` separately catches `Throwable` from its availability probe and guards reporting. |
| `com.huawei.hianalytics.process.HiAnalyticsInstance$Builder` | B: optional full analytics | Same guarded construction branch. |
| `com.huawei.hianalytics.process.HiAnalyticsManager` | B: optional full analytics | Initialization/reporting branches use the same capability result; Network Kit has an independent guarded probe. |
| `com.huawei.hianalytics.util.HiAnalyticTools` | B: optional full analytics | `HiAnalyticsUtils.enableLog(Context)` calls it only when full analytics is selected; otherwise uses bundled `HmsHiAnalyticsUtils`. |
| `org.bouncycastle.crypto.BlockCipher` | B: optional crypto implementation | `EncryptUtil`'s BC flag defaults false. Its optional CTR generator catches linkage failures and returns the already-created JCA `SecureRandom`. |
| `org.bouncycastle.crypto.engines.AESEngine` | B: optional crypto implementation | Same optional generator and linkage-safe JCA fallback. |
| `org.bouncycastle.crypto.prng.SP800SecureRandom` | B: optional crypto implementation | Same optional generator and linkage-safe JCA fallback. |
| `org.bouncycastle.crypto.prng.SP800SecureRandomBuilder` | B: optional crypto implementation | Same optional generator and linkage-safe JCA fallback. The plugin never enables the BC flag. |

The missing example rules file is classification D (host packaging defect). None of the
16 missing references is a required baseline runtime dependency (classification A).
Applications that explicitly require Huawei's BC-specific generator must provide their own
compatible BC dependency; these rules do not provide that implementation.

## Reproducible binary evidence

Extract `classes.jar` from these artifacts in Huawei's Maven repository and inspect the
methods named above. SHA-256 values refer to the extracted `classes.jar`:

| Artifact | SHA-256 |
| --- | --- |
| `com.huawei.hms:network-framework-compat:6.0.2.300` | `9651a995e0069b94b2f5771b5db0b86bf5316a1a39322a03fedf6baa996e09d2` |
| `com.huawei.hms:network-common:6.0.2.300` | `07168bfa644b32293c19baf0365d16679d8ae7580a5660967c7ba442a48c0664` |
| `com.huawei.hms:base:6.6.0.300` | `0ce798c0364e89cfce75c78a4643476c5a09b7a37688adb8c4ced5bf7fb3dd9f` |
| `com.huawei.hms:stats:6.6.0.300` | `b863d5af3f095ea53864876369a60ca95855cee2daa6375c4fa2dd8df0347a00` |
| `com.huawei.android.hms:security-encrypt:1.1.5.310` | `4ecffc564d0abd9b4c441d636aae43f461eb1df0ec2f0a6b84de589c98f9b865` |

`HuaweiOptionalDependencyTest` inspects the actual resolved class bytecode without linking
optional classes: OEM capability probes and Java IO fallback calls, analytics capability
checks and the hatool alternative, and exception-table coverage of every BC instruction.
HotSpot eagerly verifies optional OEM classes and Robolectric brings its own BC classes,
so these JVM tests do not claim to execute Android's missing-dependency paths. Those paths
were assessed from the published bytecode. The minified release build is the R8 regression
check. Device validation remains necessary; a build does not prove push, chat or backend behavior.
