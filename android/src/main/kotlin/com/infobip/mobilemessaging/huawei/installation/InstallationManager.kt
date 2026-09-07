package com.infobip.mobilemessaging.huawei.installation

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.infobip.mobile.messaging.Installation
import org.infobip.mobile.messaging.MobileMessaging
import org.infobip.mobile.messaging.mobileapi.MobileMessagingError
import org.infobip.mobile.messaging.mobileapi.Result

internal class InstallationManager(
    context: Context,
    private val isInitialized: () -> Boolean,
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
) {
    private val mobileMessaging by lazy { MobileMessaging.getInstance(context) }

    fun getInstallation(callback: Callback) {
        if (!initialized(callback)) return
        execute("native_error", callback) { complete(callback, mobileMessaging.installation) }
    }

    fun fetchInstallation(callback: Callback) {
        if (!initialized(callback)) return
        execute("installation_fetch_failed", callback) {
            mobileMessaging.fetchInstallation(
                installationListener(
                    callback,
                    "installation_fetch_failed",
                    "Unable to fetch installation",
                ),
            )
        }
    }

    fun saveInstallation(
        payload: Any?,
        callback: Callback,
    ) {
        if (!initialized(callback)) return
        execute("installation_save_failed", callback) {
            val installation = InstallationMapper.applyWritable(mobileMessaging.installation, payload)
            mobileMessaging.saveInstallation(
                installation,
                installationListener(
                    callback,
                    "installation_save_failed",
                    "Unable to save installation",
                ),
            )
        }
    }

    fun depersonalizeInstallation(
        pushRegistrationIdValue: Any?,
        callback: InstallationsCallback,
    ) {
        if (!initializedList(callback)) return
        val pushRegistrationId = validPushRegistrationId(pushRegistrationIdValue, callback) ?: return
        executeList("installation_depersonalization_failed", callback) {
            mobileMessaging.depersonalizeInstallation(
                pushRegistrationId,
                installationsListener(
                    callback,
                    "installation_depersonalization_failed",
                    "Unable to depersonalize installation",
                ),
            )
        }
    }

    fun setInstallationAsPrimary(
        pushRegistrationIdValue: Any?,
        isPrimaryValue: Any?,
        callback: InstallationsCallback,
    ) {
        if (!initializedList(callback)) return
        val pushRegistrationId = validPushRegistrationId(pushRegistrationIdValue, callback) ?: return
        val isPrimary = isPrimaryValue as? Boolean
        if (isPrimary == null) {
            failList(callback, "invalid_argument", "isPrimary must be a boolean")
            return
        }
        executeList("installation_primary_update_failed", callback) {
            mobileMessaging.setInstallationAsPrimary(
                pushRegistrationId,
                isPrimary,
                installationsListener(
                    callback,
                    "installation_primary_update_failed",
                    "Unable to update primary installation",
                ),
            )
        }
    }

    private fun initialized(callback: Callback): Boolean {
        if (isInitialized()) return true
        fail(callback, "not_initialized", "Initialize the Infobip SDK first")
        return false
    }

    private fun initializedList(callback: InstallationsCallback): Boolean {
        if (isInitialized()) return true
        failList(callback, "not_initialized", "Initialize the Infobip SDK first")
        return false
    }

    private fun validPushRegistrationId(
        value: Any?,
        callback: InstallationsCallback,
    ): String? {
        val id = (value as? String)?.trim()
        if (id.isNullOrEmpty()) {
            failList(callback, "invalid_argument", "pushRegistrationId must not be empty")
            return null
        }
        return id
    }

    private fun complete(
        callback: Callback,
        value: Installation,
    ) {
        mainHandler.post { callback(InstallationMapper.toMap(value), null) }
    }

    private fun fail(
        callback: Callback,
        code: String,
        message: String,
    ) {
        mainHandler.post { callback(null, InstallationFailure(code, message)) }
    }

    private fun fail(
        callback: Callback,
        error: MobileMessagingError?,
        fallbackCode: String,
        fallbackMessage: String,
    ) {
        fail(
            callback,
            error?.code?.toString() ?: fallbackCode,
            fallbackMessage,
        )
    }

    private fun installationListener(
        callback: Callback,
        code: String,
        message: String,
    ) = object : MobileMessaging.ResultListener<Installation>() {
        override fun onResult(result: Result<Installation, MobileMessagingError>) {
            val installation = result.data
            if (result.isSuccess && installation != null) {
                complete(callback, installation)
            } else {
                fail(callback, result.error, code, message)
            }
        }
    }

    private fun installationsListener(
        callback: InstallationsCallback,
        code: String,
        message: String,
    ) = object : MobileMessaging.ResultListener<List<Installation>>() {
        override fun onResult(result: Result<List<Installation>, MobileMessagingError>) {
            val installations = result.data
            if (result.isSuccess) {
                mainHandler.post {
                    callback(installations?.map(InstallationMapper::toMap), null)
                }
            } else {
                failList(callback, result.error, code, message)
            }
        }
    }

    private fun failList(
        callback: InstallationsCallback,
        code: String,
        message: String,
    ) {
        mainHandler.post { callback(null, InstallationFailure(code, message)) }
    }

    private fun failList(
        callback: InstallationsCallback,
        error: MobileMessagingError?,
        fallbackCode: String,
        fallbackMessage: String,
    ) {
        val code = error?.code?.toString() ?: fallbackCode
        val message = fallbackMessage
        val details = error?.let { mapOf("code" to code) }
        mainHandler.post { callback(null, InstallationFailure(code, message, details)) }
    }

    private fun executeList(
        code: String,
        callback: InstallationsCallback,
        operation: () -> Unit,
    ) {
        try {
            operation()
        } catch (_: IllegalArgumentException) {
            failList(callback, "invalid_argument", "Invalid installation argument")
        } catch (error: Exception) {
            failList(callback, code, "Installation operation failed")
        }
    }

    private fun execute(
        code: String,
        callback: Callback,
        operation: () -> Unit,
    ) {
        try {
            operation()
        } catch (_: IllegalArgumentException) {
            fail(callback, "invalid_argument", "Invalid installation payload")
        } catch (_: Exception) {
            fail(callback, code, "Installation operation failed")
        }
    }
}

internal typealias Callback = (Map<String, Any?>?, InstallationFailure?) -> Unit
internal typealias InstallationsCallback = (List<Map<String, Any?>>?, InstallationFailure?) -> Unit

internal data class InstallationFailure(
    val code: String,
    val message: String,
    val details: Map<String, Any?>? = null,
)
