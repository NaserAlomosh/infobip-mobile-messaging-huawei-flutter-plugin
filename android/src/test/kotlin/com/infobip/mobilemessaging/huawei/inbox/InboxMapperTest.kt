package com.infobip.mobilemessaging.huawei.inbox

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Test
import org.infobip.mobile.messaging.inbox.MobileInboxFilterOptions

class InboxMapperTest {
    @Test
    fun `maps null inbox to empty values`() {
        val mapped = InboxMapper.inbox(null)

        assertEquals(0, mapped[ChannelContract.COUNT_TOTAL])
        assertEquals(0, mapped[ChannelContract.COUNT_UNREAD])
        assertEquals(0, mapped[ChannelContract.COUNT_TOTAL_FILTERED])
        assertEquals(0, mapped[ChannelContract.COUNT_UNREAD_FILTERED])
        assertEquals(emptyList<Any>(), mapped[ChannelContract.MESSAGES])
    }

    @Test
    fun `null Inbox messages map to an empty list`() {
        assertTrue(InboxMapper.messages(null).isEmpty())
    }

    @Test(expected = IllegalArgumentException::class)
    fun `options reject fractional limits instead of truncating`() {
        InboxMapper.parseOptions(mapOf(ChannelContract.LIMIT to 1.5))
    }

    @Test
    fun `options accept long limits in integer range`() {
        assertEquals(20, InboxMapper.parseOptions(mapOf(ChannelContract.LIMIT to 20L)).limit)
    }

    @Test
    fun `parses UTC filters`() {
        val options = InboxMapper.parseOptions(
            mapOf(
                "from" to "2026-09-01T12:00:00Z",
                "to" to "2026-09-02T12:00:00Z",
                "topic" to "news",
                "limit" to 25,
            ),
        )

        assertEquals("2026-09-01T12:00:00Z", options.from?.toInstant().toString())
        assertEquals("news", options.topic)
        assertEquals(25, options.limit)
        assertEquals(
            MobileInboxFilterOptions::class.java,
            InboxMapper.nativeOptions(options)::class.java,
        )
    }

    @Test
    fun `keeps omitted filters absent`() {
        val options = InboxMapper.parseOptions(null)
        assertNull(options.from)
        assertNull(options.to)
        assertNull(options.topic)
        assertNull(options.topics)
        assertNull(options.limit)
    }

    @Test
    fun `rejects invalid ranges and limits`() {
        assertThrows(IllegalArgumentException::class.java) {
            InboxMapper.parseOptions(
                mapOf("from" to "2026-09-02T00:00:00Z", "to" to "2026-09-01T00:00:00Z"),
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            InboxMapper.parseOptions(mapOf("limit" to 0))
        }
    }

    @Test
    fun `validates seen identifiers`() {
        val messageIds = listOf("1788547032704145206", " id-with-spaces ")

        assertEquals(messageIds, InboxMapper.messageIds(messageIds))
        assertThrows(IllegalArgumentException::class.java) { InboxMapper.messageIds(emptyList<String>()) }
        assertThrows(IllegalArgumentException::class.java) { InboxMapper.messageIds(listOf("")) }
        assertThrows(IllegalArgumentException::class.java) { InboxMapper.messageIds(listOf("one", null)) }
        assertThrows(IllegalArgumentException::class.java) { InboxMapper.messageIds(listOf("one", 2)) }
    }

    @Test
    fun `constructs real filter options for multiple topics`() {
        val options = InboxMapper.parseOptions(
            mapOf("topics" to listOf("news", "offers"), "limit" to 10),
        )

        assertEquals(listOf("news", "offers"), options.topics)
        assertEquals(
            MobileInboxFilterOptions::class.java,
            InboxMapper.nativeOptions(options)::class.java,
        )
    }

    @Test
    fun `validates identity and mutually exclusive topic filters`() {
        assertEquals("user", InboxMapper.requiredExternalUserId("user"))
        assertThrows(IllegalArgumentException::class.java) {
            InboxMapper.requiredExternalUserId(" ")
        }
        assertThrows(IllegalArgumentException::class.java) {
            InboxMapper.parseOptions(mapOf("topic" to "one", "topics" to listOf("two")))
        }
    }
}
