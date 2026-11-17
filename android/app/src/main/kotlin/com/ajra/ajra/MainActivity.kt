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
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.FileInputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL_NAME = "com.ajra.ajra/notifications"
        const val UPDATER_CHANNEL_NAME = "com.ajra.ajra/app_updater"
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
                    "getInstalledAppInfo" -> {
                        handleGetInstalledAppInfo(result)
                    }
                    "checkRemoteApkAndPlayStore" -> {
                        val apkUrl = call.argument<String>("apkUrl") ?: "https://ajra-app-8ae42.web.app/app.apk"
                        val fallbackApkUrl = call.argument<String>("fallbackApkUrl") ?: "https://ajra-app-8ae42.web.app/ajra.apk"
                        val md5Url = call.argument<String>("md5Url") ?: "https://ajra-app-8ae42.web.app/app.apk.md5"
                        val versionJsonUrl = call.argument<String>("versionJsonUrl") ?: "https://ajra-app-8ae42.web.app/version.json"
                        handleCheckRemoteApkAndPlayStore(apkUrl, fallbackApkUrl, md5Url, versionJsonUrl, result)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledAppInfo" -> {
                        handleGetInstalledAppInfo(result)
                    }
                    "checkRemoteApkAndPlayStore" -> {
                        val apkUrl = call.argument<String>("apkUrl") ?: "https://ajra-app-8ae42.web.app/app.apk"
                        val fallbackApkUrl = call.argument<String>("fallbackApkUrl") ?: "https://ajra-app-8ae42.web.app/ajra.apk"
                        val md5Url = call.argument<String>("md5Url") ?: "https://ajra-app-8ae42.web.app/app.apk.md5"
                        val versionJsonUrl = call.argument<String>("versionJsonUrl") ?: "https://ajra-app-8ae42.web.app/version.json"
                        handleCheckRemoteApkAndPlayStore(apkUrl, fallbackApkUrl, md5Url, versionJsonUrl, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun computeInstalledApkMd5(): String {
        return try {
            val sourceDir = applicationContext.applicationInfo.sourceDir ?: return ""
            val apkFile = File(sourceDir)
            if (!apkFile.exists() || !apkFile.canRead()) return ""

            val digest = MessageDigest.getInstance("MD5")
            FileInputStream(apkFile).use { fis ->
                val buffer = ByteArray(16384)
                var read: Int
                while (fis.read(buffer).also { read = it } != -1) {
                    digest.update(buffer, 0, read)
                }
            }
            bytesToHex(digest.digest())
        } catch (_: Exception) {
            ""
        }
    }

    private fun bytesToHex(bytes: ByteArray): String {
        val sb = StringBuilder(bytes.size * 2)
        for (b in bytes) {
            sb.append(String.format("%02x", b))
        }
        return sb.toString().lowercase()
    }

    private fun getInstallerPackage(): String {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                packageManager.getInstallSourceInfo(packageName).installingPackageName ?: ""
            } else {
                @Suppress("DEPRECATION")
                packageManager.getInstallerPackageName(packageName) ?: ""
            }
        } catch (_: Exception) {
            ""
        }
    }

    private fun handleGetInstalledAppInfo(result: MethodChannel.Result) {
        Thread {
            try {
                val pInfo = packageManager.getPackageInfo(packageName, 0)
                val versionName = pInfo.versionName ?: "1.4.8"
                val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    pInfo.longVersionCode.toInt()
                } else {
                    @Suppress("DEPRECATION")
                    pInfo.versionCode
                }
                val localMd5 = computeInstalledApkMd5()
                val installer = getInstallerPackage()

                val info = mapOf(
                    "md5" to localMd5,
                    "versionName" to versionName,
                    "versionCode" to versionCode,
                    "packageName" to packageName,
                    "installerPackageName" to installer
                )
                runOnUiThread { result.success(info) }
            } catch (e: Exception) {
                runOnUiThread {
                    result.success(
                        mapOf(
                            "md5" to "",
                            "versionName" to "1.4.8",
                            "versionCode" to 3,
                            "packageName" to packageName,
                            "installerPackageName" to ""
                        )
                    )
                }
            }
        }.start()
    }

    private fun extractMd5FromHeaders(conn: HttpURLConnection): String {
        try {
            val hexRegex = Regex("^[0-9a-fA-F]{32}$")
            val rawEtag = conn.getHeaderField("ETag")?.trim()?.removePrefix("W/")?.trim('"') ?: ""
            if (hexRegex.matches(rawEtag)) {
                return rawEtag.lowercase()
            }

            val googHash = conn.getHeaderField("x-goog-hash") ?: ""
            if (googHash.contains("md5=")) {
                val parts = googHash.split(",")
                for (p in parts) {
                    val trimmed = p.trim()
                    if (trimmed.startsWith("md5=")) {
                        val b64 = trimmed.removePrefix("md5=").trim()
                        val decoded = Base64.decode(b64, Base64.DEFAULT)
                        if (decoded.size == 16) {
                            return bytesToHex(decoded)
                        }
                    }
                }
            }

            val contentMd5 = conn.getHeaderField("Content-MD5")?.trim() ?: ""
            if (contentMd5.isNotEmpty()) {
                if (hexRegex.matches(contentMd5)) {
                    return contentMd5.lowercase()
                }
                val decoded = Base64.decode(contentMd5, Base64.DEFAULT)
                if (decoded.size == 16) {
                    return bytesToHex(decoded)
                }
            }
        } catch (_: Exception) {
        }
        return ""
    }

    private fun fetchSmallText(urlStr: String): String {
        var conn: HttpURLConnection? = null
        return try {
            val sep = if (urlStr.contains("?")) "&" else "?"
            val url = URL("${urlStr}${sep}t=${System.currentTimeMillis()}")
            conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 6000
                readTimeout = 6000
                useCaches = false
                setRequestProperty("Cache-Control", "no-cache")
            }
            if (conn.responseCode != 200) return ""
            val ct = (conn.contentType ?: "").lowercase()
            if (ct.contains("text/html")) return ""
            BufferedReader(InputStreamReader(conn.inputStream)).use { it.readText().trim() }
        } catch (_: Exception) {
            ""
        } finally {
            conn?.disconnect()
        }
    }

    private fun checkPlayStoreVersion(): String {
        var conn: HttpURLConnection? = null
        return try {
            val url = URL("https://play.google.com/store/apps/details?id=$packageName&hl=fr&gl=MU&_t=${System.currentTimeMillis()}")
            conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 5000
                readTimeout = 5000
                setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36")
            }
            if (conn.responseCode != 200) return ""
            val html = BufferedReader(InputStreamReader(conn.inputStream)).use { it.readText() }
            val regex1 = Regex("""\[\[\["(\d+\.\d+\.\d+(?:\+\d+)?)"\]\]""")
            val match1 = regex1.find(html)
            if (match1 != null) return match1.groupValues[1]

            val regex2 = Regex(""""softwareVersion"\s*:\s*"(\d+\.\d+\.\d+)"""")
            val match2 = regex2.find(html)
            if (match2 != null) return match2.groupValues[1]
            ""
        } catch (_: Exception) {
            ""
        } finally {
            conn?.disconnect()
        }
    }

    private fun inspectRemoteApk(targetUrl: String, existingMd5: String): Pair<Boolean, String> {
        var headConn: HttpURLConnection? = null
        try {
            val sep = if (targetUrl.contains("?")) "&" else "?"
            val url = URL("${targetUrl}${sep}t=${System.currentTimeMillis()}")
            headConn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "HEAD"
                connectTimeout = 7000
                readTimeout = 7000
                useCaches = false
                instanceFollowRedirects = true
                setRequestProperty("Cache-Control", "no-cache")
            }
            val code = headConn.responseCode
            val contentType = (headConn.contentType ?: "").lowercase()
            val contentLength = headConn.contentLengthLong

            // Si le fichier renvoie index.html (SPA fallback) ou < 50 KB, ce n'est pas un APK valide
            if (code != 200 || contentType.contains("text/html") || (contentLength in 1..50000)) {
                return Pair(false, "")
            }

            if (existingMd5.length == 32) {
                return Pair(true, existingMd5.lowercase())
            }

            val headerMd5 = extractMd5FromHeaders(headConn)
            if (headerMd5.length == 32) {
                return Pair(true, headerMd5)
            }

            val etag = headConn.getHeaderField("ETag") ?: ""
            val lastMod = headConn.getHeaderField("Last-Modified") ?: ""
            val prefs = getSharedPreferences("ajra_apk_md5_cache", Context.MODE_PRIVATE)
            val cacheKey = "${targetUrl}|${etag}|${lastMod}|${contentLength}"
            val cachedMd5 = prefs.getString(cacheKey, "") ?: ""
            if (cachedMd5.length == 32) {
                return Pair(true, cachedMd5)
            }

            headConn.disconnect()
            headConn = null

            // Calcul direct du MD5 du fichier APK distant en streaming
            var getConn: HttpURLConnection? = null
            try {
                getConn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    connectTimeout = 10000
                    readTimeout = 20000
                    useCaches = false
                    instanceFollowRedirects = true
                    setRequestProperty("Cache-Control", "no-cache")
                }
                if (getConn.responseCode == 200 && !(getConn.contentType ?: "").lowercase().contains("text/html")) {
                    val digest = MessageDigest.getInstance("MD5")
                    var totalBytes = 0L
                    getConn.inputStream.use { input ->
                        val buffer = ByteArray(16384)
                        var read: Int
                        while (input.read(buffer).also { read = it } != -1) {
                            digest.update(buffer, 0, read)
                            totalBytes += read
                        }
                    }
                    if (totalBytes > 50000L) {
                        val computed = bytesToHex(digest.digest())
                        if (etag.isNotEmpty() || lastMod.isNotEmpty() || contentLength > 0) {
                            prefs.edit().putString(cacheKey, computed).apply()
                        }
                        return Pair(true, computed)
                    }
                }
            } finally {
                getConn?.disconnect()
            }
        } catch (_: Exception) {
        } finally {
            headConn?.disconnect()
        }
        return Pair(false, "")
    }

    private fun handleCheckRemoteApkAndPlayStore(
        apkUrl: String,
        fallbackApkUrl: String,
        md5Url: String,
        versionJsonUrl: String,
        result: MethodChannel.Result
    ) {
        Thread {
            try {
                val pInfo = packageManager.getPackageInfo(packageName, 0)
                val localVersion = pInfo.versionName ?: "1.4.8"
                val localBuildNumber = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    pInfo.longVersionCode.toInt()
                } else {
                    @Suppress("DEPRECATION")
                    pInfo.versionCode
                }
                val localMd5 = computeInstalledApkMd5()
                val installer = getInstallerPackage()

                var remoteVersion = ""
                var remoteBuildNumber = 0
                var remoteMd5 = ""
                var releaseNotes = ""
                var resolvedApkUrl = apkUrl

                // 1. Lire version.json si présent sur l'hébergement
                val versionJsonText = fetchSmallText(versionJsonUrl)
                if (versionJsonText.startsWith("{")) {
                    try {
                        val json = JSONObject(versionJsonText)
                        remoteVersion = json.optString("version", "")
                        remoteBuildNumber = json.optInt("buildNumber", 0)
                        val jsonMd5 = json.optString("md5", "").trim().lowercase()
                        if (Regex("^[0-9a-f]{32}$").matches(jsonMd5)) {
                            remoteMd5 = jsonMd5
                        }
                        val customUrl = json.optString("apkUrl", "").trim()
                        if (customUrl.startsWith("http")) {
                            resolvedApkUrl = customUrl
                        }
                        releaseNotes = json.optString("releaseNotes", json.optString("notes", ""))
                    } catch (_: Exception) {
                    }
                }

                // 2. Lire app.apk.md5 si présent
                if (remoteMd5.isEmpty()) {
                    val md5Text = fetchSmallText(md5Url)
                    val match = Regex("[0-9a-fA-F]{32}").find(md5Text)
                    if (match != null) {
                        remoteMd5 = match.value.lowercase()
                    }
                }

                // 3. Vérifier https://ajra-app-8ae42.web.app/app.apk (puis fallback ajra.apk) et calculer/comparer le MD5
                val primaryCheck = inspectRemoteApk(resolvedApkUrl, remoteMd5)
                if (primaryCheck.first && primaryCheck.second.isNotEmpty()) {
                    remoteMd5 = primaryCheck.second
                } else if (fallbackApkUrl.isNotEmpty() && fallbackApkUrl != resolvedApkUrl) {
                    val fallbackCheck = inspectRemoteApk(fallbackApkUrl, "")
                    if (fallbackCheck.first && fallbackCheck.second.isNotEmpty()) {
                        resolvedApkUrl = fallbackApkUrl
                        if (remoteMd5.isEmpty()) {
                            remoteMd5 = fallbackCheck.second
                        }
                    }
                }

                // 4. Vérifier Google Play Store
                val playStoreVersion = checkPlayStoreVersion()

                val response = mapOf(
                    "localMd5" to localMd5,
                    "remoteMd5" to remoteMd5,
                    "localVersion" to localVersion,
                    "localBuildNumber" to localBuildNumber,
                    "remoteVersion" to remoteVersion,
                    "remoteBuildNumber" to remoteBuildNumber,
                    "playStoreVersion" to playStoreVersion,
                    "resolvedApkUrl" to resolvedApkUrl,
                    "releaseNotes" to releaseNotes,
                    "installerPackageName" to installer
                )
                runOnUiThread { result.success(response) }
            } catch (e: Exception) {
                runOnUiThread {
                    result.success(
                        mapOf(
                            "localMd5" to "",
                            "remoteMd5" to "",
                            "localVersion" to "1.4.8",
                            "localBuildNumber" to 3,
                            "remoteVersion" to "",
                            "remoteBuildNumber" to 0,
                            "playStoreVersion" to "",
                            "resolvedApkUrl" to apkUrl,
                            "releaseNotes" to "",
                            "installerPackageName" to ""
                        )
                    )
                }
            }
        }.start()
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
