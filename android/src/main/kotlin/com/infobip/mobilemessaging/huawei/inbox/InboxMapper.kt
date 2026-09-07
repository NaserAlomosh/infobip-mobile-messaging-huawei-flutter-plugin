package com.infobip.mobilemessaging.huawei.inbox

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import org.infobip.mobile.messaging.inbox.Inbox
import org.infobip.mobile.messaging.inbox.InboxMessage
import org.infobip.mobile.messaging.inbox.MobileInboxFilterOptions
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.util.Date

internal object InboxMapper {
    fun requiredExternalUserId(value: Any?): String =
        (value as? String)?.takeUnless { it.isBlank() }
            ?: throw IllegalArgumentException("externalUserId must not be empty")

    fun parseOptions(value: Any?): InboxOptions {
        if (value == null) return InboxOptions()
        val map = value as? Map<*, *> ?: throw IllegalArgumentException("options must be a map")
        val from = instant(map[ChannelContract.FROM], ChannelContract.FROM)
        val to = instant(map[ChannelContract.TO], ChannelContract.TO)
        if (from != null && to != null && from.after(to)) {
            throw IllegalArgumentException("from must not be after to")
        }
        val topic =
            optionalString(map, ChannelContract.TOPIC)?.also {
                if (it.isBlank()) throw IllegalArgumentException("topic must not be empty")
            }
        val topics = optionalStrings(map, ChannelContract.TOPICS)
        if (topic != null && topics != null) {
            throw IllegalArgumentException("topic and topics are mutually exclusive")
        }
        val limit =
            integer(map[ChannelContract.LIMIT], ChannelContract.LIMIT)?.also {
                if (it <= 0) throw IllegalArgumentException("limit must be positive")
            }
        return InboxOptions(from, to, topic, topics, limit)
    }

    fun nativeOptions(options: InboxOptions): MobileInboxFilterOptions =
        if (options.topics == null) {
            MobileInboxFilterOptions(options.from, options.to, options.topic, options.limit)
        } else {
            MobileInboxFilterOptions(options.from, options.to, options.topics, options.limit)
        }

    fun messageIds(value: Any?): List<String> {
        val values = value as? List<*> ?: throw IllegalArgumentException("messageIds must be a list")
        if (values.isEmpty() || values.any { it !is String || it.isBlank() }) {
            throw IllegalArgumentException("messageIds must contain non-empty strings")
        }
        return values.filterIsInstance<String>()
    }

    fun inbox(value: Inbox?): Map<String, Any?> =
        mapOf(
            ChannelContract.COUNT_TOTAL to (value?.countTotal ?: 0),
            ChannelContract.COUNT_UNREAD to (value?.countUnread ?: 0),
            ChannelContract.COUNT_TOTAL_FILTERED to (value?.countTotalFiltered ?: 0),
            ChannelContract.COUNT_UNREAD_FILTERED to (value?.countUnreadFiltered ?: 0),
            ChannelContract.MESSAGES to messages(value?.messages),
        )

    internal fun messages(value: List<InboxMessage>?): List<Map<String, Any?>> =
        value?.map(::message) ?: emptyList()

    internal fun message(value: InboxMessage): Map<String, Any?> =
        mapOf(
            ChannelContract.MESSAGE_ID to value.messageId,
            ChannelContract.TITLE to value.title,
            ChannelContract.BODY to value.body,
            ChannelContract.TOPIC to value.topic,
            ChannelContract.SEEN to value.isSeen,
            ChannelContract.RECEIVED_TIMESTAMP to value.receivedTimestamp,
            ChannelContract.CUSTOM_PAYLOAD to value.customPayload?.let(::jsonObject),
            "sound" to value.sound,
            "vibrate" to value.isVibrate,
            "category" to value.category,
            "internalData" to value.getInternalData(),
            "contentUrl" to value.contentUrl,
            "browserUrl" to value.browserUrl,
            "webViewUrl" to value.webViewUrl,
            "inAppOpenTitle" to value.inAppOpenTitle,
            "inAppDismissTitle" to value.inAppDismissTitle,
            "sentTimestamp" to value.sentTimestamp,
            "originalPayload" to null,
            "deeplink" to value.deeplink,
            "silent" to value.isSilent,
        )

    private fun optionalString(
        map: Map<*, *>,
        key: String,
    ): String? {
        val value = map[key] ?: return null
        return value as? String ?: throw IllegalArgumentException("$key must be a string")
    }

    private fun optionalStrings(
        map: Map<*, *>,
        key: String,
    ): List<String>? {
        val value = map[key] ?: return null
        val values =
            value as? List<*>
                ?: throw IllegalArgumentException("$key must be a list")
        if (values.isEmpty() || values.any { it !is String || it.isBlank() }) {
            throw IllegalArgumentException("$key must contain non-empty strings")
        }
        return values.filterIsInstance<String>()
    }

    private fun integer(
        value: Any?,
        key: String,
    ): Int? =
        when (value) {
            null -> {
                null
            }

            is Int -> {
                value
            }

            is Long -> {
                value.takeIf { it in Int.MIN_VALUE..Int.MAX_VALUE }?.toInt()
                    ?: throw IllegalArgumentException("$key is out of range")
            }

            else -> {
                throw IllegalArgumentException("$key must be an integer")
            }
        }

    private fun instant(
        value: Any?,
        key: String,
    ): Date? {
        if (value == null) return null
        if (value !is String) throw IllegalArgumentException("$key must be a timestamp")
        return try {
            Date.from(Instant.parse(value))
        } catch (_: Exception) {
            throw IllegalArgumentException("$key must be a UTC timestamp")
        }
    }

    private fun jsonObject(value: JSONObject?): Map<String, Any?> {
        if (value == null) return emptyMap()
        return value.keys().asSequence().associateWith { key -> jsonValue(value.opt(key)) }
    }

    private fun jsonArray(value: JSONArray): List<Any?> =
        (0 until value.length()).map { index -> jsonValue(value.opt(index)) }

    private fun jsonValue(value: Any?): Any? =
        when (value) {
            null, JSONObject.NULL -> null
            is String, is Boolean, is Number -> value
            is JSONObject -> jsonObject(value)
            is JSONArray -> jsonArray(value)
            else -> null
        }
}

internal data class InboxOptions(
    val from: Date? = null,
    val to: Date? = null,
    val topic: String? = null,
    val topics: List<String>? = null,
    val limit: Int? = null,
)
