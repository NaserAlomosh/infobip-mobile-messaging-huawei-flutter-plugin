package com.infobip.mobilemessaging.huawei.chat

import android.content.Context
import android.content.Intent
import org.infobip.mobile.messaging.Message
import org.infobip.mobile.messaging.MobileMessagingCore
import org.infobip.mobile.messaging.OpenLivechatAction
import org.infobip.mobile.messaging.app.ContentIntentWrapper
import org.infobip.mobile.messaging.chat.InAppChat
import org.infobip.mobile.messaging.chat.core.InAppChatNotificationInteractionHandler

/** Installed before any Activity, including a cold notification tap, can run. */
internal class ChatNotificationRouting(
    private val context: Context,
    private val nativeHandler: () -> InAppChatNotificationInteractionHandler = {
        InAppChat.getInstance(context).getDefaultNotificationInteractionHandler()
    },
    private val settings: () -> org.infobip.mobile.messaging.NotificationSettings? = {
        MobileMessagingCore.getInstance(context).notificationSettings
    },
) : InAppChatNotificationInteractionHandler {
    override fun onNotificationInteracted(message: Message) {
        val native = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(MODE, EMBEDDED) == NATIVE
        if (native) {
            // Preserve the SDK's own message/action distinction in native mode.
            val correlationId = java.util.UUID.randomUUID().toString()
            ChatNotificationTrace.log("CHAT_NOTIFICATION_TAPPED", correlationId)
            ChatNotificationTrace.log("CHAT_MODE_RESOLVED mode=native", correlationId)
            nativeHandler().onNotificationInteracted(message)
        } else {
            val request = navigation.enqueue(message.messageId, OpenLivechatAction.parseFrom(message)?.threadId)
                ?: return
            val notificationSettings = settings()
            val launch = notificationSettings?.let { ContentIntentWrapper(context).createContentIntent(message, it) }
                ?: context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch == null) ChatNotificationTrace.log("CHAT_HOST_UNAVAILABLE", request.correlationId)
            launch?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                ?.let(context::startActivity)
        }
    }

    companion object {
        const val EMBEDDED = "embedded"
        const val NATIVE = "native"
        private const val PREFERENCES = "infobip_huawei_chat_navigation"
        private const val MODE = "presentation"
        val targets = ChatNotificationTargets()
        val navigation = ChatNotificationNavigation()
        var activeCorrelationId: String? = null

        fun install(context: Context) {
            ChatNotificationTrace.enabled = context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0
            InAppChat.getInstance(context).setNotificationInteractionHandler(ChatNotificationRouting(context.applicationContext))
        }

        fun configure(context: Context, mode: Any?): Boolean {
            if (mode != EMBEDDED && mode != NATIVE) return false
            // Commit before acknowledging so a subsequent process death retains the choice.
            check(context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().putString(MODE, mode as String).commit())
            if (mode == NATIVE) { targets.clear(); navigation.clear(); activeCorrelationId = null }
            install(context)
            return true
        }
    }
}

/** A target waits for a loaded fragment, and is consumed once, including across engine recreation. */
internal class ChatNotificationTargets {
    private var pending: String? = null
    private var listener: ((String) -> Unit)? = null

    @Synchronized fun isListening(): Boolean = listener != null
    @Synchronized fun offer(threadId: String?) {
        pending = threadId?.takeIf { it.isNotBlank() }
        drain()
    }
    @Synchronized fun listen(observer: (String) -> Unit) { listener = observer; drain() }
    @Synchronized fun cancel(observer: (String) -> Unit) { if (listener === observer) listener = null }
    @Synchronized fun clear() { pending = null }
    private fun drain() {
        val current = listener ?: return
        val target = pending ?: return
        pending = null
        current(target)
    }
}
