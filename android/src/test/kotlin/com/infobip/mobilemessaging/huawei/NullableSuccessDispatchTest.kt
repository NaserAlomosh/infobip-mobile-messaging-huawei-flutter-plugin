package com.infobip.mobilemessaging.huawei

import com.infobip.mobilemessaging.huawei.chat.ChatFailure
import com.infobip.mobilemessaging.huawei.chat.ChatManager
import com.infobip.mobilemessaging.huawei.core.MessageOperationFailure
import com.infobip.mobilemessaging.huawei.core.MessageOperations
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
class NullableSuccessDispatchTest {
    private val calls = listOf(
        MethodCall("markMessagesSeen", listOf("1788547032704145206")),
        MethodCall("showChat", null),
        MethodCall("setChatJwtProvider", null),
        MethodCall("setChatExceptionHandler", mapOf("enabled" to true)),
        MethodCall("setChatPushTitle", "title"),
        MethodCall("setChatPushBody", "body"),
        MethodCall("resolveChatJwt", mapOf("jwt" to "test-token")),
        MethodCall("rejectChatJwt", mapOf("error" to "failure")),
    )

    @Test fun `absent managers report detached exactly once`() {
        calls.forEach { call ->
            val result = RecordingResult()
            InfobipMobileMessagingHuaweiPlugin().onMethodCall(call, result)
            assertEquals(call.method, listOf("error:native_error"), result.completions)
        }
    }

    @Test fun `successful null operations complete successfully exactly once`() {
        val plugin = plugin(null)
        calls.forEach { call ->
            val result = RecordingResult()
            plugin.onMethodCall(call, result)
            assertEquals(call.method, listOf("success"), result.completions)
        }
    }

    @Test fun `operation failures preserve manager mapping exactly once`() {
        val plugin = plugin(ChatFailure("operation_failed", "Safe failure"))
        calls.forEach { call ->
            val result = RecordingResult()
            plugin.onMethodCall(call, result)
            assertEquals(call.method, listOf("error:operation_failed"), result.completions)
        }
    }

    private fun plugin(failure: ChatFailure?): InfobipMobileMessagingHuaweiPlugin {
        val plugin = InfobipMobileMessagingHuaweiPlugin()
        val chat = mock(ChatManager::class.java) { failure }
        val messages = mock(MessageOperations::class.java) {
            failure?.let { MessageOperationFailure(it.code, it.message) }
        }
        mapOf("chatManager" to chat, "messageOperations" to messages).forEach { (name, value) ->
            plugin.javaClass.getDeclaredField(name).apply { isAccessible = true }.set(plugin, value)
        }
        return plugin
    }

    private class RecordingResult : MethodChannel.Result {
        val completions = mutableListOf<String>()
        override fun success(result: Any?) {
            StandardMethodCodec.INSTANCE.encodeSuccessEnvelope(result)
            assertEquals(null, result)
            completions += "success"
        }
        override fun error(code: String, message: String?, details: Any?) { completions += "error:$code" }
        override fun notImplemented() { completions += "notImplemented" }
    }
}
