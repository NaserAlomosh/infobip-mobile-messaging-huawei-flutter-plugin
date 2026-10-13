package com.infobip.mobilemessaging.huawei.plugin

import org.infobip.mobile.messaging.Message
import org.json.JSONArray
import org.json.JSONObject

internal object MessageMapper {
    fun map(message: Message): Map<String, Any?> =
        mapOf(
            "messageId" to message.messageId,
            "title" to message.title,
            "body" to message.body,
            "sound" to message.sound,
            "vibrate" to message.isVibrate,
            "icon" to message.icon,
            "silent" to message.isSilent,
            "category" to message.category,
            "customPayload" to channelSafeObject(message.customPayload),
            "internalData" to message.getInternalData(),
            "receivedTimestamp" to message.receivedTimestamp,
            "seenDate" to message.seenTimestamp.takeIf { it != 0L },
            "contentUrl" to message.contentUrl,
            "seen" to (message.seenTimestamp != 0L),
            "originalPayload" to null,
            "browserUrl" to message.browserUrl,
            "deeplink" to message.deeplink,
            "webViewUrl" to message.webViewUrl,
            "inAppOpenTitle" to message.inAppOpenTitle,
            "inAppDismissTitle" to message.inAppDismissTitle,
            "chat" to message.isChatMessage(),
        )

    private fun channelSafeObject(value: JSONObject?): Map<String, Any?>? =
        value?.keys()?.asSequence()?.associateWith { key -> channelSafe(value.opt(key)) }

    private fun channelSafeArray(value: JSONArray): List<Any?> =
        (0 until value.length()).map { index -> channelSafe(value.opt(index)) }

    private fun channelSafe(value: Any?): Any? =
        when (value) {
            null, JSONObject.NULL -> null
            is String, is Boolean, is Int, is Long, is Double -> value
            is Float -> value.toDouble()
            is JSONObject -> channelSafeObject(value)
            is JSONArray -> channelSafeArray(value)
            is Map<*, *> -> value.entries.mapNotNull { (key, item) -> (key as? String)?.let { it to channelSafe(item) } }.toMap()
            is Iterable<*> -> value.map(::channelSafe)
            is Array<*> -> value.map(::channelSafe)
            else -> null
        }
}
