package com.infobip.mobilemessaging.huawei.chat

import android.os.Looper
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentContainerView
import androidx.fragment.app.FragmentManager
import androidx.fragment.app.FragmentTransaction
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.infobip.mobile.messaging.chat.core.widget.LivechatWidgetResult
import org.infobip.mobile.messaging.chat.view.InAppChatFragment
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ChatPlatformViewTest {
    private val activity = spy(Robolectric.buildActivity(FragmentActivity::class.java).setup().get())
    private val manager = mock(FragmentManager::class.java)
    private val transaction = mock(FragmentTransaction::class.java, RETURNS_SELF)
    private val chat = mock(ChatManager::class.java)
    private val messenger = mock(BinaryMessenger::class.java)
    init {
        doReturn(manager).`when`(activity).supportFragmentManager
        `when`(manager.beginTransaction()).thenReturn(transaction)
        `when`(chat.exceptionBridge).thenReturn(ChatExceptionBridge())
    }
    private fun create() = ChatPlatformView(activity, 7, messenger, activity, chat, ChatViewOptions())
    private fun attach(view: ChatPlatformView): InAppChatFragment {
        val container = spy(view.view as FragmentContainerView)
        doReturn(true).`when`(container).isAttachedToWindow
        view.javaClass.getDeclaredMethod("attachFragment", FragmentContainerView::class.java)
            .apply { isAccessible = true }.invoke(view, container)
        return view.javaClass.getDeclaredField("fragment").apply { isAccessible = true }.get(view) as InAppChatFragment
    }
    private fun pending(view: ChatPlatformView): ChatViewError? {
        val error = view.javaClass.getDeclaredField("pendingError").apply { isAccessible = true }.get(view) as PendingChatViewError
        return error.take()
    }
    @Test fun `queued attachment is removed even before fragment isAdded becomes true`() {
        repeat(10) {
            val view = create()
            val fragment = attach(view)
            assertFalse(fragment.isAdded)
            view.dispose()
            view.dispose()
            verify(transaction).remove(fragment)
        }
        verify(transaction, times(20)).commit()
    }
    @Test fun `repeated layout cannot queue duplicate fragments`() {
        val view = create()
        val first = attach(view)
        assertSame(first, attach(view))
        verify(transaction, times(1)).commit()
        view.dispose()
    }
    @Test fun `missing loading callback reports deadline error`() {
        val view = create()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(31))
        assertEquals("native_error", pending(view)?.code)
        view.dispose()
    }
    @Test fun `successful loading cancels deadline without asserting rendering success`() {
        val view = create()
        attach(view).eventsListener!!.onChatLoadingFinished(LivechatWidgetResult.Success(Unit))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(31))
        assertNull(pending(view))
        view.dispose()
    }
    @Test fun `failed loading reports a safe error and cancels deadline`() {
        val view = create()
        attach(view).eventsListener!!.onChatLoadingFinished(
            LivechatWidgetResult.Error(IllegalStateException("sensitive fixture must not escape")),
        )
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(31))
        val failure = pending(view)!!
        assertEquals("chat_runtime_error", failure.code)
        assertEquals("Chat loading failed", failure.message)
        view.dispose()
    }
    @Test fun `dispose cancels deadline and rejects commands`() {
        val view = create()
        view.dispose()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(31))
        assertNull(pending(view))
        val reply = mock(MethodChannel.Result::class.java)
        view.onMethodCall(MethodCall("navigateBackOrCloseChat", null), reply)
        verify(reply).error("chat_unavailable", "Chat view is unavailable", null)
    }
    @Test fun `saved activity state reports attachment error without transaction`() {
        `when`(manager.isStateSaved).thenReturn(true)
        val view = create()
        val container = spy(view.view as FragmentContainerView)
        doReturn(true).`when`(container).isAttachedToWindow
        view.javaClass.getDeclaredMethod("attachFragment", FragmentContainerView::class.java)
            .apply { isAccessible = true }.invoke(view, container)
        assertEquals("native_error", pending(view)?.code)
        verify(manager, never()).beginTransaction()
        view.dispose()
    }
}
