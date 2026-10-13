package com.infobip.mobilemessaging.huawei.chat

import android.os.Looper
import com.infobip.mobilemessaging.huawei.InfobipMobileMessagingHuaweiPlugin
import com.infobip.mobilemessaging.huawei.core.CleanupManager
import com.infobip.mobilemessaging.huawei.core.InitializationError
import com.infobip.mobilemessaging.huawei.core.MobileMessagingInitializer
import com.infobip.mobilemessaging.huawei.rtc.HuaweiRtcManager
import com.infobip.mobilemessaging.huawei.rtc.RtcFailure
import com.infobip.mobilemessaging.huawei.webrtc.WebRtcOperations
import com.infobip.mobilemessaging.huawei.webrtc.WebRtcFailure
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ChatApiLifecycleTest {
    private val plugin = InfobipMobileMessagingHuaweiPlugin()
    private val initializations = mutableListOf<(InitializationError?) -> Unit>()
    private var cleanupCallback: ((WebRtcFailure?) -> Unit)? = null
    private val initializer = mock(MobileMessagingInitializer::class.java) { call ->
        if (call.method.name == "initialize") initializations += call.getArgument<(InitializationError?) -> Unit>(3)
        null
    }
    private val chat = mock(ChatManager::class.java)
    private val rtc = mock(HuaweiRtcManager::class.java)
    private val webRtc = mock(WebRtcOperations::class.java) { call ->
        if (call.method.name == "cleanup") cleanupCallback = call.getArgument(0)
        null
    }
    private val cleanup = mock(CleanupManager::class.java)
    init {
        mapOf("initializer" to initializer, "chatManager" to chat, "huaweiRtcManager" to rtc,
            "webRtcOperations" to webRtc, "cleanupManager" to cleanup).forEach { (name, value) ->
            plugin.javaClass.getDeclaredField(name).apply { isAccessible = true }.set(plugin, value)
        }

    }
    private class Reply : MethodChannel.Result {
        val values = mutableListOf<String>()
        override fun success(result: Any?) { values += "success" }
        override fun error(code: String, message: String?, details: Any?) { values += code }
        override fun notImplemented() { values += "missing" }
    }
    private fun initialize() = Reply().also { plugin.onMethodCall(MethodCall("initialize", mapOf("applicationCode" to "fixture")), it) }
    private fun cleanup() = Reply().also { plugin.onMethodCall(MethodCall("cleanup", null), it) }
    private fun drain() = shadowOf(Looper.getMainLooper()).idle()

    @Test fun `activation failure is returned and repeated init retries Chat`() {
        `when`(chat.activate()).thenReturn(ChatFailure("chat_unavailable", "Chat activation failed"), null)
        val first = initialize(); initializations[0](null); drain()
        assertEquals(listOf("chat_unavailable"), first.values)
        val retry = initialize(); initializations[1](null); drain()
        assertEquals(listOf("success"), retry.values); verify(chat, times(2)).activate()
        verify(initializer, never()).reset()
    }
    @Test fun `pending MM initialization blocks cleanup without touching RTC`() {
        initialize(); assertEquals(listOf("operation_in_progress"), cleanup().values)
        verifyNoInteractions(rtc, webRtc, cleanup)
    }
    @Test fun `active RTC rejection preserves Chat and never hangs up`() {
        `when`(rtc.prepareCleanup()).thenReturn(RtcFailure("rtc_invalid_state", "Finish the call first"))
        assertEquals(listOf("rtc_invalid_state"), cleanup().values)
        verifyNoInteractions(chat, cleanup, webRtc); verify(rtc, never()).dispose()
    }
    @Test fun `cleanup reservation remains until SDK commit and blocks init and duplicate cleanup`() {
        val first = cleanup(); assertTrue(first.values.isEmpty())
        assertEquals(listOf("operation_in_progress"), cleanup().values)
        assertEquals(listOf("operation_in_progress"), initialize().values)
        doAnswer { verify(rtc, never()).completeCleanup(); null }.`when`(cleanup).cleanup()
        cleanupCallback!!(null); drain()
        assertEquals(listOf("success"), first.values); verify(rtc).completeCleanup()
        val next = initialize(); initializations.single()(null); drain(); assertEquals(listOf("success"), next.values)
    }
    @Test fun `native cleanup failure propagates and releases reservation for retry`() {
        `when`(cleanup.cleanup()).thenReturn(InitializationError("native_error", "Safe failure"), null)
        val first = cleanup(); cleanupCallback!!(null); drain()
        assertEquals(listOf("native_error"), first.values)
        val retry = cleanup(); cleanupCallback!!(null); drain()
        assertEquals(listOf("success"), retry.values); verify(rtc, times(2)).completeCleanup()
    }
    @Test fun `engine disposal completes pending init once and ignores stale completion`() {
        val first = initialize()
        plugin.onDetachedFromEngine(mock(FlutterPlugin.FlutterPluginBinding::class.java))
        assertEquals(listOf("native_error"), first.values)
        initializations.single()(null); drain()
        assertEquals(1, first.values.size); verify(chat, never()).activate(); verify(chat).dispose()
    }
    @Test fun `old cleanup callback cannot clean up a detached engine`() {
        val first = cleanup()
        plugin.onDetachedFromEngine(mock(FlutterPlugin.FlutterPluginBinding::class.java))
        cleanupCallback!!(null); drain()
        assertEquals(listOf("native_error"), first.values); verify(cleanup, never()).cleanup()
    }
}
