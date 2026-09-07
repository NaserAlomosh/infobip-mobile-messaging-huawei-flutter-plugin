package com.infobip.mobilemessaging.huawei.chat

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChatOperationsTest {
    @Test
    fun `availability delegates to native operation`() {
        var invoked = false
        val operations = ChatOperations(
            availability = {
                invoked = true
                true
            },
            messageCounter = { 0 },
            resetCounter = {},
            showScreen = {},
        )

        assertTrue(operations.isChatAvailable())
        assertTrue(invoked)
    }

    @Test
    fun `availability preserves false`() {
        val operations = ChatOperations(
            availability = { false },
            messageCounter = { 0 },
            resetCounter = {},
            showScreen = {},
        )

        assertFalse(operations.isChatAvailable())
    }

    @Test
    fun `reset delegates to native operation`() {
        var invoked = false
        val operations = ChatOperations(
            availability = { true },
            messageCounter = { 0 },
            resetCounter = { invoked = true },
            showScreen = {},
        )

        operations.resetMessageCounter()

        assertTrue(invoked)
    }

    @Test
    fun `message counter delegates without duplicating state`() {
        var invoked = false
        val operations = ChatOperations(
            availability = { true },
            messageCounter = {
                invoked = true
                7
            },
            resetCounter = {},
            showScreen = {},
        )

        assertTrue(operations.getMessageCounter() == 7)
        assertTrue(invoked)
    }

    @Test
    fun `show Chat delegates to native screen without a fragment`() {
        var invoked = false
        val operations = ChatOperations(
            availability = { true },
            messageCounter = { 0 },
            resetCounter = {},
            showScreen = { invoked = true },
        )

        operations.showChat()

        assertTrue(invoked)
    }

    @Test
    fun `Chat push title delegates without changing nullable string values`() {
        val received = mutableListOf<String?>()
        var screenOpened = false
        val operations = ChatOperations(
            availability = { true },
            messageCounter = { 0 },
            resetCounter = {},
            showScreen = { screenOpened = true },
            setPushTitle = { received.add(it) },
        )

        operations.setChatPushTitle("Support")
        operations.setChatPushTitle(null)
        operations.setChatPushTitle("")
        operations.setChatPushTitle("  Support  ")

        assertTrue(received == listOf("Support", null, "", "  Support  "))
        assertFalse(screenOpened)
    }

    @Test
    fun `Chat push body delegates without changing nullable string values`() {
        val received = mutableListOf<String?>()
        var screenOpened = false
        val operations = ChatOperations(
            availability = { true },
            messageCounter = { 0 },
            resetCounter = {},
            showScreen = { screenOpened = true },
            setPushBody = { received.add(it) },
        )

        operations.setChatPushBody("You have a new message")
        operations.setChatPushBody(null)
        operations.setChatPushBody("")
        operations.setChatPushBody("  New message  ")

        assertTrue(
            received == listOf("You have a new message", null, "", "  New message  "),
        )
        assertFalse(screenOpened)
    }
}
