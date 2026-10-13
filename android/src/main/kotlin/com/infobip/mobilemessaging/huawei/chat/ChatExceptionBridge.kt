package com.infobip.mobilemessaging.huawei.chat

import org.infobip.mobile.messaging.chat.core.InAppChatException
import org.infobip.mobile.messaging.chat.view.InAppChatFragment

/** Shares the current Dart handler across Huawei screens and embedded fragments. */
internal class ChatExceptionBridge : InAppChatFragment.ErrorsHandler {
    @Volatile
    private var emit: ((Map<String, String?>) -> Unit)? = null

    fun setHandler(handler: ((Map<String, String?>) -> Unit)?) {
        emit = handler
    }

    override fun handleError(exception: InAppChatException): Boolean {
        val handler = emit ?: return false // Let Huawei present its default error UI.
        handler(ChatExceptionMapper.toMap(exception.message, exception.name))
        return true
    }
}
