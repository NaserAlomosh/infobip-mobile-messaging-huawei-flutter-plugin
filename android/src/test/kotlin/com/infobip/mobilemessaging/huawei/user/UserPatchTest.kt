package com.infobip.mobilemessaging.huawei.user

import org.junit.Assert.*
import org.junit.Test

class UserPatchTest {
    @Test fun `legacy mismatch and sparse native request map`() {
        assertTrue(UserMapper.toUser(mapOf("firstName" to "Michael")).map.containsKey("lastName"))
        assertEquals(mapOf("firstName" to "Michael"), UserMapper.toPatch(mapOf("firstName" to "Michael")).map)
    }
    @Test fun `empty patch produces no SDK fields or null keys`() {
        val user = UserMapper.toPatch(emptyMap<String, Any?>())
        assertEquals(emptyMap<String, Any?>(), user.map)
    }
    @Test fun `clear and empty values survive SDK setters`() {
        val native = UserMapper.toPatch(mapOf("lastName" to null, "firstName" to "", "tags" to emptyList<String>()))
        assertTrue(native.map.containsKey("lastName"))
        assertNull(native.map["lastName"])
        assertEquals("", native.map["firstName"])
        assertTrue(native.map.containsKey("tags"))
    }
    @Test fun `invalid values fail before save`() {
        assertThrows(IllegalArgumentException::class.java) { UserMapper.toPatch(mapOf("firstName" to 5)) }
    }
    @Test fun `all supported clears produce present null keys`() {
        for (key in listOf("externalUserId", "firstName", "lastName", "middleName", "gender", "birthday", "phones", "emails", "tags")) {
            val user = UserMapper.toPatch(mapOf(key to null))
            assertTrue(key, user.map.containsKey(key))
            assertNull(key, user.map[key])
            org.infobip.mobile.messaging.mobileapi.user.UserDataValidator.validate(user)
        }
    }
    @Test fun `unsupported clears and unknown fields are rejected`() {
        for (key in listOf("customAttributes", "type", "installations", "unexpected")) {
            assertThrows(IllegalArgumentException::class.java) { UserMapper.toPatch(mapOf(key to null)) }
        }
    }
    @Test fun `custom attribute deletion remains explicit`() {
        val user = UserMapper.toPatch(mapOf("customAttributes" to mapOf("obsolete" to null)))
        val attributes = user.map["customAttributes"] as Map<*, *>
        assertTrue(attributes.containsKey("obsolete"))
        assertNull(attributes["obsolete"])
    }
}
