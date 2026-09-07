package com.infobip.mobilemessaging.huawei

import android.app.Activity
import android.content.Context
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.infobip.mobilemessaging.huawei.chat.ChatManager
import com.infobip.mobilemessaging.huawei.chat.ChatPlatformViewFactory
import com.infobip.mobilemessaging.huawei.core.CleanupManager
import com.infobip.mobilemessaging.huawei.core.MobileMessagingInitializer
import com.infobip.mobilemessaging.huawei.core.MessageOperations
import com.infobip.mobilemessaging.huawei.event.CustomEventManager
import com.infobip.mobilemessaging.huawei.inbox.InboxManager
import com.infobip.mobilemessaging.huawei.installation.InstallationManager
import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import com.infobip.mobilemessaging.huawei.plugin.NativeEventBridge
import com.infobip.mobilemessaging.huawei.user.UserManager
import com.infobip.mobilemessaging.huawei.webrtc.WebRtcConfiguration
import com.infobip.mobilemessaging.huawei.webrtc.WebRtcFailure
import com.infobip.mobilemessaging.huawei.webrtc.WebRtcOperations
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.infobip.mobile.messaging.chat.view.styles.PluginChatCustomization

class InfobipMobileMessagingHuaweiPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware {
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var initializer: MobileMessagingInitializer? = null
    private var cleanupManager: CleanupManager? = null
    private var applicationContext: Context? = null
    private var eventBridge: NativeEventBridge? = null
    private var userManager: UserManager? = null
    private var installationManager: InstallationManager? = null
    private var customEventManager: CustomEventManager? = null
    private var messageOperations: MessageOperations? = null
    private var inboxManager: InboxManager? = null
    private var chatManager: ChatManager? = null
    private var webRtcOperations: WebRtcOperations? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var activity: Activity? = null
    private var drawableLoader: PluginChatCustomization.DrawableLoader? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        drawableLoader = FlutterAssetDrawableLoader(binding)
        chatManager =
            ChatManager(
                context = binding.applicationContext,
                initialized = { initializer?.isInitialized == true },
                requestDartJwt = { id, generation -> eventBridge?.emitChatJwtRequested(id, generation) == true },
            )
        initializer =
            MobileMessagingInitializer(binding.applicationContext) {
                chatManager?.activate()
            }
        webRtcOperations =
            WebRtcOperations(
                context = binding.applicationContext,
                isInitialized = { initializer?.isInitialized == true },
                configuration = { initializer?.webRtcConfiguration },
            )
        userManager =
            UserManager(
                context = binding.applicationContext,
                isInitialized = { initializer?.isInitialized == true },
            )
        installationManager =
            InstallationManager(
                context = binding.applicationContext,
                isInitialized = { initializer?.isInitialized == true },
            )
        customEventManager =
            CustomEventManager(
                context = binding.applicationContext,
                isInitialized = { initializer?.isInitialized == true },
            )
        messageOperations =
            MessageOperations(
                context = binding.applicationContext,
                isInitialized = { initializer?.isInitialized == true },
            )
        inboxManager =
            InboxManager(
                context = binding.applicationContext,
                isInitialized = { initializer?.isInitialized == true },
            )
        cleanupManager =
            CleanupManager(
                context = binding.applicationContext,
                isInitialized = { initializer?.isInitialized == true },
                clearPluginJwtState = {
                    eventBridge?.clearPendingTaps()
                    inboxManager?.clearJwtState()
                    chatManager?.clearJwtProvider()
                    chatManager?.clearExceptionHandler()
                },
                resetPluginState = {
                    webRtcOperations?.reset()
                    initializer?.reset()
                    chatManager?.resetAfterCleanup()
                },
            )
        eventBridge = NativeEventBridge(binding.applicationContext).also { it.register() }
        methodChannel =
            MethodChannel(binding.binaryMessenger, ChannelContract.METHOD_CHANNEL).also {
                it.setMethodCallHandler(this)
            }
        eventChannel =
            EventChannel(binding.binaryMessenger, ChannelContract.EVENT_CHANNEL).also {
                it.setStreamHandler(this)
            }
        binding.platformViewRegistry.registerViewFactory(
            ChannelContract.CHAT_VIEW,
            ChatPlatformViewFactory(
                messenger = binding.binaryMessenger,
                activityProvider = { activity },
                chatManager = requireNotNull(chatManager),
            ),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        inboxManager?.setJwt(null)
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        eventBridge?.detach()
        chatManager?.detach()
        methodChannel = null
        eventChannel = null
        initializer = null
        cleanupManager = null
        eventBridge = null
        userManager = null
        installationManager = null
        customEventManager = null
        messageOperations = null
        inboxManager = null
        chatManager = null
        webRtcOperations?.reset()
        webRtcOperations = null
        applicationContext = null
        drawableLoader = null
        activity = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            ChannelContract.INITIALIZE -> {
                initialize(call, result)
            }

            ChannelContract.CLEANUP -> {
                val manager = cleanupManager ?: return detached(result)
                val error = manager.cleanup()
                if (error == null) result.success(null)
                else result.error(error.code, error.message, error.details)
            }

            ChannelContract.ENABLE_CALLS -> {
                val identity = call.arguments as? String
                if (identity == null) {
                    result.error("invalid_argument", "identity must be a string", null)
                    return
                }
                webRtcOperations?.enableCalls(identity) { failure ->
                    completeWebRtc(result, failure)
                } ?: detached(result)
            }

            ChannelContract.ENABLE_CHAT_CALLS -> {
                webRtcOperations?.enableChatCalls { failure ->
                    completeWebRtc(result, failure)
                } ?: detached(result)
            }

            ChannelContract.DISABLE_CALLS -> {
                webRtcOperations?.disableCalls { failure ->
                    completeWebRtc(result, failure)
                } ?: detached(result)
            }

            ChannelContract.REGISTER_FOR_REMOTE_NOTIFICATIONS -> {
                initializer?.registerForRemoteNotifications { error ->
                    mainHandler.post {
                        if (error == null) result.success(null)
                        else result.error(error.code, error.message, error.details)
                    }
                } ?: detached(result)
            }

            ChannelContract.MARK_MESSAGES_SEEN -> {
                val manager = messageOperations ?: return detached(result)
                val failure = manager.markMessagesSeen(call.arguments)
                if (failure == null) result.success(null)
                else result.error(failure.code, failure.message, null)
            }

            ChannelContract.GET_USER -> {
                userManager?.getUser { value, failure ->
                    result.completeUser(value, failure)
                }
                    ?: detached(result)
            }

            ChannelContract.FETCH_USER -> {
                userManager?.fetchUser { value, failure ->
                    result.completeUser(value, failure)
                }
                    ?: detached(result)
            }

            ChannelContract.SAVE_USER -> {
                userManager?.saveUser(
                    call.argument<Any?>(ChannelContract.USER),
                    { value, failure -> result.completeUser(value, failure) },
                ) ?: detached(result)
            }

            ChannelContract.PERSONALIZE -> {
                personalize(call, result)
            }

            ChannelContract.DEPERSONALIZE -> {
                userManager?.depersonalize { _, failure ->
                    if (failure == null) {
                        inboxManager?.setJwt(null)
                        result.success(null)
                    } else {
                        result.error(failure.code, failure.message, null)
                    }
                } ?: detached(result)
            }

            ChannelContract.SUBMIT_EVENT -> {
                customEventManager?.submit(
                    call.argument<Any?>(ChannelContract.CUSTOM_EVENT),
                ) { _, failure -> result.completeCustomEvent(null, failure) }
                    ?: detached(result)
            }

            ChannelContract.SUBMIT_EVENT_IMMEDIATELY -> {
                customEventManager?.submitImmediately(
                    call.argument<Any?>(ChannelContract.CUSTOM_EVENT),
                ) { event, failure -> result.completeCustomEvent(event, failure) }
                    ?: detached(result)
            }

            ChannelContract.SET_JWT -> {
                try {
                    inboxManager?.setJwt(call.argument<Any?>(ChannelContract.JWT))
                        ?: return detached(result)
                    result.success(null)
                } catch (_: IllegalArgumentException) {
                    result.error("invalid_argument", "jwt must be a string or null", null)
                }
            }

            ChannelContract.SET_CHAT_JWT_PROVIDER -> {
                val manager = chatManager ?: return detached(result)
                val failure = manager.setJwtProvider()
                if (failure == null) result.success(null)
                else result.error(failure.code, failure.message, null)
            }

            ChannelContract.SET_CHAT_EXCEPTION_HANDLER -> {
                val manager = chatManager ?: return detached(result)
                val failure = manager.setExceptionHandler(
                    call.argument<Any?>(ChannelContract.ENABLED),
                ) { payload -> eventBridge?.emitChatException(payload) }
                if (failure == null) result.success(null)
                else result.error(failure.code, failure.message, null)
            }

            ChannelContract.SET_CHAT_CUSTOMIZATION -> {
                setChatCustomization(call, result)
            }

            ChannelContract.SET_CHAT_PUSH_TITLE -> {
                val manager = chatManager ?: return detached(result)
                val failure = manager.setChatPushTitle(call.arguments as String?)
                if (failure == null) result.success(null)
                else result.error(failure.code, failure.message, null)
            }

            ChannelContract.SET_CHAT_PUSH_BODY -> {
                val manager = chatManager ?: return detached(result)
                val failure = manager.setChatPushBody(call.arguments as String?)
                if (failure == null) result.success(null)
                else result.error(failure.code, failure.message, null)
            }

            ChannelContract.SHOW_CHAT -> {
                val manager = chatManager ?: return detached(result)
                val failure = manager.showChat()
                if (failure == null) result.success(null)
                else result.error(failure.code, failure.message, null)
            }

            ChannelContract.RESOLVE_CHAT_JWT -> {
                val manager = chatManager ?: return detached(result)
                val failure = manager.resolveJwt(call.argument<Any?>("requestId"), call.argument<Any?>("generation"), call.argument<Any?>(ChannelContract.JWT))
                if (failure == null) result.success(null)
                else result.error(failure.code, failure.message, null)
            }

            ChannelContract.REJECT_CHAT_JWT -> {
                val manager = chatManager ?: return detached(result)
                val failure = manager.rejectJwt(call.argument<Any?>("requestId"), call.argument<Any?>("generation"))
                if (failure == null) result.success(null)
                else result.error(failure.code, failure.message, null)
            }

            ChannelContract.GET_INSTALLATION -> {
                installationManager?.getInstallation { value, failure ->
                    result.completeInstallation(value, failure)
                }
                    ?: detached(result)
            }

            ChannelContract.FETCH_INSTALLATION -> {
                installationManager?.fetchInstallation { value, failure ->
                    result.completeInstallation(value, failure)
                }
                    ?: detached(result)
            }

            ChannelContract.SAVE_INSTALLATION -> {
                installationManager?.saveInstallation(
                    call.argument<Any?>(ChannelContract.INSTALLATION),
                    { value, failure -> result.completeInstallation(value, failure) },
                ) ?: detached(result)
            }

            ChannelContract.DEPERSONALIZE_INSTALLATION -> {
                installationManager?.depersonalizeInstallation(
                    call.argument<Any?>(ChannelContract.PUSH_REGISTRATION_ID),
                ) { installations, failure -> result.completeInstallations(installations, failure) }
                    ?: detached(result)
            }

            ChannelContract.SET_INSTALLATION_AS_PRIMARY -> {
                installationManager?.setInstallationAsPrimary(
                    call.argument<Any?>(ChannelContract.PUSH_REGISTRATION_ID),
                    call.argument<Any?>(ChannelContract.IS_PRIMARY),
                ) { installations, failure -> result.completeInstallations(installations, failure) }
                    ?: detached(result)
            }

            ChannelContract.FETCH_INBOX -> {
                inboxManager?.fetch(
                    call.argument<Any?>(ChannelContract.EXTERNAL_USER_ID),
                    call.argument<Any?>(ChannelContract.JWT),
                    call.argument<Any?>(ChannelContract.OPTIONS),
                    { value, failure -> result.completeInbox(value, failure) },
                ) ?: detached(result)
            }

            ChannelContract.SET_INBOX_MESSAGES_SEEN -> {
                inboxManager?.setSeen(
                    call.argument<Any?>(ChannelContract.EXTERNAL_USER_ID),
                    call.argument<Any?>(ChannelContract.MESSAGE_IDS),
                    { value, failure -> result.completeInbox(value, failure) },
                ) ?: detached(result)
            }

            ChannelContract.GET_CHAT_UNREAD_MESSAGE_COUNT -> {
                chatManager?.getUnreadMessageCount { count, failure ->
                    mainHandler.post {
                        if (failure == null) {
                            result.success(count)
                        } else {
                            result.error(failure.code, failure.message, null)
                        }
                    }
                } ?: detached(result)
            }

            ChannelContract.IS_CHAT_AVAILABLE -> {
                chatManager?.isChatAvailable { available, failure ->
                    mainHandler.post {
                        if (failure == null) result.success(available)
                        else result.error(failure.code, failure.message, null)
                    }
                } ?: detached(result)
            }

            ChannelContract.RESET_CHAT_MESSAGE_COUNTER -> {
                chatManager?.resetMessageCounter { _, failure ->
                    mainHandler.post {
                        if (failure == null) result.success(null)
                        else result.error(failure.code, failure.message, null)
                    }
                } ?: detached(result)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun personalize(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val force = call.argument<Boolean>(ChannelContract.FORCE_DEPERSONALIZE)
        if (force == null) {
            result.error("invalid_argument", "forceDepersonalize must be a boolean", null)
            return
        }
        userManager?.personalize(
            call.argument<Any?>(ChannelContract.USER_IDENTITY),
            call.argument<Any?>(ChannelContract.USER_ATTRIBUTES),
            force,
            { value, failure -> result.completeUser(value, failure) },
        ) ?: detached(result)
    }

    private fun MethodChannel.Result.completeUser(
        user: Map<String, Any?>?,
        failure: com.infobip.mobilemessaging.huawei.user.UserFailure?,
    ) {
        if (failure == null) {
            success(user)
        } else {
            error(failure.code, failure.message, null)
        }
    }

    private fun MethodChannel.Result.completeInstallation(
        installation: Map<String, Any?>?,
        failure: com.infobip.mobilemessaging.huawei.installation.InstallationFailure?,
    ) {
        if (failure == null) {
            success(installation)
        } else {
            error(failure.code, failure.message, null)
        }
    }

    private fun MethodChannel.Result.completeInstallations(
        installations: List<Map<String, Any?>>?,
        failure: com.infobip.mobilemessaging.huawei.installation.InstallationFailure?,
    ) {
        if (failure == null) success(installations) else error(failure.code, failure.message, failure.details)
    }

    private fun MethodChannel.Result.completeCustomEvent(
        event: Map<String, Any?>?,
        failure: com.infobip.mobilemessaging.huawei.event.CustomEventFailure?,
    ) {
        if (failure == null) success(event) else error(failure.code, failure.message, failure.details)
    }

    private fun MethodChannel.Result.completeInbox(
        inbox: Map<String, Any?>?,
        failure: com.infobip.mobilemessaging.huawei.inbox.InboxFailure?,
    ) {
        if (failure == null) {
            success(inbox)
        } else {
            error(failure.code, failure.message, null)
        }
    }

    private fun detached(result: MethodChannel.Result) {
        result.error("native_error", "Plugin is not attached to an engine", null)
    }

    private fun completeWebRtc(
        result: MethodChannel.Result,
        failure: WebRtcFailure?,
    ) {
        mainHandler.post {
            if (failure == null) result.success(null)
            else result.error(failure.code, failure.message, failure.details)
        }
    }

    private fun setChatCustomization(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val context = applicationContext ?: return detached(result)
        val json = call.arguments as? String
        val customization = json?.let(PluginChatCustomization::parseOrNull)
        if (customization == null) {
            Log.w(TAG, "Ignoring invalid Chat customization")
            result.success(null)
            return
        }
        val loader = drawableLoader ?: return detached(result)
        val theme = customization.createTheme(context, loader)
        org.infobip.mobile.messaging.chat.InAppChat.getInstance(context).setTheme(theme)
        result.success(null)
    }

    private class FlutterAssetDrawableLoader(
        binding: FlutterPlugin.FlutterPluginBinding,
    ) : PluginChatCustomization.DrawableLoader {
        private val flutterAssets = binding.flutterAssets

        override fun loadDrawable(
            context: Context,
            drawableSrc: String?,
        ): Drawable? {
            if (drawableSrc.isNullOrBlank()) return null

            return try {
                val assetKey = flutterAssets.getAssetFilePathByName(drawableSrc)
                context.assets.open(assetKey).use {
                    Drawable.createFromStream(it, drawableSrc)
                }
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun initialize(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val applicationCode = call.argument<String>(ChannelContract.APPLICATION_CODE)
        if (applicationCode.isNullOrBlank()) {
            result.error("invalid_argument", "applicationCode must not be empty", null)
            return
        }
        val defaultMessageStorage =
            call.argument<Boolean>(ChannelContract.DEFAULT_MESSAGE_STORAGE) ?: true
        val webRtcConfiguration = try {
            WebRtcConfiguration.fromMethodChannel(
                call.argument<Any?>(ChannelContract.WEB_RTC_UI),
            )
        } catch (error: IllegalArgumentException) {
            result.error("invalid_argument", error.message, null)
            return
        }

        initializer?.initialize(applicationCode, defaultMessageStorage, webRtcConfiguration) { error ->
            mainHandler.post {
                if (error == null) {
                    result.success(null)
                } else {
                    result.error(error.code, error.message, error.details)
                }
            }
        } ?: result.error("native_error", "Plugin is not attached to an engine", null)
    }

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?,
    ) {
        eventBridge?.listen(events)
    }

    override fun onCancel(arguments: Any?) {
        eventBridge?.cancel()
        chatManager?.detach()
    }

    private companion object {
        const val TAG = "InfobipHuaweiPlugin"
    }
}
