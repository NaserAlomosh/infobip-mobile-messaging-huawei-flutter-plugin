package com.infobip.mobilemessaging.huawei.user

import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import org.infobip.mobile.messaging.CustomAttributesMapper
import org.infobip.mobile.messaging.ListCustomAttributeItem
import org.infobip.mobile.messaging.ListCustomAttributeValue
import org.infobip.mobile.messaging.CustomAttributeValue
import org.infobip.mobile.messaging.User
import org.infobip.mobile.messaging.UserAttributes
import org.infobip.mobile.messaging.UserIdentity
import java.text.SimpleDateFormat
import java.time.Instant
import java.util.Date
import java.util.Locale

internal object UserMapper {
    private val dateFormat: SimpleDateFormat
        get() =
            SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).apply {
                isLenient = false
            }

    fun toMap(user: User): Map<String, Any?> =
        mapOf(
            ChannelContract.EXTERNAL_USER_ID to user.externalUserId,
            ChannelContract.FIRST_NAME to user.firstName,
            ChannelContract.LAST_NAME to user.lastName,
            ChannelContract.MIDDLE_NAME to user.middleName,
            ChannelContract.GENDER to user.gender?.name?.lowercase(Locale.ROOT),
            ChannelContract.BIRTHDAY to user.birthday?.let(dateFormat::format),
            ChannelContract.TYPE to user.type?.name?.lowercase(Locale.ROOT),
            ChannelContract.PHONES to user.phones?.toList(),
            ChannelContract.EMAILS to user.emails?.toList(),
            ChannelContract.TAGS to user.tags?.toList(),
            ChannelContract.CUSTOM_ATTRIBUTES to channelCustomAttributes(user.customAttributes),
            ChannelContract.INSTALLATIONS to user.installations?.map { com.infobip.mobilemessaging.huawei.installation.InstallationMapper.toMap(it) },
        )

    fun toUser(value: Any?): User {
        val map = requireMap(value, ChannelContract.USER)
        return User().apply {
            externalUserId = string(map, ChannelContract.EXTERNAL_USER_ID)
            firstName = string(map, ChannelContract.FIRST_NAME)
            lastName = string(map, ChannelContract.LAST_NAME)
            middleName = string(map, ChannelContract.MIDDLE_NAME)
            gender = gender(map[ChannelContract.GENDER])
            birthday = date(map[ChannelContract.BIRTHDAY])
            phones = strings(map, ChannelContract.PHONES)?.toSet()
            emails = strings(map, ChannelContract.EMAILS)?.toSet()
            tags = strings(map, ChannelContract.TAGS)?.toSet()
            customAttributes = toNativeCustomAttributes(map[ChannelContract.CUSTOM_ATTRIBUTES])
        }
    }

    fun toIdentity(value: Any?): UserIdentity {
        val map = requireMap(value, ChannelContract.USER_IDENTITY)
        return UserIdentity().apply {
            externalUserId = string(map, ChannelContract.EXTERNAL_USER_ID)
            phones = strings(map, ChannelContract.PHONES)?.toSet()
            emails = strings(map, ChannelContract.EMAILS)?.toSet()
        }
    }

    fun toAttributes(value: Any?): UserAttributes? {
        if (value == null) return null
        val map = requireMap(value, ChannelContract.USER_ATTRIBUTES)
        return UserAttributes().apply {
            firstName = string(map, ChannelContract.FIRST_NAME)
            lastName = string(map, ChannelContract.LAST_NAME)
            middleName = string(map, ChannelContract.MIDDLE_NAME)
            gender = gender(map[ChannelContract.GENDER])
            birthday = date(map[ChannelContract.BIRTHDAY])
            tags = strings(map, ChannelContract.TAGS)?.toSet()
            customAttributes = toNativeCustomAttributes(map[ChannelContract.CUSTOM_ATTRIBUTES])
        }
    }

    private fun requireMap(
        value: Any?,
        name: String,
    ): Map<*, *> = value as? Map<*, *> ?: throw IllegalArgumentException("$name must be a map")

    private fun string(
        map: Map<*, *>,
        key: String,
    ): String? {
        val value = map[key] ?: return null
        return value as? String ?: throw IllegalArgumentException("$key must be a string")
    }

    private fun strings(
        map: Map<*, *>,
        key: String,
    ): List<String>? {
        val value = map[key] ?: return null
        val values = value as? List<*> ?: throw IllegalArgumentException("$key must be a list")
        if (values.any { it !is String }) throw IllegalArgumentException("$key must contain strings")
        return values.filterIsInstance<String>()
    }

    private fun gender(value: Any?): UserAttributes.Gender? =
        when (value) {
            null -> null
            "male" -> UserAttributes.Gender.Male
            "female" -> UserAttributes.Gender.Female
            "unknown" -> null
            else -> throw IllegalArgumentException("gender is invalid")
        }

    private fun date(value: Any?): Date? {
        if (value == null) return null
        if (value !is String) throw IllegalArgumentException("birthday must be a string")
        require(Regex("\\d{4}-\\d{2}-\\d{2}").matches(value)) { "birthday is invalid" }
        return try {
            dateFormat.parse(value) ?: throw IllegalArgumentException("birthday is invalid")
        } catch (_: java.text.ParseException) {
            throw IllegalArgumentException("birthday is invalid")
        }
    }

    internal fun toNativeCustomAttributes(value: Any?): Map<String, CustomAttributeValue?>? {
        if (value == null) return null
        val map =
            value as? Map<*, *>
                ?: throw IllegalArgumentException("customAttributes must be a map")
        if (map.keys.any { it !is String }) {
            throw IllegalArgumentException("customAttributes keys must be strings")
        }
        return map.entries.associate { (key, item) ->
            key as String to nativeCustomValue(item)
        }
    }

    private fun channelCustomAttributes(value: Map<String, CustomAttributeValue?>?): Map<String, Any?>? =
        value?.mapValues { channelValue(it.value) }

    private fun nativeCustomValue(value: Any?): CustomAttributeValue? =
        when (value) {
            null -> null
            is List<*> -> nativeCustomList(value)
            is String -> CustomAttributeValue(value)
            is Boolean -> CustomAttributeValue(value)
            is Number -> CustomAttributeValue(value)
            is Map<*, *> -> CustomAttributeValue(CustomAttributeValue.DateTime(taggedDate(value)))
            else -> throw IllegalArgumentException("customAttributes contains an unsupported value")
        }

    private fun nativeCustomList(value: List<*>): CustomAttributeValue {
        val records = value.map { record ->
            val fields = record as? Map<*, *>
                ?: throw IllegalArgumentException("CustomList must contain records")
            require(fields.isNotEmpty() && fields.keys.all { it is String }) {
                "CustomList records must have string keys"
            }
            val builder = ListCustomAttributeItem.builder()
            fields.forEach { (key, item) ->
                val name = key as String
                when (item) {
                    null -> builder.putString(name, null)
                    is String -> builder.putString(name, item)
                    is Number -> builder.putNumber(name, item)
                    is Boolean -> builder.putBoolean(name, item)
                    is Map<*, *> -> builder.putDateTime(name, CustomAttributeValue.DateTime(taggedDate(item)))
                    else -> throw IllegalArgumentException("CustomList fields must be scalar values")
                }
            }
            builder.build()
        }
        // Huawei lists use one record schema. Reject incompatible records before SDK mutation.
        val schema = records.firstOrNull()?.map?.keys
        require(records.all { it.map.keys == schema }) { "CustomList records must have the same fields" }
        val types = mutableMapOf<String, Class<*>>()
        records.forEach { record -> record.map.forEach { (key, item) ->
            if (item != null) {
                val type = if (item is Number) Number::class.java else item.javaClass
                require(types.putIfAbsent(key, type)?.let { it == type } != false) {
                    "CustomList fields must have consistent types"
                }
            }
        } }
        val holder = User()
        holder.setListCustomAttribute("value", ListCustomAttributeValue(records))
        return holder.getCustomAttributeValue("value")
    }

    private fun taggedDate(value: Map<*, *>): Date {
        if (value.size != 2 ||
            value[ChannelContract.CUSTOM_VALUE_TYPE] != ChannelContract.CUSTOM_DATE_TYPE ||
            value[ChannelContract.CUSTOM_VALUE] !is String
        ) {
            throw IllegalArgumentException("customAttributes contains a malformed date value")
        }
        return try {
            Date.from(Instant.parse(value[ChannelContract.CUSTOM_VALUE] as String))
        } catch (_: Exception) {
            throw IllegalArgumentException("customAttributes contains a malformed date value")
        }
    }

    internal fun channelValue(value: Any?): Any? =
        when (value) {
            null, is String, is Boolean, is Number -> {
                value
            }

            is CustomAttributeValue -> {
                when (value.type) {
                    CustomAttributeValue.Type.String -> value.stringValue()
                    CustomAttributeValue.Type.Number -> value.numberValue()
                    CustomAttributeValue.Type.Date -> CustomAttributesMapper.customValueToBackend(value)
                    CustomAttributeValue.Type.DateTime -> taggedChannelDate(value.dateTimeValue().date)
                    CustomAttributeValue.Type.Boolean -> value.booleanValue()
                    CustomAttributeValue.Type.CustomList -> channelValue(CustomAttributesMapper.customValueToBackend(value))
                }
            }

            is Date -> {
                mapOf(
                    ChannelContract.CUSTOM_VALUE_TYPE to ChannelContract.CUSTOM_DATE_TYPE,
                    ChannelContract.CUSTOM_VALUE to value.toInstant().toString(),
                )
            }

            is List<*> -> {
                value.map(::channelValue)
            }

            is Set<*> -> {
                value.map(::channelValue)
            }

            is Map<*, *> -> {
                value.entries.associate { (key, item) ->
                    (key as? String ?: throw IllegalArgumentException("Unsupported native user payload")) to
                        channelValue(item)
                }
            }

            else -> {
                throw IllegalArgumentException("Unsupported native user payload")
            }
        }

    private fun taggedChannelDate(value: Date): Map<String, String> =
        mapOf(
            ChannelContract.CUSTOM_VALUE_TYPE to ChannelContract.CUSTOM_DATE_TYPE,
            ChannelContract.CUSTOM_VALUE to value.toInstant().toString(),
        )
}
