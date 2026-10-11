package com.infobip.mobilemessaging.huawei.rtc

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import com.infobip.webrtc.sdk.api.model.video.VideoRenderer
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class HuaweiRtcVideoPlatformViewFactory(private val manager: HuaweiRtcManager) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        HuaweiRtcVideoPlatformView(context.applicationContext, manager, HuaweiRtcVideoOptions.decode(args))

    companion object { const val VIEW_TYPE = "infobip_mobilemessaging_huawei/rtc_video" }
}

/** A fresh renderer per authorized view; released views stay inert until Flutter recreates them. */
internal class HuaweiRtcVideoPlatformView(
    context: Context,
    manager: HuaweiRtcManager,
    private val options: HuaweiRtcVideoOptions?,
    private val rendererFactory: (Context) -> VideoRenderer = { VideoRenderer(it) },
) : PlatformView, HuaweiRtcVideoViewOwner {
    private val container = FrameLayout(context.applicationContext)
    private val placeholder = TextView(context.applicationContext).apply {
        text = "Video unavailable"
        gravity = android.view.Gravity.CENTER
        setTextColor(android.graphics.Color.WHITE)
    }
    private var renderer: VideoRenderer? = null
    private var binding: HuaweiRtcVideoBindings.Binding? = null
    private var released = false

    init {
        container.setBackgroundColor(android.graphics.Color.BLACK)
        container.addView(placeholder, FrameLayout.LayoutParams(-1, -1))
        if (options != null) {
            HuaweiRtcVideoBindings.rendering("view binding") {
                binding = manager.bindVideo(this, options)
            }
        }
    }

    override fun getView(): View = container

    override fun initializeRenderer(mirror: Boolean): VideoRenderer {
        check(!released && renderer == null)
        val created = rendererFactory(container.context)
        renderer = created // preserve partially initialized renderer for cleanup
        created.init()
        created.setMirror(mirror)
        created.setZOrderMediaOverlay(options?.local == true)
        created.visibility = View.INVISIBLE
        container.addView(created, FrameLayout.LayoutParams(-1, -1))
        return created
    }

    override fun showVideo() { renderer?.visibility = View.VISIBLE }

    override fun clearImage() {
        renderer?.visibility = View.INVISIBLE
        renderer?.clearImage()
    }

    override fun releaseRenderer() {
        if (released) return
        released = true
        val old = renderer
        renderer = null
        binding = null
        try {
            if (old != null) HuaweiRtcVideoBindings.rendering("renderer release") { old.release() }
        } finally {
            if (old != null) HuaweiRtcVideoBindings.rendering("renderer removal") { container.removeView(old) }
        }
    }

    override fun dispose() {
        val old = binding
        binding = null
        try { old?.close() } finally { releaseRenderer() }
    }
}
