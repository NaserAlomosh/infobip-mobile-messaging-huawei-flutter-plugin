package com.infobip.mobilemessaging.huawei.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ChatDraftMessageTest {
    @Test
    fun `maps draft without changing content`() {
        assertEquals("  hello  ", ChatMapper.draftMessage(mapOf("message" to "  hello  ")))
    }

    @Test
    fun `maps empty draft used to clear composer`() {
        assertEquals("", ChatMapper.draftMessage(mapOf("message" to "")))
    }

    @Test
    fun `rejects null draft`() {
        assertThrows(IllegalArgumentException::class.java) {
            ChatMapper.draftMessage(mapOf("message" to null))
        }
    }

    @Test
    fun `rejects non-string draft`() {
        assertThrows(IllegalArgumentException::class.java) {
            ChatMapper.draftMessage(mapOf("message" to 1))
        }
    }

    @Test
    fun `rejects invalid arguments`() {
        assertThrows(IllegalArgumentException::class.java) {
            ChatMapper.draftMessage("draft")
        }
    }
}
