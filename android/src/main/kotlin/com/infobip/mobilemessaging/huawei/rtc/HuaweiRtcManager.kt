package com.infobip.mobilemessaging.huawei.rtc

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.infobip.webrtc.sdk.api.call.ApplicationCall
import com.infobip.webrtc.sdk.api.model.CallStatus
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.FutureTask

/** Engine-scoped owner; all state/results/sinks are confined to Android's main thread. */
internal class HuaweiRtcManager(
    private val initialized: () -> Boolean,
    private val canStartCall: () -> Boolean,
    private val permissions: (Boolean) -> Unit,
    private val tokens: RtcTokenProvider,
    private val backend: RtcBackend,
    private val executor: ExecutorService = Executors.newSingleThreadExecutor(),
    private val main: Handler = Handler(Looper.getMainLooper()),
    private val slot: RtcCallSlot = RtcCallSlot.process,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    constructor(context: Context, initialized: () -> Boolean, canStartCall: () -> Boolean) : this(
        initialized, canStartCall,
        { video -> checkRtcPermissions(context.applicationContext, video) },
        HuaweiRtcTokenProvider(context.applicationContext), HuaweiRtcBackend(context.applicationContext),
    )

    private class Session(val input: RtcInput, var reply: MethodChannel.Result?) {
        var call: ApplicationCall? = null
        var listener: RtcListener? = null
        var tokenTask: FutureTask<Unit>? = null
        var timeout: Runnable? = null
    }

    private var session: Session? = null
    private var disposed = false
    private var cleaning = false
    private var sink: EventChannel.EventSink? = null
    private var lastEvent: Map<String, Any?>? = null
    private var sequence = 0L

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) = onMain {
        try {
            if (disposed) throw RtcFailure("rtc_invalid_state", "RTC plugin has been disposed")
            when (call.method) {
                "callApplication" -> start(RtcInput.decode(call.arguments), result)
                "hangup" -> {
                    val active = session?.call ?: throw RtcFailure("rtc_no_active_call", "There is no active RTC call")
                    if (active.status() == CallStatus.FINISHED) {
                        finish(requireNotNull(session))
                        throw RtcFailure("rtc_no_active_call", "There is no active RTC call")
                    }
                    active.hangup()
                    // A void native hangup is acceptance, not remote termination acknowledgement.
                    result.success(null)
                }
                "getActiveCall" -> {
                    val current = session
                    if (current?.call?.status() == CallStatus.FINISHED) finish(current)
                    result.success(session?.let(::snapshot))
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            replyError(result, RtcFailure.native(error))
        }
    }

    private fun start(input: RtcInput, result: MethodChannel.Result) {
        checkReady(input)
        session?.takeIf { it.call?.status() == CallStatus.FINISHED }?.let { finish(it) }
        if (session != null || backend.hasActiveCall() || !slot.acquire(this)) {
            throw RtcFailure("rtc_call_already_active", "Another RTC call or call request is active")
        }
        val current = Session(input, result)
        session = current
        val timeout = Runnable {
            if (session === current && current.call == null) {
                failPending(current, RtcFailure("rtc_token_failed", "RTC access token request timed out"))
            }
        }
        current.timeout = timeout
        main.postDelayed(timeout, TOKEN_TIMEOUT_MS)
        val task = FutureTask<Unit> {
            val token = try {
                Result.success(tokens.fetch(input.identity))
            } catch (error: Exception) {
                Result.failure(error)
            }
            main.post { tokenReady(current, token) }
        }
        current.tokenTask = task
        try {
            executor.execute(task)
        } catch (_: Exception) {
            failPending(current, RtcFailure("rtc_token_failed", "RTC access token request could not start"))
        }
    }

    private fun checkReady(input: RtcInput) {
        if (cleaning) throw RtcFailure("rtc_invalid_state", "Mobile Messaging cleanup is in progress")
        if (!initialized()) throw RtcFailure("rtc_not_initialized", "Initialize Huawei Mobile Messaging before calling")
        if (!canStartCall()) throw RtcFailure("rtc_invalid_state", "Start the call from an attached foreground Activity")
        permissions(input.video)
    }

    private fun tokenReady(current: Session, token: Result<String>) {
        if (disposed || session !== current) return // cancelled, timed out, or an older engine/account
        current.timeout?.let(main::removeCallbacks)
        current.timeout = null
        current.tokenTask = null
        val error = token.exceptionOrNull()
        if (error != null || token.getOrNull().isNullOrBlank()) {
            val failure = (error as? RtcFailure)?.takeIf { it.code == "rtc_not_initialized" }
                ?: RtcFailure("rtc_token_failed", "RTC access token acquisition failed")
            failPending(current, failure)
            return
        }
        val listener = RtcListener { type, reason ->
            // Always enqueue: a synchronous SDK callback must not race callApplication's return.
            main.post { nativeEvent(current, type, reason) }
        }
        current.listener = listener
        try {
            checkReady(current.input) // permissions / initialization can change during the HTTP request
            if (backend.hasActiveCall()) throw RtcFailure("rtc_call_already_active", "Another RTC call is active")
            current.call = backend.call(token.getOrThrow(), current.input, listener)
            val value = snapshot(current)
            val reply = current.reply
            current.reply = null
            reply?.success(value)
            emit("state", value)
        } catch (failure: Exception) {
            // Core may throw after assigning its active call. Recover only our listener's call.
            if (current.call == null) {
                try { current.call = backend.recoverCall(listener) } catch (_: Exception) {
                    Log.e(TAG, "Unable to inspect RTC state after call failure")
                }
            }
            val reply = current.reply
            current.reply = null
            reply?.let { replyError(it, RtcFailure.native(failure)) }
            if (current.call == null) release(current) else {
                // Retain ownership until terminal callback; hangup remains available if this fails.
                try { current.call?.hangup() } catch (_: Exception) {
                    Log.e(TAG, "RTC call failed and could not be terminated; ownership retained")
                }
            }
        }
    }

    private fun nativeEvent(current: Session, type: String, reason: Int?) {
        if (disposed || session !== current || current.call == null) return
        if (type == "finished") finish(current, reason)
        else {
            // Callback kind is authoritative; status is a contemporaneous SDK snapshot and may
            // already have advanced by the time a queued callback reaches the Flutter thread.
            emit(type, snapshot(current), reason)
        }
    }

    private fun snapshot(current: Session, status: CallStatus? = null): Map<String, Any?>? = current.call?.let {
        mapOf("id" to it.id(), "type" to current.input.type, "status" to (status ?: it.status()).name.lowercase())
    }

    private fun finish(current: Session, reason: Int? = null) {
        val value = snapshot(current, CallStatus.FINISHED)
        release(current)
        emit("finished", value, reason)
    }

    private fun emit(type: String, call: Map<String, Any?>?, reason: Int? = null) {
        val event = mapOf("type" to type, "call" to call, "nativeErrorCode" to reason, "sequence" to ++sequence)
        lastEvent = event
        try { sink?.success(event) } catch (_: Exception) {
            sink = null
            Log.e(TAG, "RTC event sink is unavailable; native call ownership retained")
        }
    }

    private fun failPending(current: Session, error: RtcFailure) {
        val reply = current.reply
        current.reply = null
        release(current)
        reply?.let { replyError(it, error) }
    }

    private fun release(current: Session) {
        current.timeout?.let(main::removeCallbacks)
        current.tokenTask?.cancel(true)
        current.listener?.detach() // protects even callbacks already holding the old listener
        // A no-op replacement is safe even if Core has queued a callback that reads its listener.
        try { current.call?.setEventListener(RtcListener.detached) } catch (_: Exception) {
            // The detached forwarding listener no longer references this manager or a Dart sink.
            Log.e(TAG, "Unable to clear RTC event listener")
        }
        current.listener = null
        current.call = null
        current.tokenTask = null
        current.timeout = null
        if (session === current) {
            session = null
            slot.release(this)
        }
    }

    /** MM cleanup cannot erase authentication under a live call. Pending HTTP work is cancelled. */
    fun prepareCleanup(): RtcFailure? {
        check(Looper.myLooper() == main.looper)
        if (cleaning) return RtcFailure("rtc_invalid_state", "Mobile Messaging cleanup is already in progress")
        val current = session
        if (current == null) {
            if (backend.hasActiveCall() || !slot.acquire(this)) {
                return RtcFailure("rtc_invalid_state", "Another engine owns an RTC operation; finish it before cleanup")
            }
            cleaning = true
            lastEvent = null
            return null
        }
        if (current.call != null) {
            if (current.call?.status() != CallStatus.FINISHED) {
                return RtcFailure("rtc_invalid_state", "Hang up and wait for the finished event before Mobile Messaging cleanup")
            }
            finish(current)
        } else failPending(current, RtcFailure("rtc_invalid_state", "RTC request cancelled by Mobile Messaging cleanup"))
        lastEvent = null
        check(slot.acquire(this)) // release above and reacquisition are atomic on the main thread
        cleaning = true
        return null
    }

    fun completeCleanup() {
        if (cleaning) slot.release(this)
        cleaning = false
    }

    /** Engine destruction ends owned calls. Ordinary Activity detach never invokes this. */
    fun dispose() {
        check(Looper.myLooper() == main.looper)
        if (disposed) return
        disposed = true
        sink = null
        lastEvent = null
        session?.let { current ->
            try { current.call?.hangup() } catch (_: Exception) {
                Log.e(TAG, "Unable to hang up RTC call during engine disposal")
            }
            failPending(current, RtcFailure("rtc_invalid_state", "RTC engine was disposed"))
        }
        completeCleanup()
        executor.shutdownNow()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) = onMain {
        if (!disposed) {
            sink = events
            // Reattach recovers the current native state; no unbounded history or credential cache.
            val active = session?.let(::snapshot)
            if (active != null) emit("state", active)
            else events?.success(lastEvent ?: mapOf("type" to "state", "call" to null, "nativeErrorCode" to null, "sequence" to sequence))
        }
    }

    override fun onCancel(arguments: Any?) = onMain { sink = null }

    private fun onMain(action: () -> Unit) {
        if (Looper.myLooper() == main.looper) action() else main.post(action)
    }

    private fun replyError(result: MethodChannel.Result, error: RtcFailure) = result.error(error.code, error.message, null)

    companion object {
        const val METHOD_CHANNEL = "infobip_mobilemessaging_huawei/huawei_rtc"
        const val EVENT_CHANNEL = "infobip_mobilemessaging_huawei/huawei_rtc/events"
        private const val TOKEN_TIMEOUT_MS = 30_000L
        private const val TAG = "HuaweiRtc"
    }
}
