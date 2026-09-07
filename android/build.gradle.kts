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
}

repositories {
    google()
    mavenCentral()
    maven("https://developer.huawei.com/repo/")
}

dependencies {
    testImplementation("junit:junit:4.13.2")
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
        implementation("com.infobip:infobip-rtc-ui:$rtcUiVersion")
    }
}
