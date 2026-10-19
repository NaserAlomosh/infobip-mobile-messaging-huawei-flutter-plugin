package com.infobip.mobilemessaging.huawei.rtc

import android.app.Activity
import com.infobip.mobilemessaging.huawei.InfobipMobileMessagingHuaweiPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.infobip.mobilemessaging.huawei.user.UserManager
import com.infobip.mobilemessaging.huawei.user.UserFailure
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class HuaweiRtcPluginLifecycleTest {
    @Test fun `identity mutation guards finish even when dispatch rejects the operation`() {
        for (method in listOf("initialize", "cleanup", "saveUser", "personalize", "depersonalize", "depersonalizeInstallation")) {
            val plugin = InfobipMobileMessagingHuaweiPlugin()
            val manager = mock(HuaweiRtcManager::class.java)
            field("huaweiRtcManager").set(plugin, manager)
            val reply = mock(MethodChannel.Result::class.java)
            plugin.onMethodCall(MethodCall(method, emptyMap<String, Any>()), reply)
            val order = inOrder(manager)
            order.verify(manager).beginIdentityMutation()
            order.verify(manager).endIdentityMutation()
        }
    }

    @Test fun `pending save user blocks Chat identity calls until native callback completes`() {
        val plugin = InfobipMobileMessagingHuaweiPlugin()
        val manager = mock(HuaweiRtcManager::class.java)
        val users = mock(UserManager::class.java)
        field("huaweiRtcManager").set(plugin, manager)
        field("userManager").set(plugin, users)
        var completion: ((Map<String, Any?>?, UserFailure?) -> Unit)? = null
        doAnswer {
            completion = it.getArgument(1)
            null
        }.`when`(users).saveUser(any(),
            any<(Map<String, Any?>?, UserFailure?) -> Unit>() ?: { _, _ -> })
        val reply = mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("saveUser", mapOf("user" to emptyMap<String, Any>())), reply)
        verify(manager).beginIdentityMutation()
        verify(manager, never()).endIdentityMutation()
        requireNotNull(completion).invoke(emptyMap(), null)
        verify(manager).endIdentityMutation()
        verify(reply).success(emptyMap<String, Any?>())
    }

    @Test fun `Activity attach detach and config reattach preserve manager and release obsolete Activity`() {
        val plugin = InfobipMobileMessagingHuaweiPlugin()
        val manager = mock(HuaweiRtcManager::class.java)
        field("huaweiRtcManager").set(plugin, manager)
        val old = mock(Activity::class.java)
        val replacement = mock(Activity::class.java)
        val binding = mock(ActivityPluginBinding::class.java)
        `when`(binding.activity).thenReturn(old)
        plugin.onAttachedToActivity(binding)
        assertSame(old, field("activity").get(plugin))
        plugin.onDetachedFromActivityForConfigChanges()
        assertNull(field("activity").get(plugin))
        `when`(binding.activity).thenReturn(replacement)
        plugin.onReattachedToActivityForConfigChanges(binding)
        assertSame(replacement, field("activity").get(plugin))
        assertSame(manager, field("huaweiRtcManager").get(plugin))
        plugin.onDetachedFromActivity()
        assertNull(field("activity").get(plugin))
        verify(binding, times(2)).addOnNewIntentListener(any())
        verify(binding, times(2)).removeOnNewIntentListener(any())
        verify(manager, times(2)).detachVideoViews()
        verify(manager, times(4)).screenCapture
        verify(binding, times(2)).addActivityResultListener(any())
        verify(binding, times(2)).removeActivityResultListener(any())
        verifyNoMoreInteractions(manager)
    }

    @Test fun `engine detach disposes manager and releases references`() {
        val plugin = InfobipMobileMessagingHuaweiPlugin()
        val manager = mock(HuaweiRtcManager::class.java)
        field("huaweiRtcManager").set(plugin, manager)
        plugin.onDetachedFromEngine(mock(FlutterPlugin.FlutterPluginBinding::class.java))
        verify(manager).dispose()
        assertNull(field("huaweiRtcManager").get(plugin))
        assertNull(field("huaweiRtcChannel").get(plugin))
        assertNull(field("huaweiRtcEvents").get(plugin))
    }

    private fun field(name: String) = InfobipMobileMessagingHuaweiPlugin::class.java.getDeclaredField(name).apply { isAccessible = true }
}
