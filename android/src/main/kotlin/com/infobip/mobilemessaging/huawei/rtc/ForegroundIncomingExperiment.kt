package com.infobip.mobilemessaging.huawei.rtc

import android.content.pm.ApplicationInfo
import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import org.infobip.mobile.messaging.Event
import android.os.Handler
import android.os.Looper
import com.infobip.webrtc.sdk.api.InfobipRTC
import com.infobip.webrtc.sdk.api.call.IncomingApplicationCall
import com.infobip.webrtc.sdk.api.event.listener.IncomingApplicationCallEventListener
import com.infobip.webrtc.sdk.api.model.CallStatus
import com.infobip.webrtc.sdk.api.options.ApplicationCallOptions
import io.flutter.plugin.common.EventChannel
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.logging.Level

/** EXPERIMENTAL. Main-thread state, process-owned signaling. No unregister/reset API exists. */
internal class ForegroundIncomingExperiment(
    private val identities: LiveChatIdentityResolver,
    private val tokens: RtcTokenProvider,
    private val register: (String, IncomingApplicationCallEventListener) -> Unit,
    private val hasActiveCall: () -> Boolean,
    private val slot: RtcCallSlot = RtcCallSlot.process,
    private val worker: ExecutorService = Executors.newSingleThreadExecutor(),
    private val main: Handler = Handler(Looper.getMainLooper()),
    diagnosticsEnabled: Boolean = false,
    private val singleton: (() -> Any)? = null,
    private val ringtone: IncomingRingtone = IncomingRingtone.None,
) : EventChannel.StreamHandler {
    interface Host {
        fun ready(): Boolean
        fun reap(call: IncomingApplicationCall)
        fun adopt(call: IncomingApplicationCall, video: Boolean, reservation: Any): Map<String, Any?>
    }
    private class Invitation(val call: IncomingApplicationCall) {
        val handle = UUID.randomUUID().toString()
        var accepted = false
        var ending = false
        var listener: RtcListener? = null
    }
    private var host: Host? = null
    private var sink: EventChannel.EventSink? = null
    private var started = false
    private var invalid = false
    private var visible = false
    private var epoch: Long? = null
    private var identity: ResolvedChatIdentity? = null
    private var widget: String? = null
    private var expectedUser: String? = null
    private var invitation: Invitation? = null
    private var phase = "idle"
    private var reason: String? = null
    private var registrationAttempted = false
    private val diagnostics = IncomingDiagnostics(diagnosticsEnabled)
    private var deliveredSequence = 0L
    private fun trace(code: IncomingDiagnosticCode, errorCode: Int? = null) {
        if (!diagnostics.enabled) return
        val timestamp = System.currentTimeMillis()
        if (Looper.myLooper() == main.looper) diagnostics.record(code, timestamp, errorCode)
        else main.post { diagnostics.record(code, timestamp, errorCode) }
    }
    private fun callTrace(type: String, code: Int?) {
        val event = when (type) {
            "error" -> IncomingDiagnosticCode.call_error
            "reconnecting" -> IncomingDiagnosticCode.call_reconnecting
            "reconnected" -> IncomingDiagnosticCode.call_reconnected
            "established" -> IncomingDiagnosticCode.call_established
            "finished" -> IncomingDiagnosticCode.call_finished
            else -> return
        }
        trace(event, code)
    }
    private fun observeSingleton(): Any? {
        if (!diagnostics.enabled) return null
        return try { singleton?.invoke() } catch (_: Exception) {
            trace(IncomingDiagnosticCode.singleton_observation_failed); null
        }
    }
    // Strong process reference, including after engine detach. Never captures an Activity.
    val incomingListener = IncomingApplicationCallEventListener { event ->
        main.post { receive(event.incomingApplicationCall) }
    }
    private val watch = object : Runnable {
        override fun run() {
            if (!started) return
            if (!invalid) validateOrInvalidate()
            val current = invitation
            if (current == null || current.accepted || current.ending || invalid || !visible ||
                host?.ready() != true || current.call.status() in listOf(
                    CallStatus.FINISHING, CallStatus.FINISHED, CallStatus.ESTABLISHED, CallStatus.CONNECTING)) ringtone.stop()
            ringtone.update()
            if (current != null && current.call.status() == CallStatus.FINISHED) {
                if (current.accepted) host?.reap(current.call)
                terminal(current, "sdk_finished")
            }
            else if (current != null && (!visible || host?.ready() != true)) endPresentation()
            publish()
            // Invalid experiments still reap terminal reservations, without reconnecting signaling.
            if (!invalid || invitation != null) main.postDelayed(this, 250)
        }
    }
    private val timeout = Runnable {
        if (phase == "preparing") invalidate("preparation_timeout")
    }

    fun attach(value: Host) {
        if (started && host != null && host !== value) invalidate("engine_replaced")
        host = value
    }
    fun detach() {
        ringtone.stop()
        if (started) invalidate("engine_detached")
        sink = null
        host = null
    }
    /** Media manager has released renderers/listeners. Keep an uncertain native call reserved. */
    fun retainAfterEngineDetach(call: IncomingApplicationCall) {
        val current = invitation?.takeIf { it.call === call } ?: return
        if (call.status() == CallStatus.FINISHED) { terminal(current, "sdk_finished"); return }
        check(slot.acquire(this))
        current.accepted = false
        val listener = RtcListener { type, code -> main.post {
            if (type == "finished") terminal(current, "sdk_hangup_${code ?: 0}")
        } }
        current.listener = listener
        try { call.setEventListener(listener) } catch (_: Exception) { /* Status polling retains ownership. */ }
        main.removeCallbacks(watch)
        main.postDelayed(watch, 250)
    }
    /** Activity pause/detach must silence playback without changing outgoing media or signaling. */
    fun stopRinging() { ringtone.stop() }

    fun closeScreen() { trace(IncomingDiagnosticCode.screen_closed); visible = false; endPresentation(); publish() }

    fun start(widgetId: String, user: String): Map<String, Any?> {
        trace(IncomingDiagnosticCode.start_received)
        if (widgetId.isBlank() || user.isBlank()) {
            trace(IncomingDiagnosticCode.start_rejected_arguments); publish()
            fail("Provide the configured Chat widget and personalized user")
        }
        if (host?.ready() != true) {
            trace(IncomingDiagnosticCode.start_rejected_foreground); publish()
            fail("Initialize messaging and open a foreground RTC screen")
        }
        if (started) {
            if (widget != widgetId || expectedUser != user) invalidate("identity_changed")
            validateOrInvalidate()
            if (invalid) fail("Experiment invalidated; terminate the application process before retrying")
            visible = true
            trace(IncomingDiagnosticCode.start_reused)
            publish()
            return snapshot()
        }
        if (hasActiveCall() || !slot.acquire(this)) {
            trace(IncomingDiagnosticCode.start_rejected_busy); publish()
            throw RtcFailure("rtc_call_already_active", "Another RTC operation is active")
        }
        val captured = try { RtcIdentityLifecycle.capture() } catch (e: Exception) { slot.release(this); throw e }
        started = true
        visible = true
        widget = widgetId
        expectedUser = user
        epoch = captured
        phase = "preparing"
        publish()
        main.postDelayed(watch, 250)
        main.postDelayed(timeout, 30_000)
        try {
            worker.execute {
                val outcome = try {
                    trace(IncomingDiagnosticCode.identity_resolution_started)
                    val resolved = try { identities.resolve(widgetId, user) } catch (error: Exception) {
                        trace(IncomingDiagnosticCode.identity_resolution_failed); throw error
                    }
                    trace(IncomingDiagnosticCode.identity_resolution_returned)
                    trace(IncomingDiagnosticCode.token_request_started)
                    val token = try { tokens.fetch(resolved.subject) } catch (error: Exception) {
                        trace(IncomingDiagnosticCode.token_request_failed); throw error
                    }
                    trace(IncomingDiagnosticCode.token_request_returned)
                    Result.success(resolved to token)
                } catch (_: Exception) { Result.failure<Pair<ResolvedChatIdentity, String>>(IllegalStateException()) }
                main.post {
                    if (invalid) {
                        trace(IncomingDiagnosticCode.preparation_result_discarded); publish(); return@post
                    }
                    main.removeCallbacks(timeout)
                    try {
                        val (resolved, token) = outcome.getOrThrow()
                        identity = resolved
                        validateOrInvalidate()
                        if (invalid || host?.ready() != true || !visible) fail("Preparation no longer belongs to the foreground screen")
                        if (hasActiveCall()) throw RtcFailure("rtc_call_already_active", "Another RTC operation is active")
                        // Consume the only attempt before invoking SDK: a thrown call may have side effects.
                        trace(IncomingDiagnosticCode.registration_preflight)
                        // getInstance reference identity is public; SDK mode/token/listener are not.
                        trace(IncomingDiagnosticCode.singleton_mode_unobservable)
                        val before = observeSingleton()
                        registrationAttempted = true
                        trace(IncomingDiagnosticCode.registration_invoked)
                        try { register(token, incomingListener) } catch (error: Exception) {
                            trace(IncomingDiagnosticCode.registration_threw); throw error
                        }
                        if (before != null) {
                            val after = observeSingleton()
                            if (after != null) trace(if (before === after)
                                IncomingDiagnosticCode.singleton_reference_unchanged_prior_registration_possible
                            else IncomingDiagnosticCode.singleton_reference_changed)
                        }
                        trace(IncomingDiagnosticCode.registration_returned_readiness_unconfirmed)
                        trace(IncomingDiagnosticCode.idle_connection_authentication_unobservable)
                        trace(IncomingDiagnosticCode.peer_family_unobserved)
                        phase = "registrationRequested"
                        publish()
                    } catch (_: Exception) { invalidate("registration_failed") }
                    finally { slot.release(this) }
                }
            }
        } catch (_: Exception) { invalidate("preparation_failed"); slot.release(this) }
        return snapshot()
    }

    private fun validateOrInvalidate() {
        if (!started || invalid) return
        try { RtcIdentityLifecycle.validate(requireNotNull(epoch)); identity?.validate?.invoke() }
        catch (_: Exception) { invalidate("identity_changed") }
    }

    /** Public MM lifecycle broadcasts complement validation at each actionable boundary. */
    fun identitySignal(personalizationChanged: Boolean) {
        if (personalizationChanged) invalidate("identity_changed") else validateOrInvalidate()
    }

    fun invalidate(why: String) {
        ringtone.stop()
        if (!started || invalid) return
        trace(IncomingDiagnosticCode.experiment_invalidated)
        invalid = true
        visible = false
        phase = "invalidated"
        reason = why
        // No claim that active registration was removed; it remains owned by Core.
        identity = null
        expectedUser = null
        widget = null
        main.removeCallbacks(timeout)
        if (!registrationAttempted) slot.release(this)
        endPresentation()
        publish()
    }

    private fun receive(call: IncomingApplicationCall) {
        validateOrInvalidate()
        trace(IncomingDiagnosticCode.invitation_callback)
        val previous = invitation
        if (previous != null && (previous.call === call || previous.call.id() == call.id())) {
            trace(IncomingDiagnosticCode.duplicate_invitation_ignored); publish(); return
        }
        val rejection = when {
            invalid -> IncomingDiagnosticCode.rejected_invalidated
            !started -> IncomingDiagnosticCode.rejected_not_started
            !visible -> IncomingDiagnosticCode.rejected_screen_hidden
            host?.ready() != true -> IncomingDiagnosticCode.rejected_host_unready
            previous != null -> IncomingDiagnosticCode.rejected_pending_invitation
            !slot.acquire(this) -> IncomingDiagnosticCode.rejected_call_slot_busy
            else -> null
        }
        if (rejection != null) {
            trace(rejection)
            try { call.decline(); trace(IncomingDiagnosticCode.rejection_decline_returned) }
            catch (_: Exception) { trace(IncomingDiagnosticCode.rejection_decline_failed) }
            publish()
            return
        }
        val current = Invitation(call)
        invitation = current
        val listener = RtcListener { type, code -> main.post {
            if (invitation === current && !current.accepted) {
                callTrace(type, code)
                if (type in listOf("finished", "error", "established")) ringtone.stop()
                if (type == "finished") terminal(current, "sdk_hangup_${code ?: 0}")
                else if (type == "error") { reason = "sdk_error_${code ?: 0}"; publish() }
            }
        } }
        current.listener = listener
        try {
            call.setEventListener(listener)
            val status = call.status()
            if (status == CallStatus.FINISHED) terminal(current, "cancelled")
            else {
                phase = "invitation"
                reason = null
                if (status !in listOf(CallStatus.ESTABLISHED, CallStatus.FINISHING, CallStatus.CONNECTING)) ringtone.start()
                trace(IncomingDiagnosticCode.invitation_published)
                publish()
            }
        } catch (_: Exception) {
            trace(IncomingDiagnosticCode.invitation_listener_failed)
            phase = "failed"; reason = "listener_failed"; endPresentation(); publish()
        }
    }

    private fun valid(handle: String): Invitation {
        validateOrInvalidate()
        val current = invitation
        if (invalid || !visible || host?.ready() != true || phase != "invitation" || current == null ||
            current.handle != handle || current.accepted) fail("Invitation is stale or unavailable")
        if (current.call.status() in listOf(CallStatus.FINISHED, CallStatus.FINISHING)) {
            ringtone.stop()
            if (current.call.status() == CallStatus.FINISHED) terminal(current, "cancelled")
            fail("Invitation has ended")
        }
        return current
    }

    fun accept(handle: String, video: Boolean): Map<String, Any?> {
        val current = valid(handle)
        // Video is an explicit local camera choice, never inferred from incoming options.
        // Core exposes no public remote-offer media type.
        // Host validates permissions before transferring the slot and installing its existing listener.
        ringtone.stop() // Before manager adoption or SDK acceptance can begin media.
        trace(IncomingDiagnosticCode.accept_requested)
        val value = try { requireNotNull(host).adopt(current.call, video, this) } catch (error: Exception) {
            trace(IncomingDiagnosticCode.accept_adoption_failed); publish(); throw error
        }
        current.accepted = true
        current.listener?.detach()
        current.listener = null
        phase = "connecting"
        reason = null
        publish()
        try {
            current.call.accept(ApplicationCallOptions.builder().audio(true).video(video).autoReconnect(false).build())
            trace(IncomingDiagnosticCode.accept_returned); publish()
        } catch (error: Exception) {
            trace(IncomingDiagnosticCode.accept_failed)
            phase = "failed"
            reason = "accept_failed"
            try { current.call.hangup() } catch (_: Exception) { reason = "termination_unconfirmed" }
            publish()
            throw RtcFailure.native(error)
        }
        return value
    }

    fun decline(handle: String) {
        val current = valid(handle)
        ringtone.stop() // Stop even when native decline throws or termination is delayed.
        trace(IncomingDiagnosticCode.decline_requested)
        try { current.call.decline() } catch (error: Exception) {
            trace(IncomingDiagnosticCode.decline_failed); publish(); throw error
        }
        trace(IncomingDiagnosticCode.decline_returned)
        current.ending = true
        phase = "declining"
        publish() // void decline is not a terminal acknowledgment
    }

    fun callEvent(call: IncomingApplicationCall, type: String, code: Int?) {
        val current = invitation?.takeIf { it.call === call } ?: return
        callTrace(type, code)
        if (type in listOf("finished", "error", "established")) ringtone.stop()
        if (type == "finished") terminal(current, "sdk_hangup_${code ?: 0}")
        else if (!invalid) {
            phase = when (type) { "established" -> "connected"; "reconnecting" -> "reconnecting"; "reconnected" -> "connected"; else -> phase }
            if (type == "error") reason = "sdk_error_${code ?: 0}"
            publish()
        }
    }

    private fun endPresentation() {
        ringtone.stop()
        val current = invitation ?: return
        if (current.ending) return
        current.ending = true
        if (!invalid && phase !in listOf("declining", "ending", "failed")) phase = "ending"
        try { if (current.accepted) current.call.hangup() else current.call.decline() }
        catch (_: Exception) { reason = "termination_unconfirmed" }
    }

    private fun terminal(current: Invitation, why: String) {
        if (invitation !== current) return
        ringtone.stop()
        current.listener?.detach()
        if (!current.accepted) {
            try { current.call.setEventListener(RtcListener.detached) } catch (_: Exception) { }
            slot.release(this)
        }
        invitation = null
        if (!invalid) { phase = "ended"; reason = why }
        publish()
    }

    fun snapshot(): Map<String, Any?> {
        val current = invitation
        val display = !invalid && visible && host?.ready() == true && phase == "invitation"
        return buildMap {
            putAll(mapOf(
                "state" to if (!invalid && !visible && started) "paused" else phase,
                "handle" to current?.handle?.takeIf { display },
                "family" to "application",
                "audioSupported" to (current != null && !invalid),
                "videoSupported" to (current != null && !invalid),
                "offeredCallType" to "unknown",
                "registrationAttempted" to registrationAttempted,
                "reason" to reason,
            ))
            if (diagnostics.enabled) put("diagnostics", diagnostics.snapshot())
        }
    }

    private fun publish() {
        val target = sink ?: return
        try {
            val sequence = diagnostics.sequence
            target.success(snapshot())
            // Transport enqueue is not a Dart receipt acknowledgment. Do not trace every watchdog tick.
            if (sequence > deliveredSequence) {
                trace(IncomingDiagnosticCode.event_sink_write_returned)
                deliveredSequence = diagnostics.sequence
            }
        } catch (_: Exception) {
            trace(IncomingDiagnosticCode.event_sink_write_failed)
            sink = null
        }
    }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        validateOrInvalidate()
        sink = events
        trace(IncomingDiagnosticCode.event_sink_attached)
        publish()
    }
    override fun onCancel(arguments: Any?) { trace(IncomingDiagnosticCode.event_sink_detached); sink = null }
    private fun fail(message: String): Nothing = throw RtcFailure("rtc_invalid_state", message)

    companion object {
        const val EVENTS = "infobip_mobilemessaging_huawei/huawei_rtc/incoming_experiment"
        private var process: ForegroundIncomingExperiment? = null
        fun process(context: Context): ForegroundIncomingExperiment = process ?: run {
            val app = context.applicationContext
            ForegroundIncomingExperiment(NativeLiveChatIdentityResolver(app), HuaweiRtcTokenProvider(app),
                register = { token, listener ->
                    InfobipRTC.setLogLevel(Level.OFF)
                    InfobipRTC.getInstance().registerForActiveConnection(token, app, listener)
                }, hasActiveCall = { HuaweiRtcBackend(app).hasActiveCall() },
                diagnosticsEnabled = app.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0,
                singleton = { InfobipRTC.getInstance() },
                ringtone = AndroidIncomingRingtone(app)).also { experiment ->
                    process = experiment
                    LocalBroadcastManager.getInstance(app).registerReceiver(object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            experiment.identitySignal(intent?.action in setOf(Event.PERSONALIZED.key, Event.DEPERSONALIZED.key))
                        }
                    }, IntentFilter().apply {
                        addAction(Event.INSTALLATION_UPDATED.key)
                        addAction(Event.REGISTRATION_CREATED.key)
                        addAction(Event.USER_UPDATED.key)
                        addAction(Event.PERSONALIZED.key)
                        addAction(Event.DEPERSONALIZED.key)
                    })
                }
        }
    }
}
