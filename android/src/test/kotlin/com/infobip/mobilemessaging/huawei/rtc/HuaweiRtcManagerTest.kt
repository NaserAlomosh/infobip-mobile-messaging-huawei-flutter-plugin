package com.infobip.mobilemessaging.huawei.rtc

import android.os.Looper
import com.infobip.webrtc.sdk.api.call.ApplicationCall
import com.infobip.webrtc.sdk.api.event.call.*
import com.infobip.webrtc.sdk.api.exception.IllegalStatusException
import com.infobip.webrtc.sdk.api.exception.MissingPermissionsException
import com.infobip.webrtc.sdk.api.exception.CallInProgressException
import com.infobip.webrtc.sdk.api.exception.InvalidTokenException
import com.infobip.webrtc.sdk.api.exception.ExpiredTokenException
import com.infobip.webrtc.sdk.api.model.CallStatus
import com.infobip.webrtc.sdk.api.model.ErrorCode
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Duration
import java.util.concurrent.AbstractExecutorService
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class HuaweiRtcManagerTest {
    private class QueuedExecutor : AbstractExecutorService() {
        val work = mutableListOf<Runnable>()
        private var stopped = false
        override fun execute(command: Runnable) { work += command }
        fun runNext() { work.removeAt(0).run() }
        override fun shutdown() { stopped = true }
        override fun shutdownNow(): MutableList<Runnable> { stopped = true; return mutableListOf() }
        override fun isShutdown() = stopped
        override fun isTerminated() = stopped
        override fun awaitTermination(timeout: Long, unit: TimeUnit) = stopped
    }

    internal class Reply : MethodChannel.Result {
        var completions = 0
        var value: Any? = null
        var code: String? = null
        var message: String? = null
        override fun success(result: Any?) { checkMain(); completions++; value = result }
        override fun error(errorCode: String, errorMessage: String?, details: Any?) {
            checkMain(); completions++; code = errorCode; message = errorMessage
            assertNull(details)
        }
        override fun notImplemented() { checkMain(); completions++; code = "notImplemented" }
        private fun checkMain() { assertEquals(Looper.getMainLooper(), Looper.myLooper()) }
    }

    private val executor = QueuedExecutor()
    private val slot = RtcCallSlot()
    private var initialized = true
    private var foreground = true
    private var permitted = true
    private var status = CallStatus.CALLING
    private var nativeFailure: Exception? = null
    private var tokenFailure: Exception? = null
    private var externalCall = false
    private var recoverPartial = false
    private var beforeReturn: ((RtcListener) -> Unit)? = null
    private var tokenCalls = 0
    private var callCount = 0
    private var hangups = 0
    private var requestedVideo: Boolean? = null
    private var subject: String? = null
    private lateinit var listener: RtcListener
    private val call = mock(ApplicationCall::class.java).also {
        `when`(it.id()).thenReturn("native-call-id")
        `when`(it.audioDeviceManager()).thenReturn(mock(com.infobip.webrtc.sdk.api.device.AudioDeviceManager::class.java))
        `when`(it.status()).thenAnswer { status }
        doAnswer { hangups++; null }.`when`(it).hangup()
    }
    private val backend = object : RtcBackend {
        override fun hasActiveCall() = externalCall
        override fun call(token: String, input: RtcInput, listener: RtcListener): ApplicationCall {
            assertEquals(Looper.getMainLooper(), Looper.myLooper())
            assertEquals("unit-test-token", token)
            this@HuaweiRtcManagerTest.listener = listener
            callCount++
            beforeReturn?.invoke(listener)
            nativeFailure?.let { throw it }
            return call
        }
        override fun recoverCall(listener: RtcListener) = if (recoverPartial) call else null
    }
    private val notice = Notice()
    private class Notice : RtcCallNotification {
        var autoReady = true
        var failure: RtcFailure? = null
        var starts = 0
        var stops = 0
        var identity: String? = null
        var state: (() -> RtcNotificationState?)? = null
        var action: ((String, String?, Boolean?) -> Unit)? = null
        var ready: ((RtcFailure?) -> Unit)? = null
        override fun start(identity: String, video: Boolean, state: () -> RtcNotificationState?,
                           action: (String, String?, Boolean?) -> Unit, ready: (RtcFailure?) -> Unit) {
            starts++
            this.identity = identity; this.state = state; this.action = action; this.ready = ready
            if (autoReady) ready(failure)
        }
        override fun stop(identity: String) { if (this.identity == identity) { stops++; this.identity = null } }
        override fun returnIdentity(intent: android.content.Intent) = identity.takeIf {
            intent.getStringExtra("identity") == it && it != null
        }
    }
    private var chatUser: String? = "expected-user"
    private var chatFailure: RtcFailure? = null
    private var chatLookups = 0
    private val chatResolver = LiveChatIdentityResolver { widget, expected ->
        chatLookups++
        assertEquals("exact-widget", widget)
        assertEquals("expected-user", expected)
        chatFailure?.let { throw it }
        if (chatUser != expected) throw RtcFailure("rtc_invalid_state", "User mismatch")
        ResolvedChatIdentity("chat-subject") {
            if (chatUser != expected) throw RtcFailure("rtc_invalid_state", "User changed")
        }
    }
    private val manager = manager()
    private fun manager() = HuaweiRtcManager(
        initialized = { initialized }, canStartCall = { foreground },
        permissions = {
            requestedVideo = it
            if (!permitted) throw RtcFailure("rtc_permission_denied", "Call permissions missing")
        },
        tokens = RtcTokenProvider { subject = it; tokenCalls++; tokenFailure?.let { throw it }; "unit-test-token" },
        backend = backend, executor = executor, slot = slot, notification = notice,
        chatIdentities = chatResolver,
    )
    private fun chatRequest(type: String = "audio") = mapOf(
        "callsConfigurationId" to "calls-config", "type" to type,
        "liveChatIdentity" to mapOf("widgetId" to "exact-widget", "expectedExternalUserId" to "expected-user"))

    @Test fun `Chat audio and video resolve once per call through existing token and media flow`() {
        for (type in listOf("audio", "video")) {
            val reply = invoke("callApplication", chatRequest(type))
            executor.runNext(); idle()
            assertNull(reply.code)
            assertEquals("chat-subject", subject)
            assertEquals(type == "video", requestedVideo)
            assertFalse(reply.value.toString().contains("chat-subject"))
            listener.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        }
        assertEquals(2, chatLookups)
        assertEquals(2, tokenCalls)
        assertEquals(2, callCount)
    }

    @Test fun `Chat lookup failure and timeout do not request a token or call`() {
        chatFailure = RtcFailure("rtc_identity_unavailable", "Lookup unavailable")
        val failed = invoke("callApplication", chatRequest())
        executor.runNext(); idle()
        assertEquals("rtc_identity_unavailable", failed.code)
        chatFailure = null
        val timedOut = invoke("callApplication", chatRequest())
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(31))
        executor.runNext(); idle()
        assertEquals("rtc_identity_unavailable", timedOut.code)
        assertEquals(1, timedOut.completions)
        assertEquals(0, tokenCalls)
        assertEquals(0, callCount)
    }

    @Test fun `Chat mode rejects mutation and invalidates even logout relogin to same account`() {
        val stale = invoke("callApplication", chatRequest())
        executor.runNext()
        manager.beginIdentityMutation()
        assertEquals("rtc_invalid_state", stale.code)
        assertEquals("rtc_invalid_state", invoke("callApplication", chatRequest()).code)
        manager.endIdentityMutation()
        idle()
        assertEquals(0, callCount)
        assertEquals(1, stale.completions)
        val fresh = invoke("callApplication", chatRequest())
        executor.runNext(); idle()
        assertNull(fresh.code)
    }

    @Test fun `Chat mode rechecks user after token and while foreground service starts`() {
        val pending = invoke("callApplication", chatRequest())
        executor.runNext()
        chatUser = null
        idle()
        assertEquals("rtc_invalid_state", pending.code)
        assertEquals(0, callCount)
        chatUser = "expected-user"
        notice.autoReady = false
        val waiting = invoke("callApplication", chatRequest("video"))
        executor.runNext(); idle()
        chatUser = "another-user"
        notice.ready!!.invoke(null)
        assertEquals("rtc_invalid_state", waiting.code)
        assertEquals(0, callCount)
    }

    @Test fun `other engine identity mutation invalidates Chat call before submission`() {
        notice.autoReady = false
        val pending = invoke("callApplication", chatRequest())
        executor.runNext(); idle()
        val other = manager()
        other.beginIdentityMutation(); other.endIdentityMutation()
        notice.ready!!.invoke(null)
        assertEquals("rtc_invalid_state", pending.code)
        assertEquals(0, callCount)
        other.dispose()
    }

    @Test fun `Chat disposal drops queued response without token or native call`() {
        val pending = invoke("callApplication", chatRequest())
        manager.dispose()
        executor.runNext(); idle()
        assertEquals("rtc_invalid_state", pending.code)
        assertEquals(1, pending.completions)
        assertEquals(0, tokenCalls)
        assertEquals(0, callCount)
    }

    @Test fun `native channel rejects mixed modes missing widget and missing expected user`() {
        for (args in listOf(
            chatRequest() + ("identity" to "explicit"),
            chatRequest() + ("liveChatIdentity" to mapOf("widgetId" to "exact-widget")),
            chatRequest() + ("liveChatIdentity" to mapOf("widgetId" to "", "expectedExternalUserId" to "expected-user")),
            chatRequest() + ("liveChatIdentity" to mapOf("widgetId" to "exact-widget", "expectedExternalUserId" to "")),
        )) assertEquals("rtc_invalid_argument", invoke("callApplication", args).code)
        assertEquals(0, chatLookups)
        assertEquals(0, tokenCalls)
    }

    private val events = mutableListOf<Map<*, *>>()
    private val sink = object : EventChannel.EventSink {
        override fun success(event: Any?) {
            assertEquals(Looper.getMainLooper(), Looper.myLooper())
            events += event as Map<*, *>
        }
        override fun error(code: String, message: String?, details: Any?) { fail(code) }
        override fun endOfStream() {}
    }
    private fun request(type: String = "audio") = mapOf("callsConfigurationId" to "calls-config", "type" to type, "identity" to "subject")
    private fun invoke(method: String, args: Any? = null, target: HuaweiRtcManager = manager) = Reply().also {
        target.onMethodCall(MethodCall(method, args), it)
    }
    private fun idle() = shadowOf(Looper.getMainLooper()).idle()
    private fun start(type: String = "audio"): Reply {
        val reply = invoke("callApplication", request(type))
        executor.runNext()
        idle()
        return reply
    }
    @Test fun `SDK creation waits for foreground readiness and timeout cancels delayed start`() {
        notice.autoReady = false
        val reply = start()
        assertEquals(0, callCount)
        assertEquals(0, reply.completions)
        assertEquals("calling", notice.state!!()!!.status)
        assertNull(notice.state!!()!!.callId)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(5))
        assertEquals("rtc_foreground_service_failed", reply.code)
        assertEquals(1, notice.stops)
        notice.ready!!(null)
        assertEquals(0, callCount)
    }

    @Test fun `foreground service failure prevents SDK call and releases pending request`() {
        notice.failure = RtcFailure("rtc_foreground_service_failed", "Denied")
        assertEquals("rtc_foreground_service_failed", start().code)
        assertEquals(0, callCount)
        assertEquals(1, notice.stops)
        assertNull(invoke("getActiveCall").value)
    }

    @Test fun `background during promotion rejects media creation and removes service`() {
        notice.autoReady = false
        val reply = start()
        foreground = false
        notice.ready!!(null)
        assertEquals("rtc_invalid_state", reply.code)
        assertEquals(0, callCount)
        assertEquals(1, notice.stops)
    }

    @Test fun `notification hangup works detached and duplicates are harmless until finish`() {
        start()
        foreground = false
        notice.action!!(HuaweiRtcCallService.END, "native-call-id", null)
        notice.action!!(HuaweiRtcCallService.END, "native-call-id", null)
        assertEquals(1, hangups)
        assertEquals(0, notice.stops)
        status = CallStatus.FINISHED
        notice.state!!()
        assertEquals(1, notice.stops)
        assertNull(invoke("getActiveCall").value)
    }

    @Test fun `notification mute uses native adapter and SDK readback while backgrounded`() {
        start()
        status = CallStatus.ESTABLISHED
        foreground = false
        var muted = false
        `when`(call.muted()).thenAnswer { muted }
        doAnswer { muted = it.getArgument(0); null }.`when`(call).mute(anyBoolean())
        notice.action!!(HuaweiRtcCallService.MUTE, "native-call-id", true)
        assertTrue(notice.state!!()!!.muted!!)
        notice.action!!(HuaweiRtcCallService.MUTE, "native-call-id", true)
        verify(call, times(1)).mute(true)
        notice.action!!(HuaweiRtcCallService.MUTE, "native-call-id", false)
        assertFalse(notice.state!!()!!.muted!!)
        assertEquals(0, hangups)
    }

    @Test fun `denied permission and SDK mute failures leave authoritative state unchanged`() {
        start()
        status = CallStatus.ESTABLISHED
        permitted = false
        notice.action!!(HuaweiRtcCallService.MUTE, "native-call-id", true)
        verify(call, never()).mute(anyBoolean())
        permitted = true
        doThrow(IllegalStateException("private")).`when`(call).mute(true)
        notice.action!!(HuaweiRtcCallService.MUTE, "native-call-id", true)
        assertFalse(notice.state!!()!!.muted!!)
        assertEquals(0, hangups)
    }

    @Test fun `wrong IDs and old session callbacks cannot control replacement even with reused call ID`() {
        start()
        status = CallStatus.ESTABLISHED
        val old = notice.action!!
        old(HuaweiRtcCallService.END, "wrong-id", null)
        assertEquals(0, hangups)
        status = CallStatus.FINISHED
        notice.state!!()
        status = CallStatus.CALLING
        start()
        status = CallStatus.ESTABLISHED
        old(HuaweiRtcCallService.END, "native-call-id", null)
        old(HuaweiRtcCallService.MUTE, "native-call-id", true)
        assertEquals(0, hangups)
        verify(call, never()).mute(anyBoolean())
        assertEquals(2, notice.starts)
    }

    @Test fun `missing terminal callback uses bounded stop without inventing finished or releasing live owner`() {
        start()
        notice.action!!(HuaweiRtcCallService.END, "native-call-id", null)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(10))
        assertEquals(2, hangups)
        assertEquals(1, notice.stops)
        assertNotNull(invoke("getActiveCall").value)
        assertEquals("rtc_call_already_active", invoke("callApplication", request()).code)
        assertFalse(events.any { it["type"] == "finished" })
    }

    @Test fun `validated return tap consumes once and does not create call`() {
        start()
        manager.handleNotificationIntent(android.content.Intent().putExtra("identity", notice.identity))
        assertNotNull(invoke("takeNotificationCall").value)
        assertNull(invoke("takeNotificationCall").value)
        manager.handleNotificationIntent(android.content.Intent().putExtra("identity", "old-session"))
        assertNull(invoke("takeNotificationCall").value)
        assertEquals(1, callCount)
    }

    @After fun dispose() { manager.dispose(); idle() }

    @Test fun `requires initialization before token delegation`() {
        initialized = false
        assertEquals("rtc_not_initialized", invoke("callApplication", request()).code)
        assertEquals(0, tokenCalls)
        assertEquals(0, callCount)
    }

    @Test fun `validates arguments on native boundary`() {
        for (args in listOf(null, "bad", mapOf("type" to "audio"), request("invalid"), request() + ("identity" to 1), request() + ("callsConfigurationId" to " "))) {
            assertEquals("rtc_invalid_argument", invoke("callApplication", args).code)
        }
        assertTrue(executor.work.isEmpty())
    }

    @Test fun `permission and foreground failure do not fetch token or reserve call`() {
        permitted = false
        assertEquals("rtc_permission_denied", invoke("callApplication", request("video")).code)
        permitted = true
        foreground = false
        assertEquals("rtc_invalid_state", invoke("callApplication", request()).code)
        assertEquals(0, tokenCalls)
        foreground = true
        assertNull(start().code)
    }

    @Test fun `token acquisition is dispatched and completion returns on main exactly once`() {
        val reply = invoke("callApplication", request())
        assertEquals(0, tokenCalls)
        Thread { executor.runNext() }.apply { start(); join() }
        assertEquals(0, reply.completions)
        idle()
        assertEquals(1, reply.completions)
        assertNull(reply.code)
        assertEquals("subject", subject)
        assertEquals("native-call-id", (reply.value as Map<*, *>)["id"])
        assertEquals(1, callCount)
    }

    @Test fun `audio and video permission paths remain distinct`() {
        start("video")
        assertEquals(true, requestedVideo)
        listener.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null))
        idle()
        start("audio")
        assertEquals(false, requestedVideo)
    }

    @Test fun `second call rejected during token request and native call`() {
        val first = invoke("callApplication", request())
        assertEquals("rtc_call_already_active", invoke("callApplication", request()).code)
        executor.runNext(); idle()
        assertNull(first.code)
        assertEquals("rtc_call_already_active", invoke("callApplication", request()).code)
        assertEquals(1, callCount)
    }

    @Test fun `process slot rejects another engine during token request`() {
        val other = manager()
        try {
            invoke("callApplication", request())
            assertEquals("rtc_call_already_active", invoke("callApplication", request(), other).code)
            assertEquals("rtc_invalid_state", other.prepareCleanup()?.code)
        } finally { other.dispose() }
    }

    @Test fun `cleanup reserves process slot until completion and disposal releases it`() {
        val other = manager()
        try {
            assertNull(manager.prepareCleanup())
            assertEquals("rtc_invalid_state", manager.prepareCleanup()?.code)
            assertEquals("rtc_call_already_active", invoke("callApplication", request(), other).code)
            manager.dispose()
            assertNull(other.prepareCleanup())
            other.completeCleanup()
        } finally { other.dispose() }
    }

    @Test fun `existing SDK call rejects before fetching token`() {
        externalCall = true
        assertEquals("rtc_call_already_active", invoke("callApplication", request()).code)
        assertEquals(0, tokenCalls)
    }

    @Test fun `SDK call started during HTTP request is checked again`() {
        val reply = invoke("callApplication", request())
        externalCall = true
        executor.runNext(); idle()
        assertEquals("rtc_call_already_active", reply.code)
        assertEquals(1, reply.completions)
        assertEquals(0, callCount)
    }

    @Test fun `token errors sanitized and slot released for retry`() {
        tokenFailure = IllegalStateException("sensitive token response")
        val reply = start()
        assertEquals("rtc_token_failed", reply.code)
        assertFalse(reply.message!!.contains("sensitive"))
        assertEquals(1, reply.completions)
        tokenFailure = null
        assertNull(start().code)
    }

    @Test fun `native exceptions map without leaking native text`() {
        for ((error, code) in listOf(
            MissingPermissionsException("secret") to "rtc_permission_denied",
            SecurityException("secret") to "rtc_permission_denied",
            CallInProgressException("secret") to "rtc_call_already_active",
            InvalidTokenException("secret") to "rtc_token_failed",
            ExpiredTokenException("secret") to "rtc_token_failed",
            IllegalStatusException("secret") to "rtc_invalid_state",
            IllegalArgumentException("secret") to "rtc_invalid_argument",
            RuntimeException("secret") to "rtc_call_failed",
        )) {
            nativeFailure = error
            val reply = start()
            assertEquals(code, reply.code)
            assertEquals(1, reply.completions)
            assertFalse(reply.message!!.contains("secret"))
        }
    }

    @Test fun `permission revoked during token acquisition prevents native call`() {
        val reply = invoke("callApplication", request("video"))
        permitted = false
        executor.runNext(); idle()
        assertEquals("rtc_permission_denied", reply.code)
        assertEquals(0, callCount)
    }

    @Test fun `hangup without native call fails and active hangup waits for termination`() {
        assertEquals("rtc_no_active_call", invoke("hangup").code)
        start()
        assertNull(invoke("hangup").code)
        assertEquals(1, hangups)
        assertNotNull(invoke("getActiveCall").value)
        assertEquals("rtc_call_already_active", invoke("callApplication", request()).code)
        listener.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        assertNull(invoke("getActiveCall").value)
        assertEquals("rtc_no_active_call", invoke("hangup").code)
    }

    @Test fun `failed hangup preserves ownership and permits retry`() {
        start()
        doThrow(SecurityException("secret")).`when`(call).hangup()
        assertEquals("rtc_permission_denied", invoke("hangup").code)
        assertNotNull(invoke("getActiveCall").value)
        doNothing().`when`(call).hangup()
        assertNull(invoke("hangup").code)
    }

    @Test fun `terminal callback clears listener and ignores duplicate or old callbacks`() {
        manager.onListen(null, sink)
        start()
        val old = listener
        old.onHangup(CallHangupEvent(ErrorCode.REJECTED, null)); idle()
        verify(call).setEventListener(RtcListener.detached)
        assertEquals("finished", events.last()["type"])
        assertEquals(ErrorCode.REJECTED.id, events.last()["nativeErrorCode"])
        start()
        val count = events.size
        old.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        assertEquals(count, events.size)
        assertNotNull(invoke("getActiveCall").value)
    }

    @Test fun `error is nonterminal and only numeric reason is forwarded`() {
        manager.onListen(null, sink); start()
        listener.onError(ErrorEvent(ErrorCode(123, "secret name", "secret response"))); idle()
        assertEquals("error", events.last()["type"])
        assertEquals(123, events.last()["nativeErrorCode"])
        assertFalse(events.toString().contains("secret"))
        assertNotNull(invoke("getActiveCall").value)
    }

    @Test fun `worker callbacks are serialized and sink detach does not hang up`() {
        manager.onListen(null, sink); start()
        Thread {
            listener.onRinging(mock(CallRingingEvent::class.java))
            listener.onEarlyMedia(mock(CallEarlyMediaEvent::class.java))
            listener.onEstablished(mock(CallEstablishedEvent::class.java))
        }.apply { start(); join() }
        idle()
        assertEquals(listOf("ringing", "earlyMedia", "established"), events.takeLast(3).map { it["type"] })
        val sequence = events.map { it["sequence"] as Long }
        assertEquals(sequence.sorted(), sequence)
        manager.onCancel(null)
        val size = events.size
        listener.onRinging(mock(CallRingingEvent::class.java)); idle()
        assertEquals(size, events.size)
        assertEquals(0, hangups)
        status = CallStatus.ESTABLISHED
        manager.onListen(null, sink)
        assertEquals("established", (events.last()["call"] as Map<*, *>)["status"])
    }

    @Test fun `cleanup rejects active call then permits cleanup after native termination`() {
        start()
        assertEquals("rtc_invalid_state", manager.prepareCleanup()?.code)
        assertEquals(0, hangups)
        listener.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        assertNull(manager.prepareCleanup())
        assertEquals("rtc_invalid_state", invoke("callApplication", request()).code)
        manager.completeCleanup()
        assertNull(start().code)
    }

    @Test fun `cleanup cancels pending callback once and discards stale token completion`() {
        val reply = invoke("callApplication", request())
        executor.runNext() // result is queued but has not reached the main handler
        assertNull(manager.prepareCleanup())
        manager.completeCleanup()
        idle()
        assertEquals(1, reply.completions)
        assertEquals("rtc_invalid_state", reply.code)
        assertEquals(0, callCount)
        assertNull(start().code)
    }

    @Test fun `timeout bounds token wait and late response cannot create a call`() {
        val reply = invoke("callApplication", request())
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(31))
        assertEquals("rtc_token_failed", reply.code)
        executor.runNext(); idle()
        assertEquals(1, reply.completions)
        assertEquals(0, callCount)
        assertNull(start().code)
    }

    @Test fun `engine disposal terminates owned call clears sink and listener once`() {
        manager.onListen(null, sink); start()
        val count = events.size
        manager.dispose(); manager.dispose()
        listener.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        assertEquals(1, hangups)
        verify(call).setEventListener(RtcListener.detached)
        assertEquals(count, events.size)
        assertTrue(executor.isShutdown)
        assertEquals("rtc_invalid_state", invoke("getActiveCall").code)
    }

    @Test fun `engine disposal cancels pending result exactly once`() {
        val reply = invoke("callApplication", request())
        executor.runNext()
        manager.dispose(); idle()
        assertEquals(1, reply.completions)
        assertEquals("rtc_invalid_state", reply.code)
        assertEquals(0, callCount)
    }

    @Test fun `foreground detach during token request fails safely and permits reattach`() {
        val reply = invoke("callApplication", request())
        foreground = false
        executor.runNext(); idle()
        assertEquals("rtc_invalid_state", reply.code)
        foreground = true
        assertNull(start().code)
        foreground = false
        assertNotNull(invoke("getActiveCall").value)
        assertNull(invoke("hangup").code)
    }

    @Test fun `partial native creation failure retains call until terminal cleanup`() {
        nativeFailure = RuntimeException("secret")
        recoverPartial = true
        val reply = start()
        assertEquals("rtc_call_failed", reply.code)
        assertEquals(1, reply.completions)
        assertEquals(1, hangups)
        assertNotNull(invoke("getActiveCall").value)
        listener.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        assertNull(invoke("getActiveCall").value)
    }

    @Test fun `native finished status reconciles stale reference on query`() {
        manager.onListen(null, sink); start()
        status = CallStatus.FINISHED
        assertNull(invoke("getActiveCall").value)
        assertEquals("finished", events.last()["type"])
        assertNull(events.last()["nativeErrorCode"])
    }

    @Test fun `synchronous error and duplicate hangup callbacks complete method only once`() {
        manager.onListen(null, sink)
        beforeReturn = {
            it.onError(ErrorEvent(ErrorCode.MEDIA_ERROR))
            it.onHangup(CallHangupEvent(ErrorCode.MEDIA_ERROR, null))
            it.onHangup(CallHangupEvent(ErrorCode.MEDIA_ERROR, null))
        }
        val reply = start()
        assertEquals(1, reply.completions)
        assertNull(reply.code) // creation succeeded; the failure is a subsequent native callback
        assertEquals(1, events.count { it["type"] == "error" })
        assertEquals(1, events.count { it["type"] == "finished" })
        assertNull(invoke("getActiveCall").value)
    }

    @Test fun `broken Dart sink does not turn native call creation into a failed call`() {
        var delivered = 0
        manager.onListen(null, object : EventChannel.EventSink {
            override fun success(event: Any?) {
                if (delivered++ > 0) throw IllegalStateException("engine unavailable")
            }
            override fun error(code: String, message: String?, details: Any?) {}
            override fun endOfStream() {}
        })
        val reply = start()
        assertEquals(1, reply.completions)
        assertNull(reply.code)
        assertEquals(0, hangups)
        assertNotNull(invoke("getActiveCall").value)
    }
    @Test fun `audio and wrong call id never initialize video renderers`() {
        val view = mock(HuaweiRtcVideoViewOwner::class.java)
        start()
        assertNull(manager.bindVideo(view, HuaweiRtcVideoOptions("native-call-id", true)))
        verifyNoInteractions(view)
        listener.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        start("video")
        assertNull(manager.bindVideo(view, HuaweiRtcVideoOptions("wrong-id", false)))
        verifyNoInteractions(view)
    }

    @Test fun `rendering failure preserves establishment events hangup and terminal cleanup`() {
        manager.onListen(null, sink)
        val reply = start("video")
        val view = mock(HuaweiRtcVideoViewOwner::class.java)
        `when`(view.initializeRenderer(anyBoolean())).thenReturn(mock(com.infobip.webrtc.sdk.api.model.video.VideoRenderer::class.java))
        `when`(call.remoteVideos()).thenThrow(IllegalStateException())
        assertNull(manager.bindVideo(view, HuaweiRtcVideoOptions("native-call-id", false)))
        assertEquals(1, reply.completions)
        assertNull(reply.code)
        assertEquals(0, hangups)
        listener.onEstablished(CallEstablishedEvent()); idle()
        assertEquals("established", events.last()["type"])
        assertEquals(setOf("type", "call", "nativeErrorCode", "sequence"), events.last().keys)
        invoke("hangup")
        assertEquals(1, hangups)
        listener.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        assertNull(invoke("getActiveCall").value)
        assertEquals("finished", events.last()["type"])
    }

    @Test fun `view Activity and terminal cleanup never add hangups and old camera callback stays stale`() {
        start("video")
        val track = mock(com.infobip.webrtc.sdk.api.model.video.RTCVideoTrack::class.java)
        val renderer = mock(com.infobip.webrtc.sdk.api.model.video.VideoRenderer::class.java)
        val view = mock(HuaweiRtcVideoViewOwner::class.java)
        `when`(view.initializeRenderer(anyBoolean())).thenReturn(renderer)
        `when`(call.localCameraTrack()).thenReturn(track)
        assertNotNull(manager.bindVideo(view, HuaweiRtcVideoOptions("native-call-id", true)))
        manager.detachVideoViews()
        assertEquals(0, hangups)
        verify(track).removeSink(renderer)
        val old = listener
        old.onCameraVideoUpdated(CameraVideoUpdatedEvent(track))
        old.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        start("video")
        old.onCameraVideoAdded(CameraVideoAddedEvent(track)); idle()
        verify(track, times(1)).addSink(renderer)
        verify(view, times(1)).releaseRenderer()
    }

    @Test fun `engine cleanup with a broken renderer still performs existing hangup and release`() {
        start("video")
        val view = mock(HuaweiRtcVideoViewOwner::class.java)
        `when`(view.initializeRenderer(anyBoolean())).thenReturn(mock(com.infobip.webrtc.sdk.api.model.video.VideoRenderer::class.java))
        assertNotNull(manager.bindVideo(view, HuaweiRtcVideoOptions("native-call-id", true)))
        doThrow(IllegalStateException()).`when`(view).releaseRenderer()
        manager.dispose()
        manager.dispose()
        assertEquals(1, hangups)
        verify(call).setEventListener(RtcListener.detached)
        verify(view, times(1)).releaseRenderer()
    }

    @Test fun `controls reject missing pending unestablished finished and stale calls`() {
        val args = mapOf("callId" to "native-call-id", "enabled" to true)
        assertEquals("rtc_invalid_argument", invoke("setMicrophoneMuted").code)
        assertEquals("rtc_no_active_call", invoke("setMicrophoneMuted", args).code)
        invoke("callApplication", request())
        assertEquals("rtc_no_active_call", invoke("setMicrophoneMuted", args).code)
        executor.runNext(); idle()
        assertEquals("rtc_invalid_state", invoke("setMicrophoneMuted", args).code)
        status = CallStatus.ESTABLISHED
        assertEquals("rtc_invalid_state", invoke("setMicrophoneMuted", args + ("callId" to "old-call")).code)
        assertNull(invoke("setMicrophoneMuted", args).code)
        verify(call).mute(true)
        status = CallStatus.FINISHING
        assertEquals("rtc_invalid_state", invoke("setMicrophoneMuted", args).code)
        status = CallStatus.FINISHED
        assertEquals("rtc_no_active_call", invoke("setMicrophoneMuted", args).code)
        verify(call, times(1)).mute(true)
    }

    @Test fun `control failures are sanitized and revoked permission prevents forwarding`() {
        start("video"); status = CallStatus.ESTABLISHED
        val args = mapOf("callId" to "native-call-id", "enabled" to true)
        permitted = false
        assertEquals("rtc_permission_denied", invoke("setMicrophoneMuted", args).code)
        verify(call, never()).mute(anyBoolean())
        permitted = true
        doThrow(IllegalStateException("private")).`when`(call).mute(true)
        val reply = invoke("setMicrophoneMuted", args)
        assertEquals("rtc_invalid_state", reply.code)
        assertFalse(reply.message!!.contains("private"))
        assertNotNull(invoke("getActiveCall").value)
    }

    @Test fun `old queued callbacks cannot change replacement control state or duration`() {
        start(); status = CallStatus.ESTABLISHED
        val old = listener
        old.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        `when`(call.id()).thenReturn("replacement")
        `when`(call.duration()).thenReturn(7)
        start()
        old.onEstablished(CallEstablishedEvent()); idle()
        assertEquals("rtc_invalid_state", invoke("setMicrophoneMuted", mapOf("callId" to "native-call-id", "enabled" to true)).code)
        verify(call, never()).mute(anyBoolean())
        assertEquals(7, (invoke("getActiveCall").value as Map<*, *>)["durationSeconds"])
    }

    @Test fun `camera permission recheck applies to capture but not microphone or camera removal`() {
        start("video"); status = CallStatus.ESTABLISHED
        val args = mapOf("callId" to "native-call-id", "enabled" to true)
        invoke("setMicrophoneMuted", args)
        assertEquals(false, requestedVideo)
        invoke("setCameraEnabled", args)
        assertEquals(true, requestedVideo)
        invoke("setCameraEnabled", args + ("enabled" to false))
        assertEquals(false, requestedVideo)
        invoke("switchCamera", args)
        assertEquals(true, requestedVideo)
    }

    @Test fun `duration snapshots stay zero before connection and freeze in terminal event`() {
        manager.onListen(null, sink); start()
        assertEquals(0, (invoke("getActiveCall").value as Map<*, *>)["durationSeconds"])
        status = CallStatus.ESTABLISHED
        listener.onEstablished(CallEstablishedEvent()); idle()
        assertEquals(0, (events.last()["call"] as Map<*, *>)["durationSeconds"])
        `when`(call.duration()).thenReturn(65)
        assertEquals(65, (invoke("getActiveCall").value as Map<*, *>)["durationSeconds"])
        listener.onHangup(CallHangupEvent(ErrorCode.NORMAL_HANGUP, null)); idle()
        val terminal = events.last()
        assertEquals(65, (terminal["call"] as Map<*, *>)["durationSeconds"])
        `when`(call.duration()).thenReturn(99)
        manager.onCancel(null); manager.onListen(null, sink)
        assertEquals(terminal, events.last())
    }

}
