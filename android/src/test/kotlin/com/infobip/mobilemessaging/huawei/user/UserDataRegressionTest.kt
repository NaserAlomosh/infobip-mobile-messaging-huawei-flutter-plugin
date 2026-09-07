package com.infobip.mobilemessaging.huawei.user

import org.infobip.mobile.messaging.*
import org.infobip.mobile.messaging.util.DateTimeUtil
import org.junit.Assert.*
import org.junit.Test
import java.util.TimeZone
import java.time.Instant
import java.util.Date

class UserDataRegressionTest {
    @Test fun `birthday preserves calendar day in both directions across timezones`() {
        val previous = TimeZone.getDefault()
        try {
            for (zone in listOf("UTC", "GMT+03:00", "GMT-07:00")) {
                TimeZone.setDefault(TimeZone.getTimeZone(zone))
                val outgoing = UserMapper.toUser(mapOf("birthday" to "1995-06-20"))
                assertEquals(zone, "1995-06-20", DateTimeUtil.dateToYMDString(outgoing.birthday))
                assertEquals(zone, "1995-06-20", UserMapper.toMap(outgoing)["birthday"])
                val incoming = User().apply { birthday = DateTimeUtil.dateFromYMDString("1995-06-20") }
                assertEquals(zone, "1995-06-20", UserMapper.toMap(incoming)["birthday"])
                val attributes = UserMapper.toAttributes(mapOf("birthday" to "1995-06-20"))!!
                assertEquals(zone, "1995-06-20", DateTimeUtil.dateToYMDString(attributes.birthday))
            }
        } finally { TimeZone.setDefault(previous) }
    }

    @Test fun `real Huawei custom lists preserve records values dates and null`() {
        val instant = Date.from(Instant.parse("2026-09-01T12:00:00Z"))
        val item = ListCustomAttributeItem.builder().putString("name", "first")
            .putNumber("amount", 12.5).putBoolean("active", true)
            .putDate("date", DateTimeUtil.dateFromYMDString("1995-06-20"))
            .putDateTime("time", CustomAttributeValue.DateTime(instant)).putString("optional", null).build()
        val second = ListCustomAttributeItem.builder().putString("name", "second")
            .putNumber("amount", 10).putBoolean("active", false)
            .putDate("date", DateTimeUtil.dateFromYMDString("2000-01-01"))
            .putDateTime("time", CustomAttributeValue.DateTime(instant)).putString("optional", null).build()
        val native = User().apply { setListCustomAttribute("records", ListCustomAttributeValue(listOf(item, second))) }
        val mapped = UserMapper.toMap(native)
        val records = (mapped["customAttributes"] as Map<*, *>)["records"] as List<*>
        assertEquals(2, records.size)
        assertEquals("1995-06-20", (records[0] as Map<*, *>)["date"])
        assertEquals("second", (records[1] as Map<*, *>)["name"])
        val restored = UserMapper.toUser(mapped)
        assertEquals(CustomAttributeValue.Type.CustomList, restored.getCustomAttributeValue("records").type)
        assertEquals(CustomAttributesMapper.customAttsToBackend(native.customAttributes),
            CustomAttributesMapper.customAttsToBackend(restored.customAttributes))
        val withNull = UserMapper.toUser(mapOf("customAttributes" to mapOf("deleted" to null)))
        assertTrue(withNull.customAttributes.containsKey("deleted"))
        assertNull(CustomAttributesMapper.customAttsToBackend(withNull.customAttributes)["deleted"])
    }

    @Test fun `custom list tagged DateTime becomes native instant and invalid nested data is rejected`() {
        // Use channel constants so the test verifies the established private date representation.
        val date = mapOf(com.infobip.mobilemessaging.huawei.plugin.ChannelContract.CUSTOM_VALUE_TYPE to
            com.infobip.mobilemessaging.huawei.plugin.ChannelContract.CUSTOM_DATE_TYPE,
            com.infobip.mobilemessaging.huawei.plugin.ChannelContract.CUSTOM_VALUE to "2026-09-01T12:00:00Z")
        val native = UserMapper.toUser(mapOf("customAttributes" to mapOf("records" to listOf(mapOf("time" to date)))))
        val records = CustomAttributesMapper.customValueToBackend(native.getCustomAttributeValue("records")) as List<*>
        assertEquals("2026-09-01T12:00:00Z", (records.single() as Map<*, *>)["time"])
        for (invalid in listOf(listOf(1), listOf(mapOf("x" to listOf(1))), listOf(mapOf("x" to mapOf("nested" to true))),
            listOf(mapOf("x" to 1), mapOf("y" to 2)), listOf(mapOf("x" to 1), mapOf("x" to true)))) {
            assertThrows(IllegalArgumentException::class.java) { UserMapper.toUser(mapOf("customAttributes" to mapOf("records" to invalid))) }
        }
    }
}
