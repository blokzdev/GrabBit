package dev.blokz.grabbit

import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.cozodb.CozoDb

/// Pigeon HostApi backed by the cozo_android AAR (CozoDB). Queries run on a
/// background dispatcher and results are posted back on the main thread. A single
/// SQLite-backed handle is held for the app's lifetime and released on close.
///
/// If the native library isn't bundled for this device's ABI, constructing
/// CozoDb throws UnsatisfiedLinkError/NoClassDefFoundError; openDb reports false
/// so graph features degrade gracefully (the download core is unaffected).
class CozoHost : CozoHostApi {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var db: CozoDb? = null

    override fun openDb(path: String, callback: (Result<Boolean>) -> Unit) {
        scope.launch {
            val result = runCatching {
                if (db == null) {
                    // "sqlite": a single persistent file (smaller than rocksdb,
                    // survives process death). Loaded via the existing
                    // useLegacyPackaging/extractNativeLibs setup.
                    db = CozoDb("sqlite", path, "")
                }
                true
            }.recoverCatching { e ->
                if (e is UnsatisfiedLinkError || e is NoClassDefFoundError) {
                    false
                } else {
                    throw e
                }
            }
            post { callback(result) }
        }
    }

    override fun runScript(
        script: String,
        paramsJson: String,
        callback: (Result<String>) -> Unit,
    ) {
        scope.launch {
            val result = runCatching {
                val handle = db ?: error("Cozo database is not open")
                handle.query(script, paramsJson)
            }
            post { callback(result) }
        }
    }

    override fun closeDb(callback: (Result<Unit>) -> Unit) {
        scope.launch {
            val result = runCatching {
                db?.close()
                db = null
            }
            post { callback(result) }
        }
    }

    private fun post(block: () -> Unit) = mainHandler.post(block)
}
