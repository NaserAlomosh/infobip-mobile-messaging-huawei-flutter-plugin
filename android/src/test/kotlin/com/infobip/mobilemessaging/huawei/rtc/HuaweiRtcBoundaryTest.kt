package com.infobip.mobilemessaging.huawei.rtc

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import com.infobip.webrtc.sdk.api.InfobipRTC
import com.infobip.webrtc.sdk.api.call.ApplicationCall
import com.infobip.webrtc.sdk.api.model.CallStatus
import com.infobip.webrtc.sdk.api.options.ApplicationCallOptions
import com.infobip.webrtc.sdk.api.request.CallApplicationRequest
import org.infobip.mobile.messaging.api.rtc.MobileApiRtc
import org.infobip.mobile.messaging.api.rtc.TokenBody
import org.infobip.mobile.messaging.api.rtc.TokenResponse
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentCaptor
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class HuaweiRtcBoundaryTest {
    @Test fun `audio invokes exact Core API with audio true video false and application context`() = checkNativeCall(false)
    @Test fun `video invokes exact Core API with audio true video true and separate Calls configuration`() = checkNativeCall(true)

    private fun checkNativeCall(video: Boolean) {
        val application = RuntimeEnvironment.getApplication()
        val activity = mock(Activity::class.java)
        `when`(activity.applicationContext).thenReturn(application)
        val sdk = mock(InfobipRTC::class.java)
        val call = mock(ApplicationCall::class.java)
        `when`(sdk.callApplication(any(CallApplicationRequest::class.java), any(ApplicationCallOptions::class.java))).thenReturn(call)
        val listener = RtcListener { _, _ -> }
        val backend = HuaweiRtcBackend(activity) { sdk }
        assertSame(call, backend.call("unit-test-token", RtcInput("outgoing-calls-config", if (video) "video" else "audio", null), listener))
        val request = ArgumentCaptor.forClass(CallApplicationRequest::class.java)
        val options = ArgumentCaptor.forClass(ApplicationCallOptions::class.java)
        verify(sdk).callApplication(request.capture(), options.capture())
        assertSame(application, request.value.context)
        assertEquals("unit-test-token", request.value.token)
        assertEquals("outgoing-calls-config", request.value.callsConfigurationId)
        assertSame(listener, request.value.applicationCallEventListener)
        assertTrue(options.value.isAudio)
        assertEquals(video, options.value.isVideo)
        verifyNoMoreInteractions(sdk)
    }

    @Test fun `backend detects native active call but permits finished singleton reference`() {
        val sdk = mock(InfobipRTC::class.java)
        val call = mock(ApplicationCall::class.java)
        `when`(sdk.activeApplicationCall).thenReturn(call)
        val backend = HuaweiRtcBackend(RuntimeEnvironment.getApplication()) { sdk }
        `when`(call.status()).thenReturn(CallStatus.ESTABLISHED)
        assertTrue(backend.hasActiveCall())
        `when`(call.status()).thenReturn(CallStatus.FINISHED)
        assertFalse(backend.hasActiveCall())
    }

    @Test fun `token delegates explicit identity lifespan and reads response natively`() {
        val service = mock(MobileApiRtc::class.java)
        `when`(service.getToken(any(TokenBody::class.java))).thenReturn(TokenResponse("unit-test-token", "unit-test-expiration"))
        val provider = HuaweiRtcTokenProvider({ fail("Explicit identity must not use installation fallback"); null }, { service })
        assertEquals("unit-test-token", provider.fetch("explicit-subject"))
        val request = ArgumentCaptor.forClass(TokenBody::class.java)
        verify(service).getToken(request.capture())
        assertEquals("explicit-subject", request.value.identity)
        assertEquals(43200L, request.value.timeToLive)
    }

    @Test fun `omitted identity uses current installation and token is fetched afresh`() {
        val bodies = mutableListOf<TokenBody>()
        val service = mock(MobileApiRtc::class.java)
        `when`(service.getToken(any(TokenBody::class.java))).thenAnswer {
            bodies += it.getArgument<TokenBody>(0)
            TokenResponse("unit-test-token", "unit-test-expiration")
        }
        var installation = "installation-one"
        var serviceCreations = 0
        val provider = HuaweiRtcTokenProvider({ installation }, { serviceCreations++; service })
        provider.fetch(null)
        installation = "installation-two"
        provider.fetch(null)
        assertEquals(listOf("installation-one", "installation-two"), bodies.map { it.identity })
        assertEquals(2, serviceCreations)
    }

    @Test fun `missing installation returns stable initialization error`() {
        val provider = HuaweiRtcTokenProvider({ null }, { error("Must not reach backend") })
        assertFailure("rtc_not_initialized") { provider.fetch(null) }
    }

    @Test fun `blank token and native HTTP errors never expose backend response`() {
        val service = mock(MobileApiRtc::class.java)
        val provider = HuaweiRtcTokenProvider({ "subject" }, { service })
        `when`(service.getToken(any(TokenBody::class.java))).thenReturn(TokenResponse(" ", ""))
        assertFailure("rtc_token_failed") { provider.fetch(null) }
        `when`(service.getToken(any(TokenBody::class.java))).thenThrow(RuntimeException("secret Authorization"))
        val error = assertFailure("rtc_token_failed") { provider.fetch(null) }
        assertFalse(error.message.contains("secret"))
        assertNull(error.cause)
    }

    @Test fun `audio requires microphone and video also requires camera`() {
        val context = RuntimeEnvironment.getApplication()
        shadowOf(context).denyPermissions(Manifest.permission.RECORD_AUDIO, Manifest.permission.CAMERA)
        assertFailure("rtc_permission_denied") { checkRtcPermissions(context, false) }
        shadowOf(context).grantPermissions(Manifest.permission.RECORD_AUDIO)
        checkRtcPermissions(context, false)
        assertFailure("rtc_permission_denied") { checkRtcPermissions(context, true) }
        shadowOf(context).grantPermissions(Manifest.permission.CAMERA)
        checkRtcPermissions(context, true)
    }

    @Test @Config(sdk = [31]) fun `Android 12 also requires Nearby devices permission`() {
        val context = RuntimeEnvironment.getApplication()
        shadowOf(context).grantPermissions(Manifest.permission.RECORD_AUDIO)
        shadowOf(context).denyPermissions(Manifest.permission.BLUETOOTH_CONNECT)
        assertFailure("rtc_permission_denied") { checkRtcPermissions(context, false) }
        shadowOf(context).grantPermissions(Manifest.permission.BLUETOOTH_CONNECT)
        checkRtcPermissions(context, false)
    }

    private fun assertFailure(code: String, action: () -> Unit): RtcFailure {
        try { action(); throw AssertionError("Expected $code") } catch (failure: RtcFailure) {
            assertEquals(code, failure.code)
            return failure
        }
    }
}
