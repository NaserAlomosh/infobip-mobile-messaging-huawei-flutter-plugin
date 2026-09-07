package com.infobip.mobilemessaging.huawei.inbox

import io.flutter.plugin.common.StandardMethodCodec
import org.infobip.mobile.messaging.Message
import org.infobip.mobile.messaging.inbox.InboxMessage
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class InboxRichContentTest {
    @Test fun `actual Huawei Inbox preserves every supported rich field and distinct sent time`() {
        val source = object : Message() {
            override fun getMessageId() = "1788547032704145206"
            override fun getTitle() = "title"
            override fun getBody() = "body"
            override fun getSound() = "sound"
            override fun isVibrate() = true
            override fun isSilent() = true
            override fun getCategory() = "category"
            override fun getCustomPayload() = JSONObject().put("flag", true)
            override fun getInternalData() = "{}"
            override fun getContentUrl() = "https://example.org/content"
            override fun getBrowserUrl() = "https://example.org/browser"
            override fun getDeeplink() = "app://inbox"
            override fun getWebViewUrl() = "https://example.org/webview"
            override fun getInAppOpenTitle() = "Open"
            override fun getInAppDismissTitle() = "Dismiss"
            override fun getSentTimestamp() = 111L
            override fun getReceivedTimestamp() = 222L
        }
        val native = InboxMessage.createFrom(source, "news", true)
        val mapped = InboxMapper.message(native)
        val expected = mapOf("messageId" to "1788547032704145206", "topic" to "news", "seen" to true,
            "title" to "title", "body" to "body", "sound" to "sound", "vibrate" to true,
            "silent" to true, "category" to "category", "customPayload" to mapOf("flag" to true),
            "internalData" to "{}", "contentUrl" to "https://example.org/content",
            "browserUrl" to "https://example.org/browser", "deeplink" to "app://inbox",
            "webViewUrl" to "https://example.org/webview", "inAppOpenTitle" to "Open",
            "inAppDismissTitle" to "Dismiss", "sentTimestamp" to 111L, "receivedTimestamp" to 222L,
            "originalPayload" to null)
        assertEquals(expected, mapped)
        StandardMethodCodec.INSTANCE.encodeSuccessEnvelope(mapped)
    }

    @Test fun `absent native Inbox payload stays null`() {
        val mapped = InboxMapper.message(InboxMessage.createFrom(Message(), "news", false))
        assertNull(mapped["customPayload"])
        assertNull(mapped["originalPayload"])
    }
}
