package com.infobip.mobilemessaging.huawei.inbox

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.infobip.mobile.messaging.JwtSupplier
import org.infobip.mobile.messaging.MobileMessaging
import org.infobip.mobile.messaging.inbox.Inbox
import org.infobip.mobile.messaging.inbox.MobileInbox
import org.infobip.mobile.messaging.mobileapi.MobileMessagingError
import org.infobip.mobile.messaging.mobileapi.Result

internal class InboxManager(
    context: Context,
    private val isInitialized: () -> Boolean,
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
) {
    private val mobileInbox by lazy { MobileInbox.getInstance(context) }
    private val mobileMessaging by lazy { MobileMessaging.getInstance(context) }
    @Volatile
    private var jwt: String? = null

    fun setJwt(value: Any?) {
        if (value != null && value !is String) {
            throw IllegalArgumentException("jwt must be a string or null")
        }
        jwt = (value as? String)?.trim()?.takeIf { it.isNotEmpty() }
        mobileMessaging.setJwtSupplier(JwtSupplier { jwt })
    }

    fun clearJwtState() {
        jwt = null
    }

    fun fetch(
        externalUserIdValue: Any?,
        jwtValue: Any?,
        optionsValue: Any?,
        callback: InboxCallback,
    ) {
        if (!initialized(callback)) return
        try {
            val externalUserId = InboxMapper.requiredExternalUserId(externalUserIdValue)
            val options = InboxMapper.nativeOptions(InboxMapper.parseOptions(optionsValue))
            if (jwtValue != null && jwtValue !is String) {
                throw IllegalArgumentException("jwt must be a string or null")
            }
            val explicitJwt = (jwtValue as? String)?.trim()?.takeIf { it.isNotEmpty() }
            val token = explicitJwt ?: jwt
            val listener = inboxListener(callback)
            if (token == null) {
                mobileInbox.fetchInbox(externalUserId, options, listener)
            } else {
                mobileInbox.fetchInbox(token, externalUserId, options, listener)
            }
        } catch (_: IllegalArgumentException) {
            fail(callback, "invalid_argument", "Invalid Inbox arguments")
        } catch (_: Exception) {
            fail(callback, "inbox_fetch_failed", "Unable to fetch Inbox")
        }
    }

    fun setSeen(
        externalUserIdValue: Any?,
        idsValue: Any?,
        callback: InboxCallback,
    ) {
        if (!initialized(callback)) return
        try {
            val externalUserId = InboxMapper.requiredExternalUserId(externalUserIdValue)
            val ids = InboxMapper.messageIds(idsValue).toTypedArray()
            mobileInbox.setSeen(
                externalUserId,
                ids,
                object : MobileMessaging.ResultListener<Array<String>>() {
                    override fun onResult(result: Result<Array<String>, MobileMessagingError>) {
                        if (result.isSuccess) {
                            complete(callback, null)
                        } else {
                            fail(
                                callback,
                                result.error,
                                "inbox_update_failed",
                                "Unable to update Inbox",
                            )
                        }
                    }
                },
            )
        } catch (_: IllegalArgumentException) {
            fail(callback, "invalid_argument", "Invalid Inbox arguments")
        } catch (_: Exception) {
            fail(callback, "inbox_update_failed", "Unable to update Inbox")
        }
    }

    private fun inboxListener(callback: InboxCallback) =
        object : MobileMessaging.ResultListener<Inbox>() {
            override fun onResult(result: Result<Inbox, MobileMessagingError>) {
                val inbox = result.data
                if (result.isSuccess) {
                    complete(callback, InboxMapper.inbox(inbox))
                } else {
                    fail(
                        callback,
                        result.error,
                        "inbox_fetch_failed",
                        "Unable to fetch Inbox",
                    )
                }
            }
        }

    private fun initialized(callback: InboxCallback): Boolean {
        if (isInitialized()) return true
        fail(callback, "not_initialized", "Initialize the Infobip SDK first")
        return false
    }

    private fun complete(
        callback: InboxCallback,
        value: Map<String, Any?>?,
    ) {
        mainHandler.post { callback(value, null) }
    }

    private fun fail(
        callback: InboxCallback,
        code: String,
        message: String,
    ) {
        mainHandler.post { callback(null, InboxFailure(code, message)) }
    }

    private fun fail(
        callback: InboxCallback,
        error: MobileMessagingError?,
        fallbackCode: String,
        fallbackMessage: String,
    ) {
        fail(
            callback,
            error?.code?.toString() ?: fallbackCode,
            error?.message ?: fallbackMessage,
        )
    }
}

internal typealias InboxCallback = (Map<String, Any?>?, InboxFailure?) -> Unit

internal data class InboxFailure(
    val code: String,
    val message: String,
)
