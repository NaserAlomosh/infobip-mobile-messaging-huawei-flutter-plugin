package com.infobip.mobilemessaging.huawei.chat

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentContainerView
import androidx.core.view.doOnLayout
import com.infobip.mobilemessaging.huawei.plugin.ChannelContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import org.infobip.mobile.messaging.chat.core.widget.LivechatWidgetResult
import org.infobip.mobile.messaging.chat.core.widget.LivechatWidgetView
import org.infobip.mobile.messaging.api.chat.WidgetInfo
import org.infobip.mobile.messaging.chat.view.DefaultInAppChatFragmentEventsListener
import org.infobip.mobile.messaging.chat.view.InAppChatFragment

internal class ChatPlatformView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    activity: Activity?,
    private val chatManager: ChatManager,
    private val options: ChatViewOptions,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, ChannelContract.CHAT_VIEW_CHANNEL + viewId)
    private val pendingError = PendingChatViewError()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val runtimeEvents = ChatRuntimeEventBridge { event ->
        mainHandler.post {
            if (!disposed) channel.invokeMethod(ChannelContract.CHAT_ON_RUNTIME_EVENT, event)
        }
    }
    private var fragmentActivity: FragmentActivity? = activity as? FragmentActivity
    private var fragment: InAppChatFragment? = null
    private var currentWidgetView: LivechatWidgetView? = null
    private var disposed = false
    private var flutterReady = false
    private val root: View

    init {
        Log.d(TAG, "ChatPlatformView creation started")
        val failure = chatManager.attach()
        root = when {
            failure != null -> neutralView(context, ChatViewError(failure.code, failure.message))
            activity == null -> neutralView(context, ChatViewError("activity_unavailable"))
            activity !is FragmentActivity -> {
                Log.e(TAG, "Activity does not extend FragmentActivity")
                neutralView(
                    context,
                    ChatViewError(
                        "activity_fragment_unavailable",
                        "Chat requires an AndroidX FragmentActivity",
                    ),
                )
            }
            else -> createFragmentContainer(activity)
        }
        channel.setMethodCallHandler(this)
        Log.d(TAG, "ChatPlatformView ready")
    }

    private fun createFragmentContainer(activity: FragmentActivity): FragmentContainerView =
        FragmentContainerView(activity).apply {
            id = View.generateViewId()
            layoutParams = matchParentLayoutParams()
            doOnLayout { attachFragment(this) }
        }

    private fun attachFragment(container: FragmentContainerView) {
        if (disposed || fragment != null || !container.isAttachedToWindow) return
        val activity = fragmentActivity ?: return
        val manager = activity.supportFragmentManager
        if (activity.isFinishing || activity.isDestroyed || manager.isStateSaved) {
            reportError(ChatViewError("native_error", "Chat fragment could not be attached"))
            return
        }
        try {
            Log.d(TAG, "InAppChatFragment creation started")
            val created = InAppChatFragment().apply {
                errorsHandler = chatManager.exceptionBridge
                withInput = options.withInput
                withToolbar = options.withToolbar
                eventsListener = object : DefaultInAppChatFragmentEventsListener() {
                    override fun onChatViewChanged(view: LivechatWidgetView) {
                        if (!disposed && fragment === this@apply) {
                            currentWidgetView = view
                            publishRuntimeEvent(ChannelContract.CHAT_VIEW_CHANGED, view.name)
                        }
                    }
                    override fun onChatLoadingFinished(result: LivechatWidgetResult<Unit>) {
                        publishRuntimeEvent(
                            ChannelContract.CHAT_LOADED,
                            result.isSuccess,
                        )
                        if (!result.isSuccess) {
                            reportError(ChatViewError("chat_runtime_error", "Chat loading failed"))
                        }
                    }
                    override fun onChatConnectionResumed(result: LivechatWidgetResult<Unit>) {
                        publishRuntimeResult(
                            result,
                            ChannelContract.CHAT_CONNECTION_CHANGED,
                            value = "CONNECTED",
                            failureMessage = "Chat connection could not be resumed",
                        )
                    }
                    override fun onChatConnectionPaused(result: LivechatWidgetResult<Unit>) {
                        publishRuntimeResult(
                            result,
                            ChannelContract.CHAT_CONNECTION_CHANGED,
                            value = "DISCONNECTED",
                            failureMessage = "Chat connection could not be paused",
                        )
                    }
                    override fun onChatAttachmentPreviewOpened(
                        url: String?,
                        type: String?,
                        caption: String?,
                    ): Boolean {
                        publishRuntimeEvent(
                            ChannelContract.CHAT_ATTACHMENT_PREVIEW_OPENED,
                            ChatRuntimeEventMapper.attachment(url, type, caption),
                        )
                        return false
                    }
                    override fun onExitChatPressed() {
                        publishRuntimeEvent(ChannelContract.CHAT_EXIT_PRESSED)
                    }
                    override fun onChatWidgetThemeChanged(result: LivechatWidgetResult<String?>) {
                        result.getOrNull()?.let {
                            publishRuntimeEvent(ChannelContract.CHAT_WIDGET_THEME_CHANGED, it)
                        }
                    }
                    override fun onChatWidgetInfoUpdated(widgetInfo: WidgetInfo) {
                        publishRuntimeEvent(
                            ChannelContract.CHAT_WIDGET_INFO_UPDATED,
                            ChatRuntimeEventMapper.widgetInfo(widgetInfo),
                        )
                    }
                    override fun onChatRawMessageReceived(rawMessage: String) {
                        publishRuntimeEvent(ChannelContract.CHAT_RAW_MESSAGE_RECEIVED, rawMessage)
                    }
                }
            }
            currentWidgetView = null
            fragment = created
            manager.beginTransaction()
                .replace(container.id, created, fragmentTag(container.id))
                .runOnCommit {
                    if (!disposed && fragment === created) {
                        Log.d(TAG, "InAppChatFragment attached")
                    }
                }
                .commit()
        } catch (error: RuntimeException) {
            fragment = null
            Log.e(TAG, "Native Chat error while attaching InAppChatFragment", error)
            reportError(ChatViewError("native_error", "Chat fragment could not be attached"))
        }
    }

    override fun getView(): View = root

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == ChannelContract.CHAT_VIEW_READY) {
            flutterReady = true
            runtimeEvents.ready()
            pendingError.take()?.let { channel.invokeMethod(ChannelContract.CHAT_ON_ERROR, it.toMap()) }
            result.success(null)
            return
        }
        val current = fragment
        if (current == null || disposed || !current.isAdded) {
            result.error("chat_unavailable", "Chat view is unavailable", null)
            return
        }
        when (call.method) {
            ChannelContract.CHAT_NAVIGATE_BACK -> handleNavigateBack(current, result)
            ChannelContract.CHAT_SHOW_THREADS_LIST -> runCommand(current, result) {
                current.showThreadList()
            }
            ChannelContract.CHAT_IS_MULTITHREAD -> runQuery(current, result) {
                current.isMultiThread
            }
            ChannelContract.CHAT_SEND -> handleSend(call, result, current)
            ChannelContract.CHAT_SET_DRAFT_MESSAGE -> handleDraftMessage(call, result)
            ChannelContract.CHAT_SEND_CONTEXTUAL_DATA -> handleContextualData(call, result, current)
            ChannelContract.CHAT_SET_LANGUAGE -> handleLanguage(call, result, current)
            ChannelContract.CHAT_GET_LANGUAGE -> runQuery(current, result) {
                ChatLanguageMapper.toWidgetCode(current.getLanguage())
            }
            ChannelContract.CHAT_SET_WIDGET_THEME -> handleStringArgument(call, result, current) {
                current.setWidgetTheme(it)
            }
            ChannelContract.CHAT_GET_WIDGET_THEME -> runQuery(current, result) {
                current.getWidgetTheme()
            }
            else -> result.notImplemented()
        }
    }

    private fun handleNavigateBack(current: InAppChatFragment, result: MethodChannel.Result) {
        Log.d(TAG, "Chat back navigation requested")
        runQuery(current, result) {
            val handled = ChatBackNavigation.isHandledInternally(current.isMultiThread, currentWidgetView)
            if (handled) {
                current.showThreadList()
                Log.d(TAG, "Chat back handled internally")
            } else {
                Log.d(TAG, "Chat back delegated to Flutter")
            }
            handled
        }
    }

    private fun handleLanguage(call: MethodCall, result: MethodChannel.Result, current: InAppChatFragment) {
        val code = (call.arguments as? Map<*, *>)?.get(ChannelContract.LANGUAGE) as? String
        val language = code?.takeIf { it.isNotBlank() }?.let(ChatLanguageMapper::fromWidgetCode)
        if (language == null) {
            result.error("invalid_argument", "Unsupported Chat language", null)
            return
        }
        runCommand(current, result) { current.setLanguage(language) }
    }

    private fun handleStringArgument(
        call: MethodCall,
        result: MethodChannel.Result,
        current: InAppChatFragment,
        operation: (String) -> Unit,
    ) {
        val value = (call.arguments as? Map<*, *>)?.get(ChannelContract.WIDGET_THEME) as? String
        if (value.isNullOrBlank()) {
            result.error("invalid_argument", "widgetTheme must not be empty", null)
            return
        }
        runCommand(current, result) { operation(value) }
    }

    private fun handleSend(call: MethodCall, result: MethodChannel.Result, current: InAppChatFragment) {
        val payload = try {
            ChatMapper.messagePayload(call.arguments)
        } catch (error: IllegalArgumentException) {
            result.error("invalid_argument", error.message, null)
            return
        }
        runCommand(current, result) { current.send(payload) }
    }

    private fun handleDraftMessage(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            ChatMapper.draftMessage(call.arguments)
        } catch (error: IllegalArgumentException) {
            result.error("invalid_argument", error.message, null)
            return
        }
        result.error("not_available", "Composer draft messages are not available in Huawei SDK 8.14.0", null)
    }

    private fun handleContextualData(call: MethodCall, result: MethodChannel.Result, current: InAppChatFragment) {
        val (data, strategy) = try {
            ChatMapper.contextualData(call.arguments) to ChatMapper.contextualDataStrategy(call.arguments)
        } catch (error: IllegalArgumentException) {
            result.error("invalid_argument", error.message, null)
            return
        }
        runCommand(current, result) {
            current.sendContextualData(
                data,
                strategy,
            )
        }
    }

    private fun runCommand(
        current: InAppChatFragment,
        result: MethodChannel.Result,
        operation: () -> Unit,
    ) = runQuery(current, result) {
        operation()
        null
    }

    private fun runQuery(
        current: InAppChatFragment,
        result: MethodChannel.Result,
        operation: () -> Any?,
    ) {
        root.post {
            if (disposed || fragment !== current || !current.isAdded) {
                result.error("chat_unavailable", "Chat view is unavailable", null)
                return@post
            }
            try {
                result.success(operation())
            } catch (error: RuntimeException) {
                Log.e(TAG, "Native Chat operation failed")
                result.error("native_error", "Chat operation failed", null)
            }
        }
    }

    override fun dispose() {
        if (disposed) return
        disposed = true
        runtimeEvents.dispose()
        mainHandler.removeCallbacksAndMessages(null)
        channel.setMethodCallHandler(null)
        val current = fragment
        fragment = null
        currentWidgetView = null
        val manager = fragmentActivity?.supportFragmentManager
        fragmentActivity = null
        if (current != null && manager != null && current.isAdded && !manager.isDestroyed) {
            try {
                val transaction = manager.beginTransaction().remove(current)
                if (manager.isStateSaved) transaction.commitAllowingStateLoss() else transaction.commit()
                Log.d(TAG, "InAppChatFragment removed")
            } catch (error: RuntimeException) {
                Log.w(TAG, "InAppChatFragment could not be removed", error)
            }
        }
        Log.d(TAG, "ChatPlatformView disposed")
    }

    private fun reportError(error: ChatViewError) {
        if (flutterReady) channel.invokeMethod(ChannelContract.CHAT_ON_ERROR, error.toMap()) else pendingError.set(error)
    }

    private fun publishRuntimeEvent(event: String, value: Any? = null) {
        runtimeEvents.publish(ChatRuntimeEventMapper.event(event, value))
    }

    private fun publishRuntimeResult(
        result: LivechatWidgetResult<Unit>,
        event: String,
        value: String? = null,
        failureMessage: String,
    ) {
        val payload = mutableMapOf(ChannelContract.EVENT to event)
        value?.let { payload[ChannelContract.VALUE] = it }
        runtimeEvents.publishResult(result is LivechatWidgetResult.Success, payload) {
            reportError(ChatViewError("chat_runtime_error", failureMessage))
        }
    }

    private fun neutralView(context: Context, error: ChatViewError): View {
        reportError(error)
        return FrameLayout(context).apply { layoutParams = matchParentLayoutParams() }
    }

    private fun matchParentLayoutParams() = FrameLayout.LayoutParams(
        FrameLayout.LayoutParams.MATCH_PARENT,
        FrameLayout.LayoutParams.MATCH_PARENT,
    )

    private fun fragmentTag(containerId: Int) = "infobip_huawei_chat_$containerId"

    private companion object {
        const val TAG = "InfobipHuaweiChat"
    }
}
