package com.infobip.mobilemessaging.huawei.user

import org.infobip.mobile.messaging.User
import org.infobip.mobile.messaging.UserIdentity

/** Mirrors only SDK 9.3.0's per-email length rejection, which otherwise logs the value. */
internal object UserEmailPrivacy {
    fun validate(user: User) = validateEmails(user.emails)

    fun validate(identity: UserIdentity) = validateEmails(identity.emails)

    private fun validateEmails(emails: Set<String>?) {
        if (emails?.any { it.length > 255 } == true) {
            throw UserEmailLengthException()
        }
    }
}

// Never retain the submitted value in an exception or its cause.
internal class UserEmailLengthException : IllegalArgumentException(
    "Each email must contain at most 255 UTF-16 code units",
)
