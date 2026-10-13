package com.infobip.mobilemessaging.huawei.rtc

import android.graphics.Bitmap
import android.graphics.Color
import com.infobip.webrtc.sdk.videofilter.VideoFilterManager
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.objectweb.asm.ClassReader
import org.objectweb.asm.tree.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class HuaweiRtcScreenVideoQualityTest {
    private val frames = mutableListOf<Bitmap>()
    private val manager = mock(VideoFilterManager::class.java)
    private val filter = HuaweiRtcScreenVideoFilter({}, {}, {})
    private val camera = Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888)
    init {
        doAnswer { frames.add(it.arguments[0] as Bitmap); null }.`when`(manager)
            .notifyFrameProcessed(any(Bitmap::class.java), anyInt(), anyLong())
    }

    // Undo the installed, separately bytecode-guarded SDK horizontal conversion.
    // This models remote sampling; it does not execute GLES or Portal rendering.
    private fun pixel(frame: Bitmap, x: Int, y: Int) = frame.getPixel(frame.width - 1 - x, y)
    private fun marked(w: Int, h: Int): Bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).apply {
        eraseColor(Color.WHITE)
        for (y in 0 until h) for (x in 0 until w) {
            val left = x < w / 3; val right = x >= w * 2 / 3
            val top = y < h / 3; val bottom = y >= h * 2 / 3
            if ((left || right) && (top || bottom)) setPixel(x, y,
                if (top) { if (left) Color.RED else Color.GREEN }
                else { if (left) Color.BLUE else Color.YELLOW })
        }
    }

    @Test fun `portrait full screen preserves proportions and all four corners in 640 by 480`() = geometry(90, 210)
    @Test fun `landscape full screen preserves proportions and all four corners in 640 by 480`() = geometry(210, 90)
    @Test fun `matching aspect ratio uses full output without cropping`() = geometry(80, 60)
    @Test fun `odd capture dimensions preserve fractional fit geometry`() = geometry(97, 213)

    private fun geometry(w: Int, h: Int) {
        filter.start(640, 480, 30, RuntimeEnvironment.getApplication(), manager)
        val epoch = filter.begin()
        filter.offer(marked(w, h), epoch)
        repeat(3) { filter.applyFilter(camera, it * 90, it.toLong()) }
        val scale = minOf(640f / w, 480f / h)
        val width = w * scale; val height = h * scale
        val left = (640 - width) / 2; val top = (480 - height) / 2
        for (frame in frames) {
            assertEquals(640, frame.width); assertEquals(480, frame.height)
            for ((xf, yf, color) in listOf(Triple(.15f, .15f, Color.RED), Triple(.85f, .15f, Color.GREEN),
                Triple(.15f, .85f, Color.BLUE), Triple(.85f, .85f, Color.YELLOW))) {
                assertEquals(color, pixel(frame, (left + width * xf).toInt(), (top + height * yf).toInt()))
            }
            // The actual non-black span at the midlines detects crop, stretch and fit regressions.
            val xs = (0 until 640).filter { pixel(frame, it, 240) != Color.BLACK }
            val ys = (0 until 480).filter { pixel(frame, 320, it) != Color.BLACK }
            assertEquals(width.toDouble(), xs.size.toDouble(), 2.0)
            assertEquals(height.toDouble(), ys.size.toDouble(), 2.0)
            assertEquals(left.toDouble(), xs.first().toDouble(), 1.0)
            assertEquals(top.toDouble(), ys.first().toDouble(), 1.0)
        }
        // Repeated callbacks neither alter geometry nor mutate a previous SDK-owned output.
        assertNotSame(frames[0], frames[1])
        assertTrue(frames[0].sameAs(frames[1]))
        filter.block()
        assertFalse(frames[0].isRecycled)
        assertTrue(frames[0].sameAs(frames[2]))
        camera.recycle()
    }

    @Test fun `asymmetric text-like pattern has no vertical flip rotation crop or stretch at one to one scale`() {
        val source = Bitmap.createBitmap(17, 11, Bitmap.Config.ARGB_8888).apply {
            eraseColor(Color.WHITE)
            // Unequal L and bar strokes at unequal positions expose orientation errors.
            for (y in 1..8) setPixel(2, y, Color.BLACK)
            for (x in 2..6) setPixel(x, 8, Color.BLACK)
            for (y in 2..5) setPixel(12, y, Color.BLUE)
            setPixel(16, 0, Color.RED); setPixel(0, 10, Color.GREEN)
        }
        val expected = IntArray(17 * 11)
        source.getPixels(expected, 0, 17, 0, 0, 17, 11)
        filter.start(17, 11, 30, RuntimeEnvironment.getApplication(), manager)
        filter.offer(source, filter.begin())
        for (rotation in listOf(0, 90, 180, 270)) {
            filter.applyFilter(camera, rotation, rotation.toLong())
            val result = frames.last()
            for (y in 0 until 11) for (x in 0 until 17) assertEquals(expected[y * 17 + x], pixel(result, x, y))
        }
        filter.block(); camera.recycle()
    }

    @Test fun `downsampling uses filtered coverage instead of nearest neighbor aliasing`() {
        val source = Bitmap.createBitmap(8, 8, Bitmap.Config.ARGB_8888)
        for (y in 0 until 8) for (x in 0 until 8) source.setPixel(x, y, if (x % 2 == 0) Color.BLACK else Color.WHITE)
        filter.start(4, 4, 30, RuntimeEnvironment.getApplication(), manager)
        filter.offer(source, filter.begin()); filter.applyFilter(camera, 0, 1)
        val result = frames.single()
        for (y in 0 until 4) for (x in 0 until 4) {
            val color = pixel(result, x, y)
            assertTrue(Color.red(color) in 120..136)
            assertEquals(Color.red(color), Color.green(color)); assertEquals(Color.red(color), Color.blue(color))
            assertEquals(255, Color.alpha(color))
        }
        filter.block(); camera.recycle()
    }

    @Test fun `installed filtered camera initialization uses fixed SD dimensions`() {
        val node = ClassNode()
        javaClass.classLoader!!.getResourceAsStream("com/infobip/webrtc/sdk/impl/call/handler/CameraVideoMediaHandler.class")!!.use {
            ClassReader(it).accept(node, 0)
        }
        val method = node.methods.single { it.name == "startCameraCapture" }
        val code = method.instructions.toArray().filter { it.opcode >= 0 }
        val start = code.filterIsInstance<MethodInsnNode>().single {
            it.owner == "com/infobip/webrtc/sdk/videofilter/DefaultVideoFilterManager" && it.name == "start"
        }
        val index = code.indexOf(start)
        // Assert argument prefix receiver/640/480/fps, before context/handler/observer/listener.
        val dimensions = code.take(index).windowed(3).filter {
            (it[0] as? IntInsnNode)?.operand == 640 && (it[1] as? IntInsnNode)?.operand == 480 && it[2] is VarInsnNode
        }
        assertEquals(1, dimensions.size)
        val capture = code.filterIsInstance<MethodInsnNode>().single { it.name == "startCapture" }
        val captureIndex = code.indexOf(capture)
        assertEquals(640, (code[captureIndex - 3] as IntInsnNode).operand)
        assertEquals(480, (code[captureIndex - 2] as IntInsnNode).operand)
    }
}
