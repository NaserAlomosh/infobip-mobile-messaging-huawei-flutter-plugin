package com.infobip.mobilemessaging.huawei.user

import android.os.Looper
import com.infobip.mobilemessaging.huawei.InfobipMobileMessagingHuaweiPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.infobip.mobile.messaging.*
import org.infobip.mobile.messaging.mobileapi.Result
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
class PersonalizationFlagsTest {
    private class Reply : MethodChannel.Result {
        var successes = 0
        val errors = mutableListOf<String>()
        override fun success(value: Any?) { successes++ }
        override fun error(code: String, message: String?, details: Any?) { errors.add(code) }
        override fun notImplemented() { fail("Unexpected method") }
    }

    @Test fun `dispatcher defaults and explicit flags reach six argument SDK overload once`() {
        val options = listOf(emptyMap<String, Any?>()) +
            listOf(false, true).flatMap { keep -> listOf(false, true).map { primary ->
                mapOf("keepAsLead" to keep, "setDeviceAsPrimary" to primary)
            } }
        for (flags in options) {
            val sdk = mock(MobileMessaging::class.java)
            val manager = UserManager(RuntimeEnvironment.getApplication(), { true })
            manager.javaClass.getDeclaredField("mobileMessaging\$delegate").apply {
                isAccessible = true
            }.set(manager, lazy { sdk })
            val plugin = InfobipMobileMessagingHuaweiPlugin()
            plugin.javaClass.getDeclaredField("userManager").apply { isAccessible = true }.set(plugin, manager)
            var invocations = 0
            doAnswer { call ->
                assertEquals("synthetic-id", (call.arguments[0] as UserIdentity).externalUserId)
                assertNull(call.arguments[1])
                assertEquals(true, call.arguments[2])
                assertEquals(flags["keepAsLead"] ?: false, call.arguments[3])
                assertEquals(flags["setDeviceAsPrimary"] ?: false, call.arguments[4])
                @Suppress("UNCHECKED_CAST")
                val listener = call.arguments[5] as MobileMessaging.ResultListener<User>
                listener.onResult(Result(User()))
                invocations++
                null
            }.`when`(sdk).personalize(any(UserIdentity::class.java), isNull<UserAttributes>(),
                anyBoolean(), anyBoolean(), anyBoolean(), any<MobileMessaging.ResultListener<User>>())
            val reply = Reply()
            plugin.onMethodCall(MethodCall("personalize", mapOf("userIdentity" to
                mapOf("externalUserId" to "synthetic-id"), "forceDepersonalize" to true) + flags), reply)
            shadowOf(Looper.getMainLooper()).idle()
            assertEquals(1, invocations)
            assertEquals(1, reply.successes)
            assertTrue(reply.errors.isEmpty())
            verify(sdk).personalize(any(UserIdentity::class.java), isNull<UserAttributes>(),
                anyBoolean(), anyBoolean(), anyBoolean(), any<MobileMessaging.ResultListener<User>>())
            verifyNoMoreInteractions(sdk)
        }
    }

    @Test fun `invalid optional flags fail before manager access`() {
        for (name in listOf("keepAsLead", "setDeviceAsPrimary")) {
            for (value in listOf("true", 1, emptyList<Boolean>())) {
                val reply = Reply()
                InfobipMobileMessagingHuaweiPlugin().onMethodCall(MethodCall("personalize",
                    mapOf("forceDepersonalize" to false, name to value)), reply)
                assertEquals(listOf("invalid_argument"), reply.errors)
                assertEquals(0, reply.successes)
            }
        }
    }
}
