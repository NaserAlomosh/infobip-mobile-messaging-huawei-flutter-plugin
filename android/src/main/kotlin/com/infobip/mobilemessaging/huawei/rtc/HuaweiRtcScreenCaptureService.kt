package com.infobip.mobilemessaging.huawei.rtc

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.IBinder
import androidx.core.app.NotificationCompat

/** Capture coverage only; the existing manager/service retain RTC call ownership. */
class HuaweiRtcScreenCaptureService : Service() {
    internal class Lease(val identity: String, var ready: ((Boolean) -> Unit)?, val ended: () -> Unit) {
        fun complete(value: Boolean) { val callback = ready; ready = null; callback?.invoke(value) }
    }
    companion object {
        internal var lease: Lease? = null // main thread only; never persisted
        private const val CHANNEL = "huawei_rtc_screen_poc"
        private const val NOTICE = 84732
        private const val STOP = "screen_poc_stop"
    }
    private var owned: Lease? = null
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val current = lease
        if (current == null || intent?.getStringExtra("identity") != current.identity) {
            stopSelf(); return START_NOT_STICKY
        }
        if (intent.action == STOP) { current.ended(); return START_NOT_STICKY }
        owned = current
        try {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Experimental screen capture", NotificationManager.IMPORTANCE_LOW))
            val stop = PendingIntent.getService(this, 0,
                Intent(this, javaClass).setAction(STOP).putExtra("identity", current.identity),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            val notice = NotificationCompat.Builder(this, CHANNEL)
                .setSmallIcon(com.infobip.mobilemessaging.huawei.R.drawable.huawei_rtc_call)
                .setContentTitle("Screen shared as camera · Experimental")
                .setContentText("Your device screen is being captured for the existing video call")
                .setOngoing(true).addAction(0, "Stop capture", stop).build()
            startForeground(NOTICE, notice, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            current.complete(true)
        } catch (_: Exception) { current.complete(false); stopSelf() }
        return START_NOT_STICKY
    }
    override fun onDestroy() {
        val current = owned
        owned = null
        if (current != null && lease === current) { lease = null; current.ended() }
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
