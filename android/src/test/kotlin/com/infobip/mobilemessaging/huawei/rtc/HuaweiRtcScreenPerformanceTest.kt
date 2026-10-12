package com.infobip.mobilemessaging.huawei.rtc

import android.graphics.Bitmap
import android.graphics.Color
import android.media.Image
import android.media.ImageReader
import com.infobip.webrtc.sdk.videofilter.VideoFilterManager
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class HuaweiRtcScreenPerformanceTest {
    private val submitted = mutableListOf<Bitmap>()
    private var firstFrames = 0
    private val output = mock(VideoFilterManager::class.java)
    private val filter = HuaweiRtcScreenVideoFilter({}, { firstFrames++ }, {})
    private val camera = Bitmap.createBitmap(4, 4, Bitmap.Config.ARGB_8888)
    init {
        doAnswer { submitted.add(it.arguments[0] as Bitmap); null }.`when`(output)
            .notifyFrameProcessed(any(Bitmap::class.java), anyInt(), anyLong())
        filter.start(4, 4, 30, RuntimeEnvironment.getApplication(), output)
    }
    private fun image(color: Int, paddedWidth: Int = 2): Image {
        val pixels = Bitmap.createBitmap(paddedWidth, 2, Bitmap.Config.ARGB_8888)
        pixels.eraseColor(color)
        val buffer = ByteBuffer.allocateDirect(paddedWidth * 2 * 4)
        pixels.copyPixelsToBuffer(buffer); pixels.recycle()
        val plane = mock(Image.Plane::class.java)
        `when`(plane.pixelStride).thenReturn(4)
        `when`(plane.rowStride).thenReturn(paddedWidth * 4)
        `when`(plane.buffer).thenReturn(buffer)
        return mock(Image::class.java).also { `when`(it.planes).thenReturn(arrayOf(plane)) }
    }
    private fun reader(vararg frames: Image): ImageReader = mock(ImageReader::class.java).also {
        `when`(it.acquireLatestImage()).thenReturn(frames.first(), *frames.drop(1).toTypedArray())
    }
    // Inspect only plugin-owned storage to prove identity/release; never reflect into SDK.
    private fun scratch(processor: HuaweiRtcScreenFrameProcessor): Bitmap? =
        HuaweiRtcScreenFrameProcessor::class.java.getDeclaredField("scratch").let {
            it.isAccessible = true; it.get(processor) as Bitmap?
        }
    private fun latest(): Bitmap? = HuaweiRtcScreenVideoFilter::class.java.getDeclaredField("latest").let {
        it.isAccessible = true; it.get(filter) as Bitmap?
    }

    @Test fun `first frame and stable scratch reuse preserve independent snapshots with and without padding`() {
        for (padding in listOf(2, 4)) {
            val processor = HuaweiRtcScreenFrameProcessor(2, 2)
            val epoch = filter.begin()
            val red = image(Color.RED, padding); val green = image(Color.GREEN, padding)
            val source = reader(red, green)
            processor.drain(source, filter, epoch)
            val storage = requireNotNull(scratch(processor))
            val retained = requireNotNull(latest())
            assertNotSame(storage, retained)
            filter.applyFilter(camera, 90, 1)
            val first = submitted.last()
            assertEquals(Color.RED, first.getPixel(2, 2))
            processor.drain(source, filter, epoch)
            assertSame(storage, scratch(processor))
            assertTrue(retained.isRecycled)
            assertFalse(storage.isRecycled)
            assertFalse(first.isRecycled)
            assertEquals(Color.RED, first.getPixel(2, 2))
            filter.applyFilter(camera, 270, 2)
            assertNotSame(first, submitted.last())
            assertEquals(Color.GREEN, submitted.last().getPixel(2, 2))
            processor.release(); processor.release()
            assertTrue(storage.isRecycled)
            assertNull(scratch(processor))
            assertFalse(requireNotNull(latest()).isRecycled)
            filter.block()
            assertFalse(first.isRecycled)
            verify(red).close(); verify(green).close()
        }
        assertEquals(2, firstFrames)
    }

    @Test fun `blocked and old generations drain images without reading planes or allocating scratch`() {
        val processor = HuaweiRtcScreenFrameProcessor(2, 2)
        val epoch = filter.begin(); filter.block()
        val stopped = mock(Image::class.java)
        processor.drain(reader(stopped), filter, epoch)
        val next = filter.begin()
        val stale = mock(Image::class.java)
        processor.drain(reader(stale), filter, epoch)
        verify(stopped).close(); verify(stale).close()
        verify(stopped, never()).planes; verify(stale, never()).planes
        assertNull(scratch(processor)); assertNull(latest())
        assertTrue(filter.accepts(next)); assertFalse(filter.accepts(epoch))
        filter.block()
    }

    @Test fun `stop racing conversion closes image and rejects completed snapshot`() {
        val processor = HuaweiRtcScreenFrameProcessor(2, 2)
        val epoch = filter.begin()
        val frame = image(Color.RED)
        val planes = frame.planes
        `when`(frame.planes).thenAnswer { filter.block(); planes }
        processor.drain(reader(frame), filter, epoch)
        assertNull(latest())
        assertFalse(requireNotNull(scratch(processor)).isRecycled)
        verify(frame).close()
        processor.release()
    }

    @Test fun `stride change replaces scratch and failed conversion still closes image`() {
        val processor = HuaweiRtcScreenFrameProcessor(2, 2)
        val epoch = filter.begin()
        processor.drain(reader(image(Color.RED, 2)), filter, epoch)
        val old = requireNotNull(scratch(processor))
        processor.drain(reader(image(Color.GREEN, 4)), filter, epoch)
        assertTrue(old.isRecycled); assertNotSame(old, scratch(processor))
        val broken = mock(Image::class.java)
        `when`(broken.planes).thenThrow(IllegalStateException("fixture"))
        try { processor.drain(reader(broken), filter, epoch); fail() } catch (_: IllegalStateException) { }
        verify(broken).close()
        processor.release(); filter.block()
    }

    @Test fun `latest only replacement adds no queue and submitted outputs survive stop`() {
        val processor = HuaweiRtcScreenFrameProcessor(2, 2)
        val epoch = filter.begin()
        val source = reader(image(Color.RED), image(Color.GREEN), image(Color.BLUE))
        processor.drain(source, filter, epoch)
        val first = requireNotNull(latest())
        processor.drain(source, filter, epoch)
        val second = requireNotNull(latest())
        processor.drain(source, filter, epoch)
        assertTrue(first.isRecycled); assertTrue(second.isRecycled)
        assertTrue(submitted.isEmpty())
        filter.applyFilter(camera, 0, 3)
        assertEquals(Color.BLUE, submitted.single().getPixel(2, 2))
        verify(source, times(3)).acquireLatestImage()
        verify(source, never()).acquireNextImage()
        filter.block(); processor.release()
        assertFalse(submitted.single().isRecycled)
    }

    @Test fun `empty reader has no conversion and repeated generations deliver first frames`() {
        val processor = HuaweiRtcScreenFrameProcessor(2, 2)
        val empty = mock(ImageReader::class.java)
        repeat(10) {
            val epoch = filter.begin()
            processor.drain(empty, filter, epoch)
            assertNull(latest())
            processor.drain(reader(image(Color.RED)), filter, epoch)
            filter.applyFilter(camera, 0, it.toLong())
            filter.block(); processor.release()
        }
        assertEquals(10, firstFrames)
        assertTrue(submitted.all { !it.isRecycled })
    }

    @Test fun `capture replacement and filter drawing serialize bitmap ownership across threads`() {
        val epoch = filter.begin()
        val ready = CountDownLatch(2); val start = CountDownLatch(1)
        val workers = Executors.newFixedThreadPool(2)
        try {
            val capture = workers.submit {
                val processor = HuaweiRtcScreenFrameProcessor(2, 2)
                ready.countDown(); start.await()
                try { repeat(100) { processor.drain(reader(image(Color.RED)), filter, epoch) } }
                finally { processor.release() }
            }
            val render = workers.submit {
                ready.countDown(); start.await()
                repeat(100) { filter.applyFilter(camera, 0, it.toLong()) }
            }
            assertTrue(ready.await(10, TimeUnit.SECONDS)); start.countDown()
            capture.get(30, TimeUnit.SECONDS); render.get(30, TimeUnit.SECONDS)
            filter.block()
            assertEquals(100, submitted.size)
            assertTrue(submitted.all { !it.isRecycled })
        } finally { start.countDown(); workers.shutdownNow() }
    }

    @Test fun `cached geometry follows replacement shape and output dimensions`() {
        val epoch = filter.begin()
        val portrait = Bitmap.createBitmap(2, 4, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.RED) }
        filter.offer(portrait, epoch); filter.applyFilter(camera, 0, 1)
        assertEquals(Color.BLACK, submitted.last().getPixel(0, 2))
        val landscape = Bitmap.createBitmap(4, 2, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.GREEN) }
        filter.offer(landscape, epoch); filter.applyFilter(camera, 0, 2)
        assertEquals(Color.BLACK, submitted.last().getPixel(2, 0))
        filter.start(8, 2, 30, RuntimeEnvironment.getApplication(), output)
        filter.applyFilter(camera, 0, 3)
        assertEquals(8, submitted.last().width)
        assertEquals(Color.BLACK, submitted.last().getPixel(0, 1))
        filter.block()
    }
}
