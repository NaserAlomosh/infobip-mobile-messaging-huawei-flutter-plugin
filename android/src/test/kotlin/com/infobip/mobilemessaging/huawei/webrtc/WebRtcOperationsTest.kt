package com.infobip.mobilemessaging.huawei.webrtc

import android.content.Context
import com.infobip.webrtc.ui.InfobipRtcUi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

class WebRtcOperationsTest {
    private val runtime = RecordingRuntime()

    @Test
    fun `enable calls requires initialization`() {
        val result = operations(initialized = false, configuration = WebRtcConfiguration("rtc-id"))
            .enableCallsResult("identity")
        assertEquals("not_initialized", result.single()?.code)
        assertEquals(0, runtime.enableCount)
    }

    @Test
    fun `enable calls requires WebRTC configuration`() {
        assertEquals("webrtc_not_configured", operations(configuration = null).enableCallsResult("id").single()?.code)
    }

    @Test
    fun `enable calls rejects null configuration ID`() {
        assertEquals(
            "webrtc_not_configured",
            operations(configuration = WebRtcConfiguration(null)).enableCallsResult("id").single()?.code,
        )
    }

    @Test
    fun `enable calls rejects blank configuration ID`() {
        assertEquals(
            "webrtc_not_configured",
            operations(configuration = WebRtcConfiguration("  ")).enableCallsResult("id").single()?.code,
        )
    }

    @Test
    fun `nonblank identity and configuration are forwarded unchanged`() {
        operations(configuration = WebRtcConfiguration(" rtc ")).enableCallsResult("  identity  ")
        assertEquals(" rtc ", runtime.configurationId)
        assertEquals("  identity  ", runtime.identity)
        assertEquals("withConfigurationId,withCalls,build", runtime.events.joinToString(","))
    }

    @Test
    fun `blank identity selects calls overload without identity`() {
        operations(configuration = WebRtcConfiguration("rtc-id")).enableCallsResult(" ")
        assertEquals("withCallsWithoutIdentity", runtime.events[1])
    }

    @Test
    fun `chat calls use in app chat builder flow`() {
        operations(configuration = WebRtcConfiguration("rtc-id")).enableChatCallsResult()
        assertEquals("withConfigurationId,withInAppChatCalls,build", runtime.events.joinToString(","))
    }

    @Test
    fun `built RTC UI is retained and used to disable calls`() {
        val operations = operations(configuration = WebRtcConfiguration("rtc-id"))
        operations.enableCallsResult("id")
        operations.disableCallsResult()
        assertSame(runtime.builtRtcUi, runtime.disabledReceiver)
        assertEquals("disableCalls", runtime.events.last())
    }

    @Test
    fun `disable calls requires an enabled RTC UI`() {
        val result = operations(configuration = WebRtcConfiguration("rtc-id")).disableCallsResult()
        assertEquals("webrtc_not_enabled", result.single()?.code)
    }

    @Test
    fun `missing RTC classes return unavailable`() {
        runtime.failure = ClassNotFoundException("missing")
        val result = operations(configuration = WebRtcConfiguration("rtc-id")).enableCallsResult("id")
        assertEquals("webrtc_unavailable", result.single()?.code)
    }

    @Test
    fun `reflection errors return WebRTC error`() {
        runtime.failure = NoSuchMethodException("missing method")
        val result = operations(configuration = WebRtcConfiguration("rtc-id")).enableCallsResult("id")
        assertEquals("webrtc_error", result.single()?.code)
        assertEquals("missing method", result.single()?.message)
    }

    @Test
    fun `success callback completes exactly once`() {
        runtime.callbacks = { success, _ -> success(); success() }
        val result = operations(configuration = WebRtcConfiguration("rtc-id")).enableCallsResult("id")
        assertEquals(1, result.size)
        assertNull(result.single())
    }

    @Test
    fun `error callback completes exactly once`() {
        runtime.callbacks = { _, error -> error("first"); error("second") }
        val result = operations(configuration = WebRtcConfiguration("rtc-id")).enableCallsResult("id")
        assertEquals(1, result.size)
        assertEquals("first", result.single()?.message)
    }

    @Test
    fun `success followed by error does not complete twice`() {
        runtime.callbacks = { success, error -> success(); error("late") }
        val result = operations(configuration = WebRtcConfiguration("rtc-id")).enableCallsResult("id")
        assertEquals(listOf(null), result)
    }

    @Test
    fun `reset clears built RTC UI`() {
        val operations = operations(configuration = WebRtcConfiguration("rtc-id"))
        operations.enableCallsResult("id")
        operations.reset()
        assertEquals("webrtc_not_enabled", operations.disableCallsResult().single()?.code)
    }

    @Test
    fun `reflective runtime invokes builder then final step and stores build result`() {
        InfobipRtcUi.calls.clear()
        val operations = WebRtcOperations(
            null,
            { true },
            { WebRtcConfiguration("rtc-id") },
            ReflectiveWebRtcRuntime(),
        )

        operations.enableCallsResult(" identity ")
        operations.disableCallsResult()

        assertEquals(
            listOf(
                "builder.constructor",
                "builder.withConfigurationId:rtc-id",
                "builder.withCalls: identity :PUSH",
                "finalStep.build",
                "rtcUi.disableCalls",
            ),
            InfobipRtcUi.calls,
        )
    }

    @Test
    fun `reflective runtime invokes chat calls on builder and build on final step`() {
        InfobipRtcUi.calls.clear()
        val operations = WebRtcOperations(
            null,
            { true },
            { WebRtcConfiguration("rtc-id") },
            ReflectiveWebRtcRuntime(),
        )

        operations.enableChatCallsResult()

        assertEquals(
            listOf(
                "builder.constructor",
                "builder.withConfigurationId:rtc-id",
                "builder.withInAppChatCalls",
                "finalStep.build",
            ),
            InfobipRtcUi.calls,
        )
    }

    private fun operations(
        initialized: Boolean = true,
        configuration: WebRtcConfiguration?,
    ) = WebRtcOperations(null, { initialized }, { configuration }, runtime)

    private fun WebRtcOperations.enableCallsResult(identity: String): List<WebRtcFailure?> {
        val results = mutableListOf<WebRtcFailure?>()
        enableCalls(identity, results::add)
        return results
    }

    private fun WebRtcOperations.enableChatCallsResult(): List<WebRtcFailure?> {
        val results = mutableListOf<WebRtcFailure?>()
        enableChatCalls(results::add)
        return results
    }

    private fun WebRtcOperations.disableCallsResult(): List<WebRtcFailure?> {
        val results = mutableListOf<WebRtcFailure?>()
        disableCalls(results::add)
        return results
    }

    private class RecordingRuntime : WebRtcRuntime {
        val events = mutableListOf<String>()
        val builtRtcUi = Any()
        var configurationId: String? = null
        var identity: String? = null
        var disabledReceiver: Any? = null
        var enableCount = 0
        var failure: Exception? = null
        var callbacks: (() -> Unit, (String) -> Unit) -> Unit = { success, _ -> success() }

        override fun enableCalls(
            context: Context?,
            configurationId: String,
            identity: String,
            success: () -> Unit,
            error: (String) -> Unit,
        ): Any {
            start(configurationId)
            this.identity = identity
            events += if (identity.isNotBlank()) "withCalls" else "withCallsWithoutIdentity"
            return finish(success, error)
        }

        override fun enableChatCalls(
            context: Context?,
            configurationId: String,
            success: () -> Unit,
            error: (String) -> Unit,
        ): Any {
            start(configurationId)
            events += "withInAppChatCalls"
            return finish(success, error)
        }

        override fun disableCalls(rtcUi: Any, success: () -> Unit, error: (String) -> Unit) {
            disabledReceiver = rtcUi
            events += "disableCalls"
            callbacks(success, error)
        }

        private fun start(configurationId: String) {
            enableCount++
            failure?.let { throw it }
            this.configurationId = configurationId
            events += "withConfigurationId"
        }

        private fun finish(success: () -> Unit, error: (String) -> Unit): Any {
            events += "build"
            callbacks(success, error)
            return builtRtcUi
        }
    }
}
