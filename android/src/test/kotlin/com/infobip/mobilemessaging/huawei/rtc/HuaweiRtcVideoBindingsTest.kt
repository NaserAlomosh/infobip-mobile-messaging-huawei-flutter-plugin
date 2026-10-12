package com.infobip.mobilemessaging.huawei.rtc

import com.infobip.webrtc.sdk.api.call.ApplicationCall
import com.infobip.webrtc.sdk.api.model.RemoteVideo
import com.infobip.webrtc.sdk.api.model.video.RTCVideoTrack
import com.infobip.webrtc.sdk.api.model.video.VideoRenderer
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class HuaweiRtcVideoBindingsTest {
    private val call = mock(ApplicationCall::class.java)
    private val renderer = mock(VideoRenderer::class.java)
    private val owner = mock(HuaweiRtcVideoViewOwner::class.java).also {
        `when`(it.initializeRenderer(anyBoolean())).thenReturn(renderer)
    }
    private val bindings = HuaweiRtcVideoBindings()
    private val session = Any()
    private val options = HuaweiRtcVideoOptions("call", false)
    private fun camera(endpoint: String, track: RTCVideoTrack?) = mapOf(endpoint to RemoteVideo(track, null))
    private fun remote(track: RTCVideoTrack?): HuaweiRtcVideoBindings.Binding? {
        `when`(call.remoteVideos()).thenReturn(camera("agent", track))
        return bindings.bind(session, call, owner, options)
    }

    @Test fun `late view binds snapshot and repeated refresh does not add duplicate sink`() {
        val track = mock(RTCVideoTrack::class.java)
        val binding = remote(track)
        assertNotNull(binding)
        bindings.refresh(session, call)
        verify(track, times(1)).addSink(renderer)
        binding!!.close()
        binding.close()
        verify(track, times(1)).removeSink(renderer)
        verify(owner, times(1)).releaseRenderer()
        verify(call, never()).hangup()
    }

    @Test fun `replacement removes old sink first and camera removal clears frame`() {
        val first = mock(RTCVideoTrack::class.java)
        val next = mock(RTCVideoTrack::class.java)
        remote(first)
        `when`(call.remoteVideos()).thenReturn(camera("agent", next))
        bindings.refresh(session, call)
        val order = inOrder(first, next)
        order.verify(first).addSink(renderer)
        order.verify(first).removeSink(renderer)
        order.verify(next).addSink(renderer)
        `when`(call.remoteVideos()).thenReturn(camera("agent", null))
        bindings.refresh(session, call)
        verify(next).removeSink(renderer)
        verify(owner).clearImage()
        `when`(call.remoteVideos()).thenReturn(camera("agent", next))
        bindings.refresh(session, call)
        verify(next, times(2)).addSink(renderer)
    }

    @Test fun `selection is pinned and ambiguity never substitutes another camera or screen share`() {
        val agent = mock(RTCVideoTrack::class.java)
        val other = mock(RTCVideoTrack::class.java)
        remote(agent)
        `when`(call.remoteVideos()).thenReturn(camera("other", other))
        bindings.refresh(session, call)
        verify(agent).removeSink(renderer)
        verify(other, never()).addSink(any())
        `when`(call.remoteVideos()).thenReturn(mapOf("agent" to RemoteVideo(null, other)))
        bindings.refresh(session, call)
        verify(other, never()).addSink(any())
        `when`(call.remoteVideos()).thenReturn(camera("agent", agent) + camera("other", other))
        bindings.refresh(session, call)
        verify(agent, times(1)).addSink(renderer)
    }

    @Test fun `local snapshots are cached until an explicit camera event despite wrapper churn`() {
        val first = mock(RTCVideoTrack::class.java)
        val updated = mock(RTCVideoTrack::class.java)
        `when`(call.localCameraTrack()).thenReturn(first, updated)
        bindings.bind(session, call, owner, options.copy(local = true))
        bindings.refresh(session, call)
        verify(call, times(1)).localCameraTrack()
        verify(first, times(1)).addSink(renderer)
        bindings.refresh(session, call, true)
        verify(first).removeSink(renderer)
        verify(updated).addSink(renderer)
    }

    @Test fun `late old session refresh is ignored and terminal cleanup releases once`() {
        val track = mock(RTCVideoTrack::class.java)
        remote(track)
        bindings.refresh(Any(), call, true)
        verify(track, times(1)).addSink(renderer)
        bindings.endSession(session)
        bindings.refresh(session, call, true)
        bindings.disposeViews()
        verify(owner, times(1)).releaseRenderer()
        verify(track, times(1)).removeSink(renderer)
    }

    @Test fun `failed add attempts cleanup and never controls call`() {
        val track = mock(RTCVideoTrack::class.java)
        doThrow(IllegalStateException()).`when`(track).addSink(renderer)
        assertNull(remote(track))
        verify(track).removeSink(renderer)
        verify(owner).releaseRenderer()
        verify(call, never()).hangup()
    }

    @Test fun `failed remove prevents replacement attachment and releases view`() {
        val old = mock(RTCVideoTrack::class.java)
        val replacement = mock(RTCVideoTrack::class.java)
        remote(old)
        doThrow(IllegalStateException()).`when`(old).removeSink(renderer)
        `when`(call.remoteVideos()).thenReturn(camera("agent", replacement))
        bindings.refresh(session, call)
        bindings.refresh(session, call)
        verify(replacement, never()).addSink(any())
        verify(owner).releaseRenderer()
    }

    @Test fun `initialization and snapshot failures are isolated`() {
        doThrow(IllegalStateException()).`when`(owner).initializeRenderer(anyBoolean())
        assertNull(bindings.bind(session, call, owner, options))
        verify(owner).releaseRenderer()
        verify(call, never()).hangup()
    }

    @Test fun `snapshot failure invalidates existing views`() {
        remote(mock(RTCVideoTrack::class.java))
        `when`(call.remoteVideos()).thenThrow(IllegalStateException())
        bindings.refresh(session, call)
        verify(owner).releaseRenderer()
        verify(call, never()).hangup()
    }

    @Test fun `one failing renderer release cannot block other views or repeated calls`() {
        val track = mock(RTCVideoTrack::class.java)
        remote(track)
        val nextOwner = mock(HuaweiRtcVideoViewOwner::class.java)
        val nextRenderer = mock(VideoRenderer::class.java)
        `when`(nextOwner.initializeRenderer(anyBoolean())).thenReturn(nextRenderer)
        bindings.bind(session, call, nextOwner, options)
        doThrow(IllegalStateException()).`when`(owner).releaseRenderer()
        bindings.disposeViews()
        verify(nextOwner).releaseRenderer()
        verify(track).removeSink(nextRenderer)
        val newOwner = mock(HuaweiRtcVideoViewOwner::class.java)
        `when`(newOwner.initializeRenderer(anyBoolean())).thenReturn(mock(VideoRenderer::class.java))
        assertNotNull(bindings.bind(Any(), call, newOwner, options))
    }
}
