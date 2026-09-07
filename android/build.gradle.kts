plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

group = "com.infobip.mobilemessaging.huawei"
version = "1.0.0"

android {
    namespace = "com.infobip.mobilemessaging.huawei"
    compileSdk = 36

    defaultConfig {
        minSdk = 26
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            // Allow Robolectric to access JDK internals on Java 17 and newer.
            it.jvmArgs(
                "--add-opens=java.base/java.lang=ALL-UNNAMED",
                "--add-opens=java.base/java.util=ALL-UNNAMED",
                "--add-opens=java.base/java.io=ALL-UNNAMED",
                "--add-opens=java.base/java.net=ALL-UNNAMED",
                "--add-opens=java.base/java.security=ALL-UNNAMED",
                "--add-opens=java.base/java.text=ALL-UNNAMED",
                "--add-opens=java.base/jdk.internal.access=ALL-UNNAMED",
                "--add-opens=java.desktop/java.awt.font=ALL-UNNAMED",
                "--add-opens=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED",
            )
        }
    }
}

repositories {
    google()
    mavenCentral()
    maven("https://developer.huawei.com/repo/")
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:5.20.0")
    testImplementation("org.robolectric:robolectric:4.16")
    implementation("com.infobip:infobip-mobile-messaging-huawei-sdk:8.14.0@aar") {
        isTransitive = true
    }
    implementation("com.infobip:infobip-mobile-messaging-huawei-inbox-sdk:8.14.0")
    implementation("com.infobip:infobip-mobile-messaging-huawei-chat-sdk:8.14.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")
    implementation("androidx.fragment:fragment-ktx:1.8.9")

    val webRtcEnabled = providers.gradleProperty("infobipWebRtcEnabled")
        .orNull?.toBooleanStrictOrNull() ?: false
    if (webRtcEnabled) {
        val rtcUiVersion = providers.gradleProperty("infobipRtcUiVersion").orNull
            ?: error(
                "infobipRtcUiVersion is required when infobipWebRtcEnabled=true",
            )
        implementation("com.infobip:infobip-rtc-ui:$rtcUiVersion") {
            exclude(
                group = "com.infobip",
                module = "infobip-mobile-messaging-android-sdk",
            )
        }
    }
}
