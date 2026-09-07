package com.infobip.mobilemessaging.huawei.chat

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import org.infobip.mobile.messaging.chat.core.MultithreadStrategy
import org.infobip.mobile.messaging.chat.models.MessagePayload

internal object ChatMapper {
    fun draftMessage(arguments: Any?): String {
        val map = arguments as? Map<*, *>
            ?: throw IllegalArgumentException("Arguments must be a map")
        return map[ChannelContract.MESSAGE] as? String
            ?: throw IllegalArgumentException("message must be a string")
    }

    fun messagePayload(arguments: Any?): MessagePayload {
        val text = value(arguments, ChannelContract.TEXT)
        require(text.isNotBlank()) { "Message text must not be empty" }
        return MessagePayload.Basic(text)
    }

    fun contextualData(arguments: Any?): String {
        val data = value(arguments, ChannelContract.DATA)
        require(data.isNotBlank()) { "Contextual data must not be empty" }
        return data
    }

    fun contextualDataStrategy(arguments: Any?): MultithreadStrategy {
        val strategy = value(arguments, ChannelContract.CHAT_MULTI_THREAD_STRATEGY)
        return when (strategy) {
            "ACTIVE" -> MultithreadStrategy.ACTIVE
            "ALL" -> MultithreadStrategy.ALL
            "ALL_PLUS_NEW" -> MultithreadStrategy.ALL_PLUS_NEW
            else -> throw IllegalArgumentException("Unsupported Chat contextual data strategy")
        }
    }

    private fun value(
        arguments: Any?,
        key: String,
    ): String {
        val values = arguments as? Map<*, *> ?: throw IllegalArgumentException("Arguments are invalid")
        return values[key] as? String ?: throw IllegalArgumentException("Argument is invalid")
    }
}
