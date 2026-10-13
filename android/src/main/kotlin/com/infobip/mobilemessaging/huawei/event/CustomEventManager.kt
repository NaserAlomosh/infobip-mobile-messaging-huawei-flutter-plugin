package com.infobip.mobilemessaging.huawei.event

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.infobip.mobile.messaging.CustomEvent
import org.infobip.mobile.messaging.MobileMessaging
import org.infobip.mobile.messaging.mobileapi.MobileMessagingError
import org.infobip.mobile.messaging.mobileapi.Result

internal class CustomEventManager(
    context: Context,
    private val isInitialized: () -> Boolean,
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
) {
    private val mobileMessaging by lazy { MobileMessaging.getInstance(context) }

    fun submit(
        value: Any?,
        callback: Callback,
    ) {
        if (!initialized(callback)) return
        execute(callback) {
            mobileMessaging.submitEvent(CustomEventMapper.fromMap(value))
            mainHandler.post { callback(null, null) }
        }
    }

    fun submitImmediately(
        value: Any?,
        callback: Callback,
    ) {
        if (!initialized(callback)) return
        execute(callback) {
            mobileMessaging.submitEvent(
                CustomEventMapper.fromMap(value),
                object : MobileMessaging.ResultListener<CustomEvent>() {
                    override fun onResult(result: Result<CustomEvent, MobileMessagingError>) {
                        val event = result.data
                        if (result.isSuccess && event != null) {
                            mainHandler.post { callback(CustomEventMapper.toMap(event), null) }
                        } else {
                            fail(
                                callback,
                                result.error,
                                "custom_event_submission_failed",
                                "Unable to submit custom event",
                            )
                        }
                    }
                },
            )
        }
    }

    private fun initialized(callback: Callback): Boolean {
        if (isInitialized()) return true
        fail(callback, null, "not_initialized", "Initialize the Infobip SDK first")
        return false
    }

    private fun execute(
        callback: Callback,
        operation: () -> Unit,
    ) {
        try {
            operation()
        } catch (error: IllegalArgumentException) {
            mainHandler.post {
                callback(null, CustomEventFailure("invalid_argument", error.message ?: "Invalid custom event"))
            }
        } catch (error: Exception) {
            mainHandler.post {
                callback(
                    null,
                    CustomEventFailure(
                        "custom_event_submission_failed",
                        error.message ?: "Unable to submit custom event",
                    ),
                )
            }
        }
    }

    private fun fail(
        callback: Callback,
        error: MobileMessagingError?,
        fallbackCode: String,
        fallbackMessage: String,
    ) {
        val code = error?.code?.toString() ?: fallbackCode
        val message = error?.message ?: fallbackMessage
        val details = error?.let { mapOf("code" to code, "message" to message) }
        mainHandler.post { callback(null, CustomEventFailure(code, message, details)) }
    }
}

internal typealias Callback = (Map<String, Any?>?, CustomEventFailure?) -> Unit

internal data class CustomEventFailure(
    val code: String,
    val message: String,
    val details: Map<String, Any?>? = null,
)
