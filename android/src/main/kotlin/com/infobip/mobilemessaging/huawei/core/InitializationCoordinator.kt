package com.infobip.mobilemessaging.huawei.core

internal data class InitializationError(
    val code: String,
    val message: String,
    val details: Map<String, Any?>? = null,
)

internal class InitializationCoordinator(
    private val start: (String, Boolean, (InitializationError?) -> Unit) -> Unit,
    private val afterSuccess: () -> Unit = {},
) {
    internal enum class State { NOT_INITIALIZED, INITIALIZING, INITIALIZED, FAILED }

    private var state = State.NOT_INITIALIZED
    private var applicationCode: String? = null
    private var attempt = 0
    private val callbacks = mutableListOf<(InitializationError?) -> Unit>()

    val isInitialized: Boolean
        get() = synchronized(this) { state == State.INITIALIZED }

    fun reset() {
        synchronized(this) {
            state = State.NOT_INITIALIZED
            applicationCode = null
            attempt++
            callbacks.clear()
        }
    }

    fun initialize(
        code: String,
        callback: (InitializationError?) -> Unit,
    ) = initialize(code, true, callback)

    fun initialize(
        code: String,
        defaultMessageStorage: Boolean,
        callback: (InitializationError?) -> Unit,
    ) {
        var attemptToStart: Int? = null
        var shouldCompleteImmediately = false
        var immediateError: InitializationError? = null
        synchronized(this) {
            if (applicationCode != null && applicationCode != code) {
                shouldCompleteImmediately = true
                immediateError =
                    InitializationError(
                        "already_initialized",
                        "Initialization already started with a different application code",
                    )
            } else {
                when (state) {
                    State.INITIALIZED -> {
                        shouldCompleteImmediately = true
                    }

                    State.INITIALIZING -> {
                        callbacks += callback
                    }

                    State.NOT_INITIALIZED, State.FAILED -> {
                        if (applicationCode == null) applicationCode = code
                        state = State.INITIALIZING
                        callbacks += callback
                        attempt++
                        attemptToStart = attempt
                    }
                }
            }
        }
        if (shouldCompleteImmediately) callback(immediateError)
        attemptToStart?.let { currentAttempt ->
            start(code, defaultMessageStorage) { error -> complete(currentAttempt, error) }
        }
    }

    private fun complete(
        completedAttempt: Int,
        error: InitializationError?,
    ) {
        val pending: List<(InitializationError?) -> Unit>
        synchronized(this) {
            if (state != State.INITIALIZING || completedAttempt != attempt) return
            state = if (error == null) State.INITIALIZED else State.FAILED
            pending = callbacks.toList()
            callbacks.clear()
        }
        if (error == null) {
            try {
                afterSuccess()
            } catch (_: Exception) {
                // Optional integrations must not change Mobile Messaging initialization state.
            }
        }
        pending.forEach { it(error) }
    }
}
