package com.infobip.mobilemessaging.huawei.webrtc

import android.content.Context
import java.lang.reflect.InvocationHandler
import java.lang.reflect.Proxy
import java.util.concurrent.atomic.AtomicBoolean

internal data class WebRtcFailure(
    val code: String,
    val message: String,
    val details: Any? = null,
)

internal interface WebRtcRuntime {
    fun enableCalls(
        context: Context?,
        configurationId: String,
        identity: String,
        success: () -> Unit,
        error: (String) -> Unit,
    ): Any

    fun enableChatCalls(
        context: Context?,
        configurationId: String,
        success: () -> Unit,
        error: (String) -> Unit,
    ): Any

    fun disableCalls(rtcUi: Any, success: () -> Unit, error: (String) -> Unit)
}

/** No supported HMS-only incoming-call integration exists in RTC UI 15.1.0. */
internal class UnsupportedHuaweiWebRtcRuntime : WebRtcRuntime {
    override fun enableCalls(context: Context?, configurationId: String, identity: String,
        success: () -> Unit, error: (String) -> Unit): Any = throw UnsupportedOperationException()
    override fun enableChatCalls(context: Context?, configurationId: String,
        success: () -> Unit, error: (String) -> Unit): Any = throw UnsupportedOperationException()
    override fun disableCalls(rtcUi: Any, success: () -> Unit, error: (String) -> Unit) =
        throw UnsupportedOperationException()
}

internal class WebRtcOperations(
    private val context: Context?,
    private val isInitialized: () -> Boolean,
    private val configuration: () -> WebRtcConfiguration?,
    private val runtime: WebRtcRuntime = UnsupportedHuaweiWebRtcRuntime(),
) {
    private class Session(val key: Pair<String, String>, val complete: (WebRtcFailure?) -> Unit) {
        var instance: Any? = null
        var built = false
        var enableDone = false
        var enableFailure: WebRtcFailure? = null
        var completed = false
        var closing = false
        var disabling = false
        val waiters = mutableListOf<(WebRtcFailure?) -> Unit>()
    }
    private var session: Session? = null

    fun enableCalls(identity: String, complete: (WebRtcFailure?) -> Unit) =
        enable("calls:$identity", complete) { id, success, error ->
            runtime.enableCalls(context, id, identity, success, error)
        }

    fun enableChatCalls(complete: (WebRtcFailure?) -> Unit) =
        enable("chat", complete) { id, success, error ->
            runtime.enableChatCalls(context, id, success, error)
        }

    @Synchronized
    fun disableCalls(complete: (WebRtcFailure?) -> Unit) {
        if (session == null) complete(WebRtcFailure("webrtc_not_enabled", "Enable WebRTC calls first"))
        else close(complete)
    }

    /** Await native unregistration before allowing Mobile Messaging cleanup/account replacement. */
    @Synchronized
    fun cleanup(complete: (WebRtcFailure?) -> Unit) = close(complete)

    /** Engine detach cannot await a Flutter result, but still owns the native teardown callback. */
    fun reset() { cleanup {} }

    @Synchronized
    private fun enable(
        mode: String,
        complete: (WebRtcFailure?) -> Unit,
        operation: (String, () -> Unit, (String) -> Unit) -> Any,
    ) {
        if (!isInitialized()) {
            complete(WebRtcFailure("not_initialized", "Initialize the Infobip SDK first"))
            return
        }
        val id = configuration()?.configurationId
        if (id.isNullOrBlank()) {
            complete(WebRtcFailure("webrtc_not_configured", "WebRTC configurationId is required before enabling calls"))
            return
        }
        session?.let { current ->
            val same = current.key == (mode to id)
            complete(if (same && current.enableDone && current.enableFailure == null && !current.closing) null
                else WebRtcFailure("webrtc_operation_in_progress", "Disable the current calls session before enabling another"))
            return
        }
        val current = Session(mode to id, complete)
        session = current
        try {
            current.instance = operation(id,
                { enabled(current, null) },
                { enabled(current, WebRtcFailure("webrtc_error", "WebRTC operation failed")) })
            current.built = true
            settle(current)
        } catch (error: Exception) {
            current.built = true
            current.enableDone = true
            current.enableFailure = failure(error)
            settle(current)
        } catch (_: LinkageError) {
            current.built = true
            current.enableDone = true
            current.enableFailure = WebRtcFailure("webrtc_unavailable", "The Infobip RTC UI dependency is incompatible")
            settle(current)
        }
    }

    @Synchronized
    private fun enabled(current: Session, failure: WebRtcFailure?) {
        if (session !== current || current.enableDone) return
        current.enableDone = true
        current.enableFailure = failure
        settle(current)
    }

    private fun settle(current: Session) {
        if (session !== current || !current.built || !current.enableDone) return
        if (current.instance == null) session = null
        if (!current.completed) {
            current.completed = true
            current.complete(current.enableFailure)
        }
        if (current.closing) unregister(current)
    }

    private fun close(complete: (WebRtcFailure?) -> Unit) {
        val current = session ?: return complete(null)
        current.closing = true
        current.waiters += complete
        if (!current.completed) {
            current.completed = true
            current.complete(WebRtcFailure("webrtc_cancelled", "WebRTC enable was cancelled by teardown"))
        }
        // The public SDK has no cancellation operation. A delayed enable must finish before disable.
        if (current.built && current.enableDone) unregister(current)
    }

    private fun unregister(current: Session) {
        if (current.disabling) return
        val instance = current.instance
        if (instance == null) {
            finishClose(current, null)
            return
        }
        current.disabling = true
        val once = AtomicBoolean(false)
        val finish: (WebRtcFailure?) -> Unit = { result ->
            if (once.compareAndSet(false, true)) finishClose(current, result)
        }
        try {
            runtime.disableCalls(instance, { finish(null) },
                { finish(WebRtcFailure("webrtc_error", "Unable to disable WebRTC calls")) })
        } catch (error: Exception) { finish(failure(error)) }
        catch (_: LinkageError) { finish(WebRtcFailure("webrtc_unavailable", "The Infobip RTC UI dependency is incompatible")) }
    }

    @Synchronized
    private fun finishClose(current: Session, failure: WebRtcFailure?) {
        current.disabling = false
        if (failure == null && session === current) session = null
        // On failure retain the actual instance so a caller can retry unregistration.
        val waiters = current.waiters.toList()
        current.waiters.clear()
        waiters.forEach { it(failure) }
    }

    private fun failure(error: Exception): WebRtcFailure = when (error) {
        is UnsupportedOperationException -> WebRtcFailure("webrtc_unsupported",
            "RTC UI 15.1.0 has no supported Huawei-only integration")
        is ClassNotFoundException -> WebRtcFailure("webrtc_unavailable", "The Infobip RTC UI dependency is not available")
        else -> WebRtcFailure("webrtc_error", "WebRTC operation failed")
    }
}

internal class ReflectiveWebRtcRuntime : WebRtcRuntime {
    override fun enableCalls(
        context: Context?,
        configurationId: String,
        identity: String,
        success: () -> Unit,
        error: (String) -> Unit,
    ): Any = build(context, configurationId) { builder ->
        val listeners = listeners(success, error)
        if (identity.isNotBlank()) {
            val listenTypeClass = loadClass(LISTEN_TYPE_CLASS)
            val push = requireNotNull(listenTypeClass.enumConstants).first { (it as Enum<*>).name == "PUSH" }
            invoke(builder, "withCalls", identity, push, listeners.first, listeners.second)
        } else {
            invoke(builder, "withCalls", listeners.first, listeners.second)
        }
    }

    override fun enableChatCalls(
        context: Context?,
        configurationId: String,
        success: () -> Unit,
        error: (String) -> Unit,
    ): Any = build(context, configurationId) { builder ->
        val listeners = listeners(success, error)
        invoke(builder, "withInAppChatCalls", listeners.first, listeners.second)
    }

    override fun disableCalls(rtcUi: Any, success: () -> Unit, error: (String) -> Unit) {
        val listeners = listeners(success, error)
        loadClass(RTC_UI_CLASS).getMethod("disableCalls",
            loadClass(SUCCESS_LISTENER_CLASS), loadClass(ERROR_LISTENER_CLASS))
            .invoke(rtcUi, listeners.first, listeners.second)
    }

    private fun build(context: Context?, configurationId: String, enable: (Any) -> Any?): Any {
        val builderClass = loadClass(BUILDER_CLASS)
        val builder = builderClass.getConstructor(Context::class.java).newInstance(context)
        invoke(builder, "withConfigurationId", configurationId)
        val finalStep = requireNotNull(enable(builder)) {
            "InfobipRtcUi.Builder did not return a final step"
        }
        return requireNotNull(loadClass(FINAL_STEP_CLASS).getMethod("build").invoke(finalStep)) { "InfobipRtcUi was not created" }
    }

    private fun listeners(success: () -> Unit, error: (String) -> Unit): Pair<Any, Any> =
        listener(SUCCESS_LISTENER_CLASS, "onSuccess") { success() } to
            listener(ERROR_LISTENER_CLASS, "onError") { _ ->
                error("WebRTC operation failed")
            }

    private fun listener(
        className: String,
        callbackName: String,
        callback: (Array<out Any?>) -> Unit,
    ): Any {
        val listenerClass = loadClass(className)
        return Proxy.newProxyInstance(
            listenerClass.classLoader,
            arrayOf(listenerClass),
            InvocationHandler { proxy, method, arguments ->
                when (method.name) {
                    "toString" -> className
                    "hashCode" -> System.identityHashCode(proxy)
                    "equals" -> proxy === arguments?.firstOrNull()
                    callbackName -> {
                        callback(arguments ?: emptyArray())
                        null
                    }
                    else -> null
                }
            },
        )
    }

    private fun invoke(receiver: Any, name: String, vararg arguments: Any?): Any? {
        val method = receiver.javaClass.methods.firstOrNull {
            it.name == name && it.parameterTypes.size == arguments.size &&
                it.parameterTypes.indices.all { index -> accepts(it.parameterTypes[index], arguments[index]) }
        } ?: throw NoSuchMethodException("${receiver.javaClass.name}.$name")
        return method.invoke(receiver, *arguments)
    }

    private fun accepts(type: Class<*>, value: Any?): Boolean =
        value == null && !type.isPrimitive || value != null && type.isAssignableFrom(value.javaClass)

    private fun loadClass(name: String): Class<*> = Class.forName(name)

    private companion object {
        const val RTC_UI_CLASS = "com.infobip.webrtc.ui.InfobipRtcUi"
        const val FINAL_STEP_CLASS = "com.infobip.webrtc.ui.InfobipRtcUi\$BuilderFinalStep"
        const val BUILDER_CLASS = "com.infobip.webrtc.ui.InfobipRtcUi\$Builder"
        const val SUCCESS_LISTENER_CLASS = "com.infobip.webrtc.ui.SuccessListener"
        const val ERROR_LISTENER_CLASS = "com.infobip.webrtc.ui.ErrorListener"
        const val LISTEN_TYPE_CLASS = "com.infobip.webrtc.ui.model.ListenType"
    }
}
