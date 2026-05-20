package dev.blokz.grabbit

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val warmupScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val flutterApi = YtDlpFlutterApi(messenger)
        YtDlpHostApi.setUp(messenger, YtDlpHost(applicationContext, flutterApi))
        ServiceHostApi.setUp(messenger, ServiceHost(applicationContext))
        DownloadService.flutterApi = ServiceFlutterApi(messenger)
        // Warm up the engine (first run extracts Python) so the first probe is fast.
        warmupScope.launch { runCatching { YtDlpEngine.ensureInitialized(applicationContext) } }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        DownloadService.flutterApi = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
