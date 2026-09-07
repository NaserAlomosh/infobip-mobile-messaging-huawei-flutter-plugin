package com.infobip.mobilemessaging.huawei.plugin

internal class PendingTapStore {
    private var pending: Map<String, Any?>? = null
    private var listener: ((Map<String, Any?>) -> Unit)? = null

    @Synchronized
    fun save(event: Map<String, Any?>) {
        val current = listener
        if (current == null) pending = event else current(event)
    }

    @Synchronized
    fun listen(observer: (Map<String, Any?>) -> Unit) {
        listener = observer
        take()?.let(observer)
    }

    @Synchronized
    fun cancel(observer: (Map<String, Any?>) -> Unit) {
        if (listener === observer) listener = null
    }

    @Synchronized
    fun take(): Map<String, Any?>? = pending.also { pending = null }

    @Synchronized
    fun clear() {
        pending = null
    }
}
