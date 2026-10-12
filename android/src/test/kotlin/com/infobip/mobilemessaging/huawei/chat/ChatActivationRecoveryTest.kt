package com.infobip.mobilemessaging.huawei.chat

import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import com.infobip.mobilemessaging.huawei.InfobipMobileMessagingHuaweiPlugin
import org.infobip.mobile.messaging.chat.InAppChat
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ChatActivationRecoveryTest {
    private val sdk = mock(InAppChat::class.java, RETURNS_DEEP_STUBS)
    private var time = 0L
    private var initialized = true
    private val manager = ChatManager(RuntimeEnvironment.getApplication(), { initialized }, now = { time }, chatFactory = { sdk })

    @Test fun `success is idempotent and does not replace provider or exception bridge`() {
        val events = mutableListOf<Map<String, String?>>()
        manager.setExceptionHandler(true, events::add)
        assertNull(manager.setJwtProvider())
        val provider = sdk.getWidgetJwtProvider()
        assertNull(manager.activate()); assertNull(manager.activate())
        verify(sdk, times(1)).activate()
        assertSame(provider, sdk.getWidgetJwtProvider())
        verify(sdk.inAppChatScreen(), times(2)).errorHandler = manager.exceptionBridge
    }
    @Test fun `failure is observable retry is throttled then succeeds without MM reinitialization`() {
        doThrow(IllegalStateException("fixture-sensitive-value")).doNothing().`when`(sdk).activate()
        assertEquals(ChatFailure("chat_unavailable", "Chat activation failed"), manager.activate())
        assertEquals("chat_activation_busy", manager.activate()?.code)
        assertTrue(initialized); time = 1000
        assertNull(manager.activate()); assertNull(manager.attach()); verify(sdk, times(2)).activate()
    }
    @Test fun `reentrant retry cannot duplicate activation`() {
        doAnswer { assertEquals("chat_activation_busy", manager.activate()?.code); null }.`when`(sdk).activate()
        assertNull(manager.activate()); verify(sdk, times(1)).activate()
    }
    @Test fun `cleanup invalidates activation and allows a fresh activation`() {
        doAnswer { manager.resetAfterCleanup(); null }.`when`(sdk).activate()
        assertEquals("chat_unavailable", manager.activate()?.code)
        assertEquals("chat_unavailable", manager.attach()?.code)
        doNothing().`when`(sdk).activate(); assertNull(manager.activate())
    }
    @Test fun `engine disposal invalidates activation and never reactivates`() {
        doAnswer { manager.dispose(); null }.`when`(sdk).activate()
        assertEquals("chat_unavailable", manager.activate()?.code)
        assertEquals("chat_unavailable", manager.activate()?.code)
        verify(sdk, times(1)).activate()
    }
    @Test fun `concurrent activation calls serialize and invoke SDK only once`() {
        val entered = java.util.concurrent.CountDownLatch(1)
        val release = java.util.concurrent.CountDownLatch(1)
        val secondStarted = java.util.concurrent.CountDownLatch(1)
        doAnswer { entered.countDown(); check(release.await(5, java.util.concurrent.TimeUnit.SECONDS)); null }.`when`(sdk).activate()
        val executor = java.util.concurrent.Executors.newFixedThreadPool(2)
        try {
            val first = executor.submit<ChatFailure?> { manager.activate() }
            assertTrue(entered.await(5, java.util.concurrent.TimeUnit.SECONDS))
            val second = executor.submit<ChatFailure?> { secondStarted.countDown(); manager.activate() }
            assertTrue(secondStarted.await(5, java.util.concurrent.TimeUnit.SECONDS))
            release.countDown()
            assertNull(first.get(5, java.util.concurrent.TimeUnit.SECONDS))
            assertNull(second.get(5, java.util.concurrent.TimeUnit.SECONDS))
            verify(sdk, times(1)).activate()
        } finally { release.countDown(); executor.shutdownNow() }
    }
    @Test fun `engine disposal fails a pending SDK JWT callback once and rejects late responses`() {
        var provider: org.infobip.mobile.messaging.chat.core.JwtProvider? = null
        doAnswer { provider = it.getArgument(0); null }.`when`(sdk).setWidgetJwtProvider(nullable(org.infobip.mobile.messaging.chat.core.JwtProvider::class.java))
        val requests = mutableListOf<Pair<String, Long>>()
        val owner = ChatManager(RuntimeEnvironment.getApplication(), { true }, requestDartJwt = { id, generation -> requests += id to generation; true }, chatFactory = { sdk })
        assertNull(owner.setJwtProvider())
        val oldProvider = provider!!
        val errors = mutableListOf<Throwable>(); val tokens = mutableListOf<String>()
        val callback = object : org.infobip.mobile.messaging.chat.core.JwtProvider.JwtCallback {
            override fun onJwtReady(jwt: String) { tokens += jwt }
            override fun onJwtError(error: Throwable) { errors += error }
        }
        oldProvider.provideJwt(callback)
        owner.dispose(); shadowOf(Looper.getMainLooper()).idle()
        assertEquals(1, errors.size); assertTrue(tokens.isEmpty())
        assertEquals("stale_request", owner.resolveJwt(requests.single().first, requests.single().second, "fixture").let { it?.code })
        assertNull(provider); assertEquals("chat_unavailable", owner.setJwtProvider()?.code)
    }
    @Test fun `retry leaves the configured exception listener intact`() {
        var events = 0
        manager.setExceptionHandler(true) { events++ }
        doThrow(IllegalStateException("safe fixture")).doNothing().`when`(sdk).activate()
        manager.activate(); time = 1000; assertNull(manager.activate())
        assertTrue(manager.exceptionBridge.handleError(org.infobip.mobile.messaging.chat.core.InAppChatException(message = "safe", name = "Error")))
        assertEquals(1, events)
    }
    @Test fun `activation requires MM initialization`() {
        initialized = false
        assertEquals("not_initialized", manager.activate()?.code); verify(sdk, never()).activate()
    }
    @Test fun `Activity recreation retains Chat owner but engine detach disposes it`() {
        val plugin = InfobipMobileMessagingHuaweiPlugin()
        val field = plugin.javaClass.getDeclaredField("chatManager").apply { isAccessible = true }
        field.set(plugin, manager)
        assertNull(manager.activate())
        val binding = mock(ActivityPluginBinding::class.java)
        `when`(binding.activity).thenReturn(mock(android.app.Activity::class.java))
        plugin.onAttachedToActivity(binding); plugin.onDetachedFromActivityForConfigChanges()
        plugin.onReattachedToActivityForConfigChanges(binding)
        assertSame(manager, field.get(plugin)); assertNull(manager.attach())
        plugin.onDetachedFromEngine(mock(FlutterPlugin.FlutterPluginBinding::class.java))
        assertEquals("chat_unavailable", manager.activate()?.code)
        shadowOf(Looper.getMainLooper()).idle()
    }
}
