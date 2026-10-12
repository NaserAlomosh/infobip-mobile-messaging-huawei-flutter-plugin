package com.infobip.mobilemessaging.huawei.rtc

import com.infobip.webrtc.sdk.api.call.ApplicationCall
import com.infobip.webrtc.sdk.api.device.AudioDeviceManager
import com.infobip.webrtc.sdk.api.model.device.AudioDevice
import com.infobip.webrtc.sdk.api.model.device.AudioDeviceType
import com.infobip.webrtc.sdk.api.options.VideoOptions.CameraOrientation
import org.junit.Assert.*
import org.junit.Test
import org.mockito.Mockito.*

class HuaweiRtcControlsTest {
    private val call = mock(ApplicationCall::class.java)
    private val devices = mock(AudioDeviceManager::class.java)
    private val bluetooth = AudioDevice(AudioDeviceType.BLUETOOTH, "headset")
    init {
        `when`(call.id()).thenReturn("call-1")
        `when`(call.audioDeviceManager()).thenReturn(devices)
        `when`(devices.availableAudioDevices).thenReturn(setOf(AudioDevice.SPEAKER, AudioDevice.EARPIECE, bluetooth))
        `when`(devices.activeDevice).thenReturn(AudioDevice.EARPIECE)
        `when`(call.cameraOrientation()).thenReturn(CameraOrientation.FRONT)
    }
    private fun apply(method: String, args: Map<String, Any> = emptyMap(), video: Boolean = true) =
        HuaweiRtcControls.apply(call, video, method, args)
    private fun failure(code: String, action: () -> Unit) {
        try { action(); fail("Expected $code") } catch (error: RtcFailure) { assertEquals(code, error.code) }
    }

    @Test fun `mute forwards only outgoing microphone and repeated desired state is idempotent`() {
        apply("setMicrophoneMuted", mapOf("enabled" to true))
        verify(call).mute(true)
        `when`(call.muted()).thenReturn(true)
        apply("setMicrophoneMuted", mapOf("enabled" to true))
        apply("setMicrophoneMuted", mapOf("enabled" to false))
        verify(call, times(1)).mute(true)
        verify(call).mute(false)
        verify(call, never()).speakerphone(anyBoolean())
        verify(call, never()).cameraVideo(anyBoolean())
    }
    @Test fun `speaker and earpiece routing never modify microphone`() {
        apply("setSpeakerEnabled", mapOf("enabled" to true))
        verify(devices).selectAudioDevice(AudioDevice.SPEAKER)
        `when`(devices.activeDevice).thenReturn(AudioDevice.SPEAKER)
        apply("setSpeakerEnabled", mapOf("enabled" to false))
        verify(devices).selectAudioDevice(AudioDevice.EARPIECE)
        verify(call, never()).mute(anyBoolean())
    }
    @Test fun `available Bluetooth device selected and repeated route is idempotent`() {
        apply("selectAudioOutput", mapOf("output" to "bluetooth"))
        verify(devices).selectAudioDevice(bluetooth)
        `when`(devices.activeDevice).thenReturn(bluetooth)
        apply("selectAudioOutput", mapOf("output" to "bluetooth"))
        verify(devices, times(1)).selectAudioDevice(bluetooth)
        `when`(devices.availableAudioDevices).thenReturn(setOf(AudioDevice.SPEAKER))
        failure("rtc_control_unavailable") { apply("selectAudioOutput", mapOf("output" to "bluetooth")) }
        failure("rtc_control_unavailable") { apply("setSpeakerEnabled", mapOf("enabled" to false)) }
    }
    @Test fun `camera switching toggles orientation and detects SDK silent failure`() {
        `when`(call.hasCameraVideo()).thenReturn(true)
        doAnswer { `when`(call.cameraOrientation()).thenReturn(it.getArgument(0)); null }
            .`when`(call).cameraOrientation(any(CameraOrientation::class.java))
        apply("switchCamera"); verify(call).cameraOrientation(CameraOrientation.BACK)
        apply("switchCamera"); verify(call).cameraOrientation(CameraOrientation.FRONT)
        doNothing().`when`(call).cameraOrientation(CameraOrientation.BACK)
        failure("rtc_call_failed") { apply("switchCamera") }
    }
    @Test fun `camera disabling and enabling forwards without hangup or incoming video pause`() {
        `when`(call.hasCameraVideo()).thenReturn(true)
        apply("setCameraEnabled", mapOf("enabled" to false))
        verify(call).cameraVideo(false)
        `when`(call.hasCameraVideo()).thenReturn(false)
        apply("setCameraEnabled", mapOf("enabled" to false))
        apply("setCameraEnabled", mapOf("enabled" to true))
        verify(call, times(1)).cameraVideo(false)
        verify(call).cameraVideo(true)
        verify(call, never()).hangup()
        verify(call, never()).pauseIncomingVideo()
        failure("rtc_invalid_state") { apply("switchCamera") }
        failure("rtc_invalid_state") { apply("setCameraEnabled", mapOf("enabled" to true), false) }
    }
    @Test fun `snapshot reflects SDK values and invalid argument never changes state`() {
        `when`(call.muted()).thenReturn(true)
        `when`(call.hasCameraVideo()).thenReturn(true)
        val state = HuaweiRtcControls.snapshot(call, true)
        assertEquals(true, state["microphoneMuted"])
        assertEquals(true, state["cameraEnabled"])
        assertEquals("earpiece", state["audioOutput"])
        assertEquals(listOf("bluetooth", "earpiece", "speaker"), state["availableAudioOutputs"])
        failure("rtc_invalid_argument") { apply("setMicrophoneMuted", mapOf("enabled" to "true")) }
        verify(call, never()).mute(anyBoolean())
    }
    @Test fun `failed SDK operation propagates and snapshot remains authoritative`() {
        doThrow(SecurityException("private")).`when`(call).mute(true)
        try { apply("setMicrophoneMuted", mapOf("enabled" to true)); fail() } catch (_: SecurityException) {}
        assertEquals(false, HuaweiRtcControls.snapshot(call, true)["microphoneMuted"])
    }
}
