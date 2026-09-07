package com.infobip.mobilemessaging.huawei.chat

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import org.infobip.mobile.messaging.api.chat.WidgetInfo

internal object ChatRuntimeEventMapper {
    fun event(name: String, value: Any? = null, includeValue: Boolean = value != null): Map<String, Any?> =
        buildMap {
            put(ChannelContract.EVENT, name)
            if (includeValue) put(ChannelContract.VALUE, value)
        }

    fun widgetInfo(value: WidgetInfo): Map<String, Any?> = mapOf(
        "id" to value.id,
        "title" to value.title,
        "primaryColor" to value.primaryColor,
        "backgroundColor" to value.backgroundColor,
        "primaryTextColor" to value.primaryTextColor,
        "multiThread" to value.isMultiThread,
        "multiChannelConversationEnabled" to value.isMultiChannelConversationEnabled,
        "callsEnabled" to value.isCallsEnabled,
        "themeNames" to value.themeNames,
        "attachmentConfig" to value.attachmentConfig?.let { config ->
            mapOf(
                "maxSize" to config.maxSize,
                "isEnabled" to config.isEnabled,
                "allowedExtensions" to config.allowedExtensions?.toList(),
            )
        },
    )

    fun attachment(url: String?, type: String?, caption: String?): Map<String, Any?> = mapOf(
        "url" to url,
        "type" to type,
        "caption" to caption,
    )
}
