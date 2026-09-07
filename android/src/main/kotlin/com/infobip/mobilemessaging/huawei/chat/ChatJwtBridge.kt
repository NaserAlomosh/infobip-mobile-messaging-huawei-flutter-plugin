package com.infobip.mobilemessaging.huawei.chat

import java.util.UUID

internal interface ChatJwtCallback {
    fun onJwtReady(jwt: String)
    fun onJwtError(error: Throwable)
}

internal class ChatJwtBridge(
    private val requestDartJwt: (String, Long) -> Boolean,
) {
    private data class PendingJwtRequest(val generation: Long, val callback: ChatJwtCallback)
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
        val requestId = UUID.randomUUID().toString()
        pending[requestId] = PendingJwtRequest(generation, callback)
        if (!runCatching { requestDartJwt(requestId, generation) }.getOrDefault(false)) {
            pending.remove(requestId)?.callback?.onJwtError(IllegalStateException(PROVIDER_UNAVAILABLE))
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
        return pending.remove(requestId)
    }

    @Synchronized
    fun clear() {
        enabled = false
        generation++
        val invalidated = pending.values.toList()
        pending.clear()
        invalidated.forEach { runCatching { it.callback.onJwtError(IllegalStateException(PROVIDER_UNAVAILABLE)) } }
    }

    @Synchronized
    internal fun pendingCount(): Int = pending.size

    private companion object {
        const val PROVIDER_UNAVAILABLE = "Chat JWT provider is unavailable"
        const val JWT_UNAVAILABLE = "Unable to provide Chat JWT"
    }
}
