package com.infobip.mobilemessaging.huawei.chat

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.infobip.mobile.messaging.chat.InAppChat

internal data class ChatFailure(
    val code: String,
    val message: String,
)

internal class ChatManager(
    context: Context,
    private val initialized: () -> Boolean,
    requestDartJwt: () -> Boolean = { false },
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
) {
    private val applicationContext = context.applicationContext
    private val inAppChat by lazy { InAppChat.getInstance(applicationContext) }
    private val operations by lazy { ChatOperations.from(inAppChat) }
    private val jwtBridge = ChatJwtBridge(requestDartJwt)
    @Volatile
    private var activated = false

    @Synchronized
    fun activate(): ChatFailure? {
        if (activated) return null
        Log.d(TAG, "InAppChat activation started")
        return try {
            inAppChat.activate()
            activated = true
            Log.d(TAG, "InAppChat activation succeeded")
            null
        } catch (error: Exception) {
            Log.e(TAG, "InAppChat activation failed", error)
            ChatFailure("chat_unavailable", "Chat activation failed")
        }
    }

    @Synchronized
    fun attach(): ChatFailure? {
        if (!initialized()) return ChatFailure("not_initialized", "Initialize the Infobip SDK first")
        if (!activated) return ChatFailure("chat_unavailable", "Chat is not activated")
        return null
    }

    fun instance(): InAppChat = inAppChat

    fun getUnreadMessageCount(callback: (Int?, ChatFailure?) -> Unit) {
        val failure = attach()
        if (failure != null) {
            callback(null, failure)
            return
        }
        try {
            val count = operations.getMessageCounter()
            if (count < 0) {
                callback(null, ChatFailure("native_error", "Unable to read Chat unread message count"))
            } else {
                callback(count, null)
            }
        } catch (_: Exception) {
            callback(null, ChatFailure("native_error", "Unable to read Chat unread message count"))
        }
    }

    fun isChatAvailable(callback: (Boolean?, ChatFailure?) -> Unit) = execute(
        "Unable to read Chat availability",
        callback,
    ) { operations.isChatAvailable() }

    fun resetMessageCounter(callback: (Unit?, ChatFailure?) -> Unit) = execute(
        "Unable to reset Chat message counter",
        callback,
    ) { operations.resetMessageCounter() }

    fun showChat(): ChatFailure? {
        val failure = attach()
        if (failure != null) return failure
        return try {
            operations.showChat()
            null
        } catch (_: Exception) {
            ChatFailure("native_error", "Unable to show Chat")
        }
    }

    fun setChatPushTitle(title: String?): ChatFailure? = configurePushNotification(
        "Unable to set Chat push title",
    ) { operations.setChatPushTitle(title) }

    fun setChatPushBody(body: String?): ChatFailure? = configurePushNotification(
        "Unable to set Chat push body",
    ) { operations.setChatPushBody(body) }

    @Synchronized
    fun setJwtProvider(): ChatFailure? = try {
        jwtBridge.enable()
        inAppChat.setWidgetJwtProvider { callback ->
            jwtBridge.request(
                object : ChatJwtCallback {
                    override fun onJwtReady(jwt: String) {
                        mainHandler.post { callback.onJwtReady(jwt) }
                    }

                    override fun onJwtError(error: Throwable) {
                        mainHandler.post { callback.onJwtError(error) }
                    }
                },
            )
        }
        checkNotNull(inAppChat.getWidgetJwtProvider())
        null
    } catch (_: Exception) {
        jwtBridge.clear()
        ChatFailure("native_error", "Unable to register Chat JWT provider")
    }

    @Synchronized
    fun setExceptionHandler(
        enabled: Any?,
        emit: (Map<String, String?>) -> Unit,
    ): ChatFailure? {
        if (enabled !is Boolean) {
            return ChatFailure("invalid_argument", "enabled must be a boolean")
        }
        return try {
            inAppChat.setExceptionHandler(
                if (enabled) {
                    { exception ->
                        emit(ChatExceptionMapper.toMap(exception.message, exception.name))
                    }
                } else {
                    null
                },
            )
            null
        } catch (_: Exception) {
            ChatFailure("native_error", "Unable to configure Chat exception handler")
        }
    }

    fun resolveJwt(jwt: Any?): ChatFailure? =
        if (jwtBridge.resolve(jwt)) null
        else ChatFailure("invalid_argument", "No pending Chat JWT request or JWT is invalid")

    fun rejectJwt(error: Any?): ChatFailure? =
        if (jwtBridge.reject(error)) null
        else ChatFailure("invalid_argument", "No pending Chat JWT request")

    private fun <T> execute(
        failureMessage: String,
        callback: (T?, ChatFailure?) -> Unit,
        operation: () -> T,
    ) {
        val failure = attach()
        if (failure != null) {
            callback(null, failure)
            return
        }
        try {
            callback(operation(), null)
        } catch (_: Exception) {
            callback(null, ChatFailure("native_error", failureMessage))
        }
    }

    private fun configurePushNotification(
        failureMessage: String,
        operation: () -> Unit,
    ): ChatFailure? = try {
        operation()
        null
    } catch (_: Exception) {
        ChatFailure("native_error", failureMessage)
    }

    fun detach() {
        clearJwtProvider()
        clearExceptionHandler()
    }

    @Synchronized
    fun resetAfterCleanup() {
        activated = false
    }

    fun clearJwtProvider() {
        jwtBridge.clear()
        runCatching { inAppChat.setWidgetJwtProvider(null) }
    }

    fun clearExceptionHandler() {
        runCatching { inAppChat.setExceptionHandler(null) }
    }

    private companion object {
        const val TAG = "InfobipHuaweiChat"
    }
}
