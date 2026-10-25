package com.infobip.mobilemessaging.huawei.rtc

import android.app.NotificationManager
import android.content.pm.ApplicationInfo
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentCaptor
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class IncomingRingtoneTest {
    private val app = RuntimeEnvironment.getApplication()
    private val audio = mock(AudioManager::class.java)
    private val policy = app.getSystemService(NotificationManager::class.java)
    private val uri = Uri.parse("content://private/ringtone")
    private val sound = mock(MediaPlayer::class.java)
    private lateinit var prepared: MediaPlayer.OnPreparedListener
    private lateinit var error: MediaPlayer.OnErrorListener
    private fun device(type: Int) = mock(AudioDeviceInfo::class.java).also { `when`(it.type).thenReturn(type) }
    private val speaker = device(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
    private val earpiece = device(AudioDeviceInfo.TYPE_BUILTIN_EARPIECE)
    @Before fun setup() {
        policy.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
        `when`(audio.ringerMode).thenReturn(AudioManager.RINGER_MODE_NORMAL)
        `when`(audio.getStreamVolume(AudioManager.STREAM_RING)).thenReturn(4)
        `when`(audio.mode).thenReturn(AudioManager.MODE_IN_COMMUNICATION)
        `when`(audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)).thenReturn(arrayOf(speaker, earpiece))
        if (android.os.Build.VERSION.SDK_INT >= 28) `when`(sound.setPreferredDevice(any())).thenReturn(true)
        doAnswer { prepared = it.getArgument(0); null }.`when`(sound).setOnPreparedListener(any())
        doAnswer { error = it.getArgument(0); null }.`when`(sound).setOnErrorListener(any())
    }
    private fun controller() = AndroidIncomingRingtone(app, { uri }, { sound }, audio)
    @Test fun `speaker selection is player scoped and attributes stay ringtone specific`() {
        val controller = controller(); controller.start()
        val attrs = ArgumentCaptor.forClass(AudioAttributes::class.java)
        verify(sound).setAudioAttributes(attrs.capture())
        assertEquals(AudioAttributes.USAGE_NOTIFICATION_RINGTONE, attrs.value.usage)
        verify(sound).setPreferredDevice(speaker); verify(sound).setDataSource(app, uri)
        verify(sound).setLooping(true); verify(sound, never()).start()
        prepared.onPrepared(sound); verify(sound).start(); controller.stop(); verify(sound).release()
        verify(audio, never()).setMode(anyInt()); verify(audio, never()).setSpeakerphoneOn(anyBoolean())
        verify(audio, never()).setMicrophoneMute(anyBoolean()); verify(audio, never()).setStreamVolume(anyInt(), anyInt(), anyInt())
    }
    @Test fun `unavailable or rejected speaker uses default routing`() {
        `when`(audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)).thenReturn(arrayOf(earpiece))
        val first = controller(); first.start(); prepared.onPrepared(sound)
        verify(sound, never()).setPreferredDevice(any()); first.stop(); clearInvocations(sound)
        `when`(audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)).thenReturn(arrayOf(speaker))
        `when`(sound.setPreferredDevice(speaker)).thenReturn(false)
        val next = controller(); next.start(); prepared.onPrepared(sound); verify(sound).start(); next.stop()
        verify(audio, never()).setMode(anyInt()); verify(audio, never()).setSpeakerphoneOn(anyBoolean())
    }
    @Test fun `connected Bluetooth wired and USB outputs are never overridden`() {
        for (type in listOf(AudioDeviceInfo.TYPE_BLUETOOTH_SCO, AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_USB_HEADSET)) {
            val external = device(type)
            `when`(audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)).thenReturn(arrayOf(speaker, external))
            val c = controller(); c.start(); prepared.onPrepared(sound); c.stop()
        }
        verify(sound, never()).setPreferredDevice(any())
    }
    @Test fun `headset attached while preparing clears only the player preference`() {
        val c = controller(); c.start()
        val headset = device(AudioDeviceInfo.TYPE_WIRED_HEADSET)
        `when`(audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)).thenReturn(arrayOf(speaker, headset))
        prepared.onPrepared(sound); verify(sound).setPreferredDevice(null); verify(sound).start()
        c.update(); verify(sound, times(1)).setPreferredDevice(null); c.stop()
    }
    @Test fun `failed preference clearing releases and prevents late start`() {
        val c = controller(); c.start()
        `when`(audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)).thenReturn(emptyArray())
        `when`(sound.setPreferredDevice(null)).thenReturn(false)
        prepared.onPrepared(sound); verify(sound).release(); verify(sound, never()).start()
    }
    @Test fun `stop during preparation is immediate idempotent and blocks late callback`() {
        val c = controller(); c.start(); c.start(); c.stop(); c.stop(); prepared.onPrepared(sound); c.update()
        verify(sound, never()).start(); verify(sound, times(1)).release()
    }
    @Test fun `new invitations use separate players and stale callbacks cannot stop the next`() {
        val next = mock(MediaPlayer::class.java); `when`(next.setPreferredDevice(any())).thenReturn(true)
        val queue = ArrayDeque(listOf(sound, next))
        val c = AndroidIncomingRingtone(app, { uri }, { queue.removeFirst() }, audio)
        c.start(); val oldPrepared = prepared; val oldError = error
        prepared.onPrepared(sound); c.stop(); c.start()
        oldPrepared.onPrepared(sound); oldError.onError(sound, 1, 1)
        verify(sound, times(1)).start(); verify(next, never()).release(); c.stop(); verify(next).release()
    }
    @Test fun `silent vibrate zero volume and DND suppress player allocation`() {
        for (mode in listOf(AudioManager.RINGER_MODE_SILENT, AudioManager.RINGER_MODE_VIBRATE)) {
            `when`(audio.ringerMode).thenReturn(mode); controller().start()
        }
        `when`(audio.ringerMode).thenReturn(AudioManager.RINGER_MODE_NORMAL)
        `when`(audio.getStreamVolume(AudioManager.STREAM_RING)).thenReturn(0); controller().start()
        `when`(audio.getStreamVolume(AudioManager.STREAM_RING)).thenReturn(4)
        for (filter in listOf(NotificationManager.INTERRUPTION_FILTER_NONE, NotificationManager.INTERRUPTION_FILTER_PRIORITY,
            NotificationManager.INTERRUPTION_FILTER_ALARMS)) { policy.setInterruptionFilter(filter); controller().start() }
        verifyNoInteractions(sound)
    }
    @Test fun `silent default and setup failure are contained`() {
        AndroidIncomingRingtone(app, { null }, { sound }, audio).start(); verifyNoInteractions(sound)
        doThrow(SecurityException("private uri")).`when`(sound).setDataSource(app, uri)
        controller().start(); verify(sound).release()
    }
    @Test fun `async errors and DND changes release resources`() {
        val c = controller(); c.start(); error.onError(sound, 1, 1); verify(sound).release()
        c.start(); prepared.onPrepared(sound); policy.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
        c.update(); verify(sound, times(2)).release()
    }
    @Test fun `release failure prevents overlap and can retry cleanup`() {
        val c = controller(); c.start(); doThrow(IllegalStateException()).doNothing().`when`(sound).release()
        c.stop(); c.start(); verify(sound, times(1)).prepareAsync()
        c.update(); c.start(); verify(sound, times(2)).prepareAsync(); c.stop()
    }
    @Test @Config(sdk = [26]) fun `API 26 keeps default output and supports native looping`() {
        app.applicationInfo.flags = app.applicationInfo.flags or ApplicationInfo.FLAG_DEBUGGABLE
        val c = controller(); c.start(); prepared.onPrepared(sound); c.update()
        verify(sound).setLooping(true); verify(sound, times(1)).start(); c.stop()
        verify(audio, never()).setMode(anyInt()); verify(audio, never()).setSpeakerphoneOn(anyBoolean())
    }
    @Test @Config(sdk = [31]) fun `API 31 only reads communication device and logs sanitized numeric data`() {
        app.applicationInfo.flags = app.applicationInfo.flags or ApplicationInfo.FLAG_DEBUGGABLE
        val c = controller(); c.start(); prepared.onPrepared(sound); c.update(); c.stop()
        verify(audio, never()).setCommunicationDevice(any()); verify(audio, never()).clearCommunicationDevice()
        val logs = org.robolectric.shadows.ShadowLog.getLogsForTag("HuaweiRtcRingtone").joinToString { it.msg }
        assertTrue(logs.contains("api=31")); assertTrue(logs.contains("mode=3")); assertFalse(logs.contains("private"))
        assertTrue(logs.contains("player_released"))
    }
    @Test fun `default ringtone alias uses platform source handling and honors Silent selection`() {
        android.media.RingtoneManager.setActualDefaultRingtoneUri(app, android.media.RingtoneManager.TYPE_RINGTONE, uri)
        val c = AndroidIncomingRingtone(app, createPlayer = { sound }, audio = audio)
        c.start()
        verify(sound).setDataSource(app, android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_RINGTONE))
        c.stop(); clearInvocations(sound)
        android.media.RingtoneManager.setActualDefaultRingtoneUri(app, android.media.RingtoneManager.TYPE_RINGTONE, null)
        AndroidIncomingRingtone(app, createPlayer = { sound }, audio = audio).start()
        verifyNoInteractions(sound)
    }
    @Test fun `non debuggable host emits no ringtone diagnostic logs`() {
        app.applicationInfo.flags = app.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE.inv()
        org.robolectric.shadows.ShadowLog.clear()
        val c = controller(); c.start(); prepared.onPrepared(sound); c.update(); c.stop()
        assertTrue(org.robolectric.shadows.ShadowLog.getLogsForTag("HuaweiRtcRingtone").isEmpty())
    }

    @Test fun `debug route readback failure cannot stop otherwise valid playback`() {
        app.applicationInfo.flags = app.applicationInfo.flags or ApplicationInfo.FLAG_DEBUGGABLE
        `when`(sound.routedDevice).thenThrow(IllegalStateException("private device"))
        val c = controller(); c.start(); prepared.onPrepared(sound); c.update()
        verify(sound, never()).release(); c.stop(); verify(sound).release()
    }

}
