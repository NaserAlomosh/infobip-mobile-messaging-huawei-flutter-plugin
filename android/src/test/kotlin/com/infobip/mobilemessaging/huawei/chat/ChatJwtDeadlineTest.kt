package com.infobip.mobilemessaging.huawei.chat

import org.junit.Assert.*
import org.junit.Test

class ChatJwtDeadlineTest {
    private class Clock {
        var now = 0L
        val tasks = mutableListOf<Pair<Long, () -> Unit>>()
        fun schedule(delay: Long, action: () -> Unit): () -> Unit {
            val task = (now + delay) to action
            tasks += task
            return { tasks.remove(task); Unit }
        }
        fun advance() { now += 30_000; tasks.toList().forEach { if (it.first <= now) it.second() } }
    }
    private class Reply : ChatJwtCallback {
        val tokens = mutableListOf<String>()
        val errors = mutableListOf<Throwable>()
        override fun onJwtReady(jwt: String) { tokens += jwt }
        override fun onJwtError(error: Throwable) { errors += error }
    }
    private val clock = Clock()
    private val ids = mutableListOf<Pair<String, Long>>()
    private fun bridge() = ChatJwtBridge(now = { clock.now }, schedule = clock::schedule) { id, generation ->
        ids += id to generation; true
    }.also { it.enable() }
    private fun ChatJwtBridge.resolve(index: Int) = resolve(ids[index].first, ids[index].second, "fixture-jwt")

    @Test fun `never completed request expires once and late results are rejected`() {
        val bridge = bridge(); val reply = Reply(); bridge.request(reply)
        clock.advance()
        assertEquals(1, reply.errors.size); assertEquals("Chat JWT request timed out", reply.errors.single().message)
        assertEquals(0, bridge.pendingCount()); assertTrue(clock.tasks.isEmpty())
        assertFalse(bridge.resolve(0)); assertFalse(bridge.reject(ids[0].first, ids[0].second))
        clock.advance(); assertEquals(1, reply.errors.size)
    }
    @Test fun `response after deadline is rejected even before scheduled expiry runs`() {
        val bridge = bridge(); val reply = Reply(); bridge.request(reply)
        clock.now = 30_001
        assertFalse(bridge.resolve(0)); assertEquals(1, reply.errors.size)
        assertEquals(0, bridge.pendingCount()); assertTrue(clock.tasks.isEmpty())
    }
    @Test fun `out of order success cancels deadlines and duplicates cannot complete`() {
        val bridge = bridge(); val replies = List(2) { Reply() }; replies.forEach { bridge.request(it) }
        assertTrue(bridge.resolve(1)); assertTrue(bridge.resolve(0)); assertFalse(bridge.resolve(0))
        assertTrue(clock.tasks.isEmpty()); clock.advance()
        replies.forEach { assertEquals(listOf("fixture-jwt"), it.tokens); assertTrue(it.errors.isEmpty()) }
    }
    @Test fun `cleanup replacement and engine disposal clear timers and invalidate old responses`() {
        val bridge = bridge(); val reply = Reply(); bridge.request(reply)
        bridge.clear() // ChatManager cleanup/detach/dispose all use this boundary.
        assertTrue(clock.tasks.isEmpty()); assertEquals(1, reply.errors.size)
        bridge.enable(); val fresh = Reply(); bridge.request(fresh)
        assertFalse(bridge.resolve(0)); assertTrue(bridge.resolve(1)); clock.advance()
        assertEquals(1, reply.errors.size); assertTrue(fresh.errors.isEmpty())
    }
    @Test fun `capacity is bounded and recovers after expiry`() {
        val bridge = bridge(); val replies = List(33) { Reply() }; replies.forEach { bridge.request(it) }
        assertEquals(32, bridge.pendingCount()); assertEquals(32, ids.size)
        assertEquals(1, replies.last().errors.size); clock.advance()
        assertEquals(0, bridge.pendingCount()); val next = Reply(); bridge.request(next)
        assertTrue(bridge.resolve(32)); assertEquals(1, next.tokens.size)
    }
    @Test fun `delivery and scheduler failures leave no retained callback`() {
        val reply = Reply()
        val bridge = ChatJwtBridge(schedule = clock::schedule) { _, _ -> throw IllegalStateException("fixture-sensitive-value") }
        bridge.enable(); bridge.request(reply)
        assertEquals(0, bridge.pendingCount()); assertTrue(clock.tasks.isEmpty())
        assertFalse(reply.errors.single().message!!.contains("fixture-sensitive-value"))
        val failed = ChatJwtBridge(schedule = { _, _ -> error("fixture-sensitive-value") }) { _, _ -> true }
        failed.enable(); val second = Reply(); failed.request(second)
        assertEquals(0, failed.pendingCount()); assertEquals(1, second.errors.size)
        assertFalse(second.errors.single().message!!.contains("fixture-sensitive-value"))
    }
}
