package com.infobip.mobilemessaging.huawei.chat

import org.junit.Assert.*
import org.junit.Test

class ChatJwtBridgeTest {
    private val requests = mutableListOf<Pair<String, Long>>()
    private fun bridge() = ChatJwtBridge { id, generation -> requests += id to generation; true }
    private fun ChatJwtBridge.resolve(index: Int, token: String = "test-token") =
        resolve(requests[index].first, requests[index].second, token)
    private fun ChatJwtBridge.reject(index: Int) = reject(requests[index].first, requests[index].second)

    @Test fun `request without enabled provider fails safely`() {
        val callback = RecordingCallback()
        val bridge = bridge()
        bridge.request(callback)
        assertEquals(1, callback.errors.size)
        assertEquals(0, bridge.pendingCount())
    }

    @Test fun `concurrent requests resolve out of order exactly once`() {
        val bridge = bridge().also { it.enable() }
        val first = RecordingCallback()
        val second = RecordingCallback()
        bridge.request(first)
        bridge.request(second)
        assertEquals(2, requests.size)
        assertNotEquals(requests[0].first, requests[1].first)
        assertTrue(bridge.resolve(1, "second"))
        assertTrue(first.tokens.isEmpty())
        assertTrue(bridge.resolve(0, "first"))
        assertFalse(bridge.resolve(0))
        assertFalse(bridge.reject(1))
        assertEquals(listOf("first"), first.tokens)
        assertEquals(listOf("second"), second.tokens)
        assertEquals(0, bridge.pendingCount())
    }

    @Test fun `reject is correlated and contains no provider payload`() {
        val bridge = bridge().also { it.enable() }
        val first = RecordingCallback()
        val second = RecordingCallback()
        bridge.request(first)
        bridge.request(second)
        assertTrue(bridge.reject(1))
        assertEquals("Unable to provide Chat JWT", second.errors.single().message)
        assertTrue(first.errors.isEmpty())
        assertEquals(1, bridge.pendingCount())
    }

    @Test fun `invalid unmatched and wrong generation responses leave callback pending`() {
        val bridge = bridge().also { it.enable() }
        bridge.request(RecordingCallback())
        assertFalse(bridge.resolve(0, "  "))
        assertFalse(bridge.resolve("unknown", requests[0].second, "test-token"))
        assertFalse(bridge.resolve(requests[0].first, requests[0].second + 1, "test-token"))
        assertEquals(1, bridge.pendingCount())
        assertTrue(bridge.reject(0))
    }

    @Test fun `cleanup and replacement invalidate old success failure and provider invocation`() {
        for (cleanup in listOf(true, false)) {
            requests.clear()
            val bridge = bridge()
            val oldGeneration = bridge.enable()
            val old = RecordingCallback()
            bridge.request(old)
            if (cleanup) bridge.clear()
            bridge.enable()
            val fresh = RecordingCallback()
            bridge.request(fresh)
            assertFalse(bridge.resolve(0, "old-secret"))
            assertFalse(bridge.reject(0))
            assertEquals(1, old.errors.size)
            assertTrue(fresh.tokens.isEmpty())
            assertTrue(fresh.errors.isEmpty())
            val lateProvider = RecordingCallback()
            bridge.request(lateProvider, oldGeneration)
            assertEquals(1, lateProvider.errors.size)
            assertEquals(2, requests.size)
            assertTrue(bridge.resolve(1, "new-token"))
            assertEquals(listOf("new-token"), fresh.tokens)
            assertFalse(old.errors.toString().contains("old-secret"))
        }
    }

    @Test fun `clear fails all callbacks and unavailable event sink completes safely`() {
        val bridge = bridge().also { it.enable() }
        val callbacks = List(2) { RecordingCallback() }
        callbacks.forEach { bridge.request(it) }
        bridge.clear()
        callbacks.forEach { assertEquals(1, it.errors.size) }
        assertEquals(0, bridge.pendingCount())
        val noSink = ChatJwtBridge { _, _ -> false }.also { it.enable() }
        val callback = RecordingCallback()
        noSink.request(callback)
        assertEquals(1, callback.errors.size)
        assertEquals(0, noSink.pendingCount())
    }

    private class RecordingCallback : ChatJwtCallback {
        val tokens = mutableListOf<String>()
        val errors = mutableListOf<Throwable>()
        override fun onJwtReady(jwt: String) { tokens += jwt }
        override fun onJwtError(error: Throwable) { errors += error }
    }
}
