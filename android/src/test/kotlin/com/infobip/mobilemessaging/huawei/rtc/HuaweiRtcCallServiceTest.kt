package com.infobip.mobilemessaging.huawei.rtc

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Looper
import org.robolectric.RuntimeEnvironment
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class HuaweiRtcCallServiceTest {
    private val context = RuntimeEnvironment.getApplication()
    private var state: RtcNotificationState? = RtcNotificationState("call-a", false, "calling")
    private var readyCount = 0
    private var readbackFails = false
    private val actions = mutableListOf<Triple<String, String?, Boolean?>>()
    private val current = RtcNotificationLease("session-a", false, {
        if (readbackFails) throw IllegalStateException("Temporary SDK readback failure")
        state
    },
        { action, id, muted -> actions += Triple(action, id, muted) }, { assertNull(it); readyCount++ })
    private val controller = Robolectric.buildService(HuaweiRtcCallService::class.java)
    private val service get() = controller.get()
    private val manager get() = context.getSystemService(NotificationManager::class.java)
    private fun start(notificationLease: RtcNotificationLease = current) {
        HuaweiRtcCallService.lease = notificationLease
        controller.create()
        service.onStartCommand(Intent(context, HuaweiRtcCallService::class.java)
            .putExtra(HuaweiRtcCallService.IDENTITY, notificationLease.identity), 0, 1)
    }
    private fun action(action: String, identity: String = current.identity, id: String = "call-a", muted: Boolean? = null): Intent =
        Intent(context, HuaweiRtcCallService::class.java).setAction(action)
            .putExtra(HuaweiRtcCallService.IDENTITY, identity).putExtra(HuaweiRtcCallService.CALL_ID, id)
            .apply { muted?.let { putExtra(HuaweiRtcCallService.MUTED, it) } }
    @After fun cleanup() {
        HuaweiRtcCallService.lease = null
        service.shutdown()
        controller.destroy()
        HuaweiRtcCallService.running = null
    }

    @Test fun `connecting notification promotes once and duplicate events do not create service`() {
        start()
        assertEquals(1, readyCount)
        val n = shadowOf(manager).getNotification(HuaweiRtcCallService.NOTIFICATION_ID)
        assertEquals("Audio call in progress", n.extras.getCharSequence(Notification.EXTRA_TITLE))
        assertEquals("Connecting…", n.extras.getCharSequence(Notification.EXTRA_TEXT))
        assertEquals(Notification.CATEGORY_CALL, n.category)
        assertEquals(Notification.VISIBILITY_PRIVATE, n.visibility)
        assertTrue(n.flags and Notification.FLAG_ONGOING_EVENT != 0)
        assertEquals(1, n.actions.size)
        service.onStartCommand(Intent(context, HuaweiRtcCallService::class.java)
            .putExtra(HuaweiRtcCallService.IDENTITY, current.identity), 0, 2)
        assertEquals(1, readyCount)
        assertSame(service, HuaweiRtcCallService.running)
        assertEquals(NotificationManager.IMPORTANCE_LOW, manager.getNotificationChannel(HuaweiRtcCallService.CHANNEL).importance)
    }

    @Test fun `established readback supplies chronometer and mute label then finish clears`() {
        start()
        state = RtcNotificationState("call-a", true, "established", 65, true)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        val n = shadowOf(manager).getNotification(HuaweiRtcCallService.NOTIFICATION_ID)
        assertEquals("Video call in progress", n.extras.getCharSequence(Notification.EXTRA_TITLE))
        assertTrue(n.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
        assertTrue(kotlin.math.abs(System.currentTimeMillis() - n.`when` - 65_000) < 100)
        assertEquals("Unmute", n.actions[1].title)
        state = state!!.copy(status = "finished")
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        assertNull(shadowOf(manager).getNotification(HuaweiRtcCallService.NOTIFICATION_ID))
        assertTrue(shadowOf(service).isStoppedBySelf)
    }

    @Test fun `transient SDK readback failure keeps foreground support and later finished still clears`() {
        start()
        readbackFails = true
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        assertNotNull(shadowOf(manager).getNotification(HuaweiRtcCallService.NOTIFICATION_ID))
        assertFalse(shadowOf(service).isStoppedBySelf)
        readbackFails = false
        state = state!!.copy(status = "finished")
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        assertNull(shadowOf(manager).getNotification(HuaweiRtcCallService.NOTIFICATION_ID))
    }

    @Test fun `native actions preserve identity and explicit mute target`() {
        start()
        state = state!!.copy(status = "established", muted = false)
        val n = service.notification(current, state!!)
        val end = shadowOf(n.actions[0].actionIntent).savedIntent
        val mute = shadowOf(n.actions[1].actionIntent).savedIntent
        assertEquals(current.identity, end.getStringExtra(HuaweiRtcCallService.IDENTITY))
        assertEquals("call-a", end.getStringExtra(HuaweiRtcCallService.CALL_ID))
        assertTrue(shadowOf(n.actions[0].actionIntent).isServiceIntent)
        assertTrue(mute.getBooleanExtra(HuaweiRtcCallService.MUTED, false))
        service.onStartCommand(end, 0, 2)
        service.onStartCommand(mute, 0, 3)
        assertEquals(listOf(Triple(HuaweiRtcCallService.END, "call-a", null),
            Triple(HuaweiRtcCallService.MUTE, "call-a", true)), actions)
        assertNotNull(shadowOf(manager).getNotification(HuaweiRtcCallService.NOTIFICATION_ID))
    }

    @Test fun `old call ID or session cannot affect or stop newer service`() {
        start()
        service.onStartCommand(action(HuaweiRtcCallService.END, id = "old-call"), 0, 2)
        service.onStartCommand(action(HuaweiRtcCallService.MUTE, identity = "old-session", muted = true), 0, 3)
        assertTrue(actions.isEmpty())
        assertNotNull(shadowOf(manager).getNotification(HuaweiRtcCallService.NOTIFICATION_ID))
        val newer = RtcNotificationLease("session-b", false, { state }, { _, _, _ -> }, null)
        val oldIntent = shadowOf(service.notification(current, state!!).actions[0].actionIntent).savedIntent
        HuaweiRtcCallService.lease = newer
        service.onStartCommand(Intent(context, HuaweiRtcCallService::class.java).putExtra(HuaweiRtcCallService.IDENTITY, newer.identity), 0, 4)
        service.onStartCommand(oldIntent, 0, 5)
        assertSame(newer, HuaweiRtcCallService.lease)
        assertNotNull(shadowOf(manager).getNotification(HuaweiRtcCallService.NOTIFICATION_ID))
    }

    @Test fun `task removal requests hangup before any shutdown and null restart is nonsticky`() {
        start()
        service.onTaskRemoved(null)
        assertEquals(Triple(HuaweiRtcCallService.END, "call-a", null), actions.single())
        assertNotNull(shadowOf(manager).getNotification(HuaweiRtcCallService.NOTIFICATION_ID))
        HuaweiRtcCallService.lease = null
        assertEquals(android.app.Service.START_NOT_STICKY, service.onStartCommand(null, 0, 3))
        assertNull(shadowOf(manager).getNotification(HuaweiRtcCallService.NOTIFICATION_ID))
    }

    @Test fun `unexpected destruction asks owner to end without resurrecting session`() {
        start()
        service.onDestroy()
        assertEquals(Triple(HuaweiRtcCallService.FAILURE, "call-a", null), actions.single())
        assertNull(HuaweiRtcCallService.running)
    }

    @Test fun `start restriction reports sanitized failure and drops lease`() {
        val app = mock(Context::class.java)
        `when`(app.applicationContext).thenReturn(app)
        `when`(app.startForegroundService(any(Intent::class.java))).thenThrow(SecurityException("private details"))
        var error: RtcFailure? = null
        HuaweiRtcCallNotification(app).start("blocked", false, { state }, { _, _, _ -> }, { error = it })
        assertEquals("rtc_foreground_service_failed", error?.code)
        assertFalse(error!!.message.contains("private details"))
        assertNull(HuaweiRtcCallService.lease)
    }

    @Test @Config(sdk = [30, 33, 34, 36]) fun `audio and video types are microphone and camera on supported versions`() {
        assertEquals(ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE, HuaweiRtcCallService.serviceTypes(false))
        assertEquals(ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA,
            HuaweiRtcCallService.serviceTypes(true))
        start()
        assertNotNull(shadowOf(manager).getNotification(HuaweiRtcCallService.NOTIFICATION_ID))
    }

    @Test @Config(sdk = [34]) fun `video promotion actually passes both foreground service types`() {
        state = state!!.copy(video = true)
        start(RtcNotificationLease(current.identity, true, { state }, current.action, null))
        assertEquals(ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA,
            service.foregroundServiceType)
    }

    @Test @Config(sdk = [33]) fun `notification denial still requires and starts foreground service`() {
        shadowOf(manager).setNotificationsEnabled(false)
        start()
        assertFalse(manager.areNotificationsEnabled())
        assertEquals(1, readyCount)
        assertNotNull(shadowOf(service).lastForegroundNotification)
        assertEquals(ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE, service.foregroundServiceType)
        // Robolectric cannot certify drawer versus Task Manager visibility.
    }

    @Test fun `promotion permission failure stops service and reports failure before SDK readiness`() {
        var error: RtcFailure? = null
        HuaweiRtcCallService.lease = RtcNotificationLease(current.identity, false, { state }, current.action, { error = it })
        controller.create()
        shadowOf(service).setThrowInStartForeground(SecurityException("permission denied"))
        service.onStartCommand(Intent(context, HuaweiRtcCallService::class.java)
            .putExtra(HuaweiRtcCallService.IDENTITY, current.identity), 0, 1)
        assertEquals("rtc_foreground_service_failed", error?.code)
        assertEquals(0, readyCount)
        assertTrue(shadowOf(service).isStoppedBySelf)
        assertNull(shadowOf(manager).getNotification(HuaweiRtcCallService.NOTIFICATION_ID))
        assertEquals(HuaweiRtcCallService.FAILURE, actions.single().first)
    }

    @Test @Config(sdk = [34]) fun `manifest declares media service permissions without phoneCall prerequisites`() {
        val info = context.packageManager.getPackageInfo(context.packageName,
            android.content.pm.PackageManager.GET_SERVICES or android.content.pm.PackageManager.GET_PERMISSIONS)
        val declaration = requireNotNull(info.services).single { it.name == HuaweiRtcCallService::class.java.name }
        assertFalse(declaration.exported)
        assertEquals(ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA,
            declaration.foregroundServiceType)
        assertEquals(0, declaration.flags and ServiceInfo.FLAG_STOP_WITH_TASK)
        val permissions = requireNotNull(info.requestedPermissions).toSet()
        assertTrue(permissions.containsAll(listOf("android.permission.FOREGROUND_SERVICE",
            "android.permission.FOREGROUND_SERVICE_MICROPHONE", "android.permission.FOREGROUND_SERVICE_CAMERA",
            "android.permission.POST_NOTIFICATIONS")))
        assertFalse(permissions.contains("android.permission.FOREGROUND_SERVICE_PHONE_CALL"))
        assertFalse(permissions.contains("android.permission.MANAGE_OWN_CALLS"))
    }

    @Test fun `pre Android 11 promotion has no unavailable type bits`() {
        assertEquals(0, HuaweiRtcCallService.serviceTypes(true))
    }

    @Test fun `notification tap launch preserves ID and avoids Flutter deep link`() {
        val info = android.content.pm.ResolveInfo().apply {
            activityInfo = android.content.pm.ActivityInfo().apply {
                packageName = context.packageName
                name = "TestActivity"
                applicationInfo = context.applicationInfo
            }
        }
        shadowOf(context.packageManager).addResolveInfoForIntent(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER).setPackage(context.packageName), info)
        start()
        val n = service.notification(current, state!!)
        val launch = shadowOf(n.contentIntent).savedIntent
        assertNull(launch.data)
        assertTrue(launch.flags and Intent.FLAG_ACTIVITY_SINGLE_TOP != 0)
        assertTrue(launch.flags and Intent.FLAG_ACTIVITY_CLEAR_TOP != 0)
        val component = HuaweiRtcCallNotification(context)
        assertEquals(current.identity, component.returnIdentity(launch))
        launch.putExtra(HuaweiRtcCallService.IDENTITY, "old-session")
        assertNull(component.returnIdentity(launch))
    }
}
