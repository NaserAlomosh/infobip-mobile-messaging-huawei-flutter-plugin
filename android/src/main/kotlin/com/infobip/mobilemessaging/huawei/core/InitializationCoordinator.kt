package com.infobip.mobilemessaging.huawei.core

import com.infobip.mobilemessaging.huawei.webrtc.WebRtcConfiguration

internal data class InitializationError(
    val code: String,
    val message: String,
    val details: Map<String, Any?>? = null,
)

internal class InitializationCoordinator(
    private val start: (String, Boolean, WebRtcConfiguration?, (InitializationError?) -> Unit) -> Unit,
    private val afterSuccess: (WebRtcConfiguration?) -> Unit = {},
) {
    internal enum class State { NOT_INITIALIZED, INITIALIZING, INITIALIZED, FAILED }

    private var state = State.NOT_INITIALIZED
    private var applicationCode: String? = null
    private var attempt = 0
    private var pendingWebRtcConfiguration: WebRtcConfiguration? = null
    private val callbacks = mutableListOf<(InitializationError?) -> Unit>()

    val isInitialized: Boolean
        get() = synchronized(this) { state == State.INITIALIZED }

    fun reset() {
        synchronized(this) {
            state = State.NOT_INITIALIZED
            applicationCode = null
            attempt++
            callbacks.clear()
            pendingWebRtcConfiguration = null
        }
    }

    fun initialize(
        code: String,
        callback: (InitializationError?) -> Unit,
    ) = initialize(code, true, null, callback)

    fun initialize(
        code: String,
        defaultMessageStorage: Boolean,
        webRtcConfiguration: WebRtcConfiguration? = null,
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
                        pendingWebRtcConfiguration = webRtcConfiguration
                        attemptToStart = attempt
                    }
                }
            }
        }
        if (shouldCompleteImmediately) callback(immediateError)
        attemptToStart?.let { currentAttempt ->
            start(code, defaultMessageStorage, webRtcConfiguration) { error ->
                complete(currentAttempt, error)
            }
        }
    }

    private fun complete(
        completedAttempt: Int,
        error: InitializationError?,
    ) {
        val pending: List<(InitializationError?) -> Unit>
        val webRtcConfiguration: WebRtcConfiguration?
        synchronized(this) {
            if (state != State.INITIALIZING || completedAttempt != attempt) return
            state = if (error == null) State.INITIALIZED else State.FAILED
            pending = callbacks.toList()
            callbacks.clear()
            webRtcConfiguration = pendingWebRtcConfiguration
            pendingWebRtcConfiguration = null
        }
        if (error == null) {
            try {
                afterSuccess(webRtcConfiguration)
            } catch (_: Exception) {
                // Optional integrations must not change Mobile Messaging initialization state.
            }
        }
        pending.forEach { it(error) }
    }
}
