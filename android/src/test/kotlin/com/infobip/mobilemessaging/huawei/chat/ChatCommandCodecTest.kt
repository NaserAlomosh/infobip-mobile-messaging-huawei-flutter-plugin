package com.infobip.mobilemessaging.huawei.chat

import android.app.Activity
import android.os.Looper
import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import org.infobip.mobile.messaging.chat.view.InAppChatFragment
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [28])
class ChatCommandCodecTest {
    @Test fun `embedded commands encode null and queries retain values`() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val view = ChatPlatformView(activity, 1, mock(BinaryMessenger::class.java), activity,
            mock(ChatManager::class.java), ChatViewOptions())
        activity.setContentView(view.view)
        val fragment = mock(InAppChatFragment::class.java)
        `when`(fragment.isAdded).thenReturn(true)
        `when`(fragment.isMultiThread).thenReturn(true)
        `when`(fragment.getWidgetTheme()).thenReturn("dark")
        view.javaClass.getDeclaredField("fragment").apply { isAccessible = true }.set(view, fragment)
        val calls = listOf(
            MethodCall(ChannelContract.CHAT_SEND, mapOf("text" to "hello")),
            MethodCall(ChannelContract.CHAT_SEND_CONTEXTUAL_DATA, mapOf("data" to "{}", ChannelContract.CHAT_MULTI_THREAD_STRATEGY to "ACTIVE")),
            MethodCall(ChannelContract.CHAT_SHOW_THREADS_LIST, null),
            MethodCall(ChannelContract.CHAT_SET_LANGUAGE, mapOf("language" to "en-US")),
            MethodCall(ChannelContract.CHAT_SET_WIDGET_THEME, mapOf("widgetTheme" to "dark")),
        )
        (calls.map { it to null } + listOf(
            MethodCall(ChannelContract.CHAT_IS_MULTITHREAD, null) to true,
            MethodCall(ChannelContract.CHAT_GET_WIDGET_THEME, null) to "dark",
            MethodCall(ChannelContract.CHAT_NAVIGATE_BACK, null) to false,
        )).forEach { (call, expected) ->
            val values = mutableListOf<Any?>()
            view.onMethodCall(call, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    // Encoding Unit throws, even if a permissive mock would accept it.
                    val bytes = StandardMethodCodec.INSTANCE.encodeSuccessEnvelope(result)
                    bytes.flip()
                    values += StandardMethodCodec.INSTANCE.decodeEnvelope(bytes)
                }
                override fun error(code: String, message: String?, details: Any?) { throw AssertionError(code) }
                override fun notImplemented() { throw AssertionError("not implemented") }
            })
            shadowOf(Looper.getMainLooper()).idle()
            assertEquals(call.method, listOf(expected), values)
        }
        view.dispose()
    }
}
