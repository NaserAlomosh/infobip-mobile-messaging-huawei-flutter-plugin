package com.infobip.mobilemessaging.huawei.core

import android.app.Application
import android.content.Context
import android.util.Log
import com.infobip.mobilemessaging.huawei.R
import com.infobip.mobilemessaging.huawei.webrtc.WebRtcConfiguration
import com.infobip.mobilemessaging.huawei.webrtc.WebRtcConfigurationState
import org.infobip.mobile.messaging.MobileMessaging
import org.infobip.mobile.messaging.NotificationSettings
import org.infobip.mobile.messaging.mobileapi.InternalSdkError
import org.infobip.mobile.messaging.storage.SQLiteMessageStore

internal class MobileMessagingInitializer(
    context: Context,
    afterInitialization: () -> Unit = {},
) {
    private val application = context.applicationContext as Application
    private val webRtcState = WebRtcConfigurationState()

    private val coordinator =
        InitializationCoordinator(
            start = { applicationCode, defaultMessageStorage, webRtcConfiguration, complete ->
                try {
                    Log.d(
                        TAG,
                        "Starting Infobip initialization. applicationCode length=${applicationCode.length}",
                    )

                    val notificationSettings =
                        NotificationSettings
                            .Builder(application)
                            .withMultipleNotifications()
                            .withDefaultIcon(R.drawable.ic_notification)
                            .build()

                    val builder = MobileMessaging
                        .Builder(application)
                        .withApplicationCode(applicationCode)
                        .withFullFeaturedInApps()
                        .withDisplayNotification(notificationSettings)

                    if (defaultMessageStorage) {
                        builder.withMessageStore(SQLiteMessageStore::class.java)
                    }

                    builder.build(
                        object : MobileMessaging.InitListener {
                            override fun onSuccess() {
                                Log.d(CHAT_TAG, "MobileMessaging initialization completed")
                                complete(null)
                            }

                            override fun onError(
                                error: InternalSdkError,
                                errorCode: Int?,
                            ) {
                                Log.e(
                                    TAG,
                                    "Infobip initialization failed. error=$error, errorCode=$errorCode",
                                )

                                complete(
                                    InitializationError(
                                        "initialization_failed",
                                        "Infobip SDK initialization failed: $error",
                                    ),
                                )
                            }
                        },
                    )
                } catch (e: Exception) {
                    Log.e(
                        TAG,
                        "Exception while initializing Infobip SDK",
                        e,
                    )

                    complete(
                        InitializationError(
                            "native_error",
                            "Unable to initialize the Infobip SDK: ${e.message}",
                        ),
                    )
                }
            },
            afterSuccess = { webRtcConfiguration ->
                webRtcState.capture(webRtcConfiguration)
                afterInitialization()
            },
        )

    fun initialize(
        applicationCode: String,
        defaultMessageStorage: Boolean,
        webRtcConfiguration: WebRtcConfiguration?,
        callback: (InitializationError?) -> Unit,
    ) {
        if (applicationCode.isBlank()) {
            callback(
                InitializationError(
                    "invalid_argument",
                    "applicationCode must not be empty",
                ),
            )
            return
        }

        coordinator.initialize(
            applicationCode,
            defaultMessageStorage,
            webRtcConfiguration,
            callback,
        )
    }

    val isInitialized: Boolean
        get() = coordinator.isInitialized

    val webRtcConfiguration: WebRtcConfiguration?
        get() = webRtcState.current

    fun reset() {
        coordinator.reset()
        webRtcState.clear()
    }

    fun registerForRemoteNotifications(callback: (InitializationError?) -> Unit) {
        if (!isInitialized) {
            callback(
                InitializationError(
                    "not_initialized",
                    "Initialize the Infobip SDK first",
                ),
            )
            return
        }
        try {
            MobileMessaging.getInstance(application).registerForRemoteNotifications()
            callback(null)
        } catch (e: Exception) {
            Log.e(TAG, "Unable to register for remote notifications", e)
            callback(
                InitializationError(
                    "registration_failed",
                    e.message ?: "Unable to register for remote notifications",
                ),
            )
        }
    }

    private companion object {
        const val TAG = "InfobipHuawei"
        const val CHAT_TAG = "InfobipHuaweiChat"
    }
}
