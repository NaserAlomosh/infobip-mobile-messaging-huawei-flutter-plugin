package com.infobip.mobilemessaging.huawei.rtc

import android.os.Looper
import com.infobip.webrtc.sdk.api.call.ApplicationCall
import com.infobip.webrtc.sdk.api.call.IncomingApplicationCall
import com.infobip.webrtc.sdk.api.event.call.CallHangupEvent
import com.infobip.webrtc.sdk.api.event.call.CallEstablishedEvent
import com.infobip.webrtc.sdk.api.event.call.ErrorEvent
import com.infobip.webrtc.sdk.api.event.listener.ApplicationCallEventListener
import com.infobip.webrtc.sdk.api.event.listener.IncomingApplicationCallEventListener
import com.infobip.webrtc.sdk.api.event.rtc.IncomingApplicationCallEvent
import com.infobip.webrtc.sdk.api.model.CallStatus
import com.infobip.webrtc.sdk.api.model.ErrorCode
import com.infobip.webrtc.sdk.api.options.ApplicationCallOptions
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentCaptor
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Duration
import java.util.concurrent.AbstractExecutorService
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ForegroundIncomingExperimentTest {
    private class Work : AbstractExecutorService() {
        val tasks = mutableListOf<Runnable>()
        override fun execute(command: Runnable) { tasks += command }
        fun run() { tasks.toList().also { tasks.clear() }.forEach { it.run() } }
        override fun shutdown() { }
        override fun shutdownNow(): MutableList<Runnable> = mutableListOf()
        override fun isShutdown() = false
        override fun isTerminated() = false
        override fun awaitTermination(timeout: Long, unit: TimeUnit) = true
    }
    private val ringtone = mock(IncomingRingtone::class.java)
    private val work = Work()
    private val slot = RtcCallSlot()
    private var foreground = true
    private var permissionVideo: Boolean? = null
    private var permitted = true
    private var sameInstallation = true
    private var registrations = 0
    private var lookups = 0
    private var tokenSubject: String? = null
    private var failRegister = false
    private var failToken = false
    private var failIdentity = false
    private var singletonChanges = true
    private val originalSingleton = Any()
    private val activeSingleton = Any()
    private lateinit var incoming: IncomingApplicationCallEventListener
    private val experiment = ForegroundIncomingExperiment(
        identities = LiveChatIdentityResolver { widget, user ->
            assertEquals("widget", widget); assertEquals("external-private", user); lookups++
            if (failIdentity) throw IllegalStateException("registration-private token-private")
            ResolvedChatIdentity("registration-private") {
                if (!sameInstallation) throw IllegalStateException("private backend details")
            }
        },
        tokens = RtcTokenProvider {
            tokenSubject = it
            if (failToken) throw IllegalStateException("private token response")
            "token-private"
        },
        register = { token, listener ->
            assertEquals("token-private", token)
            registrations++; incoming = listener
            if (failRegister) throw IllegalStateException("private registration error")
        }, hasActiveCall = { false }, slot = slot, worker = work,
        diagnosticsEnabled = true,
        ringtone = ringtone,
        singleton = { if (singletonChanges && registrations > 0) activeSingleton else originalSingleton },
    )
    private val manager = HuaweiRtcManager(
        initialized = { true }, canStartCall = { foreground },
        permissions = { video -> permissionVideo = video; if (!permitted) throw RtcFailure("rtc_permission_denied", "Permission denied") },
        tokens = RtcTokenProvider { "outgoing-token" },
        backend = object : RtcBackend {
            override fun hasActiveCall() = false
            override fun call(token: String, input: RtcInput, listener: RtcListener): ApplicationCall = error("Should not submit")
        }, executor = work, slot = slot, incomingExperiment = experiment,
    )
    private val events = mutableListOf<Any?>()
    private val sink = object : EventChannel.EventSink {
        override fun success(event: Any?) { events += event }
        override fun error(code: String, message: String?, details: Any?) { fail(code) }
        override fun endOfStream() { }
    }
    private var status = CallStatus.RINGING
    private var listener: ApplicationCallEventListener? = null
    private fun call(id: String = "call-native") = mock(IncomingApplicationCall::class.java).also {
        `when`(it.id()).thenReturn(id)
        `when`(it.status()).thenAnswer { status }
        doAnswer { args -> listener = args.getArgument(0); null }.`when`(it).setEventListener(any())
    }
    private fun idle() = shadowOf(Looper.getMainLooper()).idle()
    private fun tick() = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(251))
    private fun start() { experiment.start("widget", "external-private"); work.run(); idle() }
    private fun receive(call: IncomingApplicationCall) {
        incoming.onIncomingApplicationCall(IncomingApplicationCallEvent(call, mapOf("secret" to "custom-private")))
        idle()
    }
    private fun handle() = experiment.snapshot()["handle"] as String
    private fun state() = experiment.snapshot()["state"]
    private fun rejected(block: () -> Unit) {
        try { block(); fail("Expected rejection") } catch (_: RtcFailure) { }
    }
    @After fun dispose() { manager.dispose(); status = CallStatus.FINISHED; tick() }

    @Test fun `once only registration uses resolved Chat subject and no credentials reach sinks`() {
        experiment.onListen(null, sink)
        start()
        repeat(3) { experiment.start("widget", "external-private") }
        assertEquals(1, registrations); assertEquals(1, lookups)
        assertEquals("registration-private", tokenSubject)
        assertEquals("registrationRequested", state())
        receive(call())
        val output = events.toString()
        listOf("registration-private", "external-private", "token-private", "custom-private", "widget").forEach {
            assertFalse(output.contains(it))
        }
        assertEquals(true, experiment.snapshot()["registrationAttempted"])
    }
    @Test fun `late listener gets current invitation and opaque handle`() {
        start(); val call = call(); receive(call)
        val handle = handle()
        assertNotEquals(call.id(), handle)
        experiment.onListen(null, sink)
        assertEquals(handle, (events.last() as Map<*, *>)["handle"])
        experiment.onCancel(null)
        experiment.onListen(null, sink)
        assertEquals(handle, (events.last() as Map<*, *>)["handle"])
    }
    @Test fun `audio acceptance adopts existing manager controls and terminal cleanup releases slot`() {
        start(); val call = call(); receive(call)
        val value = experiment.accept(handle(), false)
        assertEquals("call-native", value["id"])
        val options = ArgumentCaptor.forClass(ApplicationCallOptions::class.java)
        verify(call).accept(options.capture())
        assertTrue(options.value.isAudio); assertFalse(options.value.isVideo); assertFalse(options.value.isAutoReconnect)
        assertEquals("connecting", state())
        status = CallStatus.ESTABLISHED
        listener!!.onEstablished(mock(CallEstablishedEvent::class.java)); idle()
        assertEquals("connected", state())
        manager.onMethodCall(MethodCall("setMicrophoneMuted", mapOf("callId" to "call-native", "enabled" to true)), Reply())
        verify(call).mute(true)
        status = CallStatus.FINISHED
        listener!!.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        assertEquals("ended", state())
        assertTrue(slot.acquire(this)); slot.release(this)
        verify(call, atLeastOnce()).setEventListener(RtcListener.detached)
    }
    @Test fun `decline waits for SDK terminal and permits repeated calls for same identity`() {
        start(); val call = call(); receive(call)
        experiment.decline(handle())
        verify(call).decline()
        assertEquals("declining", state()); assertFalse(slot.acquire(this))
        status = CallStatus.FINISHED; listener!!.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        status = CallStatus.RINGING; receive(call("second"))
        assertEquals("invitation", state()); assertEquals(1, registrations)
    }
    @Test fun `stale actions cannot accept and offer type remains unknown`() {
        start(); val call = call(); receive(call)
        rejected { experiment.accept("old-handle", false) }
        rejected { experiment.decline("old-handle") }
        verify(call, never()).accept(any(ApplicationCallOptions::class.java))
        assertEquals(true, experiment.snapshot()["videoSupported"])
        assertEquals("unknown", experiment.snapshot()["offeredCallType"])
    }
    @Test fun `explicit video acceptance uses shared manager and video options`() {
        start(); val call = call(); receive(call)
        val value = experiment.accept(handle(), true)
        assertEquals("video", value["type"])
        assertEquals(true, permissionVideo)
        val options = ArgumentCaptor.forClass(ApplicationCallOptions::class.java)
        verify(call).accept(options.capture())
        assertTrue(options.value.isVideo); assertTrue(options.value.isAudio)
        verify(ringtone, atLeastOnce()).stop()
        assertEquals("connecting", state())
    }
    @Test fun `video permission denial leaves invitation pending without SDK acceptance`() {
        start(); val call = call(); receive(call); val old = handle()
        permitted = false
        rejected { experiment.accept(old, true) }
        verify(call, never()).accept(any(ApplicationCallOptions::class.java))
        assertEquals(old, handle()); assertEquals("invitation", state())
        permitted = true
        experiment.accept(old, true)
        verify(call).accept(any(ApplicationCallOptions::class.java))
    }
    @Test fun `video initialization exception requests hangup without audio fallback`() {
        start(); val call = call(); receive(call)
        doThrow(IllegalStateException("camera unavailable")).`when`(call).accept(any(ApplicationCallOptions::class.java))
        rejected { experiment.accept(handle(), true) }
        verify(call).hangup()
        verify(call, times(1)).accept(any(ApplicationCallOptions::class.java))
        assertFalse(slot.acquire(this)); assertEquals("failed", state())
        status = CallStatus.FINISHED
        listener!!.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        assertTrue(slot.acquire(this)); slot.release(this)
    }
    @Test fun `video cancellation duplicate delivery and consecutive audio retain ownership rules`() {
        start(); val first = call(); receive(first); val old = handle()
        receive(first)
        verify(first, never()).decline()
        experiment.accept(old, true)
        val conflicting = call("conflicting")
        receive(conflicting); verify(conflicting).decline()
        rejected { experiment.accept(old, true) }
        status = CallStatus.FINISHED
        listener!!.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        status = CallStatus.RINGING
        val second = call("second"); receive(second)
        rejected { experiment.accept(old, true) }
        val value = experiment.accept(handle(), false)
        assertEquals("audio", value["type"]); assertEquals(false, permissionVideo)
        val options = ArgumentCaptor.forClass(ApplicationCallOptions::class.java)
        verify(second).accept(options.capture()); assertFalse(options.value.isVideo)
        assertEquals(1, registrations)
    }
    @Test fun `remote cancellation before acceptance invalidates the handle`() {
        start(); receive(call()); val old = handle()
        status = CallStatus.FINISHED
        listener!!.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        assertEquals("ended", state()); rejected { experiment.accept(old, false) }
        assertTrue(slot.acquire(this)); slot.release(this)
    }
    @Test fun `cancellation during accept is handled by adopted listener`() {
        start(); val call = call(); receive(call)
        doAnswer { status = CallStatus.FINISHED; listener!!.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); null }
            .`when`(call).accept(any(ApplicationCallOptions::class.java))
        experiment.accept(handle(), false); idle()
        assertEquals("ended", state()); assertTrue(slot.acquire(this)); slot.release(this)
    }
    @Test fun `duplicate callback does not decline current invitation and conflict is declined`() {
        start(); val call = call(); receive(call); val old = handle(); receive(call)
        receive(call("call-native")) // same SDK ID in another wrapper
        assertEquals(old, handle()); verify(call, never()).decline()
        val other = call("other"); receive(other)
        verify(other).decline(); assertEquals(old, handle())
    }
    @Test fun `incoming while outgoing owns slot declines without stealing ownership`() {
        start()
        val reply = Reply()
        manager.onMethodCall(MethodCall("callApplication", mapOf("callsConfigurationId" to "config", "type" to "audio")), reply)
        val call = call(); receive(call)
        verify(call).decline(); assertNull(experiment.snapshot()["handle"])
        assertFalse(slot.acquire(this))
    }
    @Test fun `registration cannot overlap outgoing preparation`() {
        val reply = Reply()
        manager.onMethodCall(MethodCall("callApplication", mapOf("callsConfigurationId" to "config", "type" to "audio")), reply)
        rejected { experiment.start("widget", "external-private") }
        assertEquals(0, registrations)
    }
    @Test fun `identity mutation rejects stale accept and decline immediately`() {
        start(); val call = call(); receive(call); val old = handle()
        manager.beginIdentityMutation(); manager.endIdentityMutation()
        assertEquals("invalidated", state()); assertNull(experiment.snapshot()["handle"])
        rejected { experiment.accept(old, false) }; rejected { experiment.decline(old) }
        rejected { experiment.start("widget", "external-private") }
        verify(call).decline(); assertEquals(1, registrations)
    }
    @Test fun `installation change detected without Flutter action`() {
        start(); receive(call()); sameInstallation = false; tick()
        assertEquals("invalidated", state()); assertNull(experiment.snapshot()["handle"])
    }
    @Test fun `different identity permanently invalidates experiment`() {
        start(); rejected { experiment.start("widget", "another-user") }
        assertEquals("invalidated", state()); assertEquals(1, registrations)
    }
    @Test fun `engine detachment rejects late callbacks and preserves registration attempt`() {
        start(); val call = call(); receive(call); val old = handle()
        manager.dispose()
        assertEquals("invalidated", state()); rejected { experiment.accept(old, false) }
        val late = call("late"); receive(late); verify(late).decline()
        assertEquals(true, experiment.snapshot()["registrationAttempted"])
    }
    @Test fun `screen disposal and background hide invitations and never re-register`() {
        start(); val call = call(); receive(call)
        foreground = false; tick(); verify(call).decline()
        assertNull(experiment.snapshot()["handle"])
        status = CallStatus.FINISHED; tick(); foreground = true
        experiment.closeScreen(); assertEquals("paused", state())
        experiment.start("widget", "external-private"); assertEquals(1, registrations)
    }
    @Test fun `accept failure keeps slot until actual termination`() {
        start(); val call = call(); receive(call)
        doThrow(IllegalStateException("private")).`when`(call).accept(any(ApplicationCallOptions::class.java))
        rejected { experiment.accept(handle(), false) }
        verify(call).hangup(); assertFalse(slot.acquire(this)); assertEquals("failed", state())
        status = CallStatus.FINISHED; listener!!.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        assertTrue(slot.acquire(this)); slot.release(this)
    }
    @Test fun `permissions checked before reservation handoff`() {
        start(); val call = call(); receive(call); permitted = false
        rejected { experiment.accept(handle(), false) }
        assertEquals("invitation", state()); verify(call, never()).accept(any(ApplicationCallOptions::class.java))
        permitted = true; experiment.decline(handle()); verify(call).decline()
    }
    @Test fun `registration errors cannot leak and cannot retry SDK subscription`() {
        failRegister = true; experiment.onListen(null, sink); start()
        assertEquals("invalidated", state()); assertEquals(1, registrations)
        rejected { experiment.start("widget", "external-private") }
        assertFalse(events.toString().contains("private"))
        assertTrue(slot.acquire(this)); slot.release(this)
    }
    @Test fun `token failure and preparation timeout never register`() {
        failToken = true; start(); assertEquals(0, registrations); assertEquals("invalidated", state())
        assertTrue(slot.acquire(this)); slot.release(this)
    }
    @Test fun `identity change while token work is pending prevents registration`() {
        experiment.start("widget", "external-private")
        manager.beginIdentityMutation(); manager.endIdentityMutation(); work.run(); idle()
        assertEquals(0, registrations); assertEquals("invalidated", state())
    }
    @Test fun `network error is sanitized and does not invent terminal success`() {
        start(); receive(call())
        listener!!.onError(mock(ErrorEvent::class.java)); idle()
        assertEquals("invitation", state()); assertFalse(slot.acquire(this))
    }
    @Test fun `preparation timeout prevents late token completion from registering`() {
        experiment.start("widget", "external-private")
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(31))
        work.run(); idle()
        assertEquals(0, registrations); assertEquals("invalidated", state())
        assertEquals("preparation_timeout", experiment.snapshot()["reason"])
        assertTrue(slot.acquire(this)); slot.release(this)
    }
    @Test fun `local hangup uses existing manager and waits for remote terminal`() {
        start(); val call = call(); receive(call); experiment.accept(handle(), false)
        manager.onMethodCall(MethodCall("hangup", null), Reply())
        verify(call).hangup(); assertFalse(slot.acquire(this))
        status = CallStatus.FINISHED
        listener!!.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        assertEquals("ended", state()); assertTrue(slot.acquire(this)); slot.release(this)
    }
    @Test fun `detached accepted call retains process reservation until terminal`() {
        start(); val call = call(); receive(call); experiment.accept(handle(), false)
        manager.dispose()
        assertEquals("invalidated", state()); assertFalse(slot.acquire(this))
        status = CallStatus.FINISHED
        listener!!.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        assertTrue(slot.acquire(this)); slot.release(this)
    }
    @Test fun `closed screen ends accepted media without unregistering signaling`() {
        start(); val call = call(); receive(call); experiment.accept(handle(), false)
        experiment.closeScreen(); verify(call).hangup()
        assertEquals("paused", state()); assertEquals(true, experiment.snapshot()["registrationAttempted"])
        assertFalse(slot.acquire(this))
    }
    @Test fun `activity recreation cannot expose or accept a background invitation`() {
        start(); val call = call(); receive(call); val old = handle()
        foreground = false
        assertNull(experiment.snapshot()["handle"])
        rejected { experiment.accept(old, false) }
        foreground = true
        assertEquals(old, handle()) // recreation before watchdog tick preserves pending invitation
        assertEquals(1, registrations)
    }
    @Test fun `SDK finished snapshot cleans adopted media when terminal callback was missed`() {
        start(); val call = call(); receive(call); experiment.accept(handle(), false)
        status = CallStatus.FINISHED; tick()
        assertEquals("ended", state()); assertTrue(slot.acquire(this)); slot.release(this)
        verify(call).setEventListener(RtcListener.detached)
    }
    @Test fun `duplicate start during preparation queues only one token task`() {
        experiment.start("widget", "external-private")
        experiment.start("widget", "external-private")
        assertEquals(1, work.tasks.size)
        work.run(); idle(); assertEquals(1, registrations)
    }
    @Test fun `MM identity broadcasts invalidate immediately without waiting for watchdog`() {
        start(); receive(call()); sameInstallation = false
        experiment.identitySignal(false)
        assertEquals("invalidated", state()); assertNull(experiment.snapshot()["handle"])
    }
    @Test fun `same-user personalization broadcast still invalidates fixed identity experiment`() {
        start(); experiment.identitySignal(true)
        assertEquals("invalidated", state())
    }
    private fun diagnosticCodes(): List<String> =
        (experiment.snapshot()["diagnostics"] as List<*>).map { (it as Map<*, *>)["event"] as String }

    @Test fun `diagnostics distinguish stages and never report registration readiness`() {
        experiment.onListen(null, sink); start()
        val codes = diagnosticCodes()
        val stages = listOf("start_received", "identity_resolution_started", "identity_resolution_returned",
            "token_request_started", "token_request_returned", "registration_preflight", "registration_invoked",
            "singleton_reference_changed", "registration_returned_readiness_unconfirmed")
        assertEquals(stages, codes.filter { it in stages })
        assertTrue(codes.contains("idle_connection_authentication_unobservable"))
        assertTrue(codes.contains("peer_family_unobserved"))
        assertEquals("registrationRequested", state())
        assertEquals(1, registrations)
    }
    @Test fun `unchanged singleton flags prior registration possibility without replacement or retry`() {
        singletonChanges = false; start()
        assertTrue(diagnosticCodes().contains("singleton_reference_unchanged_prior_registration_possible"))
        experiment.start("widget", "external-private")
        assertEquals(1, registrations)
    }
    @Test fun `identity and token failures identify their stage without exposing exception text`() {
        failIdentity = true; start()
        assertTrue(diagnosticCodes().contains("identity_resolution_failed"))
        assertFalse(diagnosticCodes().contains("token_request_started"))
        assertEquals(0, registrations)
        assertFalse(experiment.snapshot().toString().contains("private"))
    }
    @Test fun `token and registration exceptions have distinct safe diagnostics`() {
        failToken = true; start()
        assertTrue(diagnosticCodes().contains("token_request_failed"))
        assertFalse(diagnosticCodes().contains("registration_invoked"))
        assertFalse(experiment.snapshot().toString().contains("private"))
    }
    @Test fun `registration throw is distinct from a normal unconfirmed return`() {
        failRegister = true; start()
        assertTrue(diagnosticCodes().contains("registration_threw"))
        assertFalse(diagnosticCodes().contains("registration_returned_readiness_unconfirmed"))
    }
    @Test fun `native invitation and local rejection are visible without reading custom data`() {
        start(); experiment.closeScreen(); val call = call(); receive(call)
        assertTrue(diagnosticCodes().contains("invitation_callback"))
        assertTrue(diagnosticCodes().contains("rejected_screen_hidden"))
        assertTrue(diagnosticCodes().contains("rejection_decline_returned"))
        verify(call).decline()
        assertFalse(experiment.snapshot().toString().contains("custom-private"))
    }
    @Test fun `call error callbacks expose numeric code only`() {
        start(); receive(call())
        val errorEvent = mock(ErrorEvent::class.java)
        `when`(errorEvent.errorCode).thenReturn(ErrorCode.NETWORK_ERROR)
        listener!!.onError(errorEvent); idle()
        val entries = experiment.snapshot()["diagnostics"] as List<*>
        val error = entries.map { it as Map<*, *> }.last { it["event"] == "call_error" }
        assertEquals(ErrorCode.NETWORK_ERROR.id, error["errorCode"])
    }
    @Test fun `channel write failure is retained and replayed on reattachment`() {
        experiment.onListen(null, object : EventChannel.EventSink {
            override fun success(event: Any?) { throw IllegalStateException("token-private") }
            override fun error(code: String, message: String?, details: Any?) { }
            override fun endOfStream() { }
        })
        start(); experiment.onListen(null, sink)
        assertTrue(events.toString().contains("event_sink_write_failed"))
        assertFalse(events.toString().contains("private"))
        val count = diagnosticCodes().count { it == "event_sink_write_returned" }
        repeat(8) { tick() }
        assertEquals(count, diagnosticCodes().count { it == "event_sink_write_returned" })
    }
    @Test fun `diagnostics are bounded and absent when disabled`() {
        val disabled = IncomingDiagnostics(false)
        disabled.record(IncomingDiagnosticCode.start_received)
        assertTrue(disabled.snapshot().isEmpty()); assertEquals(0L, disabled.sequence)
        val enabled = IncomingDiagnostics(true)
        repeat(150) { enabled.record(IncomingDiagnosticCode.start_received, it.toLong()) }
        assertEquals(100, enabled.snapshot().size)
        assertEquals(51L, enabled.snapshot().first()["sequence"])
        val release = ForegroundIncomingExperiment(
            LiveChatIdentityResolver { _, _ -> error("unused") }, RtcTokenProvider { error("unused") },
            { _, _ -> }, { false }, worker = work,
            singleton = { error("Must never inspect singleton when disabled") })
        release.onListen(null, sink)
        assertFalse(release.snapshot().containsKey("diagnostics"))
    }
    @Test fun `admitted invitation rings once and duplicate cannot restart after acceptance`() {
        start(); verify(ringtone, never()).start()
        doAnswer { assertEquals("invitation", state()); null }.`when`(ringtone).start()
        val call = call(); receive(call); receive(call)
        verify(ringtone, times(1)).start()
        experiment.accept(handle(), false)
        receive(call)
        verify(ringtone, times(1)).start()
    }
    @Test fun `accept silences ringtone before call media acceptance`() {
        start(); val call = call(); receive(call)
        clearInvocations(ringtone, call)
        experiment.accept(handle(), false)
        val order = inOrder(ringtone, call)
        order.verify(ringtone).stop()
        order.verify(call).accept(any(ApplicationCallOptions::class.java))
    }
    @Test fun `decline silences before SDK even when decline throws`() {
        start(); val call = call(); receive(call)
        clearInvocations(ringtone, call)
        doThrow(IllegalStateException("private")).`when`(call).decline()
        try { experiment.decline(handle()); fail("Expected native error") } catch (_: IllegalStateException) { }
        val order = inOrder(ringtone, call)
        order.verify(ringtone).stop(); order.verify(call).decline()
    }
    @Test fun `remote cancellation and subsequent invitations ring independently`() {
        start(); val first = call(); receive(first)
        clearInvocations(ringtone)
        status = CallStatus.FINISHED
        listener!!.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        verify(ringtone, atLeastOnce()).stop()
        status = CallStatus.RINGING; receive(call("second"))
        verify(ringtone, times(1)).start()
        experiment.decline(handle())
        status = CallStatus.FINISHED; tick()
        status = CallStatus.RINGING; receive(call("third"))
        verify(ringtone, times(2)).start()
    }
    @Test fun `call errors and establishment silence pending playback`() {
        start(); receive(call()); clearInvocations(ringtone)
        listener!!.onError(mock(ErrorEvent::class.java)); idle()
        verify(ringtone).stop()
        clearInvocations(ringtone)
        listener!!.onEstablished(mock(CallEstablishedEvent::class.java)); idle()
        verify(ringtone).stop()
    }
    @Test fun `terminal status without callback and finishing status silence playback`() {
        start(); receive(call()); clearInvocations(ringtone)
        status = CallStatus.FINISHING; tick()
        verify(ringtone, atLeastOnce()).stop()
        assertFalse(slot.acquire(this)) // FINISHING must not release uncertain ownership.
        clearInvocations(ringtone)
        status = CallStatus.FINISHED; tick()
        verify(ringtone, atLeastOnce()).stop()
    }
    @Test fun `rejected and already ended invitations never ring`() {
        start(); experiment.closeScreen(); receive(call())
        verify(ringtone, never()).start()
        experiment.start("widget", "external-private")
        status = CallStatus.FINISHED; receive(call("ended"))
        verify(ringtone, never()).start()
    }
    @Test fun `invalidated invitation never rings and existing playback stops`() {
        start(); receive(call()); clearInvocations(ringtone)
        experiment.invalidate("identity_changed")
        verify(ringtone, atLeastOnce()).stop()
        receive(call("late")); verify(ringtone, never()).start()
    }
    @Test fun `screen closure Activity pause and engine cleanup stop without restarting`() {
        start(); receive(call()); clearInvocations(ringtone)
        experiment.stopRinging(); verify(ringtone).stop()
        experiment.closeScreen(); verify(ringtone, atLeast(2)).stop()
        manager.dispose(); verify(ringtone, atLeast(3)).stop()
        verify(ringtone, never()).start()
    }
    @Test fun `foreground loss stops ringtone through existing watchdog`() {
        start(); receive(call()); clearInvocations(ringtone)
        foreground = false; tick()
        verify(ringtone, atLeastOnce()).stop()
        foreground = true; tick()
        verify(ringtone, never()).start()
    }
    private class Reply : MethodChannel.Result {
        override fun success(result: Any?) { }
        override fun error(code: String, message: String?, details: Any?) { }
        override fun notImplemented() { fail("Missing method") }
    }
}
