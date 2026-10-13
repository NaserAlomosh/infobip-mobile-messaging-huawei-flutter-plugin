package com.infobip.mobilemessaging.huawei.chat

import org.infobip.mobile.messaging.chat.InAppChat
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ChatErrorPrivacyTest {
    @Test fun `activation errors do not expose native exception payloads`() {
        val sdk = mock(InAppChat::class.java)
        doThrow(IllegalStateException("secret-jwt personal attributes")).`when`(sdk).activate()
        val manager = ChatManager(RuntimeEnvironment.getApplication(), { true })
        manager.javaClass.getDeclaredField("inAppChat\$delegate")
            .apply { isAccessible = true }.set(manager, lazy { sdk })
        ShadowLog.clear()

        assertEquals(ChatFailure("chat_unavailable", "Chat activation failed"), manager.activate())

        val logs = ShadowLog.getLogs()
        assertTrue(logs.any { it.msg == "InAppChat activation failed" })
        assertTrue(logs.none { it.msg.contains("secret-jwt") || it.throwable != null })
    }
}
