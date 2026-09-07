package com.infobip.mobilemessaging.huawei.webrtc

import android.content.Context
import java.lang.reflect.InvocationHandler
import java.lang.reflect.Proxy

internal data class WebRtcFailure(
    val code: String,
    val message: String,
    val details: Any? = null,
)

internal class WebRtcOperations(
    private val context: Context,
    private val isInitialized: () -> Boolean,
    private val configuration: () -> WebRtcConfiguration?,
) {
    private var rtcUi: Any? = null

    fun enableCalls(
        identity: String,
        complete: (WebRtcFailure?) -> Unit,
    ) = enable(complete) { finalStep, success, error ->
        if (identity.isNotBlank()) {
            val listenTypeClass = loadClass(LISTEN_TYPE_CLASS)
            val push = listenTypeClass.enumConstants.first { (it as Enum<*>).name == "PUSH" }
            invoke(finalStep, "withCalls", identity, push, success, error)
        } else {
            invoke(finalStep, "withCalls", success, error)
        }
    }

    fun enableChatCalls(complete: (WebRtcFailure?) -> Unit) =
        enable(complete) { finalStep, success, error ->
            invoke(finalStep, "withInAppChatCalls", success, error)
        }

    fun disableCalls(complete: (WebRtcFailure?) -> Unit) {
        val current = rtcUi
            ?: return complete(WebRtcFailure("webrtc_not_enabled", "Enable WebRTC calls first"))
        reflect(complete) { success, error ->
            loadClass(RTC_UI_CLASS)
            invoke(current, "disableCalls", success, error)
        }
    }

    fun reset() {
        rtcUi = null
    }

    private fun enable(
        complete: (WebRtcFailure?) -> Unit,
        operation: (Any, Any, Any) -> Any?,
    ) {
        if (!isInitialized()) {
            complete(WebRtcFailure("not_initialized", "Initialize the Infobip SDK first"))
            return
        }
        val webRtcConfiguration = configuration()
        if (webRtcConfiguration == null) {
            complete(
                WebRtcFailure(
                    "webrtc_not_configured",
                    "Initialize the Infobip SDK with WebRTCUI configuration first",
                ),
            )
            return
        }
        reflect(complete) { success, error ->
            val builderClass = loadClass(BUILDER_CLASS)
            loadClass(BUILDER_FINAL_STEP_CLASS)
            val builder = builderClass.getConstructor(Context::class.java).newInstance(context)
            val finalStep = invoke(
                builder,
                "withConfigurationId",
                webRtcConfiguration.configurationId,
            ) ?: error("InfobipRtcUi.Builder did not return a final step")
            rtcUi = operation(finalStep, success, error)
                ?: error("InfobipRtcUi was not created")
        }
    }

    private fun reflect(
        complete: (WebRtcFailure?) -> Unit,
        operation: (Any, Any) -> Unit,
    ) {
        try {
            val success = listener(SUCCESS_LISTENER_CLASS) { complete(null) }
            val error = listener(ERROR_LISTENER_CLASS) { arguments ->
                complete(
                    WebRtcFailure(
                        "webrtc_error",
                        arguments.firstOrNull()?.toString() ?: "WebRTC operation failed",
                    ),
                )
            }
            operation(success, error)
        } catch (_: ClassNotFoundException) {
            complete(
                WebRtcFailure(
                    "webrtc_unavailable",
                    "The Infobip RTC UI dependency is not available",
                ),
            )
        } catch (error: ReflectiveOperationException) {
            complete(
                WebRtcFailure(
                    "webrtc_error",
                    error.cause?.message ?: error.message ?: "WebRTC operation failed",
                ),
            )
        } catch (error: RuntimeException) {
            complete(
                WebRtcFailure(
                    "webrtc_error",
                    error.message ?: "WebRTC operation failed",
                ),
            )
        }
    }

    private fun listener(
        className: String,
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
                    else -> {
                        callback(arguments ?: emptyArray())
                        null
                    }
                }
            },
        )
    }

    private fun invoke(
        receiver: Any,
        name: String,
        vararg arguments: Any?,
    ): Any? {
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
        const val BUILDER_CLASS = "com.infobip.webrtc.ui.InfobipRtcUi\$Builder"
        const val BUILDER_FINAL_STEP_CLASS =
            "com.infobip.webrtc.ui.InfobipRtcUi\$BuilderFinalStep"
        const val SUCCESS_LISTENER_CLASS = "com.infobip.webrtc.ui.SuccessListener"
        const val ERROR_LISTENER_CLASS = "com.infobip.webrtc.ui.ErrorListener"
        const val LISTEN_TYPE_CLASS = "com.infobip.webrtc.ui.model.ListenType"
    }
}
