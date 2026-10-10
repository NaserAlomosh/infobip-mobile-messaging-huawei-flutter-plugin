plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val agcFile = file("agconnect-services.json")
val huaweiAppId = if (agcFile.exists()) {
    val agc = groovy.json.JsonSlurper().parse(agcFile) as Map<*, *>
    val client = agc["client"] as? Map<*, *>
    client?.get("app_id")?.toString().orEmpty()
} else ""

android {
    namespace = "com.infobip.mobilemessaging.huawei.example"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.infobip.mobilemessaging.huawei.example"
        minSdk = 26
        targetSdk = 36
        manifestPlaceholders["huaweiAppId"] = "appid=$huaweiAppId"
        resValue("string", "example_huawei_app_id", huaweiAppId)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.5",
    )
}

flutter {
    source = "../.."
}