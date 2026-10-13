package com.infobip.mobilemessaging.huawei.core

import android.content.Context
import org.infobip.mobile.messaging.JwtSupplier
import org.infobip.mobile.messaging.MobileMessaging

internal class CleanupManager private constructor(
    private val isInitialized: () -> Boolean,
    private val clearPluginJwtState: () -> Unit,
    private val clearSdkJwtSupplier: () -> Unit,
    private val cleanupSdk: () -> Unit,
    private val resetPluginState: () -> Unit,
) {
    constructor(
        context: Context,
        isInitialized: () -> Boolean,
        clearPluginJwtState: () -> Unit,
        resetPluginState: () -> Unit,
    ) : this(
        isInitialized = isInitialized,
        clearPluginJwtState = clearPluginJwtState,
        clearSdkJwtSupplier = {
            MobileMessaging.getInstance(context).setJwtSupplier(JwtSupplier { null })
        },
        cleanupSdk = { MobileMessaging.getInstance(context).cleanup() },
        resetPluginState = resetPluginState,
    )

    fun cleanup(): InitializationError? {
        if (!isInitialized()) {
            return InitializationError("not_initialized", "Initialize the Infobip SDK first")
        }
        return try {
            // Do not destroy plugin callbacks if the SDK rejects/throws. The SDK's
            // internal cleanup itself is not rollback-capable.
            cleanupSdk()
            clearPluginJwtState()
            clearSdkJwtSupplier()
            resetPluginState()
            null
        } catch (_: Exception) {
            InitializationError("native_error", "Unable to clean up the Infobip SDK")
        }
    }

    internal companion object {
        fun forTesting(
            isInitialized: () -> Boolean,
            clearPluginJwtState: () -> Unit,
            clearSdkJwtSupplier: () -> Unit,
            cleanupSdk: () -> Unit,
            resetPluginState: () -> Unit,
        ) = CleanupManager(
            isInitialized,
            clearPluginJwtState,
            clearSdkJwtSupplier,
            cleanupSdk,
            resetPluginState,
        )
    }
}
