package com.ajra.ajra

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL_NAME = "com.ajra.ajra/notifications"
        const val NOTIFICATION_CHANNEL_ID = "ajra_notifications_high_v2"
        const val NOTIFICATION_CHANNEL_NAME = "Notifications et Messages AJRA"
    }

    private var backgroundWakeLock: PowerManager.WakeLock? = null
    private var lastSoundTimestamp: Long = 0L
    private var lastNotificationTag: String = ""
    private var lastNotificationTime: Long = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createHighImportanceNotificationChannel()
        requestNotificationPermissionIfNeeded()
        acquireBackgroundKeepAliveLock()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createHighImportanceNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showNotification" -> {
                        val id = call.argument<Int>("id") ?: (System.currentTimeMillis() % Int.MAX_VALUE).toInt()
                        val tag = call.argument<String>("tag")
                        val title = call.argument<String>("title") ?: "AJRA"
                        val body = call.argument<String>("body") ?: "Nouvelle notification"
                        showSystemNotification(id, title, body, tag)
                        result.success(true)
                    }
                    "playNotificationSound" -> {
                        playPhoneNotificationSoundAndVibrate()
                        result.success(true)
                    }
                    "requestPermission" -> {
                        requestNotificationPermissionIfNeeded()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun acquireBackgroundKeepAliveLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
            if (backgroundWakeLock == null) {
                backgroundWakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "AJRA::BackgroundNotificationKeepAlive"
                ).apply {
                    setReferenceCounted(false)
                }
            }
            if (backgroundWakeLock?.isHeld == false) {
                backgroundWakeLock?.acquire(24 * 60 * 60 * 1000L)
            }
        } catch (_: Exception) {
        }
    }

    private fun wakeScreenBriefly() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
            @Suppress("DEPRECATION")
            val screenLock = powerManager.newWakeLock(
                PowerManager.SCREEN_DIM_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "AJRA::NotificationScreenWake"
            )
            screenLock.acquire(4000L)
        } catch (_: Exception) {
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= 33) {
            try {
                if (checkSelfPermission("android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 1001)
                }
            } catch (_: Exception) {
            }
        }
    }

    private fun createHighImportanceNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val notificationManager =
                    getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
                val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build()

                val channel = NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    NOTIFICATION_CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Alertes sonores pour les nouveaux messages et notifications AJRA même écran éteint"
                    enableLights(true)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 350, 150, 350)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    setSound(soundUri, audioAttributes)
                }
                notificationManager.createNotificationChannel(channel)
            } catch (_: Exception) {
            }
        }
    }

    private fun playPhoneNotificationSoundAndVibrate() {
        val now = System.currentTimeMillis()
        if (now - lastSoundTimestamp < 1200L) return
        lastSoundTimestamp = now

        try {
            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(applicationContext, soundUri)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ringtone?.isLooping = false
            }
            ringtone?.play()
        } catch (_: Exception) {
        }

        try {
            @Suppress("DEPRECATION")
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            if (vibrator != null && vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(
                        VibrationEffect.createWaveform(longArrayOf(0, 300, 150, 300), -1)
                    )
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(longArrayOf(0, 300, 150, 300), -1)
                }
            }
        } catch (_: Exception) {
        }
    }

    private fun showSystemNotification(id: Int, title: String, body: String, tag: String?) {
        try {
            val now = System.currentTimeMillis()
            if ((!tag.isNullOrEmpty() && tag == lastNotificationTag) || (now - lastNotificationTime < 2500L)) {
                return
            }
            if (!tag.isNullOrEmpty()) {
                lastNotificationTag = tag
            }
            lastNotificationTime = now

            createHighImportanceNotificationChannel()
            wakeScreenBriefly()

            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

            val launchIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(this, id, launchIntent, pendingFlags)

            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
                    .setPriority(Notification.PRIORITY_MAX)
                    .setSound(soundUri)
                    .setDefaults(Notification.DEFAULT_ALL)
            }

            builder.setSmallIcon(applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(pendingIntent)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                builder.setCategory(Notification.CATEGORY_MESSAGE)
                builder.setVisibility(Notification.VISIBILITY_PUBLIC)
            }

            if (!tag.isNullOrEmpty()) {
                notificationManager.notify(tag, 0, builder.build())
            } else {
                notificationManager.notify(id, builder.build())
            }
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        try {
            if (backgroundWakeLock?.isHeld == true) {
                backgroundWakeLock?.release()
            }
        } catch (_: Exception) {
        }
        super.onDestroy()
    }
}
