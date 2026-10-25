package com.infobip.mobilemessaging.huawei.rtc

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.AudioDeviceInfo
import android.app.NotificationManager
import android.content.pm.ApplicationInfo
import android.util.Log
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build

internal interface IncomingRingtone {
    fun start()
    fun stop()
    fun update()

    object None : IncomingRingtone {
        override fun start() { }
        override fun stop() { }
        override fun update() { }
    }
}

/** Main-thread, invitation-owned player. No global routing or audio-focus mutations. */
internal class AndroidIncomingRingtone(
    context: Context,
    private val defaultUri: (Context) -> Uri? = {
        // Keep an explicit Silent selection silent; use Android's cached/default-source fallback otherwise.
        if (RingtoneManager.getActualDefaultRingtoneUri(it, RingtoneManager.TYPE_RINGTONE) == null) null
        else RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
    },
    private val createPlayer: () -> MediaPlayer = { MediaPlayer() },
    private val audio: AudioManager? = context.applicationContext.getSystemService(AudioManager::class.java),
) : IncomingRingtone {
    private val app = context.applicationContext
    private var player: MediaPlayer? = null
    private var attempted = false
    private var stopping = false
    private var speakerPreferred = false
    private var lastRoute: Int? = null
    private var playing = false
    private val debug = app.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    // Only fixed messages and numeric Android constants enter Logcat. Never include device names/IDs or URIs.
    private fun diagnostic(event: String) {
        if (debug) Log.d("HuaweiRtcRingtone", event)
    }

    private fun audible(): Boolean = try {
        val policy = app.getSystemService(NotificationManager::class.java)
        audio != null && audio.ringerMode == AudioManager.RINGER_MODE_NORMAL &&
            audio.getStreamVolume(AudioManager.STREAM_RING) > 0 &&
            policy != null && policy.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL
    } catch (_: Exception) { false }

    private fun outputs(): List<AudioDeviceInfo>? = try {
        audio?.getDevices(AudioManager.GET_DEVICES_OUTPUTS)?.toList()
    } catch (_: Exception) { diagnostic("output_query_failed"); null }

    private fun external(devices: List<AudioDeviceInfo>) = devices.any {
        it.type != AudioDeviceInfo.TYPE_BUILTIN_SPEAKER && it.type != AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
    }

    override fun start() {
        if (attempted || player != null || stopping) return
        attempted = true
        if (!audible()) { diagnostic("ringtone_suppressed_by_sound_policy"); return }
        try {
            val uri = defaultUri(app) ?: return // Intentional Silent selection: never override.
            val sound = createPlayer()
            player = sound // Own before any fallible configuration.
            sound.setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            sound.isLooping = true // MediaPlayer supports looping on all supported API levels (26+).
            sound.setOnErrorListener { failed, _, _ ->
                if (player === failed) { diagnostic("playback_error"); stop() }
                true
            }
            val devices = outputs()
            if (debug) try {
                diagnostic("preplay api=${Build.VERSION.SDK_INT} mode=${audio?.mode} outputs=${devices?.map { it.type }?.distinct()?.sorted()}")
                if (Build.VERSION.SDK_INT >= 31) diagnostic("communication_device_type=${audio?.communicationDevice?.type}")
            } catch (_: Exception) { diagnostic("audio_snapshot_unavailable") }
            if (Build.VERSION.SDK_INT < 28) diagnostic("preferred_output_unsupported_using_default")
            else if (devices != null && !external(devices)) {
                val speaker = devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
                if (speaker != null) {
                    speakerPreferred = try { sound.setPreferredDevice(speaker) } catch (_: Exception) { false }
                    diagnostic(if (speakerPreferred) "speaker_preference_accepted" else "speaker_preference_failed_using_default")
                } else diagnostic("speaker_unavailable_using_default")
            } else diagnostic("external_or_unknown_outputs_using_default")
            // Async preparation keeps Accept/cancel responsive even for an inaccessible custom URI.
            sound.setOnPreparedListener { prepared ->
                if (player !== prepared || stopping) return@setOnPreparedListener
                try {
                    if (!audible()) { stop(); return@setOnPreparedListener }
                    refreshPreference(prepared)
                    if (player !== prepared || stopping) return@setOnPreparedListener
                    prepared.start()
                    playing = true
                    diagnostic("playback_start_returned_route_unconfirmed")
                } catch (_: Exception) { diagnostic("playback_start_failed"); stop() }
            }
            sound.setDataSource(app, uri)
            sound.prepareAsync()
        } catch (_: Exception) { diagnostic("player_setup_failed"); stop() }
    }

    override fun stop() {
        attempted = false
        val sound = player ?: return
        stopping = true
        try {
            // release also works while preparing; no stop() call in an illegal player state.
            sound.release()
            player = null
            speakerPreferred = false
            lastRoute = null
            playing = false
            stopping = false
            diagnostic("player_released")
        } catch (_: Exception) { diagnostic("player_release_failed") }
    }

    private fun refreshPreference(sound: MediaPlayer) {
        if (Build.VERSION.SDK_INT < 28 || !speakerPreferred) return
        val devices = outputs()
        if (devices == null || external(devices) || devices.none { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }) {
            if (!sound.setPreferredDevice(null)) {
                diagnostic("clear_preference_failed"); stop(); return
            }
            speakerPreferred = false
            diagnostic("external_or_unknown_outputs_preference_cleared")
        }
    }

    /** Reuses the experiment watchdog. External attachment clears only this player's preference. */
    override fun update() {
        if (stopping) { stop(); return }
        val sound = player ?: return
        if (!audible()) { stop(); return }
        try {
            refreshPreference(sound)
        } catch (_: Exception) { diagnostic("routing_update_failed"); stop(); return }
        if (player !== sound || stopping) return
        if (debug && playing && Build.VERSION.SDK_INT >= 28) try {
            val route = sound.routedDevice?.type ?: 0
            if (lastRoute != route) {
                lastRoute = route
                diagnostic("observed_output_type=$route") // 0 means unknown, not speaker success.
            }
        } catch (_: Exception) { diagnostic("route_readback_unavailable") }
    }
}
