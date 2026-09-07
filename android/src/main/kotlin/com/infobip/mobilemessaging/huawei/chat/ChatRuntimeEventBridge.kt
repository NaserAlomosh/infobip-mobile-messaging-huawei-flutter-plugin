package com.infobip.mobilemessaging.huawei.chat

internal class ChatRuntimeEventBridge(
    private val capacity: Int = DEFAULT_CAPACITY,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private val pending = ArrayDeque<Map<String, Any?>>()
    private var ready = false
    private var disposed = false

    fun publish(event: Map<String, Any?>) {
        if (disposed) return
        if (ready) {
            emit(event)
            return
        }
        if (pending.size == capacity) pending.removeFirst()
        pending.addLast(event)
    }

    fun publishResult(
        successful: Boolean,
        event: Map<String, Any?>,
        onFailure: () -> Unit,
    ) {
        if (successful) publish(event) else onFailure()
    }

    fun ready() {
        if (disposed || ready) return
        ready = true
        while (pending.isNotEmpty()) emit(pending.removeFirst())
    }

    fun dispose() {
        disposed = true
        pending.clear()
    }

    companion object {
        const val DEFAULT_CAPACITY = 32
    }
}
