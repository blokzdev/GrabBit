package dev.blokz.grabbit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/// Foreground service that keeps the process alive (and OS-compliant) while the
/// in-process download queue runs. The progress notification is built and owned
/// here; its "Stop" action is routed back to Dart via [ServiceFlutterApi].
class DownloadService : Service() {
    companion object {
        const val channelId = "grabbit_downloads"
        const val notificationId = 42
        const val actionStop = "dev.blokz.grabbit.STOP"
        const val extraText = "text"
        const val extraProgress = "progress"
        const val extraIndeterminate = "indeterminate"

        /// Set by MainActivity while the FlutterEngine is alive.
        @Volatile
        var flutterApi: ServiceFlutterApi? = null
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == actionStop) {
            flutterApi?.onStopRequested {}
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val text = intent?.getStringExtra(extraText) ?: "Downloading…"
        val progress = intent?.getIntExtra(extraProgress, 0) ?: 0
        val indeterminate = intent?.getBooleanExtra(extraIndeterminate, true) ?: true
        startForegroundCompat(buildNotification(text, progress, indeterminate))
        return START_NOT_STICKY
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(notificationId, notification)
        }
    }

    private fun buildNotification(
        text: String,
        progress: Int,
        indeterminate: Boolean,
    ): Notification {
        createChannel()
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentPi = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_IMMUTABLE,
        )
        val stopPi = PendingIntent.getService(
            this,
            1,
            Intent(this, DownloadService::class.java).setAction(actionStop),
            PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("GrabBit")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, progress, indeterminate)
            .setContentIntent(contentPi)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPi)
            .build()
    }

    private fun createChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(channelId) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    "Downloads",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
    }
}
