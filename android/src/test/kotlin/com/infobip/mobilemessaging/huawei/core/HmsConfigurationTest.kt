package com.infobip.mobilemessaging.huawei.core

import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class HmsConfigurationTest {
    @Test fun `library contains no usable fake sender ID`() {
        assertNull(HmsConfiguration.appId(RuntimeEnvironment.getApplication()))
        for (invalid in listOf(null, "", " ", "APP_ID", "your-app-id", "123 456", "000")) {
            assertNull(HmsConfiguration.validAppId(invalid))
        }
        assertEquals("123456789", HmsConfiguration.validAppId("123456789"))
    }

    @Test fun `missing host configuration fails before native initialization`() {
        val initializer = MobileMessagingInitializer(RuntimeEnvironment.getApplication())
        val results = mutableListOf<InitializationError?>()
        initializer.initialize("test-application-code", true, null) { results += it }
        assertEquals("hms_configuration_missing", results.single()?.code)
        assertFalse(initializer.isInitialized)
        assertFalse(results.toString().contains("test-application-code"))
    }
}
