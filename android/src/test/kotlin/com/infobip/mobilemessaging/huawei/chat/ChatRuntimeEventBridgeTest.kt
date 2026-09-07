package com.infobip.mobilemessaging.huawei.chat

import org.junit.Assert.assertEquals
import org.junit.Test

class ChatRuntimeEventBridgeTest {
    @Test
    fun `replays buffered events in order`() {
        val emitted = mutableListOf<Map<String, Any?>>()
        val bridge = ChatRuntimeEventBridge(3, emitted::add)
        bridge.publish(mapOf("event" to "first"))
        bridge.publish(mapOf("event" to "second"))

        bridge.ready()

        assertEquals(listOf("first", "second"), emitted.map { it["event"] })
    }

    @Test
    fun `buffer is bounded to newest events`() {
        val emitted = mutableListOf<Map<String, Any?>>()
        val bridge = ChatRuntimeEventBridge(2, emitted::add)
        bridge.publish(mapOf("event" to "first"))
        bridge.publish(mapOf("event" to "second"))
        bridge.publish(mapOf("event" to "third"))

        bridge.ready()

        assertEquals(listOf("second", "third"), emitted.map { it["event"] })
    }

    @Test
    fun `dispose clears pending events and rejects future events`() {
        val emitted = mutableListOf<Map<String, Any?>>()
        val bridge = ChatRuntimeEventBridge(2, emitted::add)
        bridge.publish(mapOf("event" to "pending"))

        bridge.dispose()
        bridge.ready()
        bridge.publish(mapOf("event" to "late"))

        assertEquals(emptyList<Map<String, Any?>>(), emitted)
    }

    @Test
    fun `publishes successful chat loading result`() {
        val emitted = mutableListOf<Map<String, Any?>>()
        val bridge = ChatRuntimeEventBridge(emit = emitted::add).apply { ready() }

        bridge.publishResult(true, mapOf("event" to "chatLoaded")) { error("unexpected failure") }

        assertEquals(listOf(mapOf("event" to "chatLoaded")), emitted)
    }

    @Test
    fun `publishes successful connection resumed result`() {
        val emitted = mutableListOf<Map<String, Any?>>()
        val bridge = ChatRuntimeEventBridge(emit = emitted::add).apply { ready() }

        bridge.publishResult(
            true,
            mapOf("event" to "chatConnectionChanged", "value" to "CONNECTED"),
        ) { error("unexpected failure") }

        assertEquals("CONNECTED", emitted.single()["value"])
    }

    @Test
    fun `publishes successful connection paused result`() {
        val emitted = mutableListOf<Map<String, Any?>>()
        val bridge = ChatRuntimeEventBridge(emit = emitted::add).apply { ready() }

        bridge.publishResult(
            true,
            mapOf("event" to "chatConnectionChanged", "value" to "DISCONNECTED"),
        ) { error("unexpected failure") }

        assertEquals("DISCONNECTED", emitted.single()["value"])
    }

    @Test
    fun `failed result reports error without publishing successful event`() {
        val emitted = mutableListOf<Map<String, Any?>>()
        var failures = 0
        val bridge = ChatRuntimeEventBridge(emit = emitted::add).apply { ready() }

        bridge.publishResult(false, mapOf("event" to "chatLoaded")) { failures++ }

        assertEquals(emptyList<Map<String, Any?>>(), emitted)
        assertEquals(1, failures)
    }
}
