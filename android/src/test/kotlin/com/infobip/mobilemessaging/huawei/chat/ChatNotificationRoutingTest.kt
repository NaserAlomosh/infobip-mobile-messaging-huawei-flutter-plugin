package com.infobip.mobilemessaging.huawei.chat

import android.app.Activity
import android.app.PendingIntent
import android.content.ContextWrapper
import android.content.Intent
import com.infobip.mobilemessaging.huawei.plugin.NotificationTapReceiver
import org.infobip.mobile.messaging.Message
import org.infobip.mobile.messaging.MobileMessagingCore
import org.infobip.mobile.messaging.NotificationSettings
import org.infobip.mobile.messaging.NotificationTapReceiverActivity
import org.infobip.mobile.messaging.OpenLivechatAction
import org.infobip.mobile.messaging.chat.InAppChatImpl
import org.infobip.mobile.messaging.chat.view.InAppChatActivity
import org.infobip.mobile.messaging.notification.BaseNotificationHandler
import org.infobip.mobile.messaging.platform.AndroidBroadcaster
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ChatNotificationRoutingTest {
    class FlutterHost : Activity()
    private val launches = mutableListOf<Intent>()
    private val events = mutableListOf<Map<String, Any?>>()
    private val context = object : ContextWrapper(RuntimeEnvironment.getApplication()) {
        override fun startActivity(intent: Intent) {
            assertEquals("SDK must start navigation before broadcasting its tap", launches.size, events.size)
            launches += intent
        }
        override fun sendBroadcast(intent: Intent) { NotificationTapReceiver.decode(intent)?.let(events::add) }
    }
    init { android.provider.Settings.Secure.putString(context.contentResolver, android.provider.Settings.Secure.ANDROID_ID, "routing-test-device") }
    private val settings = mock(NotificationSettings::class.java).apply {
        `when`(callbackActivity).thenReturn(FlutterHost::class.java)
    }
    private val sdk = InAppChatImpl().apply {
        init(context)
        val core = mock(MobileMessagingCore::class.java)
        `when`(core.notificationSettings).thenReturn(settings)
        javaClass.getDeclaredField("mmCore").apply { isAccessible = true }.set(this, core)
        javaClass.getDeclaredField("coreBroadcaster").apply { isAccessible = true }.set(this, AndroidBroadcaster(context))
    }
    private fun message(thread: String? = null) = Message().apply {
        messageId = "fixture-${thread ?: "first"}"
        messageType = "chat"
        customPayload = JSONObject().apply { if (thread != null) put("threadId", thread) }
    }
    @After fun cleanup() {
        sdk.setNotificationInteractionHandler(null)
        ChatNotificationRouting.targets.clear()
        ChatNotificationRouting.navigation.clear()
        context.getSharedPreferences("infobip_huawei_chat_navigation", 0).edit().clear().commit()
    }
    @Test fun `published SDK default reproduces differing destinations based on payload`() {
        sdk.setNotificationInteractionHandler(null)
        val first = message()
        val existing = message("existing-thread")
        assertTrue(first.isChatMessage)
        assertNull(OpenLivechatAction.parseFrom(first))
        assertEquals("existing-thread", OpenLivechatAction.parseFrom(existing).threadId)
        sdk.messageTapped(first)
        sdk.messageTapped(existing)
        assertEquals(listOf(FlutterHost::class.java.name, InAppChatActivity::class.java.name), launches.map { it.component!!.className })
        assertEquals(2, events.size)
    }
    @Test fun `published SDK pending intents use same tap Activity and retain thread payload`() {
        val method = BaseNotificationHandler::class.java.getDeclaredMethod("createTapPendingIntent", NotificationSettings::class.java, Message::class.java).apply { isAccessible = true }
        for (thread in listOf(null, "existing-thread")) {
            val pending = method.invoke(BaseNotificationHandler(context), settings, message(thread)) as PendingIntent
            val intents = shadowOf(pending).savedIntents
            assertEquals(1, intents.size)
            assertEquals(NotificationTapReceiverActivity::class.java.name, intents.single().component!!.className)
            val decoded = Message.createFrom(intents.single().getBundleExtra("org.infobip.mobile.messaging.message"))
            assertEquals(thread, decoded.customPayload.opt("threadId"))
        }
    }
    @Test fun `embedded routes both payloads to Flutter before exactly one SDK event with thread intact`() {
        assertTrue(ChatNotificationRouting.configure(context, "embedded"))
        sdk.setNotificationInteractionHandler(ChatNotificationRouting(context) { settings })
        for (thread in listOf(null, "existing-thread")) {
            assertTrue(sdk.messageTapped(message(thread)))
            assertEquals(FlutterHost::class.java.name, launches.last().component!!.className)
            assertEquals(launches.size, events.size)
            val payload = events.last()["payload"] as Map<*, *>
            val mapped = payload["message"] as Map<*, *>
            assertEquals(thread, (mapped["customPayload"] as Map<*, *>)["threadId"])
        }
        val first = ChatNotificationRouting.navigation.peek()!!
        assertNull(first.threadId)
        assertEquals(first, ChatNotificationRouting.navigation.peek())
        assertTrue(ChatNotificationRouting.navigation.acknowledge(first.correlationId))
        assertEquals("existing-thread", ChatNotificationRouting.navigation.peek()!!.threadId)
    }
    @Test fun `native preference survives handler recreation for first and existing conversation`() {
        assertTrue(ChatNotificationRouting.configure(context, "native"))
        ChatNotificationRouting.navigation.clear()
        ChatNotificationRouting.targets.clear()
        org.robolectric.Robolectric.buildContentProvider(ChatNotificationRoutingProvider::class.java).create()
        assertEquals("native", context.getSharedPreferences("infobip_huawei_chat_navigation", 0).getString("presentation", null))
        assertNativeRoutingWithoutFlutterNavigation()
    }
    private fun assertNativeRoutingWithoutFlutterNavigation() {
        val requests = mutableListOf<ChatNavigationRequest>()
        val observer: (ChatNavigationRequest) -> Unit = requests::add
        ChatNotificationRouting.navigation.listen(observer)
        for (thread in listOf(null, "existing-thread")) {
            sdk.setNotificationInteractionHandler(ChatNotificationRouting(context, nativeHandler = { sdk.getDefaultNotificationInteractionHandler() }) { settings })
            sdk.messageTapped(message(thread))
            val intent = launches.last()
            assertEquals(if (thread == null) FlutterHost::class.java.name else InAppChatActivity::class.java.name, intent.component!!.className)
            assertEquals(thread, Message.createFrom(intent.getBundleExtra("org.infobip.mobile.messaging.message")).customPayload.opt("threadId"))
        }
        assertEquals(2, launches.size)
        assertEquals(2, events.size)
        assertNull(ChatNotificationRouting.navigation.peek())
        assertTrue(requests.isEmpty())
        ChatNotificationRouting.navigation.cancel(observer)
    }
    @Test fun `fresh installation defaults to SDK native routing without Flutter navigation`() {
        assertFalse(context.getSharedPreferences("infobip_huawei_chat_navigation", 0).contains("presentation"))
        assertNativeRoutingWithoutFlutterNavigation()
    }
    @Test fun `existing installation without mode remains native after provider recreation`() {
        val preferences = context.getSharedPreferences("infobip_huawei_chat_navigation", 0)
        preferences.edit().putBoolean("existing-installation", true).commit()
        org.robolectric.Robolectric.buildContentProvider(ChatNotificationRoutingProvider::class.java).create()
        ChatNotificationRouting.install(context)
        assertFalse(preferences.contains("presentation"))
        assertNativeRoutingWithoutFlutterNavigation()
    }
    @Test fun `saved embedded mode survives handler recreation and simulated process state loss`() {
        assertTrue(ChatNotificationRouting.configure(context, "embedded"))
        sdk.setNotificationInteractionHandler(ChatNotificationRouting(context) { settings })
        sdk.messageTapped(message("existing-thread"))
        val pending = ChatNotificationRouting.navigation.peek()!!
        // Engine recreation retains the process-local pending request.
        ChatNotificationRouting.install(context)
        assertEquals(pending, ChatNotificationRouting.navigation.peek())
        // Simulate process loss: transient requests disappear, saved mode remains.
        ChatNotificationRouting.navigation.clear()
        ChatNotificationRouting.targets.clear()
        org.robolectric.Robolectric.buildContentProvider(ChatNotificationRoutingProvider::class.java).create()
        assertNull(ChatNotificationRouting.navigation.peek())
        assertEquals("embedded", context.getSharedPreferences("infobip_huawei_chat_navigation", 0).getString("presentation", null))
        sdk.setNotificationInteractionHandler(ChatNotificationRouting(context) { settings })
        sdk.messageTapped(message("existing-thread"))
        assertEquals(listOf(FlutterHost::class.java.name, FlutterHost::class.java.name), launches.map { it.component!!.className })
        assertEquals("existing-thread", ChatNotificationRouting.navigation.peek()!!.threadId)
    }
    @Test fun `cold process provider installs routing before any Flutter engine exists`() {
        val provider = org.robolectric.Robolectric.buildContentProvider(ChatNotificationRoutingProvider::class.java).create().get()
        val restored = org.infobip.mobile.messaging.chat.InAppChat.getInstance(context)
        assertTrue(restored.getNotificationInteractionHandler() is ChatNotificationRouting)
        assertNotNull(provider.context)
        assertFalse(ChatNotificationRouting.configure(context, "unknown"))
        assertTrue(ChatNotificationRouting.configure(context, "native"))
        ChatNotificationRouting.install(context)
        assertEquals("native", context.getSharedPreferences("infobip_huawei_chat_navigation", 0).getString("presentation", null))
        assertNull(ChatNotificationRouting.navigation.peek())
    }
    @Test fun `reapplying embedded configuration during cold startup preserves pending thread`() {
        ChatNotificationRouting.targets.offer("cold-thread")
        assertTrue(ChatNotificationRouting.configure(context, "embedded"))
        val threads = mutableListOf<String>()
        val listener: (String) -> Unit = threads::add
        ChatNotificationRouting.targets.listen(listener)
        ChatNotificationRouting.targets.cancel(listener)
        assertEquals(listOf("cold-thread"), threads)
    }
    @Test fun `ready fragment receives targets once and cancelled fragment does not consume cold target`() {
        val targets = ChatNotificationTargets()
        val shown = mutableListOf<String>()
        val observer: (String) -> Unit = shown::add
        targets.listen(observer)
        targets.offer("foreground")
        targets.cancel(observer)
        targets.offer("background-or-cold")
        assertEquals(listOf("foreground"), shown)
        targets.listen(observer)
        targets.listen(observer)
        assertEquals(listOf("foreground", "background-or-cold"), shown)
    }
}
