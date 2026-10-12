package com.infobip.mobilemessaging.huawei.rtc

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.media.projection.MediaProjection
import android.hardware.display.VirtualDisplay
import android.view.Surface
import com.infobip.webrtc.sdk.api.call.ApplicationCall
import com.infobip.webrtc.sdk.api.model.CallStatus
import com.infobip.webrtc.sdk.videofilter.VideoFilter
import com.infobip.webrtc.sdk.videofilter.VideoFilterManager
import org.junit.Assert.*
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import io.flutter.plugin.common.MethodChannel

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class HuaweiRtcScreenAsCameraTest {
    private val app: Context = RuntimeEnvironment.getApplication()
    private val call = mock(ApplicationCall::class.java)
    private var owner: ScreenCaptureCall? = ScreenCaptureCall("session-A", call, true)
    private var installed: VideoFilter? = null
    private val host = mock(Activity::class.java)
    private var request = 0
    private val controller = HuaweiRtcScreenCaptureController(app, owner = { owner }, sdkInt = { 29 })
    init {
        `when`(call.id()).thenReturn("A")
        `when`(call.status()).thenReturn(CallStatus.ESTABLISHED)
        `when`(call.hasCameraVideo()).thenReturn(true)
        `when`(call.videoFilter).thenAnswer { installed }
        doAnswer { installed = it.arguments[0] as VideoFilter; null }.`when`(call).setVideoFilter(any())
        `when`(host.hasWindowFocus()).thenReturn(true)
        doAnswer { request = it.arguments[1] as Int; null }.`when`(host).startActivityForResult(any(), anyInt())
        controller.attach(host)
    }
    private class Reply : MethodChannel.Result {
        var code: String? = null
        var value: Any? = null
        var completions = 0
        override fun success(result: Any?) { completions++; value = result }
        override fun error(errorCode: String, errorMessage: String?, details: Any?) { completions++; code = errorCode }
        override fun notImplemented() { error("missing", null, null) }
    }
    @After fun cleanup() { controller.endCall(); shadowOf(Looper.getMainLooper()).idle() }
    @Test fun `unsupported API never requests capture`() {
        val old = HuaweiRtcScreenCaptureController(app, owner = { owner })
        try { old.start("A", Reply()); fail() } catch (e: RtcFailure) { assertEquals("screen_unsupported", e.code) }
        verify(host, never()).startActivityForResult(any(), anyInt())
    }
    @Test fun `duplicate start and permission cancellation`() {
        val first = Reply(); controller.start("A", first)
        try { controller.start("A", Reply()); fail() } catch (e: RtcFailure) { assertEquals("screen_busy", e.code) }
        assertTrue(controller.permission(request, Activity.RESULT_CANCELED, null))
        assertEquals("screen_permission_cancelled", first.code)
        assertEquals("cancelled", controller.snapshot("A")["state"])
        assertEquals(true, controller.snapshot("A")["framesBlocked"])
    }
    @Test fun `duplicate stop invalidates consent without SDK signaling`() {
        val start = Reply(); controller.start("A", start)
        val stale = request
        val stop = Reply(); controller.stop("A", stop)
        val again = Reply(); controller.stop("A", again)
        assertEquals(1, stop.completions); assertEquals(1, again.completions)
        assertTrue(controller.permission(stale, Activity.RESULT_OK, Intent()))
        assertEquals("stopped", controller.snapshot("A")["state"])
        verify(call, never()).stopScreenShare()
        verify(call, never()).hangup()
    }
    @Test fun `session replacement rejects stale operations and results`() {
        controller.start("A", Reply())
        val stale = request
        controller.endCall()
        owner = ScreenCaptureCall("session-B", mock(ApplicationCall::class.java), true)
        assertTrue(controller.permission(stale, Activity.RESULT_OK, Intent()))
        try { controller.stop("A", Reply()); fail() } catch (e: RtcFailure) { assertEquals("rtc_invalid_state", e.code) }
    }
    @Test fun `Activity recreation cancels pending capture and releases owner`() {
        val start = Reply(); controller.start("A", start)
        controller.detach()
        assertEquals("screen_cancelled", start.code)
        assertFalse(controller.busy())
        assertEquals(true, controller.snapshot("A")["projectionTerminated"])
    }
    @Test fun `audio only disabled camera and missing Activity are rejected`() {
        owner = ScreenCaptureCall("session-A", call, false)
        try { controller.start("A", Reply()); fail() } catch (e: RtcFailure) { assertEquals("screen_camera_required", e.code) }
        owner = ScreenCaptureCall("session-A", call, true)
        `when`(call.hasCameraVideo()).thenReturn(false)
        try { controller.start("A", Reply()); fail() } catch (e: RtcFailure) { assertEquals("screen_camera_required", e.code) }
        controller.detach()
        try { controller.start("A", Reply()); fail() } catch (e: RtcFailure) { assertEquals("screen_activity_missing", e.code) }
    }
    @Test fun `SDK filter failure never launches consent or captures`() {
        doThrow(IllegalStateException("media unavailable")).`when`(call).setVideoFilter(any())
        try { controller.start("A", Reply()); fail() } catch (_: IllegalStateException) { }
        assertFalse(controller.busy())
        verify(host, never()).startActivityForResult(any(), anyInt())
    }
    @Test fun `filter forwards camera and rejects stale screen bitmap`() {
        var camera = 0; var screen = 0
        val filter = HuaweiRtcScreenVideoFilter({ camera++ }, { screen++ }, {})
        val output = mock(VideoFilterManager::class.java)
        filter.start(640, 480, 30, app, output)
        val cameraBitmap = Bitmap.createBitmap(640, 480, Bitmap.Config.ARGB_8888)
        filter.applyFilter(cameraBitmap, 90, 1234)
        verify(output).notifyFrameProcessed(cameraBitmap, 90, 1234)
        assertEquals(1, camera)
        val epoch = filter.begin()
        val screenBitmap = Bitmap.createBitmap(20, 40, Bitmap.Config.ARGB_8888)
        filter.offer(screenBitmap, epoch)
        filter.applyFilter(cameraBitmap, 90, 2345)
        assertEquals(1, screen)
        filter.block(); assertTrue(screenBitmap.isRecycled)
        val stale = Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888)
        filter.offer(stale, epoch); assertTrue(stale.isRecycled)
        filter.applyFilter(cameraBitmap, 90, 3456)
        verify(output).notifyFrameProcessed(cameraBitmap, 90, 3456)
        assertEquals(2, camera)
        filter.stop()
        cameraBitmap.recycle()
    }
    @Test fun `projection stop confirms teardown without RTC signaling`() { projectionScenario(false) }
    @Test fun `system projection revocation releases resources without restart`() { projectionScenario(true) }
    @Test fun `call termination stops projection before SDK call teardown`() { projectionScenario(false, ending = true) }
    private fun projectionScenario(revoked: Boolean, ending: Boolean = false) {
        val projection = mock(MediaProjection::class.java)
        val display = mock(VirtualDisplay::class.java)
        var callback: MediaProjection.Callback? = null
        doAnswer { callback = it.arguments[0] as MediaProjection.Callback; null }.`when`(projection).registerCallback(any(), any())
        `when`(projection.createVirtualDisplay(anyString(), anyInt(), anyInt(), anyInt(), anyInt(),
            any(Surface::class.java), isNull(), any(Handler::class.java))).thenReturn(display)
        doAnswer { callback?.onStop(); null }.`when`(projection).stop()
        val capture = HuaweiRtcScreenCaptureController(app, owner = { owner }, sdkInt = { 29 },
            projectionProvider = { _, _ -> projection })
        capture.attach(host)
        capture.start("A", Reply())
        capture.permission(request, Activity.RESULT_OK, Intent())
        requireNotNull(HuaweiRtcScreenCaptureService.lease).complete(true)
        assertNotNull(callback)
        // An SDK screen-stop failure must be irrelevant, including indefinite reconnection.
        doThrow(IllegalStateException("signaling unavailable")).`when`(call).stopScreenShare()
        if (revoked) callback?.onStop()
        if (ending) { `when`(call.status()).thenReturn(CallStatus.FINISHING); capture.endCall() }
        val reply = Reply()
        capture.stop("A", reply)
        val limit = System.nanoTime() + 2_000_000_000
        while (reply.completions == 0 && System.nanoTime() < limit) {
            Thread.yield(); shadowOf(Looper.getMainLooper()).idle()
        }
        assertEquals(1, reply.completions)
        assertEquals(true, capture.snapshot("A")["projectionTerminated"])
        assertEquals(true, capture.snapshot("A")["resourcesReleased"])
        assertEquals(true, capture.snapshot("A")["framesBlocked"])
        verify(display).release()
        verify(projection).unregisterCallback(requireNotNull(callback))
        if (revoked) verify(projection, never()).stop() else verify(projection).stop()
        verify(call, never()).stopScreenShare()
        verify(call, never()).hangup()
        assertFalse(capture.busy())
    }
    @Test fun `missing termination callback reports uncertain instead of stopped`() {
        val projection = mock(MediaProjection::class.java)
        val capture = HuaweiRtcScreenCaptureController(app, owner = { owner }, sdkInt = { 29 },
            projectionProvider = { _, _ -> projection })
        capture.attach(host); capture.start("A", Reply()); capture.permission(request, Activity.RESULT_OK, Intent())
        requireNotNull(HuaweiRtcScreenCaptureService.lease).complete(true)
        val reply = Reply(); capture.stop("A", reply)
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofSeconds(4))
        assertEquals("screen_stop_uncertain", reply.code)
        assertEquals(false, capture.snapshot("A")["projectionTerminated"])
        assertEquals("error", capture.snapshot("A")["state"])
        assertTrue(capture.busy())
        // Test cleanup; production deliberately retains ownership while uncertain.
        HuaweiRtcScreenCaptureService.lease = null
    }
}
