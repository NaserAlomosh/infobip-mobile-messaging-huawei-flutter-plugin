package com.infobip.mobilemessaging.huawei.rtc

/** Fixed vocabulary only: never accept exception text, identities, tokens or SDK payloads. */
internal enum class IncomingDiagnosticCode {
    start_received, start_rejected_arguments, start_rejected_foreground, start_rejected_busy,
    start_reused, identity_resolution_started, identity_resolution_returned, identity_resolution_failed,
    token_request_started, token_request_returned, token_request_failed, preparation_result_discarded,
    registration_preflight, singleton_mode_unobservable, singleton_reference_changed,
    singleton_reference_unchanged_prior_registration_possible, singleton_observation_failed,
    registration_invoked, registration_returned_readiness_unconfirmed, registration_threw,
    idle_connection_authentication_unobservable, peer_family_unobserved,
    invitation_callback, duplicate_invitation_ignored, rejected_invalidated, rejected_not_started,
    rejected_screen_hidden, rejected_host_unready, rejected_pending_invitation, rejected_call_slot_busy,
    rejection_decline_returned, rejection_decline_failed, invitation_published, invitation_listener_failed,
    accept_requested, accept_adoption_failed, accept_returned, accept_failed,
    decline_requested, decline_returned, decline_failed, call_error, call_reconnecting,
    call_reconnected, call_established, call_finished, experiment_invalidated,
    screen_closed, event_sink_attached, event_sink_detached, event_sink_write_returned,
    event_sink_write_failed,
}

/** Bounded process memory, serialized only in a debuggable host. Main-thread confined. */
internal class IncomingDiagnostics(val enabled: Boolean) {
    private val entries = ArrayDeque<Map<String, Any>>()
    var sequence = 0L
        private set

    fun record(code: IncomingDiagnosticCode, timestamp: Long = System.currentTimeMillis(), errorCode: Int? = null) {
        if (!enabled) return
        val entry = mutableMapOf<String, Any>(
            "sequence" to ++sequence, "timestampMillis" to timestamp, "event" to code.name,
        )
        if (errorCode != null) entry["errorCode"] = errorCode
        entries.addLast(entry)
        if (entries.size > 100) entries.removeFirst()
    }

    fun snapshot(): List<Map<String, Any>> = entries.toList()
}
