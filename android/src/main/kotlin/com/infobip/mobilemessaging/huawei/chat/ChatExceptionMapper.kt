package com.infobip.mobilemessaging.huawei.chat

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract

internal object ChatExceptionMapper {
    fun toMap(
        message: String?,
        name: String?,
    ): Map<String, String?> =
        mapOf(
            ChannelContract.MESSAGE to message,
            ChannelContract.NAME to name,
        )
}
