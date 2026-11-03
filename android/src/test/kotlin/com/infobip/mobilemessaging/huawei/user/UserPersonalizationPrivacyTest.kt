package com.infobip.mobilemessaging.huawei.user

import android.os.Looper
import org.infobip.mobile.messaging.*
import org.infobip.mobile.messaging.mobileapi.MobileMessagingError
import org.infobip.mobile.messaging.mobileapi.Result
import org.infobip.mobile.messaging.mobileapi.user.UserDataValidator
import org.infobip.mobile.messaging.mobileapi.user.UserDataValidationException
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
class UserPersonalizationPrivacyTest {
    private fun manager(sdk: MobileMessaging, initialized: Boolean = true): UserManager =
    UserManager(RuntimeEnvironment.getApplication(), { initialized }).also {
        it.javaClass.getDeclaredField("mobileMessaging\$delegate").apply {
            isAccessible = true
        }.set(it, lazy { sdk })
    }

    @Test fun `overlong identity emails fail privately without SDK calls or forced depersonalization`() {
        for (email in listOf("x".repeat(256), "😀".repeat(128))) {
            for (force in listOf(false, true)) {
                for (keep in listOf(false, true)) for (primary in listOf(false, true)) {
                    val sdk = mock(MobileMessaging::class.java)
                    ShadowLog.clear()
                    var callbacks = 0
                    var failure: UserFailure? = null
                    manager(sdk).personalize(
                    mapOf("externalUserId" to "synthetic-id", "emails" to listOf("valid@example.invalid", email)),
                    null, force, keep, primary,
                    ) { result, error ->
                        assertNull(result)
                        failure = error
                        callbacks++
                    }
                    shadowOf(Looper.getMainLooper()).idle()
                    assertEquals(1, callbacks)
                    assertEquals("-10", failure?.code)
                    assertEquals("Each email must contain at most 255 UTF-16 code units", failure?.message)
                    assertFalse(failure.toString().contains(email))
                    assertFalse(failure.toString().contains("synthetic-id"))
                    assertTrue(ShadowLog.getLogs().isEmpty())
                    verifyNoInteractions(sdk)
                }
            }
        }
    }

    @Test fun `accepted identities attributes force flag and success callback pass unchanged`() {
        val emails = listOf("valid@example.invalid", "other@example.invalid", " spaced@example.invalid ",
        "用户@example.invalid", "", "malformed", "x".repeat(255), "😀".repeat(127) + "x")
        for (force in listOf(false, true)) {
            for (keep in listOf(false, true)) for (primary in listOf(false, true)) {
                val sdk = mock(MobileMessaging::class.java)
                var invocations = 0
                doAnswer { call ->
                    val identity = call.arguments[0] as UserIdentity
                    val attributes = call.arguments[1] as UserAttributes
                    assertEquals(emails.toSet(), identity.emails)
                    assertEquals("synthetic-id", identity.externalUserId)
                    assertEquals(setOf("synthetic-phone"), identity.phones)
                    assertEquals("Synthetic", attributes.firstName)
                    assertEquals(force, call.arguments[2])
                    assertEquals(keep, call.arguments[3])
                    assertEquals(primary, call.arguments[4])
                    UserDataValidator.validate(identity)
                    @Suppress("UNCHECKED_CAST")
                    val listener = call.arguments[5] as MobileMessaging.ResultListener<User>
                    listener.onResult(Result(User().apply { firstName = "Synthetic" }))
                    invocations++
                    null
                }.`when`(sdk).personalize(any(UserIdentity::class.java), any(UserAttributes::class.java), anyBoolean(), anyBoolean(), anyBoolean(), any<MobileMessaging.ResultListener<User>>())
                var callbacks = 0
                manager(sdk).personalize(mapOf("externalUserId" to "synthetic-id",
                "phones" to listOf("synthetic-phone"), "emails" to emails + emails.first()),
                mapOf("firstName" to "Synthetic"), force, keep, primary) { result, error ->
                    assertNull(error)
                    assertEquals("Synthetic", result?.get("firstName"))
                    callbacks++
                }
                shadowOf(Looper.getMainLooper()).idle()
                assertEquals(1, invocations)
                assertEquals(1, callbacks)
            }
        }
    }

    @Test fun `null empty and omitted email collections keep identity representation`() {
        for (payload in listOf(mapOf("externalUserId" to "synthetic-id"),
        mapOf("externalUserId" to "synthetic-id", "emails" to null),
        mapOf("externalUserId" to "synthetic-id", "emails" to emptyList<String>()))) {
            for (force in listOf(false, true)) {
                for (keep in listOf(false, true)) for (primary in listOf(false, true)) {
                    val sdk = mock(MobileMessaging::class.java)
                    var invocations = 0
                    doAnswer { call ->
                        val identity = call.arguments[0] as UserIdentity
                        assertEquals(UserMapper.toIdentity(payload).map, identity.map)
                        assertNull(call.arguments[1])
                        assertEquals(force, call.arguments[2])
                        assertEquals(keep, call.arguments[3])
                        assertEquals(primary, call.arguments[4])
                        invocations++
                        null
                    }.`when`(sdk).personalize(any(UserIdentity::class.java), isNull<UserAttributes>(), anyBoolean(), anyBoolean(), anyBoolean(), any<MobileMessaging.ResultListener<User>>())
                    manager(sdk).personalize(payload, null, force, keep, primary) { _, _ -> }
                    assertEquals(1, invocations)
                }
            }
        }
    }

    @Test fun `initialization still takes precedence and SDK errors remain failures`() {
        val sdk = mock(MobileMessaging::class.java)
        var failure: UserFailure? = null
        manager(sdk, false).personalize(mapOf("emails" to listOf("x".repeat(256))), null, true) {
            _, error -> failure = error
        }
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals("not_initialized", failure?.code)
        verifyNoInteractions(sdk)
        doAnswer { call ->
            @Suppress("UNCHECKED_CAST")
            val listener = call.arguments[5] as MobileMessaging.ResultListener<User>
            listener.onResult(Result(null, MobileMessagingError("denied", "synthetic-private-message")))
            null
        }.`when`(sdk).personalize(any(UserIdentity::class.java), isNull<UserAttributes>(), anyBoolean(), anyBoolean(), anyBoolean(), any<MobileMessaging.ResultListener<User>>())
        manager(sdk).personalize(mapOf("externalUserId" to "synthetic-id"), null, false) {
            result, error -> assertNull(result); failure = error
        }
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(UserFailure("denied", "Unable to personalize user"), failure)
    }

    @Test fun `installed identity validator rejects same UTF16 boundary and maps to minus ten`() {
        for (email in listOf("x".repeat(256), "😀".repeat(128))) {
            val identity = UserMapper.toIdentity(mapOf("emails" to listOf(email)))
            val error = assertThrows(UserDataValidationException::class.java) {
                UserDataValidator.validate(identity)
            }
            assertTrue(error.message!!.contains(email))
            assertEquals("-10", MobileMessagingError.createFrom(error).code)
            val privateError = assertThrows(UserEmailLengthException::class.java) {
                UserEmailPrivacy.validate(identity)
            }
            assertFalse(privateError.toString().contains(email))
            assertNull(privateError.cause)
        }
    }
}
