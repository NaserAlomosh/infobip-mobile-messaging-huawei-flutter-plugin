package com.infobip.mobilemessaging.huawei.user

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import org.infobip.mobile.messaging.CustomAttributeValue
import org.infobip.mobile.messaging.User
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant
import java.util.Date

class UserMapperTest {
    @Test
    fun `tagged dates map to native date times`() {
        val instant = Instant.parse("2026-09-01T12:00:00Z")
        val tag = mapOf(
            ChannelContract.CUSTOM_VALUE_TYPE to ChannelContract.CUSTOM_DATE_TYPE,
            ChannelContract.CUSTOM_VALUE to instant.toString(),
        )

        val user = UserMapper.toUser(
            mapOf(
                ChannelContract.CUSTOM_ATTRIBUTES to mapOf(
                    "created" to tag,
                    "text" to instant.toString(),
                ),
            ),
        )

        assertEquals(
            Date.from(instant),
            user.customAttributes?.get("created")?.dateTimeValue()?.date,
        )

        assertEquals(
            instant.toString(),
            user.customAttributes?.get("text")?.stringValue(),
        )
    }

    @Test
    fun `native dates map to tagged channel values`() {
        val instant = Instant.parse("2026-09-01T12:00:00Z")

        val user = User().apply {
            customAttributes = mapOf(
                "created" to CustomAttributeValue(
                    CustomAttributeValue.DateTime(
                        Date.from(instant),
                    ),
                ),
            )
        }

        val custom =
            UserMapper.toMap(user)[ChannelContract.CUSTOM_ATTRIBUTES] as Map<*, *>

        val created = custom["created"] as Map<*, *>

        assertEquals(
            ChannelContract.CUSTOM_DATE_TYPE,
            created[ChannelContract.CUSTOM_VALUE_TYPE],
        )

        assertEquals(
            instant.toString(),
            created[ChannelContract.CUSTOM_VALUE],
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun `malformed tagged dates are rejected`() {
        UserMapper.toUser(
            mapOf(
                ChannelContract.CUSTOM_ATTRIBUTES to mapOf(
                    "created" to mapOf(
                        ChannelContract.CUSTOM_VALUE_TYPE to ChannelContract.CUSTOM_DATE_TYPE,
                        ChannelContract.CUSTOM_VALUE to "not-a-date",
                    ),
                ),
            ),
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun `unsupported custom values are rejected`() {
        UserMapper.toUser(
            mapOf(
                ChannelContract.CUSTOM_ATTRIBUTES to mapOf(
                    "bad" to Any(),
                ),
            ),
        )
    }
}