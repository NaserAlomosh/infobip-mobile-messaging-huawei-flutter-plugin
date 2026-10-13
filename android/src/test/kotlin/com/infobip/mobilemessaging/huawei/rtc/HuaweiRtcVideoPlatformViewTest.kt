package com.infobip.mobilemessaging.huawei.rtc

import com.infobip.webrtc.sdk.api.model.video.VideoRenderer
import android.view.View
import android.widget.FrameLayout
import org.webrtc.RendererCommon.ScalingType
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class HuaweiRtcVideoPlatformViewTest {
    private val context = RuntimeEnvironment.getApplication()
    private val manager = mock(HuaweiRtcManager::class.java)

    @Test fun `invalid parameters allocate no renderer and disposal is inert`() {
        var allocated = 0
        val view = HuaweiRtcVideoPlatformView(context, manager, null) { allocated++; VideoRenderer(it) }
        view.dispose(); view.dispose()
        assertEquals(0, allocated)
        verifyNoInteractions(manager)
    }

    @Test fun `rejected call allocates no renderer`() {
        var allocated = 0
        val view = HuaweiRtcVideoPlatformView(context, manager, HuaweiRtcVideoOptions("unknown", true)) {
            allocated++; VideoRenderer(it)
        }
        assertEquals(0, allocated)
        view.dispose()
    }

    @Test fun `renderer initialization once and release failure clears references`() {
        val renderer = spy(VideoRenderer(context))
        doNothing().`when`(renderer).init()
        doThrow(IllegalStateException()).`when`(renderer).release()
        val view = HuaweiRtcVideoPlatformView(context, manager, null) { renderer }
        view.initializeRenderer(true)
        view.showVideo()
        assertEquals(View.VISIBLE, renderer.visibility)
        view.clearImage()
        assertEquals(View.INVISIBLE, renderer.visibility)
        view.dispose(); view.dispose()
        verify(renderer, times(1)).init()
        verify(renderer, times(1)).release()
        assertEquals(1, (view.view as FrameLayout).childCount) // only unavailable label remains
        assertSame(context, view.view.context)
    }

    @Test fun `creation options require exact call and camera source`() {
        assertNull(HuaweiRtcVideoOptions.decode(mapOf("callId" to "", "source" to "local")))
        assertNull(HuaweiRtcVideoOptions.decode(mapOf("callId" to "call", "source" to "screen")))
        assertEquals(HuaweiRtcVideoOptions("call", false), HuaweiRtcVideoOptions.decode(mapOf("callId" to "call", "source" to "remote")))
    }

    @Test fun `screen preview fit measures full video inside wide and tall containers then restores camera layout`() {
        val renderer = spy(VideoRenderer(context))
        doNothing().`when`(renderer).init()
        doNothing().`when`(renderer).release()
        val view = HuaweiRtcVideoPlatformView(context, manager, null) { renderer }
        view.initializeRenderer(false); view.showVideo()
        renderer.onFrameResolutionChanged(640, 480, 0)
        val container = view.view as FrameLayout
        fun measure(w: Int, h: Int) {
            container.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY))
            container.layout(0, 0, w, h)
        }
        measure(300, 160)
        assertEquals(300, renderer.measuredWidth); assertEquals(160, renderer.measuredHeight)
        renderer.setScalingType(ScalingType.SCALE_ASPECT_FIT)
        view.layoutScreenPreview(true)
        measure(300, 160)
        assertEquals(213, renderer.measuredWidth); assertEquals(160, renderer.measuredHeight)
        assertEquals(43, renderer.left); assertEquals(0, renderer.top)
        measure(160, 300)
        assertEquals(160, renderer.measuredWidth); assertEquals(120, renderer.measuredHeight)
        assertEquals(0, renderer.left); assertEquals(90, renderer.top)
        renderer.setScalingType(ScalingType.SCALE_ASPECT_BALANCED)
        view.layoutScreenPreview(false)
        measure(160, 300)
        assertEquals(160, renderer.measuredWidth); assertEquals(300, renderer.measuredHeight)
        view.dispose()
    }
}
