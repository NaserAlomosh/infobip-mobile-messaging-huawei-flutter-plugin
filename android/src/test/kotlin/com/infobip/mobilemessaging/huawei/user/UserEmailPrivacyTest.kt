package com.infobip.mobilemessaging.huawei.user

import android.os.Looper
import org.infobip.mobile.messaging.MobileMessaging
import org.infobip.mobile.messaging.User
import org.infobip.mobile.messaging.mobileapi.user.UserDataValidator
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class UserEmailPrivacyTest {
    private fun manager(sdk: MobileMessaging): UserManager =
        UserManager(RuntimeEnvironment.getApplication(), { true }).also {
            it.javaClass.getDeclaredField("mobileMessaging\$delegate").apply {
                isAccessible = true
            }.set(it, lazy { sdk })
        }

    @Test fun `overlong emails fail privately before SDK access on both APIs`() {
        val email = "x".repeat(256) + "@example.invalid"
        for (patch in listOf(false, true)) {
            val sdk = mock(MobileMessaging::class.java)
            val manager = manager(sdk)
            ShadowLog.clear()
            var failure: UserFailure? = null
            var calls = 0
            val callback: (Map<String, Any?>?, UserFailure?) -> Unit = { result, error ->
                assertNull(result)
                failure = error
                calls++
            }
            val payload = mapOf("emails" to listOf("valid@example.invalid", email))
            if (patch) manager.patchUser(payload, callback) else manager.saveUser(payload, callback)
            shadowOf(Looper.getMainLooper()).idle()
            assertEquals(1, calls)
            assertEquals("-10", failure?.code)
            assertTrue(failure!!.message.contains("255"))
            assertFalse(failure.toString().contains(email))
            assertTrue(ShadowLog.getLogs().isEmpty())
            verifyNoInteractions(sdk)
        }
    }

    @Test fun `SDK accepted strings and list semantics remain unchanged on both APIs`() {
        val values = listOf("valid@example.invalid", "other@example.invalid", "", "malformed",
            " spaced@example.invalid ", "用户@example.invalid", "x".repeat(255))
        for (patch in listOf(false, true)) {
            val sdk = mock(MobileMessaging::class.java)
            val manager = manager(sdk)
            var saved: User? = null
            doAnswer { saved = it.arguments[0] as User; null }.`when`(sdk).saveUser(any(), any())
            val payload = mapOf("emails" to values + values.first(), "firstName" to "Synthetic")
            if (patch) manager.patchUser(payload) { _, _ -> } else manager.saveUser(payload) { _, _ -> }
            assertEquals(values.toSet(), saved!!.emails)
            assertEquals("Synthetic", saved!!.firstName)
            UserDataValidator.validate(saved)
        }
    }

    @Test fun `null empty omitted and non-email maps retain SDK representation`() {
        for (map in listOf(emptyMap(), mapOf("emails" to null),
            mapOf("emails" to emptyList<String>()), mapOf("firstName" to "Synthetic"))) {
            val patch = UserMapper.toPatch(map)
            val legacy = UserMapper.toUser(map)
            val beforePatch = patch.map.toMap()
            val beforeLegacy = legacy.map.toMap()
            UserEmailPrivacy.validate(patch)
            UserEmailPrivacy.validate(legacy)
            assertEquals(beforePatch, patch.map)
            assertEquals(beforeLegacy, legacy.map)
            assertEquals(map.containsKey("emails"), patch.map.containsKey("emails"))
            assertTrue(legacy.map.containsKey("emails"))
        }
    }

    @Test fun `installed SDK overlength validator embeds the submitted value in its failure`() {
        val email = "x".repeat(256) + "@example.invalid"
        val error = assertThrows(org.infobip.mobile.messaging.mobileapi.user.UserDataValidationException::class.java) {
            UserDataValidator.validate(UserMapper.toPatch(mapOf("emails" to listOf(email))))
        }
        assertTrue(error.message!!.contains(email))
        val sdkError = org.infobip.mobile.messaging.mobileapi.MobileMessagingError.createFrom(error)
        assertEquals("-10", sdkError.code)
    }

    @Test fun `UTF16 boundary matches actual SDK rejection without syntax rules`() {
        for (email in listOf("x".repeat(255), "😀".repeat(127) + "x")) {
            val user = UserMapper.toPatch(mapOf("emails" to listOf(email)))
            UserEmailPrivacy.validate(user)
            UserDataValidator.validate(user)
        }
        for (email in listOf("x".repeat(256), "😀".repeat(128))) {
            val error = assertThrows(UserEmailLengthException::class.java) {
                UserEmailPrivacy.validate(UserMapper.toPatch(mapOf("emails" to listOf(email))))
            }
            assertFalse(error.toString().contains(email))
            assertNull(error.cause)
        }
    }
}
