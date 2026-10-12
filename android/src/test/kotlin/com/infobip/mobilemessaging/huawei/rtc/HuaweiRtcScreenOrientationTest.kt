package com.infobip.mobilemessaging.huawei.rtc

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import com.infobip.webrtc.sdk.videofilter.VideoFilterManager
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.objectweb.asm.ClassReader
import org.objectweb.asm.Opcodes
import org.objectweb.asm.tree.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class HuaweiRtcScreenOrientationTest {
    private fun sdkMethod(type: String, method: String): MethodNode {
        val node = ClassNode()
        javaClass.classLoader!!.getResourceAsStream("$type.class")!!.use {
            ClassReader(it).accept(node, 0)
        }
        return node.methods.single { it.name == method }
    }

    @Test fun `installed converter retains zero rotation horizontal inversion contract`() {
        // Inspect shipped bytecode, without invoking implementation or private SDK APIs.
        // Fail if an SDK update invalidates the compensation's documented assumptions.
        val converter = sdkMethod("com/infobip/webrtc/sdk/videofilter/util/BitmapToVideoFrameConverter", "convert")
        val rotate = converter.instructions.toArray().filterIsInstance<MethodInsnNode>()
            .single { it.owner == "android/graphics/Matrix" && it.name == "postRotate" &&
                (it.previous.previous.previous as? LdcInsnNode)?.cst == 180f }
        assertEquals(0.5f, (rotate.previous as LdcInsnNode).cst)
        assertEquals(0.5f, (rotate.previous.previous as LdcInsnNode).cst)
        val executable = converter.instructions.toArray().filter { it.opcode >= 0 }
        val branch = executable[executable.indexOf(rotate) - 5] as JumpInsnNode
        assertEquals(Opcodes.IFNE, branch.opcode) // 180 degrees only when rotation == 0
        val rotationLoad = executable[executable.indexOf(branch) - 1] as VarInsnNode
        assertEquals(2, rotationLoad.`var`)
        assertEquals(Opcodes.ILOAD, rotationLoad.opcode)

        val yuv = sdkMethod("org/webrtc/YuvConverter", "convertInternal")
        val scale = yuv.instructions.toArray().filterIsInstance<MethodInsnNode>()
            .single { it.owner == "android/graphics/Matrix" && it.name == "preScale" }
        assertEquals(-1f, (scale.previous as LdcInsnNode).cst)
        assertEquals(Opcodes.FCONST_1, scale.previous.previous.opcode)
    }

    @Test fun `portrait screen corners retain natural order after SDK conversion`() = screenCorners(8, 12)
    @Test fun `landscape screen corners retain natural order after SDK conversion`() = screenCorners(12, 8)

    private fun screenCorners(w: Int, h: Int) {
        val source = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        for (y in 0 until h) for (x in 0 until w) {
            source.setPixel(x, y, if (y < h / 2) {
                if (x < w / 2) Color.RED else Color.GREEN
            } else if (x < w / 2) Color.BLUE else Color.YELLOW)
        }
        val camera = Bitmap.createBitmap(16, 16, Bitmap.Config.ARGB_8888)
        val filter = HuaweiRtcScreenVideoFilter({}, {}, {})
        var submitted: Bitmap? = null
        val output = mock(VideoFilterManager::class.java)
        doAnswer {
            submitted = it.arguments[0] as Bitmap
            assertEquals(0, it.arguments[1])
            null
        }.`when`(output).notifyFrameProcessed(any(Bitmap::class.java), anyInt(), anyLong())
        filter.start(16, 16, 30, RuntimeEnvironment.getApplication(), output)
        filter.offer(source, filter.begin())
        // Camera sensor/device rotation must not alter display-oriented replacement.
        for (rotation in listOf(0, 90, 180, 270)) {
            filter.applyFilter(camera, rotation, 1234L)
            val frame = requireNotNull(submitted)
            assertEquals(16, frame.width); assertEquals(16, frame.height)
            // CPU model of the bytecode-guarded texture sampling transform. This
            // verifies composition, not GLES execution, encoding or portal rendering.
            val sampling = Matrix().apply {
                postRotate(180f, .5f, .5f)
                preConcat(Matrix().apply {
                    preTranslate(.5f, .5f); preScale(1f, -1f); preTranslate(-.5f, -.5f)
                })
            }
            for (y in listOf(5, 10)) for (x in listOf(5, 10)) {
                val point = floatArrayOf((x + .5f) / 16, (y + .5f) / 16)
                sampling.mapPoints(point)
                val actual = frame.getPixel((point[0] * 16).toInt(), (point[1] * 16).toInt())
                val expected = if (y < 8) {
                    if (x < 8) Color.RED else Color.GREEN
                } else if (x < 8) Color.BLUE else Color.YELLOW
                assertEquals("rotation=$rotation corner=$x,$y", expected, actual)
            }
            // Letterboxing stays black, including after compensation.
            assertEquals(Color.BLACK, frame.getPixel(if (w < h) 0 else 8, if (w < h) 8 else 0))
            frame.recycle() // mocked manager only; production output stays GC-owned
        }
        filter.block(); camera.recycle()
    }

    @Test fun `camera bitmap rotation and timestamp pass through before and after sharing`() {
        val output = mock(VideoFilterManager::class.java)
        val filter = HuaweiRtcScreenVideoFilter({}, {}, {})
        filter.start(16, 16, 30, RuntimeEnvironment.getApplication(), output)
        val camera = Bitmap.createBitmap(16, 16, Bitmap.Config.ARGB_8888)
        filter.applyFilter(camera, 270, 11)
        filter.begin(); filter.block()
        filter.applyFilter(camera, 90, 22)
        verify(output).notifyFrameProcessed(same(camera), eq(270), eq(11L))
        verify(output).notifyFrameProcessed(same(camera), eq(90), eq(22L))
        assertFalse(camera.isRecycled)
        camera.recycle()
    }
}
