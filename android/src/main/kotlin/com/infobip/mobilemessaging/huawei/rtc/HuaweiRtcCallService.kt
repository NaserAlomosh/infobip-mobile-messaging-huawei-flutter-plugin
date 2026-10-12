package com.infobip.mobilemessaging.huawei.rtc

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.infobip.mobilemessaging.huawei.R

internal data class RtcNotificationState(
    val callId: String?, val video: Boolean, val status: String,
    val durationSeconds: Int = 0, val muted: Boolean? = null,
)

/** A process-local observation lease, not a second RTC owner. All access is on main. */
internal interface RtcCallNotification {
    fun start(identity: String, video: Boolean, state: () -> RtcNotificationState?,
              action: (String, String?, Boolean?) -> Unit, ready: (RtcFailure?) -> Unit)
    fun stop(identity: String)
    fun returnIdentity(intent: Intent): String? = null
}

internal class HuaweiRtcCallNotification(context: Context) : RtcCallNotification {
    private val app = context.applicationContext
    override fun start(identity: String, video: Boolean, state: () -> RtcNotificationState?,
                       action: (String, String?, Boolean?) -> Unit, ready: (RtcFailure?) -> Unit) {
        val lease = RtcNotificationLease(identity, video, state, action, ready)
        check(HuaweiRtcCallService.lease == null)
        HuaweiRtcCallService.lease = lease
        try {
            ContextCompat.startForegroundService(app, Intent(app, HuaweiRtcCallService::class.java)
                .putExtra(HuaweiRtcCallService.IDENTITY, identity))
        } catch (_: Exception) {
            HuaweiRtcCallService.lease = null
            ready(RtcFailure("rtc_foreground_service_failed", "RTC foreground service could not start"))
        }
    }
    override fun stop(identity: String) {
        if (HuaweiRtcCallService.lease?.identity != identity) return
        HuaweiRtcCallService.lease = null
        HuaweiRtcCallService.running?.shutdown()
        app.stopService(Intent(app, HuaweiRtcCallService::class.java))
    }
    override fun returnIdentity(intent: Intent): String? {
        val current = HuaweiRtcCallService.lease ?: return null
        val state = current.state() ?: return null
        return current.identity.takeIf {
            intent.action == "${HuaweiRtcCallService.RETURN}.${current.identity}" &&
                intent.getStringExtra(HuaweiRtcCallService.IDENTITY) == it &&
                intent.getStringExtra(HuaweiRtcCallService.CALL_ID) == state.callId && state.callId != null
        }
    }
}

internal class RtcNotificationLease(
    val identity: String, val video: Boolean, val state: () -> RtcNotificationState?,
    val action: (String, String?, Boolean?) -> Unit, var ready: ((RtcFailure?) -> Unit)?,
) {
    fun complete(error: RtcFailure?) { val callback = ready; ready = null; callback?.invoke(error) }
}

/** Non-sticky: process death cannot recreate a call or resurrect its notification. */
class HuaweiRtcCallService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private var identity: String? = null
    private var promoted = false
    private val poll = object : Runnable {
        override fun run() {
            val current = lease?.takeIf { it.identity == identity }
            if (current == null) { shutdown(); return }
            val state = try { current.state() } catch (_: Exception) {
                // A transient SDK readback failure must not drop foreground media support.
                main.postDelayed(this, 1000)
                return
            }
            if (state == null || state.status == "finished") { shutdown(); return }
            try {
                getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(current, state))
            } catch (_: Exception) {
                // Permission/channel denial does not remove the requirement to run a FGS.
            }
            main.postDelayed(this, 1000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val current = lease
        if (current == null) { shutdown(); return START_NOT_STICKY }
        // A late start/action from an older call must not stop a newer service.
        if (intent?.getStringExtra(IDENTITY) != current.identity) return START_NOT_STICKY
        if (intent.action == END || intent.action == MUTE) {
            val state = current.state()
            if (identity == current.identity && state?.callId != null &&
                state.callId == intent.getStringExtra(CALL_ID)) {
                current.action(intent.action!!, state.callId,
                    if (intent.hasExtra(MUTED)) intent.getBooleanExtra(MUTED, false) else null)
            }
            return START_NOT_STICKY
        }
        identity = current.identity
        running = this
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "Ongoing RTC calls", NotificationManager.IMPORTANCE_LOW)
                .apply { description = "Active audio and video calls"; setShowBadge(false) })
            val state = current.state() ?: throw IllegalStateException("No RTC request")
            val notification = notification(current, state)
            if (Build.VERSION.SDK_INT >= 30) startForeground(NOTIFICATION_ID, notification, serviceTypes(current.video))
            else startForeground(NOTIFICATION_ID, notification)
            promoted = true
            current.complete(null) // SDK media creation happens only after successful promotion.
            main.removeCallbacks(poll)
            poll.run()
        } catch (_: Exception) {
            current.complete(RtcFailure("rtc_foreground_service_failed", "RTC foreground service could not start"))
            if (lease === current) current.action(FAILURE, current.state()?.callId, null)
            shutdown()
        }
        return START_NOT_STICKY
    }

    internal fun notification(current: RtcNotificationLease, state: RtcNotificationState): Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.huawei_rtc_call)
            .setContentTitle(if (state.video) "Video call in progress" else "Audio call in progress")
            .setContentText(when (state.status) {
                "established" -> if (state.muted == true) "Connected · microphone muted" else "Connected"
                "finishing" -> "Ending call…"
                else -> "Connecting…"
            })
            .setCategory(NotificationCompat.CATEGORY_CALL).setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPriority(NotificationCompat.PRIORITY_LOW).setOngoing(true).setOnlyAlertOnce(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
        if (state.status == "established") {
            builder.setWhen(System.currentTimeMillis() - state.durationSeconds.coerceAtLeast(0).toLong() * 1000)
                .setUsesChronometer(true).setShowWhen(true)
        } else builder.setShowWhen(false)
        if (state.callId != null) {
            val launch = packageManager.getLaunchIntentForPackage(packageName)
            if (launch != null) {
                launch.action = "$RETURN.${current.identity}"
                launch.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                identify(launch, current, state, RETURN).setData(null) // Avoid Flutter deep-link interpretation.
                builder.setContentIntent(PendingIntent.getActivity(this, 0, launch, pendingFlags))
            }
            builder.addAction(0, "End Call", actionIntent(current, state, END))
            if (state.status == "established" && state.muted != null) {
                builder.addAction(0, if (state.muted) "Unmute" else "Mute",
                    actionIntent(current, state, MUTE, !state.muted))
            }
        }
        return builder.build()
    }

    private fun actionIntent(current: RtcNotificationLease, state: RtcNotificationState, action: String, muted: Boolean? = null): PendingIntent {
        val intent = identify(Intent(this, HuaweiRtcCallService::class.java).setAction(action), current, state,
            "$action/$muted")
        muted?.let { intent.putExtra(MUTED, it) }
        // Existing foreground service handles these; never starts a new RTC operation.
        return PendingIntent.getService(this, 0, intent, pendingFlags)
    }
    private fun identify(intent: Intent, current: RtcNotificationLease, state: RtcNotificationState, action: String): Intent =
        intent.setData(Uri.Builder().scheme("huawei-rtc").authority("call").appendPath(current.identity)
            .appendPath(state.callId ?: "pending").appendPath(action).build())
            .putExtra(IDENTITY, current.identity).putExtra(CALL_ID, state.callId)

    override fun onTaskRemoved(rootIntent: Intent?) {
        lease?.takeIf { it.identity == identity }?.let { it.action(END, it.state()?.callId, null) }
        super.onTaskRemoved(rootIntent)
    }
    internal fun shutdown() {
        main.removeCallbacks(poll)
        if (promoted) stopForeground(STOP_FOREGROUND_REMOVE)
        getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
        promoted = false
        stopSelf()
    }
    override fun onDestroy() {
        main.removeCallbacks(poll)
        if (running === this) {
            running = null
            lease?.takeIf { it.identity == identity }?.let {
                it.complete(RtcFailure("rtc_foreground_service_failed", "RTC foreground service stopped"))
                it.action(FAILURE, it.state()?.callId, null)
            }
        }
        super.onDestroy()
    }
    companion object {
        internal const val CHANNEL = "huawei_rtc_ongoing_calls"
        internal const val NOTIFICATION_ID = 0x48525443
        internal const val IDENTITY = "huaweiRtcSession"
        internal const val CALL_ID = "huaweiRtcCallId"
        internal const val RETURN = "com.infobip.huawei.rtc.RETURN"
        internal const val END = "com.infobip.huawei.rtc.END"
        internal const val MUTE = "com.infobip.huawei.rtc.MUTE"
        internal const val MUTED = "huaweiRtcMuted"
        internal const val FAILURE = "serviceFailure"
        internal var lease: RtcNotificationLease? = null
        internal var running: HuaweiRtcCallService? = null
        private val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        internal fun serviceTypes(video: Boolean): Int = if (Build.VERSION.SDK_INT >= 30)
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                (if (video) ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA else 0) else 0
    }
}
