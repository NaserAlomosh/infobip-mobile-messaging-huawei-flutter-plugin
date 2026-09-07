package com.infobip.mobilemessaging.huawei.chat

import org.infobip.mobile.messaging.chat.InAppChat

internal class ChatOperations(
    private val availability: () -> Boolean,
    private val messageCounter: () -> Int,
    private val resetCounter: () -> Unit,
    private val showScreen: () -> Unit,
    private val setPushTitle: (String?) -> Unit = {},
    private val setPushBody: (String?) -> Unit = {},
) {
    fun isChatAvailable(): Boolean = availability()

    fun getMessageCounter(): Int = messageCounter()

    fun resetMessageCounter() = resetCounter()

    fun showChat() = showScreen()

    fun setChatPushTitle(title: String?) = setPushTitle(title)

    fun setChatPushBody(body: String?) = setPushBody(body)

    companion object {
        fun from(chat: InAppChat) = ChatOperations(
            availability = { chat.isChatAvailable },
            messageCounter = { chat.getMessageCounter() },
            resetCounter = { chat.resetMessageCounter() },
            showScreen = { chat.inAppChatScreen().show() },
            setPushTitle = { chat.setChatPushTitle(it) },
            setPushBody = { chat.setChatPushBody(it) },
        )
    }
}
