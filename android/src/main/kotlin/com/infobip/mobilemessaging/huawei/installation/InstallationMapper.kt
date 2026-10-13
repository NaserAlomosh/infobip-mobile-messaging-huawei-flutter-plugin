package com.infobip.mobilemessaging.huawei.installation

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import com.infobip.mobilemessaging.huawei.user.UserMapper
import org.infobip.mobile.messaging.Installation

internal object InstallationMapper {
    fun toMap(value: Installation): Map<String, Any?> =
        mapOf(
            ChannelContract.INSTALLATION_ID to null,
            ChannelContract.PUSH_REGISTRATION_ID to value.pushRegistrationId,
            ChannelContract.PUSH_SERVICE_TOKEN to value.pushServiceToken,
            ChannelContract.PUSH_SERVICE_TYPE to value.pushServiceType?.name,
            ChannelContract.IS_PUSH_REGISTRATION_ENABLED to value.isPushRegistrationEnabled,
            ChannelContract.IS_PRIMARY_DEVICE to value.isPrimaryDevice,
            ChannelContract.NOTIFICATIONS_ENABLED to value.getNotificationsEnabled(),
            ChannelContract.SDK_VERSION to value.sdkVersion,
            ChannelContract.APP_VERSION to value.appVersion,
            ChannelContract.OS to value.os,
            ChannelContract.OS_VERSION to value.osVersion,
            ChannelContract.DEVICE_MANUFACTURER to value.deviceManufacturer,
            ChannelContract.DEVICE_MODEL to value.deviceModel,
            ChannelContract.DEVICE_SECURE to value.getDeviceSecure(),
            ChannelContract.LANGUAGE to value.language,
            ChannelContract.DEVICE_TIMEZONE_OFFSET to value.deviceTimezoneOffset,
            ChannelContract.APPLICATION_USER_ID to value.applicationUserId,
            ChannelContract.DEVICE_NAME to value.deviceName,
            ChannelContract.CUSTOM_ATTRIBUTES to UserMapper.channelValue(value.customAttributes),
        )

    fun applyWritable(target: Installation, payload: Any?): Installation {
        val map = payload as? Map<*, *> ?: throw IllegalArgumentException("installation must be a map")
        boolean(map, ChannelContract.IS_PRIMARY_DEVICE)?.let { target.isPrimaryDevice = it }
        boolean(map, ChannelContract.IS_PUSH_REGISTRATION_ENABLED)?.let { target.isPushRegistrationEnabled = it }
        if (map.containsKey(ChannelContract.CUSTOM_ATTRIBUTES)) {
            target.customAttributes = UserMapper.toNativeCustomAttributes(map[ChannelContract.CUSTOM_ATTRIBUTES])
        }
        return target
    }

    private fun boolean(map: Map<*, *>, key: String): Boolean? {
        val value = map[key] ?: return null
        return value as? Boolean ?: throw IllegalArgumentException("$key must be a boolean")
    }
}
