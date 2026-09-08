package com.infobip.mobilemessaging.huawei.rtc

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.infobip.webrtc.sdk.api.InfobipRTC
import com.infobip.webrtc.sdk.api.call.ApplicationCall
import com.infobip.webrtc.sdk.api.event.call.*
import com.infobip.webrtc.sdk.api.model.CallStatus
import com.infobip.webrtc.sdk.api.model.ErrorCode
import com.infobip.webrtc.sdk.api.options.ApplicationCallOptions
import com.infobip.webrtc.sdk.api.request.CallApplicationRequest
import com.infobip.webrtc.sdk.impl.event.listener.DefaultApplicationCallEventListener
import java.util.logging.Level

internal interface RtcBackend {
    fun hasActiveCall(): Boolean
    fun call(token: String, input: RtcInput, listener: RtcListener): ApplicationCall
    fun recoverCall(listener: RtcListener): ApplicationCall? = null
}

internal class HuaweiRtcBackend(context: Context, private val rtc: () -> InfobipRTC = { InfobipRTC.getInstance() }) : RtcBackend {
    private val application = context.applicationContext

    override fun hasActiveCall(): Boolean = rtc().let {
        listOf(it.activeApplicationCall?.status(), it.activeCall?.status(), it.activeRoomCall?.status())
            .any { status -> status != null && status != CallStatus.FINISHED }
    }

    override fun call(token: String, input: RtcInput, listener: RtcListener): ApplicationCall {
        // Public process-wide setting: avoid Core diagnostic payloads in application logs.
        InfobipRTC.setLogLevel(Level.OFF)
        return rtc().callApplication(
            CallApplicationRequest(token, application, input.callsConfigurationId, listener),
            ApplicationCallOptions.builder().audio(true).video(input.video).build(),
        )
    }

    override fun recoverCall(listener: RtcListener): ApplicationCall? =
        rtc().activeApplicationCall?.takeIf { it.eventListener === listener }
}

internal fun checkRtcPermissions(context: Context, video: Boolean) {
    val required = mutableListOf(Manifest.permission.RECORD_AUDIO)
    if (video) required += Manifest.permission.CAMERA
    // The SDK integration contract requires this before calls on Android 12+.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) required += Manifest.permission.BLUETOOTH_CONNECT
    if (required.any { ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED }) {
        throw RtcFailure("rtc_permission_denied", "Grant microphone, camera for video, and Nearby devices on Android 12+ before calling")
    }
}

/** The SDK's documented no-op adapter implements the remaining application-call callbacks. */
internal class RtcListener(callback: (String, Int?) -> Unit) : DefaultApplicationCallEventListener() {
    companion object { val detached = DefaultApplicationCallEventListener() }
    @Volatile private var callback: ((String, Int?) -> Unit)? = callback
    fun detach() { callback = null }
    private fun emit(type: String, reason: ErrorCode? = null) { callback?.invoke(type, reason?.id) }
    override fun onRinging(event: CallRingingEvent) = emit("ringing")
    override fun onEarlyMedia(event: CallEarlyMediaEvent) = emit("earlyMedia")
    override fun onEstablished(event: CallEstablishedEvent) = emit("established")
    override fun onHangup(event: CallHangupEvent) = emit("finished", event.errorCode)
    // onError is not necessarily terminal (e.g. a media operation can fail).
    override fun onError(event: ErrorEvent) = emit("error", event.errorCode)
    override fun onReconnecting(event: ReconnectingEvent) = emit("reconnecting")
    override fun onReconnected(event: ReconnectedEvent) = emit("reconnected")
}
