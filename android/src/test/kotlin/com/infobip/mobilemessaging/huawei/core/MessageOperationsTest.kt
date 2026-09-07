package com.infobip.mobilemessaging.huawei.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MessageOperationsTest {
    @Test
    fun `forwards one message ID in one SDK call`() {
        val calls = mutableListOf<List<String>>()
        val operations = operations(calls)

        assertNull(operations.markMessagesSeen(listOf("one")))

        assertEquals(listOf(listOf("one")), calls)
    }

    @Test
    fun `preserves all opaque string values exactly`() {
        val calls = mutableListOf<List<String>>()
        val operations = operations(calls)
        val ids = listOf("second", "1788547032704145206", "second", "  spaced  ", "消息:🚀/\u0000")

        assertNull(operations.markMessagesSeen(ids))

        assertEquals(listOf(ids), calls)
    }

    @Test
    fun `rejects non-list arguments`() {
        val calls = mutableListOf<List<String>>()

        val failure = operations(calls).markMessagesSeen("one")

        assertEquals("invalid_argument", failure?.code)
        assertEquals(emptyList<List<String>>(), calls)
    }

    @Test
    fun `rejects lists containing non-string values`() {
        val calls = mutableListOf<List<String>>()

        val failure = operations(calls).markMessagesSeen(listOf("one", 2))

        assertEquals("invalid_argument", failure?.code)
        assertEquals(emptyList<List<String>>(), calls)
    }

    @Test
    fun `rejects an empty list`() {
        val calls = mutableListOf<List<String>>()

        val failure = operations(calls).markMessagesSeen(emptyList<String>())

        assertEquals("invalid_argument", failure?.code)
        assertEquals(emptyList<List<String>>(), calls)
    }

    @Test
    fun `requires initialized Mobile Messaging`() {
        var invoked = false
        val operations = MessageOperations.forTesting(
            isInitialized = { false },
            setMessagesSeen = { invoked = true },
        )

        val failure = operations.markMessagesSeen(listOf("one"))

        assertEquals("not_initialized", failure?.code)
        assertEquals(false, invoked)
    }

    private fun operations(calls: MutableList<List<String>>) =
        MessageOperations.forTesting(
            isInitialized = { true },
            setMessagesSeen = { calls += it.toList() },
        )
}
