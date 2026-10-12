package com.infobip.mobilemessaging.huawei.rtc

import android.graphics.Bitmap
import android.media.Image
import android.media.ImageReader

/** Confined to one capture worker. Scratch storage never reaches the filter or SDK. */
internal class HuaweiRtcScreenFrameProcessor(private val width: Int, private val height: Int) {
    private var scratch: Bitmap? = null

    fun drain(source: ImageReader, filter: HuaweiRtcScreenVideoFilter, epoch: Long) {
        // Always drain and close, including queued callbacks after Stop. No bitmap work
        // for a blocked generation; offer still validates a Stop racing conversion.
        source.acquireLatestImage()?.use { image ->
            if (!filter.accepts(epoch)) return
            filter.offer(convert(image), epoch)
        }
    }

    private fun convert(image: Image): Bitmap {
        val plane = image.planes[0]
        val paddedWidth = plane.rowStride / plane.pixelStride
        var padded = scratch
        if (padded == null || padded.width != paddedWidth) {
            padded?.recycle()
            padded = Bitmap.createBitmap(paddedWidth, height, Bitmap.Config.ARGB_8888)
            scratch = padded
        }
        plane.buffer.rewind()
        padded.copyPixelsFromBuffer(plane.buffer)
        val frame = Bitmap.createBitmap(padded, 0, 0, width, height)
        // createBitmap may return its input for a full-size crop. Transfer only an
        // independent snapshot; the worker will overwrite scratch on the next image.
        return if (frame === padded) padded.copy(Bitmap.Config.ARGB_8888, false) else frame
    }

    /** Called only after the capture worker is confirmed dead, including cleanup retries. */
    fun release() {
        scratch?.recycle()
        scratch = null
    }
}
