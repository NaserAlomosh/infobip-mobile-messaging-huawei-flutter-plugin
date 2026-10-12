package com.infobip.mobilemessaging.huawei.rtc

import com.infobip.webrtc.sdk.api.call.ApplicationCall
import com.infobip.webrtc.sdk.api.model.device.AudioDeviceType
import com.infobip.webrtc.sdk.api.options.VideoOptions.CameraOrientation

/** Only SDK readback crosses the channel; never optimistic UI flags. */
internal object HuaweiRtcControls {
    fun snapshot(call: ApplicationCall, video: Boolean): Map<String, Any?> {
        val devices = call.audioDeviceManager()
        return mapOf(
            "callId" to call.id(),
            "microphoneMuted" to call.muted(),
            "speakerEnabled" to call.speakerphone(),
            "cameraEnabled" to (video && call.hasCameraVideo()),
            "cameraOrientation" to call.cameraOrientation()?.name?.lowercase(),
            "audioOutput" to devices?.activeDevice?.audioDeviceType?.name?.lowercase()?.replace("wired_headset", "wiredHeadset"),
            "availableAudioOutputs" to (devices?.availableAudioDevices.orEmpty()
                .map { it.audioDeviceType.name.lowercase().replace("wired_headset", "wiredHeadset") }.distinct().sorted()),
        )
    }

    fun apply(call: ApplicationCall, video: Boolean, method: String, args: Map<*, *>) {
        fun boolean(): Boolean = args["enabled"] as? Boolean
            ?: throw RtcFailure("rtc_invalid_argument", "Provide a boolean enabled value")
        fun requireVideo() {
            if (!video) throw RtcFailure("rtc_invalid_state", "Camera controls require a video call")
        }
        fun select(output: String) {
            val devices = call.audioDeviceManager()
                ?: throw RtcFailure("rtc_control_unavailable", "Audio device selection is unavailable")
            val type = AudioDeviceType.values().firstOrNull { it.name.lowercase().replace("wired_headset", "wiredHeadset") == output }
                ?: throw RtcFailure("rtc_invalid_argument", "Unknown audio output")
            val device = devices.availableAudioDevices.firstOrNull { it.audioDeviceType == type }
                ?: throw RtcFailure("rtc_control_unavailable", "Requested audio output is unavailable")
            if (devices.activeDevice != device) devices.selectAudioDevice(device)
        }
        when (method) {
            "setMicrophoneMuted" -> boolean().let { if (call.muted() != it) call.mute(it) }
            // Explicit earpiece selection avoids SDK fallback to Bluetooth when speaker is off.
            "setSpeakerEnabled" -> select(if (boolean()) "speaker" else "earpiece")
            "selectAudioOutput" -> select(args["output"] as? String
                ?: throw RtcFailure("rtc_invalid_argument", "Provide an audio output"))
            "setCameraEnabled" -> { requireVideo(); boolean().let { if (call.hasCameraVideo() != it) call.cameraVideo(it) } }
            "switchCamera" -> {
                requireVideo()
                if (!call.hasCameraVideo()) throw RtcFailure("rtc_invalid_state", "Enable the camera before switching")
                val previous = call.cameraOrientation()
                    ?: throw RtcFailure("rtc_control_unavailable", "Camera orientation is unavailable")
                val target = if (previous == CameraOrientation.FRONT) CameraOrientation.BACK else CameraOrientation.FRONT
                call.cameraOrientation(target)
                // SDK can report camera errors by callback instead of throwing.
                if (call.cameraOrientation() != target) throw RtcFailure("rtc_call_failed", "Camera switch failed")
            }
        }
    }
}
