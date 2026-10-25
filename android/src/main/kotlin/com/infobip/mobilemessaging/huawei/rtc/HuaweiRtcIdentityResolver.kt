package com.infobip.mobilemessaging.huawei.rtc

import android.content.Context
import org.infobip.mobile.messaging.MobileMessaging
import org.infobip.mobile.messaging.api.appinstance.MobileApiAppInstance
import org.infobip.mobile.messaging.mobileapi.MobileApiResourceProvider

internal fun interface LiveChatIdentityResolver {
    fun resolve(widgetId: String, expectedExternalUserId: String): ResolvedChatIdentity
}

/** Blocking SDK boundary. No identity, service, response, or failure payload is cached/logged. */
internal class NativeLiveChatIdentityResolver(
    private val currentUser: () -> Pair<String?, String?>,
    private val service: () -> MobileApiAppInstance,
) : LiveChatIdentityResolver {
    constructor(context: Context) : this(
        currentUser = {
            MobileMessaging.getInstance(context.applicationContext).let {
                it.installation?.pushRegistrationId to it.user?.externalUserId
            }
        },
        service = { MobileApiResourceProvider().getMobileApiAppInstance(context.applicationContext) },
    )

    override fun resolve(widgetId: String, expectedExternalUserId: String): ResolvedChatIdentity {
        try {
            val before = currentUser()
            val pushId = before.first?.takeIf { it.isNotBlank() }
                ?: throw RtcFailure("rtc_not_initialized", "Installation registration is required")
            if (before.second != expectedExternalUserId) {
                throw RtcFailure("rtc_invalid_state", "Personalize the expected user before calling")
            }
            val matches = service().getLivechatContactInformation(pushId)?.liveChatDestinations
                .orEmpty().filter { it.widgetId == widgetId }
            if (matches.size != 1) {
                throw RtcFailure("rtc_identity_unavailable", "A unique matching Chat destination is required")
            }
            val identity = matches.single().registrationId?.takeIf { it.isNotBlank() }
                ?: throw RtcFailure("rtc_identity_unavailable", "Chat registration is not available")
            if (currentUser() != before) {
                throw RtcFailure("rtc_invalid_state", "User or installation changed during lookup")
            }
            return ResolvedChatIdentity(identity) {
                if (currentUser() != before) {
                    throw RtcFailure("rtc_invalid_state", "User or installation changed before call submission")
                }
            }
        } catch (failure: RtcFailure) {
            throw failure
        } catch (_: Exception) {
            throw RtcFailure("rtc_identity_unavailable", "Chat identity lookup failed")
        }
    }
}

/** Kept only by one pending call; never serialized to Flutter or persisted. */
internal class ResolvedChatIdentity(val subject: String, val validate: () -> Unit)

/** Process-wide epoch detects even logout/relogin to the same user across engines.
 * Access is confined to the Android main thread, like the call slot.
 */
internal object RtcIdentityLifecycle {
    private var epoch = 0L
    private var mutations = 0
    fun begin() { epoch++; mutations++ }
    fun end() { check(mutations > 0); mutations-- }
    fun capture(): Long {
        if (mutations != 0) invalid()
        return epoch
    }
    fun validate(expected: Long) {
        if (mutations != 0 || epoch != expected) invalid()
    }
    private fun invalid(): Nothing = throw RtcFailure(
        "rtc_invalid_state", "Messaging identity changed or an account operation is pending")
}
