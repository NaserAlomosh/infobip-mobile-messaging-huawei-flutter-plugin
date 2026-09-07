package com.infobip.mobilemessaging.huawei.user

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.infobip.mobile.messaging.MobileMessaging
import org.infobip.mobile.messaging.SuccessPending
import org.infobip.mobile.messaging.User
import org.infobip.mobile.messaging.UserAttributes
import org.infobip.mobile.messaging.UserIdentity
import org.infobip.mobile.messaging.mobileapi.MobileMessagingError
import org.infobip.mobile.messaging.mobileapi.Result

internal class UserManager(
    context: Context,
    private val isInitialized: () -> Boolean,
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
) {
    private val mobileMessaging by lazy { MobileMessaging.getInstance(context) }

    fun getUser(callback: (Map<String, Any?>?, UserFailure?) -> Unit) {
        if (!initialized(callback)) return
        execute("native_error", callback) {
            val user = mobileMessaging.user
            if (user == null) {
                mainHandler.post { callback(emptyMap(), null) }
            } else {
                complete(callback, user)
            }
        }
    }

    fun fetchUser(callback: (Map<String, Any?>?, UserFailure?) -> Unit) {
        if (!initialized(callback)) return
        execute("user_fetch_failed", callback) {
            mobileMessaging.fetchUser(userListener(callback, "user_fetch_failed", "Unable to fetch user"))
        }
    }

    fun saveUser(
        value: Any?,
        callback: (Map<String, Any?>?, UserFailure?) -> Unit,
    ) {
        if (!initialized(callback)) return
        execute("invalid_argument", callback) {
            val user = UserMapper.toUser(value)
            mobileMessaging.saveUser(
                user,
                userListener(callback, "user_save_failed", "Unable to save user"),
            )
        }
    }

    fun personalize(
        identityValue: Any?,
        attributesValue: Any?,
        forceDepersonalize: Boolean,
        callback: (Map<String, Any?>?, UserFailure?) -> Unit,
    ) {
        if (!initialized(callback)) return
        execute("invalid_argument", callback) {
            val identity: UserIdentity = UserMapper.toIdentity(identityValue)
            val attributes: UserAttributes? = UserMapper.toAttributes(attributesValue)
            val listener =
                userListener(
                    callback,
                    "personalization_failed",
                    "Unable to personalize user",
                )
            mobileMessaging.personalize(identity, attributes, forceDepersonalize, listener)
        }
    }

    fun depersonalize(callback: (Map<String, Any?>?, UserFailure?) -> Unit) {
        if (!initialized(callback)) return
        execute("depersonalization_failed", callback) {
            mobileMessaging.depersonalize(
                object : MobileMessaging.ResultListener<SuccessPending>() {
                    override fun onResult(result: Result<SuccessPending, MobileMessagingError>) {
                        if (result.isSuccess) {
                            mainHandler.post { callback(emptyMap(), null) }
                        } else {
                            fail(
                                callback,
                                result.error,
                                "depersonalization_failed",
                                "Unable to depersonalize user",
                            )
                        }
                    }
                },
            )
        }
    }

    private fun initialized(callback: (Map<String, Any?>?, UserFailure?) -> Unit): Boolean {
        if (isInitialized()) return true
        fail(callback, "not_initialized", "Initialize the Infobip SDK first")
        return false
    }

    private fun complete(
        callback: (Map<String, Any?>?, UserFailure?) -> Unit,
        user: org.infobip.mobile.messaging.User,
    ) {
        mainHandler.post { callback(UserMapper.toMap(user), null) }
    }

    private fun fail(
        callback: (Map<String, Any?>?, UserFailure?) -> Unit,
        code: String,
        message: String,
    ) {
        mainHandler.post { callback(null, UserFailure(code, message)) }
    }

    private fun fail(
        callback: (Map<String, Any?>?, UserFailure?) -> Unit,
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

    private fun userListener(
        callback: (Map<String, Any?>?, UserFailure?) -> Unit,
        code: String,
        message: String,
    ) = object : MobileMessaging.ResultListener<User>() {
        override fun onResult(result: Result<User, MobileMessagingError>) {
            val user = result.data
            if (result.isSuccess && user != null) {
                complete(callback, user)
            } else {
                fail(callback, result.error, code, message)
            }
        }
    }

    private fun execute(
        code: String,
        callback: (Map<String, Any?>?, UserFailure?) -> Unit,
        operation: () -> Unit,
    ) {
        try {
            operation()
        } catch (_: IllegalArgumentException) {
            fail(callback, "invalid_argument", "Invalid user payload")
        } catch (_: Exception) {
            fail(callback, code, "User operation failed")
        }
    }
}

internal data class UserFailure(
    val code: String,
    val message: String,
)
