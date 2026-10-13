package com.infobip.mobilemessaging.huawei.chat

import org.infobip.mobile.messaging.chat.core.InAppChatException
import org.infobip.mobile.messaging.chat.view.InAppChatErrorsHandler
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChatExceptionBridgeTest {
    @Test
    fun `default and removed handlers defer to Huawei without callbacks`() {
        val bridge = ChatExceptionBridge()
        val error = InAppChatException(message = "message", name = "name")
        assertFalse(bridge.handleError(error))
        var calls = 0
        bridge.setHandler { calls++ }
        assertTrue(bridge.handleError(error))
        bridge.setHandler(null)
        assertFalse(bridge.handleError(error))
        assertEquals(1, calls)
    }

    @Test
    fun `existing screen and fragment references observe replacement and preserve nullable fields`() {
        val bridge = ChatExceptionBridge()
        val screenHandler: InAppChatErrorsHandler = bridge
        val fragmentHandler: org.infobip.mobile.messaging.chat.view.InAppChatFragment.ErrorsHandler = bridge
        val first = mutableListOf<Map<String, String?>>()
        val second = mutableListOf<Map<String, String?>>()
        bridge.setHandler { first += it }
        assertTrue(screenHandler.handleError(InAppChatException(message = "failure", name = "native_name")))
        bridge.setHandler { second += it }
        assertTrue(fragmentHandler.handleError(InAppChatException()))
        assertEquals(listOf(mapOf("message" to "failure", "name" to "native_name")), first)
        assertEquals(listOf(mapOf("message" to null, "name" to null)), second)
    }
}
