package com.infobip.mobilemessaging.huawei.plugin

import org.infobip.mobile.messaging.Message
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
// SDK 35 supports Java 17; Robolectric's SDK 36 runtime requires Java 21.
@Config(sdk = [35])
class MessageMapperTest {
    @Test
    fun `preserves non-null internal data`() {
        val internalData = "{\"campaignId\":\"campaign-1\"}"

        val mapped = MessageMapper.map(message(internalData = internalData))

        assertEquals(internalData, mapped["internalData"])
    }

    @Test
    fun `preserves null internal data`() {
        val mapped = MessageMapper.map(message(internalData = null))

        assertNull(mapped["internalData"])
    }

    @Test
    fun `maps unseen timestamp as false with no seen date`() {
        val mapped = MessageMapper.map(message(seenTimestamp = 0L))

        assertFalse(mapped["seen"] as Boolean)
        assertNull(mapped["seenDate"])
    }

    @Test
    fun `maps seen timestamp as true with the exact seen date`() {
        val seenTimestamp = 1_788_264_060_123L

        val mapped = MessageMapper.map(message(seenTimestamp = seenTimestamp))

        assertTrue(mapped["seen"] as Boolean)
        assertEquals(seenTimestamp, mapped["seenDate"])
    }

    @Test
    fun `maps chat flag from the native chat message API`() {
        val mapped = MessageMapper.map(message(chat = true))

        assertTrue(mapped["chat"] as Boolean)
    }

    @Test
    fun `maps nested custom payload to channel-safe values`() {
        val customPayload =
            JSONObject()
                .put("nested", JSONObject().put("enabled", true))
                .put("items", JSONArray().put(1).put(JSONObject.NULL).put(2.5))

        val mapped = MessageMapper.map(message(customPayload = customPayload))
        val payload = mapped["customPayload"] as Map<*, *>

        assertEquals(mapOf("enabled" to true), payload["nested"])
        assertEquals(listOf(1, null, 2.5), payload["items"])
    }

    private fun message(
        internalData: String? = null,
        seenTimestamp: Long = 0L,
        chat: Boolean = false,
        customPayload: JSONObject? = null,
    ): Message =
        object : Message() {
            override fun getInternalData(): String? = internalData

            override fun getSeenTimestamp(): Long = seenTimestamp

            override fun isChatMessage(): Boolean = chat

            override fun getCustomPayload(): JSONObject? = customPayload
        }
}
