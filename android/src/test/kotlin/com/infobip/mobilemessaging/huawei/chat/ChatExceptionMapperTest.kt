package com.infobip.mobilemessaging.huawei.chat

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ChatExceptionMapperTest {
    @Test
    fun `maps only native message and name`() {
        val mapped = ChatExceptionMapper.toMap("Connection failed", "Error")

        assertEquals(setOf(ChannelContract.MESSAGE, ChannelContract.NAME), mapped.keys)
        assertEquals("Connection failed", mapped[ChannelContract.MESSAGE])
        assertEquals("Error", mapped[ChannelContract.NAME])
    }

    @Test
    fun `preserves null optional fields`() {
        val mapped = ChatExceptionMapper.toMap(null, null)

        assertNull(mapped[ChannelContract.MESSAGE])
        assertNull(mapped[ChannelContract.NAME])
    }
}
