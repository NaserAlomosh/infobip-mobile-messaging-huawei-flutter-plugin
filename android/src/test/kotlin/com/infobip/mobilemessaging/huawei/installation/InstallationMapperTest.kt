package com.infobip.mobilemessaging.huawei.installation

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import org.infobip.mobile.messaging.Installation
import org.infobip.mobile.messaging.CustomAttributeValue
import org.infobip.mobile.messaging.util.DateTimeUtil
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Instant
import java.util.Date

class InstallationMapperTest {
    @Test
    fun `maps native installation fields`() {
        val installation = Installation().apply {
            isPushRegistrationEnabled = true
            isPrimaryDevice = false
            language = "en"
            customAttributes = mapOf(
                "date" to CustomAttributeValue(DateTimeUtil.dateFromYMDString("1995-06-20")),
                "created" to CustomAttributeValue(
                    CustomAttributeValue.DateTime(Date.from(Instant.parse("2026-09-01T10:15:30Z"))),
                ),
            )
        }

        val mapped = InstallationMapper.toMap(installation)

        assertNull(mapped[ChannelContract.INSTALLATION_ID])
        assertEquals(true, mapped[ChannelContract.IS_PUSH_REGISTRATION_ENABLED])
        assertEquals(false, mapped[ChannelContract.IS_PRIMARY_DEVICE])
        assertEquals("en", mapped[ChannelContract.LANGUAGE])
        val attributes = mapped[ChannelContract.CUSTOM_ATTRIBUTES] as Map<*, *>
        assertEquals("1995-06-20", attributes["date"])
        assertEquals(
            ChannelContract.CUSTOM_DATE_TYPE,
            (attributes["created"] as Map<*, *>)[ChannelContract.CUSTOM_VALUE_TYPE],
        )
        assertEquals("2026-09-01T10:15:30Z", (attributes["created"] as Map<*, *>)[ChannelContract.CUSTOM_VALUE])
    }

    @Test
    fun `applies only writable fields`() {
        val installation = Installation()
        InstallationMapper.applyWritable(
            installation,
            mapOf(
                ChannelContract.PUSH_REGISTRATION_ID to "ignored",
                ChannelContract.DEVICE_MODEL to "ignored",
                ChannelContract.LANGUAGE to "ignored",
                ChannelContract.CUSTOM_ATTRIBUTES to mapOf("score" to 3),
            ),
        )

        assertNull(installation.pushRegistrationId)
        assertNull(installation.deviceModel)
        assertNull(installation.language)
        assertEquals(3, installation.customAttributes["score"]?.numberValue())
    }
}
