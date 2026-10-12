package com.infobip.mobilemessaging.huawei.rtc

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import com.infobip.webrtc.sdk.videofilter.VideoFilter
import com.infobip.webrtc.sdk.videofilter.VideoFilterManager

/** Experimental camera substitution. No SDK implementation classes or native screen track. */
internal class HuaweiRtcScreenVideoFilter(private val cameraFrame: (Long) -> Unit,
    private val screenFrame: (Long) -> Unit, private val filterStopped: () -> Unit) : VideoFilter {
    private val lock = Any()
    private var manager: VideoFilterManager? = null
    private var latest: Bitmap? = null
    private var generation = 0L
    private var sharing = false
    private var cameraReported = false
    private var screenReported = false
    private var width = 640
    private var height = 480
    private val paint = Paint(Paint.FILTER_BITMAP_FLAG)

    fun begin(): Long = synchronized(lock) { sharing = true; screenReported = false; ++generation }
    fun block() = synchronized(lock) {
        sharing = false
        cameraReported = false
        generation++
        latest?.recycle()
        latest = null
        generation
    }
    /** Ownership transfers even when rejected. At most one capture bitmap is retained. */
    fun offer(frame: Bitmap, epoch: Long) = synchronized(lock) {
        if (!sharing || epoch != generation) frame.recycle()
        else { latest?.recycle(); latest = frame }
    }
    override fun start(w: Int, h: Int, fps: Int, context: Context, output: VideoFilterManager) {
        synchronized(lock) { width = w; height = h; manager = output }
    }
    override fun stop() = synchronized(lock) { manager = null; block(); filterStopped() }
    override fun applyFilter(bitmap: Bitmap, rotation: Int, timestampNs: Long) {
        synchronized(lock) {
            val output = manager ?: return
            if (!sharing) {
                output.notifyFrameProcessed(bitmap, rotation, timestampNs)
                if (!cameraReported) { cameraReported = true; cameraFrame(generation) }
                return
            }
            // Runs on SDK filter worker, not RTC capture thread. Camera cadence supplies
            // monotonic timestamps and backpressure. Never recycle a submitted bitmap:
            // public API has no consumption callback; immutable output is GC-owned.
            val result = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(result)
            canvas.drawColor(Color.BLACK)
            // RTC 2.5.28 rotates the bitmap texture 180 degrees for rotation=0;
            // WebRTC YuvConverter then flips Y. Together they flip X. Compensate
            // only substituted screen pixels, in the existing output allocation.
            canvas.scale(-1f, 1f, width / 2f, height / 2f)
            latest?.let { frame ->
                val scale = minOf(width.toFloat() / frame.width, height.toFloat() / frame.height)
                val w = frame.width * scale
                val h = frame.height * scale
                canvas.drawBitmap(frame, null, RectF((width-w)/2, (height-h)/2, (width+w)/2, (height+h)/2), paint)
            }
            // Display-oriented screen output is independent of camera facing/rotation.
            output.notifyFrameProcessed(result, 0, timestampNs)
            if (latest != null && !screenReported) { screenReported = true; screenFrame(generation) }
        }
    }
}
