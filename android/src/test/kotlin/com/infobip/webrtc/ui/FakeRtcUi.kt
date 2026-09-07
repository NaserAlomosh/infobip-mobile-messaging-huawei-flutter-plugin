package com.infobip.webrtc.ui

import android.content.Context
import com.infobip.webrtc.ui.model.ListenType

fun interface SuccessListener {
    fun onSuccess()
}

fun interface ErrorListener {
    fun onError(error: Any?)
}

class InfobipRtcUi {
    fun disableCalls(success: SuccessListener, error: ErrorListener) {
        calls += "rtcUi.disableCalls"
        success.onSuccess()
    }

    class Builder(context: Context?) {
        init {
            calls += "builder.constructor"
        }

        fun withConfigurationId(configurationId: String): Builder {
            calls += "builder.withConfigurationId:$configurationId"
            return this
        }

        fun withCalls(
            identity: String,
            listenType: ListenType,
            success: SuccessListener,
            error: ErrorListener,
        ): BuilderFinalStep {
            calls += "builder.withCalls:$identity:$listenType"
            return BuilderFinalStep()
        }

        fun withCalls(success: SuccessListener, error: ErrorListener): BuilderFinalStep {
            calls += "builder.withCalls"
            return BuilderFinalStep()
        }

        fun withInAppChatCalls(success: SuccessListener, error: ErrorListener): BuilderFinalStep {
            calls += "builder.withInAppChatCalls"
            return BuilderFinalStep()
        }
    }

    class BuilderFinalStep {
        fun build(): InfobipRtcUi {
            calls += "finalStep.build"
            return builtInstance
        }
    }

    companion object {
        val calls = mutableListOf<String>()
        val builtInstance = InfobipRtcUi()
    }
}
