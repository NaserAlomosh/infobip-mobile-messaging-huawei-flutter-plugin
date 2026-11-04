package com.infobip.mobilemessaging.huawei.chat

import org.junit.Assert.*
import org.junit.Test

class ChatNotificationNavigationTest {
    @Test fun `first conversation without thread remains pending with no engine until explicit ack`() {
        val queue = ChatNotificationNavigation()
        val first = queue.enqueue("first-push", null)!!
        assertNull(first.threadId)
        assertEquals(first, queue.peek())
        assertEquals(first, queue.peek())
        val delivered = mutableListOf<ChatNavigationRequest>()
        val observer: (ChatNavigationRequest) -> Unit = delivered::add
        queue.listen(observer)
        queue.cancel(observer)
        queue.listen(observer)
        assertEquals(listOf(first, first), delivered)
        assertEquals(first, queue.peek())
        assertFalse(queue.acknowledge("unknown"))
        assertTrue(queue.acknowledge(first.correlationId))
        assertNull(queue.peek())
        assertFalse(queue.acknowledge(first.correlationId))
    }
    @Test fun `duplicates preserve original correlation and first valid tap is never suppressed`() {
        val queue = ChatNotificationNavigation()
        val first = queue.enqueue("same-push", "existing-thread")!!
        assertEquals(first, queue.enqueue("same-push", "existing-thread"))
        assertEquals("existing-thread", queue.peek()!!.threadId)
        queue.acknowledge(first.correlationId)
        assertNull(queue.enqueue("same-push", "existing-thread"))
        val next = queue.enqueue("new-push", "existing-thread")!!
        assertNotEquals(first.correlationId, next.correlationId)
        assertEquals(next, queue.peek())
    }
    @Test fun `repeated distinct taps are queued rather than overwriting an unhandled request`() {
        val queue = ChatNotificationNavigation()
        val requests = (1..10).map { queue.enqueue("push-$it", "thread-$it")!! }
        for (request in requests) {
            assertEquals(request, queue.peek())
            assertTrue(queue.acknowledge(request.correlationId))
        }
        assertNull(queue.peek())
    }
    @Test fun `cleanup removes pending requests and does not retain previous identity deduplication`() {
        val queue = ChatNotificationNavigation()
        queue.enqueue("push", "thread")
        queue.clear()
        assertNull(queue.peek())
        assertNotNull(queue.enqueue("push", null))
    }
}
