package com.infobip.mobilemessaging.huawei.rtc

import com.infobip.webrtc.sdk.api.exception.IllegalStatusException
import com.infobip.webrtc.sdk.api.exception.MissingPermissionsException
import com.infobip.webrtc.sdk.api.exception.CallInProgressException
import com.infobip.webrtc.sdk.api.exception.InvalidTokenException
import com.infobip.webrtc.sdk.api.exception.ExpiredTokenException

internal class RtcFailure(val code: String, override val message: String) : Exception(message) {
    companion object {
        fun native(error: Exception): RtcFailure = when (error) {
            is RtcFailure -> error
            is CallInProgressException ->
                RtcFailure("rtc_call_already_active", "Another RTC call is active")
            is InvalidTokenException, is ExpiredTokenException ->
                RtcFailure("rtc_token_failed", "RTC rejected the access token")
            is MissingPermissionsException, is SecurityException ->
                RtcFailure("rtc_permission_denied", "Grant the required call permissions before calling")
            is IllegalStatusException, is IllegalStateException ->
                RtcFailure("rtc_invalid_state", "RTC cannot perform this operation in its current state")
            is IllegalArgumentException ->
                RtcFailure("rtc_invalid_argument", "RTC rejected the call arguments")
            else -> RtcFailure("rtc_call_failed", "RTC could not perform the call operation")
        }
    }
}

// Never make this a data class: its generated toString would include the identity.
internal class RtcInput(val callsConfigurationId: String, val type: String, val identity: String?) {
    val video: Boolean get() = type == "video"

    companion object {
        fun decode(arguments: Any?): RtcInput {
            val data = arguments as? Map<*, *> ?: invalid()
            val configuration = data["callsConfigurationId"] as? String ?: invalid()
            val type = data["type"] as? String ?: invalid()
            val identity = data["identity"]
            if (configuration.isBlank() || type !in setOf("audio", "video") ||
                (identity != null && (identity !is String || identity.isBlank()))) invalid()
            return RtcInput(configuration, type, identity as? String)
        }

        private fun invalid(): Nothing = throw RtcFailure(
            "rtc_invalid_argument",
            "Provide a Calls configuration ID, audio or video type, and an optional nonblank identity",
        )
    }
}

/** Main-thread reservation also covers token acquisition across multiple Flutter engines. */
internal class RtcCallSlot {
    private var owner: Any? = null
    fun acquire(candidate: Any): Boolean {
        if (owner != null) return false
        owner = candidate
        return true
    }
    fun release(candidate: Any) {
        if (owner === candidate) owner = null
    }

    companion object { val process = RtcCallSlot() }
}
