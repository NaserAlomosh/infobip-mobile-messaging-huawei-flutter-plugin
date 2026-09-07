package com.infobip.mobilemessaging.huawei

import android.os.Looper
import com.infobip.mobilemessaging.huawei.installation.InstallationManager
import com.infobip.mobilemessaging.huawei.user.UserManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.infobip.mobile.messaging.Installation
import org.infobip.mobile.messaging.MobileMessaging
import org.infobip.mobile.messaging.mobileapi.MobileMessagingError
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
class NullableNativeDataTest {
    private fun inject(target: Any, field: String, value: Any) {
        target.javaClass.getDeclaredField(field).apply { isAccessible = true }.set(target, value)
    }
    @Test fun `absent cached user returns empty map through real manager and dispatcher`() {
        val sdk = mock(MobileMessaging::class.java)
        val manager = UserManager(RuntimeEnvironment.getApplication(), { true })
        inject(manager, "mobileMessaging\$delegate", lazy { sdk })
        val plugin = InfobipMobileMessagingHuaweiPlugin()
        inject(plugin, "userManager", manager)
        val result = RecordingResult()
        plugin.onMethodCall(MethodCall("getUser", null), result)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf(emptyMap<String, Any?>()), result.values)
        assertTrue(result.errors.isEmpty())
    }

    @Test fun `backend user failure is never normalized to empty user`() {
        val sdk = mock(MobileMessaging::class.java)
        val manager = UserManager(RuntimeEnvironment.getApplication(), { true })
        inject(manager, "mobileMessaging\$delegate", lazy { sdk })
        doAnswer { invocation ->
            @Suppress("UNCHECKED_CAST")
            val listener = invocation.arguments.single() as MobileMessaging.ResultListener<org.infobip.mobile.messaging.User>
            listener.onResult(Result(null, MobileMessagingError("denied", "Safe failure")))
            null
        }.`when`(sdk).fetchUser(any())
        val plugin = InfobipMobileMessagingHuaweiPlugin()
        inject(plugin, "userManager", manager)
        val result = RecordingResult()
        plugin.onMethodCall(MethodCall("fetchUser", null), result)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf("denied"), result.errors)
        assertTrue(result.values.isEmpty())
    }

    @Test fun `installation operations preserve populated null and failed SDK callbacks`() {
        for (method in listOf("depersonalizeInstallation", "setInstallationAsPrimary")) {
            for (state in listOf("populated", "null", "error")) {
                val sdk = mock(MobileMessaging::class.java)
                val manager = InstallationManager(RuntimeEnvironment.getApplication(), { true })
                inject(manager, "mobileMessaging\$delegate", lazy { sdk })
                val answer = org.mockito.stubbing.Answer<Unit> { invocation ->
                    val listener = invocation.arguments.last() as MobileMessaging.ResultListener<List<Installation>>
                    listener.onResult(Result<List<Installation>, MobileMessagingError>(
                        if (state == "populated") listOf(Installation()) else null,
                        if (state == "error") MobileMessagingError("rejected", "Safe failure") else null))
                }
                doAnswer(answer).`when`(sdk).depersonalizeInstallation(anyString(), any())
                doAnswer(answer).`when`(sdk).setInstallationAsPrimary(anyString(), anyBoolean(), any())
                val plugin = InfobipMobileMessagingHuaweiPlugin()
                inject(plugin, "installationManager", manager)
                val result = RecordingResult()
                plugin.onMethodCall(MethodCall(method, mapOf("pushRegistrationId" to "1788547032704145206", "isPrimary" to true)), result)
                shadowOf(Looper.getMainLooper()).idle()
                if (state == "error") {
                    assertEquals(listOf("rejected"), result.errors)
                    assertTrue(result.values.isEmpty())
                } else {
                    assertTrue(result.errors.isEmpty())
                    assertEquals(1, result.values.size)
                    if (state == "null") assertNull(result.values.single())
                    else assertEquals(1, (result.values.single() as List<*>).size)
                }
            }
        }
    }
    private class RecordingResult : MethodChannel.Result {
        val values = mutableListOf<Any?>()
        val errors = mutableListOf<String>()
        override fun success(result: Any?) { values.add(result) }
        override fun error(code: String, message: String?, details: Any?) { errors += code }
        override fun notImplemented() { throw AssertionError("not implemented") }
    }
}
