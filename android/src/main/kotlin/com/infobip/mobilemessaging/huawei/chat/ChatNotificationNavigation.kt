package com.infobip.mobilemessaging.huawei.chat

import android.util.Log
import java.util.UUID

/** Only opaque correlation IDs and stage names are logged, never SDK message data. */
internal object ChatNotificationTrace {
    var enabled = false
    fun log(stage: String, correlationId: String) {
        if (enabled) Log.d("InfobipChatNavigation", "$stage correlationId=$correlationId")
    }
}

internal data class ChatNavigationRequest(
    val correlationId: String,
    val threadId: String?,
) {
    fun toMap(): Map<String, Any?> = mapOf("correlationId" to correlationId, "threadId" to threadId)
}

/** Reading/delivering a request does not consume it. Only Flutter route acknowledgement does. */
internal class ChatNotificationNavigation {
    private val pending = linkedMapOf<String, ChatNavigationRequest>()
    private val completed = linkedSetOf<String>()
    private var listener: ((ChatNavigationRequest) -> Unit)? = null

    @Synchronized fun enqueue(messageId: String?, threadId: String?): ChatNavigationRequest? {
        val key = messageId?.takeIf { it.isNotBlank() } ?: UUID.randomUUID().toString()
        if (key in completed) return null
        pending[key]?.let { listener?.invoke(it); return it }
        val request = ChatNavigationRequest(UUID.randomUUID().toString(), threadId)
        pending[key] = request
        ChatNotificationTrace.log("CHAT_NOTIFICATION_TAPPED", request.correlationId)
        ChatNotificationTrace.log("CHAT_ACTION_INTERCEPTED", request.correlationId)
        ChatNotificationTrace.log("CHAT_MODE_RESOLVED mode=embedded", request.correlationId)
        ChatNotificationTrace.log("CHAT_EVENT_QUEUED", request.correlationId)
        listener?.invoke(request)
        return request
    }
    @Synchronized fun peek(): ChatNavigationRequest? = pending.values.firstOrNull()
    @Synchronized fun acknowledge(correlationId: String): Boolean {
        val entry = pending.entries.firstOrNull { it.value.correlationId == correlationId } ?: return false
        pending.remove(entry.key)
        completed.add(entry.key)
        if (completed.size > 64) completed.remove(completed.first())
        return true
    }
    @Synchronized fun listen(observer: (ChatNavigationRequest) -> Unit) {
        listener = observer
        peek()?.let(observer)
    }
    @Synchronized fun cancel(observer: (ChatNavigationRequest) -> Unit) {
        if (listener === observer) listener = null
    }
    @Synchronized fun clear() { pending.clear(); completed.clear() }
}
