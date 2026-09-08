package com.infobip.mobilemessaging.huawei.rtc

import android.content.Context
import org.infobip.mobile.messaging.MobileMessaging
import org.infobip.mobile.messaging.api.rtc.MobileApiRtc
import org.infobip.mobile.messaging.api.rtc.TokenBody
import org.infobip.mobile.messaging.mobileapi.MobileApiResourceProvider

internal fun interface RtcTokenProvider {
    /** Blocking network boundary. Only invoked on the token executor. */
    fun fetch(identity: String?): String
}

internal class HuaweiRtcTokenProvider(
    private val installationIdentity: () -> String?,
    private val service: () -> MobileApiRtc,
) : RtcTokenProvider {
    constructor(context: Context) : this(
        installationIdentity = { MobileMessaging.getInstance(context.applicationContext).installation?.pushRegistrationId },
        // A fresh provider captures the current initialized MM application, not a previous account.
        service = { MobileApiResourceProvider().getMobileApiRtc(context.applicationContext) },
    )

    override fun fetch(identity: String?): String {
        val subject = identity ?: installationIdentity()?.takeIf { it.isNotBlank() }
            ?: throw RtcFailure("rtc_not_initialized", "Wait for Mobile Messaging installation registration or supply an identity")
        return try {
            service().getToken(TokenBody(subject, 43200L))?.token?.takeIf { it.isNotBlank() }
                ?: throw RtcFailure("rtc_token_failed", "RTC access token acquisition failed")
        } catch (_: Exception) {
            // Do not forward SDK HTTP exceptions, responses, tokens, or application credentials.
            throw RtcFailure("rtc_token_failed", "RTC access token acquisition failed")
        }
    }
}
