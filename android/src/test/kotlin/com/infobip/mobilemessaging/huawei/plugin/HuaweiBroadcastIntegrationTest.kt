package com.infobip.mobilemessaging.huawei.plugin

import android.content.ContextWrapper
import android.content.Intent
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.StandardMethodCodec
import org.infobip.mobile.messaging.Installation
import org.infobip.mobile.messaging.Message
import org.infobip.mobile.messaging.User
import org.infobip.mobile.messaging.chat.core.InAppChatBroadcasterImpl
import org.infobip.mobile.messaging.interactive.NotificationAction
import org.infobip.mobile.messaging.interactive.NotificationCategory
import org.infobip.mobile.messaging.interactive.platform.AndroidInteractiveBroadcaster
import org.infobip.mobile.messaging.platform.AndroidBroadcaster
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class HuaweiBroadcastIntegrationTest {
    private val taps = PendingTapStore()
    // Simulates Android delivery to the manifest receiver; SDK local broadcasts still run normally.
    private val context = object : ContextWrapper(RuntimeEnvironment.getApplication()) {
        override fun sendBroadcast(intent: Intent) {
            NotificationTapReceiver.decode(intent)?.let(taps::save)
        }
    }
    private val bridge = NativeEventBridge(context, tapStore = taps, cachedInstallation = { Installation() })
    private val events = mutableListOf<Map<*, *>>()
    private val sink = object : EventChannel.EventSink {
        override fun success(event: Any?) {
            StandardMethodCodec.INSTANCE.encodeSuccessEnvelope(event)
            events += event as Map<*, *>
        }
        override fun error(code: String, message: String?, details: Any?) { throw AssertionError(code) }
        override fun endOfStream() {}
    }
    @After fun detach() { bridge.detach() }
    private fun idle() = shadowOf(Looper.getMainLooper()).idle()
    private fun message() = Message().apply {
        messageId = "1788547032704145206"
        title = "title"
        body = "body"
        category = "category"
        customPayload = JSONObject().put("nested", JSONObject().put("flag", true))
    }
    private fun payload(type: String) = events.single { it["type"] == type }["payload"] as Map<*, *>

    @Test fun `published Huawei broadcasters decode messages installation user registration and unread`() {
        bridge.register()
        bridge.listen(sink)
        val broadcaster = AndroidBroadcaster(context)
        broadcaster.messageReceived(message())
        broadcaster.installationUpdated(org.infobip.mobile.messaging.InstallationMapper.fromJson("{\"pushRegistrationId\":\"opaque-id\"}"))
        broadcaster.userUpdated(User().apply { externalUserId = "user-id" })
        broadcaster.registrationCreated("test-push-token", "1788547032704145206")
        InAppChatBroadcasterImpl(context).unreadMessagesCounterUpdated(7)
        idle()
        assertEquals(5, events.size)
        val received = payload(ChannelContract.MESSAGE_RECEIVED)["message"] as Map<*, *>
        assertEquals("1788547032704145206", received["messageId"])
        assertEquals(mapOf("nested" to mapOf("flag" to true)), received["customPayload"])
        assertEquals("opaque-id", (payload(ChannelContract.INSTALLATION_UPDATED)["installation"] as Map<*, *>)["pushRegistrationId"])
        assertEquals("user-id", (payload(ChannelContract.USER_UPDATED)["user"] as Map<*, *>)["externalUserId"])
        val registration = payload(ChannelContract.REGISTRATION_UPDATED)["installation"] as Map<*, *>
        assertEquals("1788547032704145206", registration["pushRegistrationId"])
        assertEquals("test-push-token", registration["pushServiceToken"])
        assertEquals(7, payload(ChannelContract.CHAT_UNREAD_MESSAGE_COUNTER_UPDATED)["count"])
    }

    @Test fun `tap before engine registration replays full payload once`() {
        AndroidBroadcaster(context).notificationTapped(message())
        idle()
        bridge.register()
        bridge.listen(sink)
        idle()
        val tapped = payload(ChannelContract.NOTIFICATION_TAPPED)["message"] as Map<*, *>
        assertEquals("1788547032704145206", tapped["messageId"])
        assertEquals("title", tapped["title"])
        assertEquals(mapOf("nested" to mapOf("flag" to true)), tapped["customPayload"])
        bridge.cancel()
        bridge.listen(sink)
        idle()
        assertEquals(1, events.size)
        assertNull(taps.take())
    }

    @Test fun `live taps and action broadcasts deliver once despite SDK local duplicate`() {
        bridge.register()
        bridge.listen(sink)
        AndroidBroadcaster(context).notificationTapped(message())
        val action = NotificationAction.Builder().withId("approve").withTitleText("Approve").build()
        val category = NotificationCategory("bank-actions", action)
        AndroidInteractiveBroadcaster(context).notificationActionTapped(message(), category, action)
        idle()
        assertEquals(2, events.size)
        val actionPayload = payload(ChannelContract.NOTIFICATION_ACTION_TAPPED)
        assertEquals("approve", actionPayload["actionId"])
        assertEquals("bank-actions", actionPayload["category"])
        assertEquals("bank-actions", (actionPayload["message"] as Map<*, *>)["category"])
        assertEquals("1788547032704145206", (actionPayload["message"] as Map<*, *>)["messageId"])
        bridge.cancel()
        bridge.listen(sink)
        assertEquals(2, events.size)
    }
}
