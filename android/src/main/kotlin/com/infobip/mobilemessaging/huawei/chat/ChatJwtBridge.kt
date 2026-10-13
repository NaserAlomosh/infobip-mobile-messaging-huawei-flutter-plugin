package com.infobip.mobilemessaging.huawei.chat

import java.util.UUID
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.TimeUnit

internal interface ChatJwtCallback {
    fun onJwtReady(jwt: String)
    fun onJwtError(error: Throwable)
}

internal class ChatJwtBridge(
    private val timeoutMs: Long = 30_000,
    private val now: () -> Long = { System.nanoTime() / 1_000_000 },
    private val schedule: (Long, () -> Unit) -> (() -> Unit) = ChatJwtDeadline::schedule,
    private val requestDartJwt: (String, Long) -> Boolean,
) {
    private class PendingJwtRequest(val generation: Long, val callback: ChatJwtCallback, val deadline: Long) {
        var cancel: (() -> Unit)? = null
    }
    private val pending = mutableMapOf<String, PendingJwtRequest>()
    private var generation = 0L
    private var enabled = false

    @Synchronized
    fun enable(): Long {
        clear()
        enabled = true
        return generation
    }

    @Synchronized
    fun isCurrent(value: Long): Boolean = enabled && generation == value

    @Synchronized
    fun request(callback: ChatJwtCallback, providerGeneration: Long = generation) {
        if (!isCurrent(providerGeneration)) {
            callback.onJwtError(IllegalStateException(PROVIDER_UNAVAILABLE))
            return
        }
        if (pending.size >= 32) {
            callback.onJwtError(IllegalStateException(JWT_UNAVAILABLE))
            return
        }
        val requestId = UUID.randomUUID().toString()
        val request = PendingJwtRequest(generation, callback, now() + timeoutMs)
        pending[requestId] = request
        try {
            request.cancel = schedule(timeoutMs) { expire(requestId) }
        } catch (_: Exception) {
            remove(requestId)?.callback?.onJwtError(IllegalStateException(JWT_UNAVAILABLE))
            return
        }
        if (!runCatching { requestDartJwt(requestId, generation) }.getOrDefault(false)) {
            remove(requestId)?.callback?.onJwtError(IllegalStateException(PROVIDER_UNAVAILABLE))
        }
    }

    @Synchronized
    fun resolve(requestId: Any?, responseGeneration: Any?, jwt: Any?): Boolean {
        val value = (jwt as? String)?.trim()
        if (value.isNullOrEmpty()) return false
        val request = take(requestId, responseGeneration) ?: return false
        request.callback.onJwtReady(value)
        return true
    }

    @Synchronized
    fun reject(requestId: Any?, responseGeneration: Any?): Boolean {
        val request = take(requestId, responseGeneration) ?: return false
        // Never forward a provider's exception text: it may contain credentials.
        request.callback.onJwtError(IllegalStateException(JWT_UNAVAILABLE))
        return true
    }

    private fun take(requestId: Any?, responseGeneration: Any?): PendingJwtRequest? {
        if (requestId !is String || (responseGeneration !is Long && responseGeneration !is Int)) return null
        val request = pending[requestId] ?: return null
        if (!isCurrent(request.generation) || (responseGeneration as Number).toLong() != request.generation) return null
        if (now() >= request.deadline) { expire(requestId); return null }
        return remove(requestId)
    }

    private fun remove(id: String): PendingJwtRequest? = pending.remove(id)?.also { it.cancel?.invoke() }

    @Synchronized
    private fun expire(id: String) {
        remove(id)?.let { runCatching { it.callback.onJwtError(IllegalStateException("Chat JWT request timed out")) } }
    }

    @Synchronized
    fun clear() {
        enabled = false
        generation++
        val invalidated = pending.values.toList()
        pending.clear()
        invalidated.forEach {
            it.cancel?.invoke()
            runCatching { it.callback.onJwtError(IllegalStateException(PROVIDER_UNAVAILABLE)) }
        }
    }

    @Synchronized
    internal fun pendingCount(): Int = pending.size

    private companion object {
        const val PROVIDER_UNAVAILABLE = "Chat JWT provider is unavailable"
        const val JWT_UNAVAILABLE = "Unable to provide Chat JWT"
    }
}

/** One process-wide daemon; cancellation removes queued work and its callback references. */
private object ChatJwtDeadline {
    private val executor = ScheduledThreadPoolExecutor(1) { task ->
        Thread(task, "HuaweiChatJwtDeadline").apply { isDaemon = true }
    }.apply { removeOnCancelPolicy = true }

    fun schedule(delayMs: Long, action: () -> Unit): () -> Unit {
        val task = executor.schedule({ action() }, delayMs, TimeUnit.MILLISECONDS)
        return { task.cancel(false); Unit }
    }
}
