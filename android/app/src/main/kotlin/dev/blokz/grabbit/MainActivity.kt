package dev.blokz.grabbit

import android.content.Intent
import android.view.WindowManager
import dev.blokz.grabbit.cozo.CozoHost
import dev.blokz.grabbit.cozo.CozoHostApi
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth.
class MainActivity : FlutterFragmentActivity() {
    private val warmupScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var storageHost: StorageHost? = null
    private var shareFlutterApi: ShareFlutterApi? = null

    // Set from the launch intent (cold start) and consumed once by Dart via
    // takeInitialSharedText; warm-start shares are pushed through shareFlutterApi.
    private var pendingSharedText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The launch intent is available by the time the engine is configured.
        pendingSharedText = sharedTextFrom(intent)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val flutterApi = YtDlpFlutterApi(messenger)
        YtDlpHostApi.setUp(messenger, YtDlpHost(applicationContext, flutterApi))
        CozoHostApi.setUp(messenger, CozoHost())
        ServiceHostApi.setUp(messenger, ServiceHost(applicationContext))
        DownloadService.flutterApi = ServiceFlutterApi(messenger)
        storageHost = StorageHost(this).also { StorageHostApi.setUp(messenger, it) }
        shareFlutterApi = ShareFlutterApi(messenger)
        ShareHostApi.setUp(messenger, object : ShareHostApi {
            override fun takeInitialSharedText(): String? {
                val text = pendingSharedText
                pendingSharedText = null
                return text
            }
        })
        // FLAG_SECURE blocks screenshots and hides content in the recents preview (P9e).
        PrivacyHostApi.setUp(messenger, object : PrivacyHostApi {
            override fun setSecureFlag(enabled: Boolean) {
                runOnUiThread {
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                }
            }
        })
        // Warm up the engine (first run extracts Python) so the first probe is fast.
        warmupScope.launch { runCatching { YtDlpEngine.ensureInitialized(applicationContext) } }
    }

    // A share that arrives while the app is already running. singleTop routes it
    // here instead of relaunching, so push it straight to Dart.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = sharedTextFrom(intent) ?: return
        val api = shareFlutterApi
        if (api != null) api.onSharedText(text) {} else pendingSharedText = text
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        storageHost?.onActivityResult(requestCode, resultCode, data)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        DownloadService.flutterApi = null
        storageHost = null
        shareFlutterApi = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        // Extracts shared text from an ACTION_SEND / ACTION_SEND_MULTIPLE intent.
        private fun sharedTextFrom(intent: Intent?): String? {
            if (intent == null) return null
            return when (intent.action) {
                Intent.ACTION_SEND ->
                    intent.getStringExtra(Intent.EXTRA_TEXT)?.takeIf { it.isNotBlank() }
                Intent.ACTION_SEND_MULTIPLE ->
                    intent.getStringArrayListExtra(Intent.EXTRA_TEXT)
                        ?.filterNotNull()
                        ?.joinToString("\n")
                        ?.takeIf { it.isNotBlank() }
                else -> null
            }
        }
    }
}
