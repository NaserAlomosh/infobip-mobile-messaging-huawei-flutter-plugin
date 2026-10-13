package com.infobip.mobilemessaging.huawei.plugin

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.infobip.mobile.messaging.Event
import org.infobip.mobile.messaging.Message
import org.infobip.mobile.messaging.interactive.InteractiveEvent
import org.infobip.mobile.messaging.interactive.NotificationAction
import org.infobip.mobile.messaging.interactive.NotificationCategory

/** Receives the SDK's explicit-package broadcast even before a Flutter engine exists. */
class NotificationTapReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        decode(intent)?.let(pendingTaps::save)
    }

    internal companion object {
        // Memory only: no message content or credentials are persisted by this bridge.
        val pendingTaps = PendingTapStore()

        fun decode(intent: Intent): Map<String, Any?>? {
            val type = when (intent.action) {
                Event.NOTIFICATION_TAPPED.key -> ChannelContract.NOTIFICATION_TAPPED
                InteractiveEvent.NOTIFICATION_ACTION_TAPPED.key -> ChannelContract.NOTIFICATION_ACTION_TAPPED
                else -> return null
            }
            val extras = intent.extras ?: return null
            return runCatching {
                val message = Message.createFrom(extras) ?: return null
                val payload = mutableMapOf<String, Any?>("message" to MessageMapper.map(message))
                if (type == ChannelContract.NOTIFICATION_ACTION_TAPPED) {
                    payload["actionId"] = NotificationAction.createFrom(extras)?.id
                    val category = NotificationCategory.createFrom(extras)?.categoryId
                    payload["category"] = category
                    if (category != null) payload["message"] = MessageMapper.map(message) + ("category" to category)
                }
                EventEnvelope.create(type, payload)
            }.getOrNull()
        }
    }
}
