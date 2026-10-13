package com.infobip.mobilemessaging.huawei.core

import android.content.Context
import org.infobip.mobile.messaging.MobileMessaging

internal data class MessageOperationFailure(
    val code: String,
    val message: String,
)

internal class MessageOperations private constructor(
    private val isInitialized: () -> Boolean,
    private val setMessagesSeen: (Array<String>) -> Unit,
) {
    constructor(
        context: Context,
        isInitialized: () -> Boolean,
    ) : this(
        isInitialized = isInitialized,
        setMessagesSeen = { MobileMessaging.getInstance(context).setMessagesSeen(*it) },
    )

    fun markMessagesSeen(arguments: Any?): MessageOperationFailure? {
        val values = arguments as? List<*>
            ?: return MessageOperationFailure("invalid_argument", "messageIds must be a list")
        if (values.isEmpty()) {
            return MessageOperationFailure("invalid_argument", "messageIds must not be empty")
        }
        if (values.any { it !is String }) {
            return MessageOperationFailure(
                "invalid_argument",
                "messageIds must contain only strings",
            )
        }
        if (!isInitialized()) {
            return MessageOperationFailure("not_initialized", "Initialize the Infobip SDK first")
        }

        return try {
            setMessagesSeen(values.map { it as String }.toTypedArray())
            null
        } catch (_: Exception) {
            MessageOperationFailure("native_error", "Unable to mark messages as seen")
        }
    }

    internal companion object {
        fun forTesting(
            isInitialized: () -> Boolean,
            setMessagesSeen: (Array<String>) -> Unit,
        ) = MessageOperations(isInitialized, setMessagesSeen)
    }
}
