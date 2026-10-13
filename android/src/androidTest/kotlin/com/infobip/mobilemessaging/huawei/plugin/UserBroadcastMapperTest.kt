package com.infobip.mobilemessaging.huawei.plugin

import android.content.Intent
import android.os.Bundle
import com.infobip.mobilemessaging.huawei.user.UserMapper
import junit.framework.TestCase
import org.infobip.mobile.messaging.BroadcastParameter
import org.infobip.mobile.messaging.Event
import org.infobip.mobile.messaging.User
import org.infobip.mobile.messaging.UserMapper as NativeUserMapper

class UserBroadcastMapperTest : TestCase() {
    fun testUserUpdatedReconstructsHuaweiUserBundle() {
        val mapped = lifecyclePayload(Event.USER_UPDATED, userIntent())

        assertEquals("external-id", mapped?.get(ChannelContract.EXTERNAL_USER_ID))
        assertEquals("Ada", mapped?.get(ChannelContract.FIRST_NAME))
        assertEquals("Lovelace", mapped?.get(ChannelContract.LAST_NAME))
    }

    fun testPersonalizedReconstructsHuaweiUserBundle() {
        val mapped = lifecyclePayload(Event.PERSONALIZED, userIntent())

        assertEquals("external-id", mapped?.get(ChannelContract.EXTERNAL_USER_ID))
        assertEquals("Ada", mapped?.get(ChannelContract.FIRST_NAME))
        assertEquals("Lovelace", mapped?.get(ChannelContract.LAST_NAME))
    }

    fun testMissingExtrasAreIgnored() {
        assertNull(UserBroadcastMapper.fromIntent(Intent(Event.USER_UPDATED.key)))
    }

    fun testMalformedBundleDoesNotThrow() {
        val intent = Intent(Event.USER_UPDATED.key).putExtras(
            Bundle().apply {
                putString(BroadcastParameter.EXTRA_USER, "invalid")
            },
        )

        assertNull(UserBroadcastMapper.fromIntent(intent))
    }

    fun testDepersonalizedDoesNotRequireUserExtras() {
        val intent = Intent(Event.DEPERSONALIZED.key)

        assertEquals(Event.DEPERSONALIZED.key, intent.action)
        assertNull(intent.extras)
    }

    fun testMessageAndInstallationActionsRemainOutsideUserDecoding() {
        assertNull(UserBroadcastMapper.fromIntent(Intent(Event.MESSAGE_RECEIVED.key)))
        assertNull(UserBroadcastMapper.fromIntent(Intent(Event.INSTALLATION_UPDATED.key)))
    }

    private fun lifecyclePayload(
        event: Event,
        intent: Intent,
    ): Map<String, Any?>? {
        assertEquals(event.key, intent.action)
        return UserBroadcastMapper.fromIntent(intent)?.let(UserMapper::toMap)
    }

    private fun userIntent(): Intent {
        val user = User().apply {
            externalUserId = "external-id"
            firstName = "Ada"
            lastName = "Lovelace"
        }
        return Intent().putExtras(
            NativeUserMapper.toBundle(BroadcastParameter.EXTRA_USER, user),
        )
    }
}
