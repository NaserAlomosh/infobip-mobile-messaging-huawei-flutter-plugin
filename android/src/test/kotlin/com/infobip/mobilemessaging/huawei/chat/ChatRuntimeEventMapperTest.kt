package com.infobip.mobilemessaging.huawei.chat

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class ChatRuntimeEventMapperTest {
    @Test
    fun `loaded event preserves success and failure`() {
        assertEquals(
            true,
            ChatRuntimeEventMapper.event(ChannelContract.CHAT_LOADED, true)[ChannelContract.VALUE],
        )
        assertEquals(
            false,
            ChatRuntimeEventMapper.event(ChannelContract.CHAT_LOADED, false)[ChannelContract.VALUE],
        )
    }

    @Test
    fun `exit event has no value`() {
        val event = ChatRuntimeEventMapper.event(ChannelContract.CHAT_EXIT_PRESSED)

        assertFalse(event.containsKey(ChannelContract.VALUE))
    }

    @Test
    fun `theme and raw message values are unchanged`() {
        val theme = "  dark theme  "
        val rawMessage = " {\"message\":[1,true]}\n"

        assertEquals(
            theme,
            ChatRuntimeEventMapper.event(ChannelContract.CHAT_WIDGET_THEME_CHANGED, theme)[ChannelContract.VALUE],
        )
        assertEquals(
            rawMessage,
            ChatRuntimeEventMapper.event(ChannelContract.CHAT_RAW_MESSAGE_RECEIVED, rawMessage)[ChannelContract.VALUE],
        )
    }

    @Test
    fun `attachment preserves values including nulls`() {
        val attachment = ChatRuntimeEventMapper.attachment(null, "application/pdf", null)

        assertNull(attachment["url"])
        assertEquals("application/pdf", attachment["type"])
        assertNull(attachment["caption"])
    }
    @Test
    fun `widget info uses exact Huawei fields and channel compatible extensions`() {
        val widget = org.infobip.mobile.messaging.api.chat.WidgetInfo(
            "id", "title", "#111111", "#222222", "#333333", true, false, true,
            listOf("dark"), org.infobip.mobile.messaging.api.chat.WidgetAttachmentConfig(2048L, true, linkedSetOf("pdf", "png")),
        )
        assertEquals(
            mapOf(
                "id" to "id", "title" to "title", "primaryColor" to "#111111",
                "backgroundColor" to "#222222", "primaryTextColor" to "#333333",
                "multiThread" to true, "multiChannelConversationEnabled" to false,
                "callsEnabled" to true, "themeNames" to listOf("dark"),
                "attachmentConfig" to mapOf("maxSize" to 2048L, "isEnabled" to true, "allowedExtensions" to listOf("pdf", "png")),
            ),
            ChatRuntimeEventMapper.widgetInfo(widget),
        )
        val empty = ChatRuntimeEventMapper.widgetInfo(org.infobip.mobile.messaging.api.chat.WidgetInfo())
        assertNull(empty["title"])
        assertNull(empty["attachmentConfig"])
        assertNull(empty["themeNames"])
    }

}
