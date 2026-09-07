package com.infobip.mobilemessaging.huawei.core

import android.content.Context

internal object HmsConfiguration {
    fun appId(context: Context): String? {
        // Huawei 8.14 MobileMessaging.Builder.loadSenderId uses this host-owned resource.
        val resource = context.resources.getIdentifier("app_id", "string", context.packageName)
        return if (resource == 0) null else validAppId(context.getString(resource))
    }

    internal fun validAppId(value: String?): String? =
        value?.takeIf { it.matches(Regex("[0-9]+")) && it.any { digit -> digit != '0' } }

    fun failure() = InitializationError(
        "hms_configuration_missing",
        "Provide the host application's Huawei App ID in the app_id string resource",
    )
}
