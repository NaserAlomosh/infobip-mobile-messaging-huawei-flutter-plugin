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

internal class WebRtcOperations(
    private val context: Context?,
    private val isInitialized: () -> Boolean,
    private val configuration: () -> WebRtcConfiguration?,
    private val runtime: WebRtcRuntime = ReflectiveWebRtcRuntime(),
) {
    private var rtcUi: Any? = null

    fun enableCalls(identity: String, complete: (WebRtcFailure?) -> Unit) =
        enable(complete) { configurationId, success, error ->
            runtime.enableCalls(context, configurationId, identity, success, error)
        }

    fun enableChatCalls(complete: (WebRtcFailure?) -> Unit) =
        enable(complete) { configurationId, success, error ->
            runtime.enableChatCalls(context, configurationId, success, error)
        }

    fun disableCalls(complete: (WebRtcFailure?) -> Unit) {
        val current = rtcUi
            ?: return complete(WebRtcFailure("webrtc_not_enabled", "Enable WebRTC calls first"))
        reflect(complete) { success, error -> runtime.disableCalls(current, success, error) }
    }

    fun reset() {
        rtcUi = null
    }

    private fun enable(
        complete: (WebRtcFailure?) -> Unit,
        operation: (String, () -> Unit, (String) -> Unit) -> Any,
    ) {
        if (!isInitialized()) {
            complete(WebRtcFailure("not_initialized", "Initialize the Infobip SDK first"))
            return
        }
        val configurationId = configuration()?.configurationId
        if (configurationId.isNullOrBlank()) {
            complete(
                WebRtcFailure(
                    "webrtc_not_configured",
                    "WebRTC configurationId is required before enabling calls",
                ),
            )
            return
        }
        reflect(complete) { success, error ->
            rtcUi = operation(configurationId, success, error)
        }
    }

    private fun reflect(
        complete: (WebRtcFailure?) -> Unit,
        operation: (() -> Unit, (String) -> Unit) -> Unit,
    ) {
        val completed = AtomicBoolean(false)
        val finish: (WebRtcFailure?) -> Unit = { failure ->
            if (completed.compareAndSet(false, true)) complete(failure)
        }
        try {
            operation(
                { finish(null) },
                { message -> finish(WebRtcFailure("webrtc_error", message)) },
            )
        } catch (_: ClassNotFoundException) {
            finish(
                WebRtcFailure(
                    "webrtc_unavailable",
                    "The Infobip RTC UI dependency is not available",
                ),
            )
        } catch (error: ReflectiveOperationException) {
            finish(
                WebRtcFailure(
                    "webrtc_error",
                    error.cause?.message ?: error.message ?: "WebRTC operation failed",
                ),
            )
        } catch (error: RuntimeException) {
            finish(WebRtcFailure("webrtc_error", error.message ?: "WebRTC operation failed"))
        }
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
            val push = listenTypeClass.enumConstants.first { (it as Enum<*>).name == "PUSH" }
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
        invoke(rtcUi, "disableCalls", listeners.first, listeners.second)
    }

    private fun build(context: Context?, configurationId: String, enable: (Any) -> Any?): Any {
        val builderClass = loadClass(BUILDER_CLASS)
        val builder = builderClass.getConstructor(Context::class.java).newInstance(context)
        invoke(builder, "withConfigurationId", configurationId)
        val finalStep = requireNotNull(enable(builder)) {
            "InfobipRtcUi.Builder did not return a final step"
        }
        return requireNotNull(invoke(finalStep, "build")) { "InfobipRtcUi was not created" }
    }

    private fun listeners(success: () -> Unit, error: (String) -> Unit): Pair<Any, Any> =
        listener(SUCCESS_LISTENER_CLASS, "onSuccess") { success() } to
            listener(ERROR_LISTENER_CLASS, "onError") { arguments ->
                error(arguments.firstOrNull()?.toString() ?: "WebRTC operation failed")
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
        const val BUILDER_CLASS = "com.infobip.webrtc.ui.InfobipRtcUi\$Builder"
        const val SUCCESS_LISTENER_CLASS = "com.infobip.webrtc.ui.SuccessListener"
        const val ERROR_LISTENER_CLASS = "com.infobip.webrtc.ui.ErrorListener"
        const val LISTEN_TYPE_CLASS = "com.infobip.webrtc.ui.model.ListenType"
    }
}
