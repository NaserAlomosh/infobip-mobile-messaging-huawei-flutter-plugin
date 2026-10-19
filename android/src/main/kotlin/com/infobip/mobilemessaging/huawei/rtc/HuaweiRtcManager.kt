package com.infobip.mobilemessaging.huawei.rtc

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.infobip.webrtc.sdk.api.call.ApplicationCall
import com.infobip.webrtc.sdk.api.model.CallStatus
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
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
    private val notification: RtcCallNotification? = null,
    private val chatIdentities: LiveChatIdentityResolver? = null,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    constructor(context: Context, initialized: () -> Boolean, canStartCall: () -> Boolean) : this(
        initialized, canStartCall,
        { video -> checkRtcPermissions(context.applicationContext, video) },
        HuaweiRtcTokenProvider(context.applicationContext), HuaweiRtcBackend(context.applicationContext),
        notification = HuaweiRtcCallNotification(context),
        chatIdentities = NativeLiveChatIdentityResolver(context.applicationContext),
    )

    fun beginIdentityMutation() {
        RtcIdentityLifecycle.begin()
        session?.takeIf { it.input.chatWidgetId != null && it.call == null }?.let {
            failPending(it, RtcFailure("rtc_invalid_state", "Messaging identity changed before call submission"))
        }
    }
    fun endIdentityMutation() { RtcIdentityLifecycle.end() }

    private class Session(val input: RtcInput, var reply: MethodChannel.Result?) {
        val identity = UUID.randomUUID().toString()
        @Volatile var cancelled = false
        var identityEpoch: Long? = null
        @Volatile var resolvedIdentity: ResolvedChatIdentity? = null
        var ending = false
        var endTimeout: Runnable? = null
        var serviceTimeout: Runnable? = null
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
    private var notificationReturn: String? = null
    private val videoBindings = HuaweiRtcVideoBindings()
    internal var screenCapture: HuaweiRtcScreenCaptureController? = null
        private set

    internal fun configureScreenCapture(context: Context) {
        screenCapture = HuaweiRtcScreenCaptureController(context, owner = {
            session?.let { current -> current.call?.let { ScreenCaptureCall(current.identity, it, current.input.video) } }
        }, previewChanged = { capture ->
            val current = session
            if (!disposed && current != null && current.identity == capture.identity && current.call === capture.call) {
                videoBindings.updatePreview(current, capture.call, screenCapture?.substituting(current.identity) == true)
            }
        })
    }

    fun bindVideo(view: HuaweiRtcVideoViewOwner, options: HuaweiRtcVideoOptions): HuaweiRtcVideoBindings.Binding? {
        var binding: HuaweiRtcVideoBindings.Binding? = null
        HuaweiRtcVideoBindings.rendering("session binding") {
            check(Looper.myLooper() == main.looper)
            val current = session
            val call = current?.call
            if (!disposed && !cleaning && canStartCall() && current != null &&
                current.input.video && call != null && call.id() == options.callId &&
                call.status() != CallStatus.FINISHED && call.status() != CallStatus.FINISHING) {
                binding = videoBindings.bind(current, call, view, options,
                    screenOutput = screenCapture?.substituting(current.identity) == true)
            }
        }
        return binding
    }

    fun detachVideoViews() {
        HuaweiRtcVideoBindings.rendering("view detach") { videoBindings.disposeViews() }
    }

    private fun refreshVideo(current: Session, localChanged: Boolean) {
        if (disposed || session !== current || !current.input.video) return
        HuaweiRtcVideoBindings.rendering("video refresh") {
            val call = current.call ?: return@rendering
            if (call.status() == CallStatus.FINISHED || call.status() == CallStatus.FINISHING) {
                videoBindings.endSession(current)
            } else {
                videoBindings.updatePreview(current, call, screenCapture?.substituting(current.identity) == true)
                videoBindings.refresh(current, call, localChanged)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) = onMain {
        try {
            if (disposed) throw RtcFailure("rtc_invalid_state", "RTC plugin has been disposed")
            when (call.method) {
                "startScreenAsCamera", "stopScreenAsCamera", "getScreenAsCameraState" -> {
                    val id = (call.arguments as? Map<*, *>)?.get("callId") as? String
                        ?: throw RtcFailure("rtc_invalid_argument", "Provide the current call ID")
                    val capture = screenCapture ?: throw RtcFailure("screen_unsupported", "Capture adapter unavailable")
                    when (call.method) {
                        "startScreenAsCamera" -> capture.start(id, result)
                        "stopScreenAsCamera" -> capture.stop(id, result)
                        else -> result.success(capture.snapshot(id))
                    }
                }
                "callApplication" -> start(RtcInput.decode(call.arguments), result)
                "hangup" -> {
                    val active = session?.call ?: throw RtcFailure("rtc_no_active_call", "There is no active RTC call")
                    if (active.status() == CallStatus.FINISHED) {
                        finish(requireNotNull(session))
                        throw RtcFailure("rtc_no_active_call", "There is no active RTC call")
                    }
                    screenCapture?.endCall()
                    active.hangup()
                    // A void native hangup is acceptance, not remote termination acknowledgement.
                    result.success(null)
                }
                "getCallControls", "setMicrophoneMuted", "setSpeakerEnabled", "switchCamera",
                "setCameraEnabled", "selectAudioOutput" -> {
                    val args = call.arguments as? Map<*, *>
                        ?: throw RtcFailure("rtc_invalid_argument", "Provide the current call ID")
                    val id = args["callId"] as? String
                        ?: throw RtcFailure("rtc_invalid_argument", "Provide the current call ID")
                    val current = session ?: throw RtcFailure("rtc_no_active_call", "There is no active RTC call")
                    val active = current.call ?: throw RtcFailure("rtc_no_active_call", "There is no active RTC call")
                    if (active.id() != id) throw RtcFailure("rtc_invalid_state", "The requested call is no longer current")
                    if (active.status() == CallStatus.FINISHED) {
                        finish(current)
                        throw RtcFailure("rtc_no_active_call", "There is no active RTC call")
                    }
                    if (call.method != "getCallControls") {
                        if (screenCapture?.busy() == true && call.method in listOf("switchCamera", "setCameraEnabled"))
                            throw RtcFailure("screen_camera_locked", "Stop capture before changing camera publication")
                        if (active.status() != CallStatus.ESTABLISHED || !canStartCall() || cleaning)
                            throw RtcFailure("rtc_invalid_state", "Controls require an established foreground call")
                        permissions(current.input.video && (call.method == "switchCamera" ||
                            (call.method == "setCameraEnabled" && args["enabled"] == true)))
                        HuaweiRtcControls.apply(active, current.input.video, call.method, args)
                    }
                    result.success(HuaweiRtcControls.snapshot(active, current.input.video))
                }
                "takeNotificationCall" -> {
                    val current = session
                    val requested = notificationReturn
                    notificationReturn = null
                    result.success(current?.takeIf { it.identity == requested &&
                        it.call?.status() != CallStatus.FINISHED }?.let(::snapshot))
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
        val epoch = if (input.chatWidgetId != null) {
            try { RtcIdentityLifecycle.capture() } catch (failure: RtcFailure) {
                slot.release(this)
                throw failure
            }
        } else null
        val current = Session(input, result)
        current.identityEpoch = epoch
        session = current
        val timeout = Runnable {
            if (session === current && current.call == null) {
                failPending(current, if (input.chatWidgetId != null && current.resolvedIdentity == null)
                    RtcFailure("rtc_identity_unavailable", "Chat identity lookup timed out")
                else RtcFailure("rtc_token_failed", "RTC access token request timed out"))
            }
        }
        current.timeout = timeout
        main.postDelayed(timeout, TOKEN_TIMEOUT_MS)
        val task = FutureTask<Unit> {
            val token = try {
                if (current.cancelled) throw RtcFailure("rtc_invalid_state", "Call preparation cancelled")
                val identity = if (input.chatWidgetId != null) {
                    val resolver = chatIdentities ?: throw RtcFailure(
                        "rtc_identity_unavailable", "Chat identity resolution is unavailable")
                    resolver.resolve(input.chatWidgetId, requireNotNull(input.expectedExternalUserId)).also {
                        current.resolvedIdentity = it
                    }.subject
                } else input.identity
                if (current.cancelled || Thread.currentThread().isInterrupted) throw RtcFailure("rtc_invalid_state", "Call preparation cancelled")
                Result.success(tokens.fetch(identity))
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
            val failure = (error as? RtcFailure)?.takeIf { it.code in setOf("rtc_not_initialized", "rtc_invalid_state", "rtc_identity_unavailable") }
                ?: RtcFailure("rtc_token_failed", "RTC access token acquisition failed")
            failPending(current, failure)
            return
        }
        try {
            validateIdentity(current)
            checkReady(current.input)
            if (notification == null) { createCall(current, token.getOrThrow()); return }
            val timeout = Runnable {
                if (session === current && current.call == null) failPending(current,
                    RtcFailure("rtc_foreground_service_failed", "RTC foreground service timed out"))
            }
            current.serviceTimeout = timeout
            main.postDelayed(timeout, 5000)
            notification.start(current.identity, current.input.video,
                state = { notificationState(current) },
                action = { action, id, muted -> notificationAction(current, action, id, muted) },
                ready = { failure ->
                    if (!disposed && session === current) {
                        current.serviceTimeout?.let(main::removeCallbacks)
                        current.serviceTimeout = null
                        if (failure != null) failPending(current, failure)
                        else createCall(current, token.getOrThrow())
                    }
                })
        } catch (failure: Exception) { failPending(current, RtcFailure.native(failure)) }
    }

    private fun validateIdentity(current: Session) {
        current.identityEpoch?.let {
            RtcIdentityLifecycle.validate(it)
            requireNotNull(current.resolvedIdentity).validate()
        }
    }

    private fun createCall(current: Session, token: String) {
        val listener = RtcListener { type, reason ->
            // Always enqueue: a synchronous SDK callback must not race callApplication's return.
            main.post { nativeEvent(current, type, reason) }
        }
        current.listener = listener
        listener.cameraChanged = { localChanged ->
            main.post { refreshVideo(current, localChanged) }
        }
        try {
            validateIdentity(current)
            checkReady(current.input) // permissions / initialization can change during the HTTP request
            if (backend.hasActiveCall()) throw RtcFailure("rtc_call_already_active", "Another RTC call is active")
            current.call = backend.call(token, current.input, listener)
            current.resolvedIdentity = null
            current.identityEpoch = null
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

    fun handleNotificationIntent(intent: Intent) {
        notification?.returnIdentity(intent)?.let {
            notificationReturn = it
            session?.let { current -> emit("returnToCall", snapshot(current)) }
            // Consume Activity intent once, including across configuration recreation.
            intent.removeExtra(HuaweiRtcCallService.IDENTITY)
        }
    }

    private fun notificationState(current: Session): RtcNotificationState? {
        if (disposed || session !== current) return null
        val call = current.call ?: return RtcNotificationState(null, current.input.video, "calling")
        if (call.status() == CallStatus.FINISHED) { finish(current); return null }
        return RtcNotificationState(call.id(), current.input.video, call.status().name.lowercase(),
            call.duration().coerceAtLeast(0),
            if (call.status() == CallStatus.ESTABLISHED) try { call.muted() } catch (_: Exception) { null } else null)
    }

    private fun notificationAction(current: Session, action: String, id: String?, muted: Boolean?) {
        if (disposed || session !== current) return
        val call = current.call
        if (call?.id() != id) return
        if (action == HuaweiRtcCallService.MUTE) {
            if (call == null || current.ending || call.status() != CallStatus.ESTABLISHED || muted == null) return
            try {
                permissions(false)
                HuaweiRtcControls.apply(call, current.input.video, "setMicrophoneMuted", mapOf("enabled" to muted))
            } catch (_: Exception) { Log.e(TAG, "RTC notification microphone control failed") }
        } else if (action == HuaweiRtcCallService.END || action == HuaweiRtcCallService.FAILURE) {
            if (call == null) { failPending(current, RtcFailure("rtc_invalid_state", "RTC request cancelled")); return }
            if (call.status() == CallStatus.FINISHED) { finish(current); return }
            if (current.ending) return
            current.ending = true
            screenCapture?.endCall()
            try { call.hangup() } catch (_: Exception) { Log.e(TAG, "RTC notification hangup failed") }
            val timeout = Runnable {
                if (session === current) {
                    if (call.status() == CallStatus.FINISHED) finish(current)
                    else {
                        try { call.hangup() } catch (_: Exception) { Log.e(TAG, "RTC hangup retry failed") }
                        notification?.stop(current.identity)
                        // Retain ownership; never invent finished or allow a replacement.
                        Log.e(TAG, "RTC terminal callback timed out; notification stopped, ownership retained")
                    }
                }
            }
            current.endTimeout = timeout
            main.postDelayed(timeout, 10_000)
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
        mapOf("id" to it.id(), "type" to current.input.type, "status" to (status ?: it.status()).name.lowercase(), "durationSeconds" to it.duration().coerceAtLeast(0))
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
        screenCapture?.endCall()
        current.serviceTimeout?.let(main::removeCallbacks)
        current.endTimeout?.let(main::removeCallbacks)
        notification?.stop(current.identity)
        if (notificationReturn == current.identity) notificationReturn = null
        current.listener?.detachRendering()
        HuaweiRtcVideoBindings.rendering("session rendering cleanup") { videoBindings.endSession(current) }
        current.timeout?.let(main::removeCallbacks)
        current.cancelled = true
        current.resolvedIdentity = null
        current.identityEpoch = null
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
        detachVideoViews()
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
