package com.infobip.mobilemessaging.huawei.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CleanupManagerTest {
    @Test
    fun `cleanup commits JWT removal after SDK success and resets initialization`() {
        var pluginJwt: String? = "plugin-token"
        var supplierJwt: String? = "supplier-token"
        var initialized = true
        val calls = mutableListOf<String>()
        val manager =
            CleanupManager.forTesting(
                isInitialized = { initialized },
                clearPluginJwtState = {
                    calls += "pluginJwt"
                    pluginJwt = null
                },
                clearSdkJwtSupplier = {
                    calls += "sdkJwt"
                    supplierJwt = null
                },
                cleanupSdk = {
                    calls += "cleanup"
                    assertEquals("plugin-token", pluginJwt)
                    assertEquals("supplier-token", supplierJwt)
                },
                resetPluginState = {
                    calls += "reset"
                    initialized = false
                },
            )

        assertNull(manager.cleanup())

        assertEquals(listOf("cleanup", "pluginJwt", "sdkJwt", "reset"), calls)
        assertNull(pluginJwt)
        assertNull(supplierJwt)
        assertFalse(initialized)
    }

    @Test
    fun `cleanup requires initialization`() {
        var invoked = false
        val manager =
            CleanupManager.forTesting(
                isInitialized = { false },
                clearPluginJwtState = { invoked = true },
                clearSdkJwtSupplier = { invoked = true },
                cleanupSdk = { invoked = true },
                resetPluginState = { invoked = true },
            )

        val error = manager.cleanup()

        assertEquals("not_initialized", error?.code)
        assertFalse(invoked)
    }

    @Test
    fun `native cleanup failure does not report success or reset initialization`() {
        var initialized = true
        var cleared = false
        val manager =
            CleanupManager.forTesting(
                isInitialized = { initialized },
                clearPluginJwtState = { cleared = true },
                clearSdkJwtSupplier = { cleared = true },
                cleanupSdk = { error("failure") },
                resetPluginState = { initialized = false },
            )

        val error = manager.cleanup()

        assertEquals("native_error", error?.code)
        assertTrue(initialized)
        assertFalse(cleared)
    }
}
