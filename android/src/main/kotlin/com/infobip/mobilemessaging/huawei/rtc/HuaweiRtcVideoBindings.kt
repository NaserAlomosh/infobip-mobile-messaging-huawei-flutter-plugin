package com.infobip.mobilemessaging.huawei.rtc

import android.util.Log
import com.infobip.webrtc.sdk.api.call.ApplicationCall
import com.infobip.webrtc.sdk.api.model.video.RTCVideoTrack
import com.infobip.webrtc.sdk.api.model.video.VideoRenderer
import com.infobip.webrtc.sdk.api.options.VideoOptions.CameraOrientation
import org.webrtc.RendererCommon.ScalingType

internal data class HuaweiRtcVideoOptions(val callId: String, val local: Boolean) {
    companion object {
        fun decode(args: Any?): HuaweiRtcVideoOptions? {
            val map = args as? Map<*, *> ?: return null
            val id = (map["callId"] as? String)?.takeIf { it.isNotBlank() } ?: return null
            val local = when (map["source"]) { "local" -> true; "remote" -> false; else -> return null }
            return HuaweiRtcVideoOptions(id, local)
        }
    }
}

internal interface HuaweiRtcVideoViewOwner {
    fun initializeRenderer(mirror: Boolean): VideoRenderer
    fun showVideo()
    fun clearImage()
    fun layoutScreenPreview(enabled: Boolean)
    fun releaseRenderer()
}

/** Main-thread rendering bookkeeping only. Never creates, controls, or disposes a call/track. */
internal class HuaweiRtcVideoBindings {
    private val bindings = mutableSetOf<Binding>()
    private var sessionKey: Any? = null
    private var localTrack: RTCVideoTrack? = null
    private var localRead = false

    inner class Binding internal constructor(
        internal var session: Any?,
        internal var owner: HuaweiRtcVideoViewOwner?,
        internal val local: Boolean,
        internal var renderer: VideoRenderer?,
        private var mirrored: Boolean,
    ) {
        private var active = true
        private var attemptedTrack: RTCVideoTrack? = null
        private var endpoint: String? = null
        private var screenPreview = false

        internal fun preview(mirror: Boolean, screenOutput: Boolean) {
            if (!active || !local) return
            if (!rendering("preview policy") {
                if (mirrored != mirror) {
                    renderer?.setMirror(mirror)
                    mirrored = mirror
                }
                if (screenPreview != screenOutput) {
                    renderer?.setScalingType(if (screenOutput) ScalingType.SCALE_ASPECT_FIT else ScalingType.SCALE_ASPECT_BALANCED)
                    owner?.layoutScreenPreview(screenOutput)
                    screenPreview = screenOutput
                }
            }) close()
        }

        internal fun reconcile(track: RTCVideoTrack?, replaceLocal: Boolean = false) {
            if (!active) return
            // Local wrapper identity is not native-track identity. Local camera events explicitly
            // invalidate the attachment; ordinary remote refreshes reuse the cached local track.
            if (!replaceLocal && attemptedTrack === track) return
            val previous = attemptedTrack
            attemptedTrack = null
            if (previous != null && !rendering("sink removal") { previous.removeSink(requireNotNull(renderer)) }) {
                close() // uncertain removal must never be followed by replacement attachment
                return
            }
            if (track == null) {
                rendering("clear frame") { owner?.clearImage() }
                return
            }
            attemptedTrack = track // addSink may fail after partially registering its sink
            if (!rendering("sink attachment") { track.addSink(requireNotNull(renderer)); owner?.showVideo() }) close()
        }

        internal fun remoteTrack(videos: Map<String, com.infobip.webrtc.sdk.api.model.RemoteVideo>): RTCVideoTrack? {
            if (videos.size != 1) return null
            val entry = videos.entries.single()
            if (endpoint == null) endpoint = entry.key
            return if (entry.key == endpoint) entry.value.camera else null
        }

        fun close() {
            if (!active) return
            active = false
            val oldTrack = attemptedTrack
            val oldRenderer = renderer
            val oldOwner = owner
            attemptedTrack = null
            renderer = null
            owner = null
            session = null
            endpoint = null
            try {
                if (oldTrack != null && oldRenderer != null) {
                    rendering("sink cleanup") { oldTrack.removeSink(oldRenderer) }
                }
            } finally {
                bindings.remove(this)
                rendering("renderer cleanup") { oldOwner?.releaseRenderer() }
                if (bindings.isEmpty()) resetSnapshot()
            }
        }
    }

    fun bind(session: Any, call: ApplicationCall, owner: HuaweiRtcVideoViewOwner, options: HuaweiRtcVideoOptions,
        screenOutput: Boolean = false): Binding? {
        if (sessionKey !== session) {
            disposeViews()
            sessionKey = session
        }
        var binding: Binding? = null
        if (!rendering("renderer initialization") {
                val mirror = options.local && !screenOutput && call.cameraOrientation() == CameraOrientation.FRONT
                binding = Binding(session, owner, options.local, owner.initializeRenderer(mirror), mirror)
                bindings.add(requireNotNull(binding))
            }) {
            rendering("initialization cleanup") { owner.releaseRenderer() }
            return null
        }
        updatePreview(session, call, screenOutput)
        refresh(session, call)
        return binding?.takeIf { it.owner != null }
    }

    /** Display controls affect this renderer only, never the SDK publication or track. */
    fun updatePreview(session: Any, call: ApplicationCall, screenOutput: Boolean) {
        if (sessionKey !== session || bindings.none { it.local }) return
        rendering("preview snapshot") {
            val mirror = !screenOutput && call.cameraOrientation() == CameraOrientation.FRONT
            bindings.toList().filter { it.session === session && it.local }.forEach {
                it.preview(mirror, screenOutput)
            }
        }
    }

    fun refresh(session: Any, call: ApplicationCall, localChanged: Boolean = false) {
        if (sessionKey !== session || bindings.isEmpty()) return
        var nextLocal = localTrack
        var videos = emptyMap<String, com.infobip.webrtc.sdk.api.model.RemoteVideo>()
        val hasLocal = bindings.any { it.local }
        if (!rendering("track snapshot") {
                if (hasLocal && (!localRead || localChanged)) nextLocal = call.localCameraTrack()
                if (bindings.any { !it.local }) videos = call.remoteVideos()
            }) {
            // A snapshot failure blanks and invalidates rendering, never the active call.
            endSession(session)
            return
        }
        if (hasLocal) { localTrack = nextLocal; localRead = true }
        bindings.toList().forEach {
            if (it.session === session) {
                it.reconcile(if (it.local) nextLocal else it.remoteTrack(videos), it.local && localChanged)
            }
        }
    }

    fun endSession(session: Any) {
        bindings.toList().filter { it.session === session }.forEach { it.close() }
        if (sessionKey === session) resetSnapshot()
    }

    fun disposeViews() {
        bindings.toList().forEach { it.close() }
        resetSnapshot()
    }

    private fun resetSnapshot() { sessionKey = null; localTrack = null; localRead = false }

    companion object {
        internal fun rendering(operation: String, action: () -> Unit): Boolean = try {
            action()
            true
        } catch (error: Exception) {
            // Class and fixed operation only: no SDK messages, call IDs, identities, or tokens.
            Log.e("HuaweiRtcVideo", "$operation failed (${error.javaClass.simpleName})")
            false
        }
    }
}
