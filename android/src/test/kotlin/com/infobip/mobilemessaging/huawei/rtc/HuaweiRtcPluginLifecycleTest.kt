package com.infobip.mobilemessaging.huawei.rtc

import android.app.Activity
import com.infobip.mobilemessaging.huawei.InfobipMobileMessagingHuaweiPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class HuaweiRtcPluginLifecycleTest {
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
        verifyNoInteractions(manager)
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
