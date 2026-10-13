package com.infobip.mobilemessaging.huawei.chat

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import org.infobip.mobile.messaging.chat.InAppChat

internal data class ChatFailure(
    val code: String,
    val message: String,
)

internal class ChatManager(
    context: Context,
    private val initialized: () -> Boolean,
    requestDartJwt: (String, Long) -> Boolean = { _, _ -> false },
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
    private val now: () -> Long = SystemClock::uptimeMillis,
    private val chatFactory: (Context) -> InAppChat = InAppChat::getInstance,
) {
    private val applicationContext = context.applicationContext
    private val inAppChat by lazy { chatFactory(applicationContext) }
    private val operations by lazy { ChatOperations.from(inAppChat) }
    private val jwtBridge = ChatJwtBridge(requestDartJwt = requestDartJwt)
    internal val exceptionBridge = ChatExceptionBridge()
    @Volatile
    private var activated = false
    private var activating = false
    private var disposed = false
    private var activationGeneration = 0L
    private var retryAfter = 0L

    @Synchronized
    fun activate(): ChatFailure? {
        if (disposed) return ChatFailure("chat_unavailable", "Chat engine has been disposed")
        if (!initialized()) return ChatFailure("not_initialized", "Initialize the Infobip SDK first")
        if (activated) return null
        if (activating || now() < retryAfter) return ChatFailure("chat_activation_busy", "Retry Chat activation after one second")
        val generation = activationGeneration
        activating = true
        Log.d(TAG, "InAppChat activation started")
        return try {
            inAppChat.activate()
            if (disposed || generation != activationGeneration) return ChatFailure("chat_unavailable", "Chat activation was invalidated")
            inAppChat.inAppChatScreen().errorHandler = exceptionBridge
            if (disposed || generation != activationGeneration) return ChatFailure("chat_unavailable", "Chat activation was invalidated")
            activated = true
            Log.d(TAG, "InAppChat activation succeeded")
            null
        } catch (error: Exception) {
            if (generation == activationGeneration) retryAfter = now() + 1000
            Log.e(TAG, "InAppChat activation failed")
            ChatFailure("chat_unavailable", "Chat activation failed")
        } finally {
            activating = false
        }
    }

    @Synchronized
    fun attach(): ChatFailure? {
        if (disposed) return ChatFailure("chat_unavailable", "Chat engine has been disposed")
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
            inAppChat.inAppChatScreen().errorHandler = exceptionBridge
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
    fun setJwtProvider(): ChatFailure? {
        if (disposed) return ChatFailure("chat_unavailable", "Chat engine has been disposed")
        return try {
            val generation = jwtBridge.enable()
            inAppChat.setWidgetJwtProvider { callback ->
                jwtBridge.request(
                    object : ChatJwtCallback {
                        override fun onJwtReady(jwt: String) {
                            mainHandler.post {
                                if (jwtBridge.isCurrent(generation)) callback.onJwtReady(jwt)
                                else callback.onJwtError(IllegalStateException("Chat JWT provider is unavailable"))
                            }
                        }

                        override fun onJwtError(error: Throwable) {
                            mainHandler.post { callback.onJwtError(error) }
                        }
                    },
                    generation,
                )
            }
            checkNotNull(inAppChat.getWidgetJwtProvider())
            null
        } catch (_: Exception) {
            jwtBridge.clear()
            ChatFailure("native_error", "Unable to register Chat JWT provider")
        }
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
            // Keep one bridge so already-open screens observe handler replacement/removal.
            inAppChat.inAppChatScreen().errorHandler = exceptionBridge
            exceptionBridge.setHandler(if (enabled) emit else null)
            null
        } catch (_: Exception) {
            exceptionBridge.setHandler(null)
            ChatFailure("native_error", "Unable to configure Chat exception handler")
        }
    }

    fun resolveJwt(requestId: Any?, generation: Any?, jwt: Any?): ChatFailure? =
        if (jwtBridge.resolve(requestId, generation, jwt)) null
        else ChatFailure("stale_request", "Chat JWT request is stale or invalid")

    fun rejectJwt(requestId: Any?, generation: Any?): ChatFailure? =
        if (jwtBridge.reject(requestId, generation)) null
        else ChatFailure("stale_request", "Chat JWT request is stale or invalid")

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
    fun dispose() {
        disposed = true
        activationGeneration++
        activated = false
        detach()
    }

    @Synchronized
    fun resetAfterCleanup() {
        activationGeneration++
        activated = false
        retryAfter = 0L
    }

    fun clearJwtProvider() {
        jwtBridge.clear()
        runCatching { inAppChat.setWidgetJwtProvider(null) }
    }

    fun clearExceptionHandler() {
        exceptionBridge.setHandler(null)
        runCatching { inAppChat.inAppChatScreen().errorHandler = null }
    }

    private companion object {
        const val TAG = "InfobipHuaweiChat"
    }
}
