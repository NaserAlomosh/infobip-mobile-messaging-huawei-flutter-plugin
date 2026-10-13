package com.infobip.mobilemessaging.huawei.webrtc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WebRtcConfigurationTest {
    @Test
    fun `missing WebRTC configuration is accepted`() {
        assertNull(WebRtcConfiguration.fromMethodChannel(null))
    }

    @Test
    fun `configuration ID is parsed exactly`() {
        val configuration =
            WebRtcConfiguration.fromMethodChannel(mapOf("configurationId" to "rtc-id"))

        assertEquals("rtc-id", configuration?.configurationId)
    }

    @Test
    fun `null configuration ID is accepted`() {
        val configuration =
            WebRtcConfiguration.fromMethodChannel(mapOf("configurationId" to null))

        assertNull(configuration?.configurationId)
    }

    @Test
    fun `empty and whitespace configuration IDs are preserved`() {
        assertEquals(
            "",
            WebRtcConfiguration.fromMethodChannel(mapOf("configurationId" to ""))
                ?.configurationId,
        )
        assertEquals(
            "  ",
            WebRtcConfiguration.fromMethodChannel(mapOf("configurationId" to "  "))
                ?.configurationId,
        )
    }

    @Test
    fun `state is cleared for a new initialization lifecycle`() {
        val state = WebRtcConfigurationState()
        state.capture(WebRtcConfiguration("rtc-id"))

        state.clear()

        assertNull(state.current)
    }
}
