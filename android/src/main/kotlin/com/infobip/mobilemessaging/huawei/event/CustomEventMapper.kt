package com.infobip.mobilemessaging.huawei.event

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import org.infobip.mobile.messaging.CustomAttributeValue
import org.infobip.mobile.messaging.CustomEvent
import java.time.Instant
import java.util.Date

internal object CustomEventMapper {
    fun fromMap(value: Any?): CustomEvent {
        val map = value as? Map<*, *> ?: throw IllegalArgumentException("customEvent must be a map")
        val definitionId =
            (map[ChannelContract.DEFINITION_ID] as? String)?.trim()?.takeIf(String::isNotEmpty)
                ?: throw IllegalArgumentException("definitionId must not be empty")
        val properties = properties(map[ChannelContract.PROPERTIES]) ?: emptyMap()
        return CustomEvent(definitionId, properties)
    }

    fun toMap(value: CustomEvent): Map<String, Any?> =
        mapOf(
            ChannelContract.DEFINITION_ID to value.definitionId,
            ChannelContract.EVENT_ID to null,
            ChannelContract.CREATED_AT to null,
            ChannelContract.PROPERTIES to value.properties?.mapValues { (_, item) -> channelValue(item) },
        )

    private fun properties(value: Any?): Map<String, CustomAttributeValue>? {
        if (value == null) return null
        val map = value as? Map<*, *> ?: throw IllegalArgumentException("properties must be a map")
        if (map.keys.any { it !is String }) {
            throw IllegalArgumentException("properties keys must be strings")
        }
        return map.entries.associate { (key, item) -> key as String to nativeValue(item) }
    }

    private fun nativeValue(value: Any?): CustomAttributeValue =
        when (value) {
            is String -> CustomAttributeValue(value)
            is Boolean -> CustomAttributeValue(value)
            is Number -> CustomAttributeValue(value)
            // EventPropertiesMapper supports Date, but not DateTime or CustomList.
            // Use the stored UTC representation to avoid the Date constructor's local-time formatting.
            is Map<*, *> -> CustomAttributeValue(
                taggedDate(value).toInstant().truncatedTo(java.time.temporal.ChronoUnit.SECONDS).toString(),
                CustomAttributeValue.Type.Date,
            )
            else -> throw IllegalArgumentException("properties contains an unsupported value")
        }

    private fun taggedDate(value: Map<*, *>): Date {
        val encoded = value[ChannelContract.CUSTOM_VALUE]
        if (value.size != 2 ||
            value[ChannelContract.CUSTOM_VALUE_TYPE] != ChannelContract.CUSTOM_DATE_TYPE ||
            encoded !is String
        ) {
            throw IllegalArgumentException("properties contains a malformed date value")
        }
        return try {
            Date.from(Instant.parse(encoded))
        } catch (_: Exception) {
            throw IllegalArgumentException("properties contains a malformed date value")
        }
    }

    private fun channelValue(value: CustomAttributeValue): Any =
        when (value.type) {
            CustomAttributeValue.Type.String -> value.stringValue()
            CustomAttributeValue.Type.Boolean -> value.booleanValue()
            CustomAttributeValue.Type.Number -> value.numberValue()
            CustomAttributeValue.Type.Date -> mapOf(
                ChannelContract.CUSTOM_VALUE_TYPE to ChannelContract.CUSTOM_DATE_TYPE,
                ChannelContract.CUSTOM_VALUE to value.dateValue().toInstant().toString(),
            )
            else -> throw IllegalArgumentException("Unsupported custom event payload")
        }
}
