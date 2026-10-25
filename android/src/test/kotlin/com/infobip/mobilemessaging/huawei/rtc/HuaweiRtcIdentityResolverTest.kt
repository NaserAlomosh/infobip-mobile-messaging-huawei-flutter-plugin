package com.infobip.mobilemessaging.huawei.rtc

import org.infobip.mobile.messaging.api.appinstance.LivechatContactInformation
import org.infobip.mobile.messaging.api.appinstance.LivechatDestination
import org.infobip.mobile.messaging.api.appinstance.MobileApiAppInstance
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class HuaweiRtcIdentityResolverTest {
    private val service = mock(MobileApiAppInstance::class.java)
    private var user: Pair<String?, String?> = "installation" to "expected-user"
    private val resolver = NativeLiveChatIdentityResolver({ user }, { service })
    private fun contacts(vararg destinations: LivechatDestination) {
        `when`(service.getLivechatContactInformation("installation"))
            .thenReturn(LivechatContactInformation(arrayOf(*destinations)))
    }
    private fun failure(expected: String, action: () -> Unit) {
        try { action(); fail("Expected a sanitized error") } catch (error: RtcFailure) {
            assertEquals(expected, error.code)
            assertFalse(error.message!!.contains("private-response"))
        }
    }

    @Test fun `selects exact widget and fetches afresh instead of caching`() {
        contacts(LivechatDestination("other-widget", "other-id"), LivechatDestination("widget", "resolved-one"))
        assertEquals("resolved-one", resolver.resolve("widget", "expected-user").subject)
        contacts(LivechatDestination("widget", "resolved-two"))
        assertEquals("resolved-two", resolver.resolve("widget", "expected-user").subject)
        verify(service, times(2)).getLivechatContactInformation("installation")
    }

    @Test fun `never chooses a sole destination for the wrong widget`() {
        contacts(LivechatDestination("other-widget", "other-id"))
        failure("rtc_identity_unavailable") { resolver.resolve("widget", "expected-user") }
    }

    @Test fun `rejects empty duplicate and blank registration results`() {
        contacts()
        failure("rtc_identity_unavailable") { resolver.resolve("widget", "expected-user") }
        contacts(LivechatDestination("widget", "one"), LivechatDestination("widget", "two"))
        failure("rtc_identity_unavailable") { resolver.resolve("widget", "expected-user") }
        contacts(LivechatDestination("widget", "  "))
        failure("rtc_identity_unavailable") { resolver.resolve("widget", "expected-user") }
    }

    @Test fun `requires current installation and expected personalized user before network`() {
        user = null to "expected-user"
        failure("rtc_not_initialized") { resolver.resolve("widget", "expected-user") }
        user = "installation" to "another-user"
        failure("rtc_invalid_state") { resolver.resolve("widget", "expected-user") }
        user = "installation" to null
        failure("rtc_invalid_state") { resolver.resolve("widget", "expected-user") }
        verifyNoInteractions(service)
    }

    @Test fun `discards response if user or installation changed during network request`() {
        `when`(service.getLivechatContactInformation("installation")).thenAnswer {
            user = "new-installation" to "another-user"
            LivechatContactInformation(arrayOf(LivechatDestination("widget", "stale-id")))
        }
        failure("rtc_invalid_state") { resolver.resolve("widget", "expected-user") }
    }

    @Test fun `network failures never expose response details`() {
        `when`(service.getLivechatContactInformation("installation"))
            .thenThrow(IllegalStateException("private-response"))
        failure("rtc_identity_unavailable") { resolver.resolve("widget", "expected-user") }
    }

    @Test fun `resolved identity rejects later logout and installation changes`() {
        contacts(LivechatDestination("widget", "resolved"))
        val resolved = resolver.resolve("widget", "expected-user")
        user = "installation" to null
        failure("rtc_invalid_state") { resolved.validate() }
        user = "other-installation" to "expected-user"
        failure("rtc_invalid_state") { resolved.validate() }
    }
}
