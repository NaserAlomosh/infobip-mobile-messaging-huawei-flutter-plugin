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
    private val manager = manager()
    private fun manager() = HuaweiRtcManager(
        initialized = { initialized }, canStartCall = { foreground },
        permissions = {
            requestedVideo = it
            if (!permitted) throw RtcFailure("rtc_permission_denied", "Call permissions missing")
        },
        tokens = RtcTokenProvider { subject = it; tokenCalls++; tokenFailure?.let { throw it }; "unit-test-token" },
        backend = backend, executor = executor, slot = slot,
    )
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
}
