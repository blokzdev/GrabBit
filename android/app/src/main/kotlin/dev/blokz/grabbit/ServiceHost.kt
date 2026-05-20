package dev.blokz.grabbit

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import androidx.core.content.ContextCompat

/// Pigeon HostApi: starts/updates/stops [DownloadService] and probes whether the
/// active network is unmetered (for the Wi-Fi-only setting).
class ServiceHost(private val context: Context) : ServiceHostApi {
    override fun startService(text: String, progress: Long, indeterminate: Boolean) {
        val intent = Intent(context, DownloadService::class.java)
            .putExtra(DownloadService.extraText, text)
            .putExtra(DownloadService.extraProgress, progress.toInt())
            .putExtra(DownloadService.extraIndeterminate, indeterminate)
        ContextCompat.startForegroundService(context, intent)
    }

    override fun updateNotification(text: String, progress: Long, indeterminate: Boolean) =
        startService(text, progress, indeterminate)

    override fun stopService() {
        context.stopService(Intent(context, DownloadService::class.java))
    }

    override fun isUnmetered(callback: (Result<Boolean>) -> Unit) {
        val cm = context.getSystemService(ConnectivityManager::class.java)
        val caps = cm?.getNetworkCapabilities(cm.activeNetwork)
        val unmetered = caps?.hasCapability(
            NetworkCapabilities.NET_CAPABILITY_NOT_METERED,
        ) ?: false
        callback(Result.success(unmetered))
    }
}
