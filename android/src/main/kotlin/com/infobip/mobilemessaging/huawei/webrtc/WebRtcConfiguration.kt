package com.infobip.mobilemessaging.huawei.webrtc

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract

internal data class WebRtcConfiguration(
    val configurationId: String?,
) {
    companion object {
        fun fromMethodChannel(value: Any?): WebRtcConfiguration? {
            if (value == null) return null
            require(value is Map<*, *>) { "webRTCUI must be a map or null" }
            val configurationId = value[ChannelContract.CONFIGURATION_ID]
            require(configurationId == null || configurationId is String) {
                "webRTCUI.configurationId must be a string or null"
            }
            return WebRtcConfiguration(configurationId as String?)
        }
    }
}

internal class WebRtcConfigurationState {
    var current: WebRtcConfiguration? = null
        private set

    fun capture(configuration: WebRtcConfiguration?) {
        current = configuration
    }

    fun clear() {
        current = null
    }
}
