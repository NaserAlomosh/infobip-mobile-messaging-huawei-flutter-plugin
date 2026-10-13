package com.infobip.mobilemessaging.huawei.event

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.infobip.mobile.messaging.CustomAttributeValue
import org.infobip.mobile.messaging.EventPropertiesMapper
import org.junit.Assert.assertThrows
import org.junit.Test
import java.util.Date

class CustomEventMapperTest {
    @Test
    fun `maps definition properties and tagged dates`() {
        val event =
            CustomEventMapper.fromMap(
                mapOf(
                    ChannelContract.DEFINITION_ID to " purchase ",
                    ChannelContract.PROPERTIES to
                        mapOf(
                            "amount" to 12.5,
                            "paid" to true,
                            "at" to
                                mapOf(
                                    ChannelContract.CUSTOM_VALUE_TYPE to ChannelContract.CUSTOM_DATE_TYPE,
                                    ChannelContract.CUSTOM_VALUE to "2026-09-05T12:00:00Z",
                                ),
                        ),
                ),
            )

        assertEquals("purchase", event.definitionId)
        assertEquals(12.5, event.properties?.get("amount")?.numberValue())
        assertEquals(true, event.properties?.get("paid")?.booleanValue())
        assertEquals(Date.from(java.time.Instant.parse("2026-09-05T12:00:00Z")), event.properties?.get("at")?.dateValue())
    }

    @Test
    fun `rejects malformed payloads`() {
        assertThrows(IllegalArgumentException::class.java) {
            CustomEventMapper.fromMap(mapOf(ChannelContract.DEFINITION_ID to " "))
        }
        assertThrows(IllegalArgumentException::class.java) {
            CustomEventMapper.fromMap(
                mapOf(
                    ChannelContract.DEFINITION_ID to "event",
                    ChannelContract.PROPERTIES to mapOf("unsupported" to emptyMap<String, Any>()),
                ),
            )
        }
    }
    @Test
    fun `primitive values and absent metadata round trip`() {
        val properties = mapOf("text" to "hello", "count" to 42, "large" to 9007199254740993L, "ratio" to 1.25, "flag" to false)
        val event = CustomEventMapper.fromMap(mapOf("definitionId" to "event", "properties" to properties))
        val result = CustomEventMapper.toMap(event)
        assertEquals(properties, result["properties"])
        assertEquals(properties, EventPropertiesMapper.eventPropertiesToBackend(event.properties))
        assertNull(result["eventId"])
        assertNull(result["createdAt"])
    }

    @Test
    fun `date retains UTC seconds across time zones and backend serialization`() {
        val original = java.util.TimeZone.getDefault()
        try {
            java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("GMT+03:00"))
            val tag = mapOf(ChannelContract.CUSTOM_VALUE_TYPE to "date", "value" to "2026-09-05T12:00:00.123Z")
            val event = CustomEventMapper.fromMap(mapOf("definitionId" to "event", "properties" to mapOf("at" to tag)))
            assertEquals(CustomAttributeValue.Type.Date, event.properties["at"]?.type)
            assertEquals("2026-09-05T12:00:00Z", EventPropertiesMapper.eventPropertiesToBackend(event.properties)["at"])
            assertEquals(mapOf("at" to tag + ("value" to "2026-09-05T12:00:00Z")), CustomEventMapper.toMap(event)["properties"])
        } finally {
            java.util.TimeZone.setDefault(original)
        }
    }

    @Test
    fun `rejects unsupported collections nulls and malformed dates`() {
        for (value in listOf(null, listOf(1, 2), mapOf("nested" to true), mapOf(ChannelContract.CUSTOM_VALUE_TYPE to "date", "value" to "bad"))) {
            assertThrows(IllegalArgumentException::class.java) {
                CustomEventMapper.fromMap(mapOf("definitionId" to "event", "properties" to mapOf("key" to value)))
            }
        }
        assertThrows(IllegalArgumentException::class.java) {
            CustomEventMapper.fromMap(mapOf("definitionId" to "event", "properties" to mapOf(1 to "value")))
        }
        assertEquals(emptyMap<String, Any>(), CustomEventMapper.toMap(CustomEventMapper.fromMap(mapOf("definitionId" to "event")))["properties"])
    }

}
