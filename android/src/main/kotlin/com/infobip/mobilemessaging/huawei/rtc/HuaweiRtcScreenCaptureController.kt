package com.infobip.mobilemessaging.huawei.rtc

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import androidx.core.content.ContextCompat
import com.infobip.webrtc.sdk.api.call.ApplicationCall
import com.infobip.webrtc.sdk.api.model.CallStatus
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

internal data class ScreenCaptureCall(val identity: String, val call: ApplicationCall, val video: Boolean)

/** Experimental, main-thread session controller; owns the exact projection it acquires. */
internal class HuaweiRtcScreenCaptureController(context: Context, private val owner: () -> ScreenCaptureCall?,
    private val sdkInt: () -> Int = { Build.VERSION.SDK_INT },
    private val projectionProvider: (Int, Intent) -> MediaProjection? = { code, data ->
        context.applicationContext.getSystemService(MediaProjectionManager::class.java).getMediaProjection(code, data)
    },
    private val readerProvider: (Int, Int) -> ImageReader = { w, h ->
        ImageReader.newInstance(w, h, PixelFormat.RGBA_8888, 2)
    },
    private val shutdownWorker: (HandlerThread) -> Unit = { worker ->
        worker.quitSafely()
        worker.join(500)
    },
    private val stopService: () -> Boolean = {
        context.applicationContext.stopService(Intent(context, HuaweiRtcScreenCaptureService::class.java))
    }) : EventChannel.StreamHandler {
    private val app = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private var activity: Activity? = null
    private var sink: EventChannel.EventSink? = null
    private var session: Capture? = null
    private var filterCall: ApplicationCall? = null
    private var filter: HuaweiRtcScreenVideoFilter? = null
    private var last = idle()
    private var lastCapture: Capture? = null
    private class Capture(val owner: ScreenCaptureCall, val request: Int, val filter: HuaweiRtcScreenVideoFilter,
                          var startReply: MethodChannel.Result?) {
        val identity = UUID.randomUUID().toString()
        val callId = owner.call.id()
        var state = "requestingPermission"
        var epoch = 0L
        var projection: MediaProjection? = null
        var callback: MediaProjection.Callback? = null
        var display: VirtualDisplay? = null
        var reader: ImageReader? = null
        var worker: HandlerThread? = null
        var frames: HuaweiRtcScreenFrameProcessor? = null
        var stopRequested = false
        var terminated = false
        var released = false
        var restored = false
        var completed = false
        var cleanupRunning = false
        var cleanupAttempts = 0
        var restoreEpoch = -1L
        var captureWidth = 0
        var captureHeight = 0
        var resizeReported = false
        var serviceStopped = false
        var error: String? = null
        val stops = mutableListOf<MethodChannel.Result>()
    }
    companion object {
        const val EVENTS = "infobip_mobilemessaging_huawei/screen_as_camera/events"
        // Do not reuse request IDs when a cancelled Activity result can arrive late.
        private var requestId = 43000
        private fun idle() = mapOf<String, Any?>("callId" to null, "state" to "idle", "framesBlocked" to true,
            "projectionTerminated" to true, "resourcesReleased" to true, "cameraOutputRestored" to false, "error" to null)
    }
    fun attach(value: Activity) { activity = value }
    fun detach() { activity = null; session?.let { stop(it, "activity_detached") } }
    fun busy() = session != null
    private fun valid(c: Capture): Boolean = owner()?.let {
        it.identity == c.owner.identity && it.call === c.owner.call &&
            it.call.status() != CallStatus.FINISHED && it.call.status() != CallStatus.FINISHING
    } == true
    fun snapshot(callId: String): Map<String, Any?> {
        val current = owner() ?: throw RtcFailure("rtc_no_active_call", "No active call")
        if (current.call.id() != callId) throw RtcFailure("rtc_invalid_state", "Stale call ID")
        return session?.takeIf { it.owner.identity == current.identity }?.let(::value)
            ?: last.takeIf { it["callId"] == callId && session == null }
            ?: idle().plus("callId" to callId)
    }
    fun start(callId: String, result: MethodChannel.Result) {
        if (sdkInt() < 29) throw RtcFailure("screen_unsupported", "Screen as camera requires Android 10+")
        val current = owner() ?: throw RtcFailure("rtc_no_active_call", "No active call")
        if (current.call.id() != callId) throw RtcFailure("rtc_invalid_state", "Stale call ID")
        if (session != null) throw RtcFailure("screen_busy", "Capture operation is already active")
        val host = activity ?: throw RtcFailure("screen_activity_missing", "Return to the call Activity")
        if (!host.hasWindowFocus() || !current.video || current.call.status() != CallStatus.ESTABLISHED ||
            !current.call.hasCameraVideo()) throw RtcFailure("screen_camera_required", "Use an established video call with camera enabled")
        if (filterCall !== current.call) {
            if (current.call.videoFilter != null) throw RtcFailure("screen_filter_conflict", "Another camera filter is installed")
            filter = HuaweiRtcScreenVideoFilter(
                cameraFrame = { epoch -> main.post {
                    val c = session ?: lastCapture
                    if (c != null && valid(c) && filterCall === current.call &&
                        c.owner.identity == current.identity && c.restoreEpoch == epoch && c.stopRequested) {
                        c.restored = true; publish(c)
                    }
                } },
                screenFrame = { epoch -> main.post { session?.let { c -> if (c.owner.call === current.call && c.epoch == epoch && !c.stopRequested && c.state == "starting" && valid(c)) {
                    c.state = "sharing"; publish(c)
                    val reply = c.startReply; c.startReply = null; safely { reply?.success(value(c)) }
                } } } },
                filterStopped = { main.post { session?.takeIf { it.owner.call === current.call }?.let { stop(it, "filter_stopped") } } },
            )
            current.call.setVideoFilter(filter)
            if (current.call.videoFilter !== filter) throw RtcFailure("screen_filter_failed", "Camera filter installation failed")
            filterCall = current.call
        }
        if (requestId >= 65000) throw RtcFailure("screen_busy", "Capture request limit reached; restart after ending the call")
        val c = Capture(current, ++requestId, requireNotNull(filter), result)
        session = c
        lastCapture = c
        publish(c)
        try { host.startActivityForResult(app.getSystemService(MediaProjectionManager::class.java).createScreenCaptureIntent(), c.request) }
        catch (_: Exception) { stop(c, "permission_launch_failed") }
    }
    fun permission(request: Int, resultCode: Int, data: Intent?): Boolean {
        if (request !in 43001..65000) return false
        val c = session?.takeIf { it.request == request && !it.stopRequested } ?: return true
        if (!valid(c)) { stop(c, "call_ended"); return true }
        if (resultCode != Activity.RESULT_OK || data == null) {
            c.state = "cancelled"; c.stopRequested = true; c.terminated = true; c.released = true
            val reply = c.startReply; c.startReply = null
            safely { reply?.error("screen_permission_cancelled", "Screen capture permission cancelled", null) }
            publish(c); session = null; return true
        }
        c.state = "starting"; publish(c)
        // Consent remains only in this one-shot closure, never persisted or reused.
        val lease = HuaweiRtcScreenCaptureService.Lease(c.identity,
            ready = { ready ->
                if (session === c && !c.stopRequested) {
                    if (!valid(c)) stop(c, "call_ended")
                    else if (ready) acquire(c, resultCode, data) else stop(c, "service_failed")
                }
            }, ended = {
                if (session === c) {
                    if (HuaweiRtcScreenCaptureService.lease == null) {
                        c.serviceStopped = true
                        c.cleanupAttempts = minOf(c.cleanupAttempts, 2)
                    }
                    stop(c, "service_ended")
                }
            })
        HuaweiRtcScreenCaptureService.lease = lease
        try { ContextCompat.startForegroundService(app, Intent(app, HuaweiRtcScreenCaptureService::class.java).putExtra("identity", c.identity)) }
        catch (_: Exception) { stop(c, "service_failed") }
        main.postDelayed({ if (session === c && !c.stopRequested && c.state == "starting") stop(c, "start_timeout") }, 8000)
        return true
    }
    private fun acquire(c: Capture, code: Int, data: Intent) {
        try {
            val projection = projectionProvider(code, data)
                ?: throw IllegalStateException("No projection")
            c.projection = projection
            val callback = object : MediaProjection.Callback() {
                override fun onStop() {
                    c.terminated = true
                    if (!c.stopRequested) stop(c, "projection_revoked") else { c.cleanupAttempts = minOf(c.cleanupAttempts, 2); cleanup(c) }
                }
                override fun onCapturedContentResize(width: Int, height: Int) {
                    if (width <= 0 || height <= 0 || c.stopRequested) return
                    if (!c.resizeReported) {
                        c.resizeReported = true
                        c.captureWidth = width; c.captureHeight = height
                        return
                    }
                    if (width == c.captureWidth && height == c.captureHeight) return
                    stop(c, "capture_size_changed")
                }
            }
            c.callback = callback
            projection.registerCallback(callback, main)
            val metrics = app.resources.displayMetrics
            c.captureWidth = metrics.widthPixels
            c.captureHeight = metrics.heightPixels
            val scale = minOf(1f, 640f / maxOf(metrics.widthPixels, metrics.heightPixels))
            val w = (metrics.widthPixels * scale).toInt().coerceAtLeast(1)
            val h = (metrics.heightPixels * scale).toInt().coerceAtLeast(1)
            val worker = HandlerThread("HuaweiScreenPoc").apply { start() }
            c.worker = worker
            val handler = Handler(worker.looper)
            val reader = readerProvider(w, h)
            c.reader = reader
            c.epoch = c.filter.begin()
            val frames = HuaweiRtcScreenFrameProcessor(w, h)
            c.frames = frames
            reader.setOnImageAvailableListener({ source ->
                try {
                    frames.drain(source, c.filter, c.epoch)
                } catch (_: Exception) { main.post { if (session === c && !c.stopRequested) stop(c, "frame_failed") } }
            }, handler)
            c.display = projection.createVirtualDisplay("Huawei screen-as-camera POC", w, h, metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, reader.surface, null, handler)
        } catch (_: Exception) { stop(c, "capture_failed") }
    }
    fun stop(callId: String, result: MethodChannel.Result) {
        snapshot(callId) // reject stale call operations, even duplicate stops
        val c = session?.takeIf { it.owner.identity == owner()?.identity }
        if (c == null) { result.success(snapshot(callId)); return }
        if (!c.cleanupRunning) c.cleanupAttempts = 0
        c.stops += result
        main.postDelayed({
            if (c.stops.remove(result)) {
                c.state = "error"; c.error = "stop_uncertain"; publish(c)
                safely { result.error("screen_stop_uncertain", "Capture termination was not confirmed", null) }
            }
        }, 3000)
        stop(c)
    }
    fun endCall() {
        session?.let { stop(it, "call_ended") }
        filter?.block()
        filter = null; filterCall = null; lastCapture = null
    }
    private fun stop(c: Capture, reason: String? = null) {
        if (!c.stopRequested) {
            c.stopRequested = true; c.error = reason; c.state = "stopping"
            c.restoreEpoch = c.filter.block()
            val reply = c.startReply; c.startReply = null
            safely { reply?.error("screen_cancelled", "Capture start did not complete", null) }
            publish(c)
            main.postDelayed({
                if (!c.completed) {
                    c.state = "error"; c.error = "stop_uncertain"; publish(c)
                }
            }, 3000)
        }
        cleanup(c)
    }
    /** Each successful step clears only its own reference. Failed steps retain ownership. */
    private fun cleanup(c: Capture) {
        if (c.completed || c.cleanupRunning || c.cleanupAttempts >= 3) return
        c.cleanupRunning = true
        c.cleanupAttempts++
        fun attempt(action: () -> Unit) {
            try { action() } catch (_: Exception) { c.error = "cleanup_failed" }
        }
        attempt {
            if (c.projection == null) c.terminated = true
            else if (!c.terminated) c.projection?.stop()
        }
        attempt { c.display?.release(); c.display = null }
        // Drain capture work before closing its reader. Never join on the main thread.
        val worker = c.worker
        fun finish() {
            if (c.worker == null) attempt { c.frames?.release(); c.frames = null }
            if (c.worker == null) attempt {
                c.reader?.setOnImageAvailableListener(null, null)
                c.reader?.close(); c.reader = null
            }
            if (c.terminated) attempt {
                c.callback?.let { c.projection?.unregisterCallback(it) }
                c.callback = null; c.projection = null
            }
            attempt {
                if (!c.serviceStopped) {
                    val lease = HuaweiRtcScreenCaptureService.lease
                    if (lease == null || lease.identity != c.identity) c.serviceStopped = true
                    else if (!stopService()) {
                        HuaweiRtcScreenCaptureService.lease = null
                        c.serviceStopped = true
                    }
                }
            }
            c.released = c.display == null && c.reader == null && c.worker == null && c.frames == null &&
                c.callback == null && c.serviceStopped
            c.cleanupRunning = false
            if (c.terminated && c.released) {
                c.completed = true
                c.state = if (c.error == null || c.error in listOf("projection_revoked", "activity_detached", "call_ended", "capture_size_changed")) "stopped" else "error"
                publish(c)
                val replies = c.stops.toList(); c.stops.clear()
                replies.forEach { safely { it.success(value(c)) } }
                if (session === c) session = null
            } else {
                publish(c)
                if (c.cleanupAttempts < 3) main.postDelayed({ cleanup(c) }, 250)
            }
        }
        if (worker == null) finish()
        else {
            // quitSafely drains already queued image callbacks; offer() remains blocked.
            Thread {
                try { shutdownWorker(worker) } catch (_: Exception) { }
                main.post {
                    if (!worker.isAlive) c.worker = null
                    if (c.worker != null) c.error = "cleanup_failed"
                    finish()
                }
            }.start()
        }
    }
    private fun value(c: Capture) = mapOf<String, Any?>("callId" to c.callId, "state" to c.state,
        "framesBlocked" to (c.stopRequested || c.epoch == 0L), "projectionTerminated" to c.terminated,
        "resourcesReleased" to c.released, "cameraOutputRestored" to c.restored, "error" to c.error)
    private fun publish(c: Capture) { last = value(c); deliver(last) }
    private fun safely(action: () -> Unit) { try { action() } catch (_: Exception) { /* Engine loss cannot prevent capture teardown. */ } }
    private fun deliver(value: Map<String, Any?>) {
        try { sink?.success(value) } catch (_: Exception) { sink = null }
    }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events; deliver(session?.let(::value) ?: last) }
    override fun onCancel(arguments: Any?) { sink = null }
}
